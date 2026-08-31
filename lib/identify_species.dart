import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'historial.dart';
import 'models/observation.dart';
import 'models/user.dart';
import 'refugio.dart';
import 'services/consejo_mascota.dart';
import 'services/economia.dart';
import 'services/especie_ia_service.dart';
import 'services/foto_service.dart';
import 'services/repositorio_m.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'services/ubicacion_foto.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
import 'widgets/mascota_vista.dart';
import 'widgets/veridia_ui.dart';

class IdentifySpeciesScreen extends StatefulWidget {
  const IdentifySpeciesScreen({super.key});

  @override
  State<IdentifySpeciesScreen> createState() => _IdentifySpeciesScreenState();
}

class _IdentifySpeciesScreenState extends State<IdentifySpeciesScreen> {
  bool _photoTaken = false;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMimeType;

  /// Dónde se tomó la observación. Se resuelve por foto (EXIF) y solo se
  /// cae al GPS del dispositivo si la imagen no trae coordenadas.
  UbicacionFoto _ubicacion = const UbicacionFoto.desconocida();
  String _mensajeUbicacion = 'Toma o elige una foto para ubicar la especie.';
  String? _selectedSpecies;
  final ImagePicker _imagePicker = ImagePicker();
  final EspecieIAService _especieIAService = EspecieIAService();

  bool _isAnalyzing = false;
  bool _isSaving = false;
  SpeciesIdentification? _aiResult;
  String? _aiError;

  /// Lo que valdría la foto que se está encuadrando ahora mismo.
  ///
  /// Se recalcula al abrir la pantalla, al ubicar la foto y al identificarla:
  /// son los tres momentos en los que cambia algo que la mascota mire.
  ContextoFoto? _contextoMascota;

  @override
  void initState() {
    super.initState();
    // Se pide el permiso de una vez para que el diálogo del sistema no
    // aparezca en mitad del flujo de la foto, pero la ubicación que se
    // guarda NO se decide aquí: se decide en _resolverUbicacion().
    Geolocator.requestPermission().ignore();
    unawaited(_recalcularPreviaMascota());
  }

  /// Le pregunta al repositorio cuánto pagaría esta foto, con el MISMO
  /// cálculo que se usará al guardarla.
  ///
  /// Adelantarlo es el punto de toda la mecánica: enterarte de que estabas
  /// sobre un humedal cuando la foto ya está guardada no cambia nada, pero
  /// saberlo con la cámara en la mano sí te mueve cien metros.
  Future<void> _recalcularPreviaMascota() async {
    final perfil = UserRepository.instance.currentUser.value;
    if (perfil == null) return;

    final contexto = await ObservationRepository.instance.contextoDeFoto(
      userId: perfil.userId,
      momento: DateTime.now(),
      latitude: _ubicacion.latitude,
      longitude: _ubicacion.longitude,
      tipoEspecie: _aiResult?.type,
      especieActual: _aiResult?.commonName,
    );
    if (!mounted) return;
    setState(() => _contextoMascota = contexto);
  }

  Future<void> _takePhotoFromCamera() async {
    await _pickPhoto(ImageSource.camera, 'cámara');
  }

  Future<void> _pickPhotoFromGallery() async {
    await _pickPhoto(ImageSource.gallery, 'galería');
  }

  Future<void> _pickPhoto(ImageSource source, String sourceLabel) async {
    try {
      // Sin `imageQuality`: ese parámetro hace que el selector reescriba el
      // JPEG y en el camino BORRA el EXIF, que es de donde sacamos dónde y
      // cuándo se tomó la foto de verdad.
      final XFile? photo = await _imagePicker.pickImage(source: source);
      if (photo == null) return;

      final mimeType = photo.mimeType ?? 'image/jpeg';
      final bytes = await photo.readAsBytes();
      if (!mounted) return;

      setState(() {
        if (kIsWeb) {
          _selectedImageBytes = bytes;
          _selectedImageFile = null;
        } else {
          _selectedImageFile = File(photo.path);
          _selectedImageBytes = null;
        }
        _selectedImageMimeType = mimeType;
        _photoTaken = true;
        _aiResult = null;
        _aiError = null;
        _ubicacion = const UbicacionFoto.desconocida();
        _mensajeUbicacion = 'Ubicando la foto...';
      });

      await _resolverUbicacion(bytes, esCamara: source == ImageSource.camera);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la $sourceLabel: $e')),
        );
      }
    }
  }

  /// Decide dónde se tomó la foto.
  ///
  /// Prioridad: las coordenadas que la propia foto trae en su EXIF y, solo si
  /// no las trae, el GPS del celular. Es lo que evita que una foto tomada en
  /// casa quede registrada donde el explorador la subió.
  Future<void> _resolverUbicacion(
    Uint8List bytes, {
    required bool esCamara,
  }) async {
    final ubicacion = await ubicacionDeObservacion(bytes);
    if (!mounted) return;

    setState(() {
      _ubicacion = ubicacion;
      _mensajeUbicacion = switch (ubicacion.origen) {
        OrigenUbicacion.foto =>
          'Tomada en ${ubicacion.etiqueta} (según la foto)',
        OrigenUbicacion.dispositivo =>
          esCamara
              ? 'Tomada en ${ubicacion.etiqueta}'
              : 'La foto no trae ubicación; se usará donde estás ahora '
                    '(${ubicacion.etiqueta})',
        OrigenUbicacion.desconocida =>
          'Sin ubicación: la foto no la trae y el GPS no respondió. '
              'Se guardará sin punto en el mapa.',
      };
    });
    unawaited(_recalcularPreviaMascota());
  }

  Future<void> _analizarConIA() async {
    final bytes =
        _selectedImageBytes ?? await _selectedImageFile?.readAsBytes();
    if (bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _aiResult = null;
      _aiError = null;
    });

    try {
      // La Cloud Function `identificarEspecie` revisa fotos repetidas ANTES
      // de llamar a Gemini (así una foto ya usada no gasta cuota de IA) y
      // devuelve un [SpeciesIdentification] que ya trae el sha256 que hará
      // falta al guardar.
      final result = await _especieIAService.identify(
        bytes,
        _selectedImageMimeType ?? 'image/jpeg',
        origen: 'una observación',
      );
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        if (result.identified && result.commonName != null) {
          _selectedSpecies = result.commonName;
        }
      });
      // Ya se sabe QUÉ es: la mariquita puede confirmar si era un cultivo y
      // el colibrí si la especie cuenta como nueva del día.
      unawaited(_recalcularPreviaMascota());
    } on FotoDuplicadaException catch (e) {
      if (!mounted) return;
      setState(() => _aiError = e.message);
    } on SpeciesIdentificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = 'Ocurrió un error inesperado analizando la foto.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _guardarObservacion() async {
    final aiIdentified = _aiResult?.identified == true;
    final currentUser = UserRepository.instance.currentUser.value;
    if (currentUser == null) {
      _mostrarError('Debes iniciar sesión para guardar observaciones.');
      return;
    }

    setState(() => _isSaving = true);

    final observationId = ObservationRepository.instance.nuevoId();

    String? imageUrl;
    String? errorFoto;
    final bytes =
        _selectedImageBytes ?? await _selectedImageFile?.readAsBytes();

    if (bytes != null) {
      final subida = await FotoService.instance.subirFotoObservacion(
        bytes: bytes,
        userId: currentUser.userId,
        observationId: observationId,
        mimeType: _selectedImageMimeType ?? 'image/jpeg',
      );
      imageUrl = subida.url;
      errorFoto = subida.error;
    }

    List<String> mensajesDesafios = const [];

    if (aiIdentified) {
      // La IA sí identificó algo: guardar y avanzar desafíos es trabajo del
      // servidor (Cloud Function `guardarObservacion`), que ya tiene en
      // caché la identificación que Gemini dio para este sha256 — el
      // cliente no le manda su propio `_aiResult`, así que no hay forma de
      // fingir un resultado distinto.
      try {
        final resultado = await ObservationRepository.instance.guardarConIA(
          identificacion: _aiResult!,
          observationId: observationId,
          imageUrl: imageUrl,
          latitude: _ubicacion.latitude,
          longitude: _ubicacion.longitude,
          location: _ubicacion.etiqueta,
        );
        mensajesDesafios = resultado.avances.map((avance) {
          final palabra = avance.veridiumsGanados == 1
              ? 'Veridium'
              : 'Veridiums';
          return avance.completado
              ? '🏆 Completaste "${avance.title}" — '
                    '¡+${avance.veridiumsGanados} $palabra!'
              : '🎯 Avanzaste en "${avance.title}": '
                    '${avance.progreso}/${avance.meta} '
                    '(+${avance.veridiumsGanados} $palabra)';
        }).toList();

        // Lo que pagó la foto en sí, aparte de los desafíos: el Veridium base
        // y, si la mascota que lleva puesta aportó algo, por qué. Decirlo es
        // la mitad de la mecánica: una mejora que suma en silencio no enseña
        // a nadie que salir de noche o acercarse al humedal vale más.
        if (resultado.veridiumsPorLaFoto > 0) {
          final palabra = resultado.veridiumsPorLaFoto == 1
              ? 'Veridium'
              : 'Veridiums';
          final bono = resultado.bonoMascota;
          mensajesDesafios = [
            '📷 Foto verificada: +${resultado.veridiumsPorLaFoto} $palabra',
            if (bono != null) '🐾 ${bono.motivo} (+${bono.veridiums})',
            ...mensajesDesafios,
          ];
        }
      } on GuardarObservacionException catch (e) {
        if (mounted) setState(() => _isSaving = false);
        _mostrarError(e.message);
        return;
      } catch (e) {
        if (mounted) setState(() => _isSaving = false);
        _mostrarError('No se pudo guardar la observación: $e');
        return;
      }
    } else {
      // Sin IA (especie elegida a mano de la guía): no otorga Veridiums ni
      // toca ningún desafío, así que sigue escribiendo directo desde aquí.
      final observation = Observation(
        id: observationId,
        commonName: _selectedSpecies ?? 'Especie observada',
        scientificName: _selectedSpecies != null
            ? 'Referencia visual'
            : 'Sin confirmar',
        location: _ubicacion.etiqueta,
        notes: 'Registrado desde la guía de observación',
        dateTime: _ubicacion.fecha ?? DateTime.now(),
        imagePath: imageUrl,
        latitude: _ubicacion.latitude,
        longitude: _ubicacion.longitude,
        type: null,
        userId: currentUser.userId,
        userDisplayName: currentUser.displayName,
      );

      try {
        await ObservationRepository.instance
            .addObservation(observation)
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        if (mounted) setState(() => _isSaving = false);
        final mensaje = e is TimeoutException
            ? 'La conexión está muy lenta y no se pudo guardar. Revisa tu internet e intenta de nuevo.'
            : 'No se pudo guardar la observación: $e';
        _mostrarError(mensaje);
        return;
      }
    }

    if (mounted) setState(() => _isSaving = false);
    if (!mounted) return;

    // La observación quedó guardada, pero sin foto: hay que decirlo en vez
    // de dejar una tarjeta vacía y que parezca un fallo de la app.
    if (errorFoto != null) {
      _mostrarError('Se guardó la observación, pero sin foto. $errorFoto');
    }

    if (mensajesDesafios.isNotEmpty) {
      final avances = mensajesDesafios.any(
        (m) => m.startsWith('🎯') || m.startsWith('🏆'),
      );
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            avances ? '¡Desafío actualizado!' : '¡Veridiums ganados!',
          ),
          content: Text(mensajesDesafios.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Genial'),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;
    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HistoryScreen()),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    mostrarErrorVeridia(context, mensaje);
  }

  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Identificar especie',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: VeridiaColors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          VeridiaAppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Container(color: VeridiaColors.background),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: VeridiaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.my_location,
                                size: 18,
                                color: VeridiaColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ubicación del avistamiento',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mensajeUbicacion,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Enfoca una planta o un animal y la IA te dirá '
                            'qué especie es. Cada identificación queda en tu '
                            'diario y suma para tus desafíos.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_contextoMascota != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _PreviaMascota(contexto: _contextoMascota!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: VeridiaSectionTitle(
                      title: 'Tus identificaciones',
                      subtitle: 'Especies que ya registraste con la IA',
                      actionLabel: 'Ver diario',
                      onAction: () =>
                          VeridiaNav.abrir(context, const HistoryScreen()),
                    ),
                  ),
                  _MisIdentificaciones(
                    onSeleccionar: (nombre) =>
                        setState(() => _selectedSpecies = nombre),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedSpecies != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VeridiaColors.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Seleccionada: $_selectedSpecies',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: VeridiaColors.primary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _captureOption(
                                icon: Icons.photo_library,
                                label: 'Galería',
                                onTap: _pickPhotoFromGallery,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _captureOption(
                                icon: Icons.camera_alt,
                                label: 'Cámara',
                                onTap: _takePhotoFromCamera,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_photoTaken)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: veridiaCaraClay(
                            VeridiaColors.surfaceContainer,
                          ),
                          borderRadius: BorderRadius.circular(VeridiaRadii.md),
                          border: Border.all(
                            color: VeridiaCard.bordePorDefecto,
                          ),
                          boxShadow: veridiaRelieve(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sugerencia de ruta',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ve hacia el humedal en la mañana si buscas garzas y patos. Para otras aves, recorre el bosque y el sendero ecológico.',
                              style: TextStyle(
                                fontSize: 12,
                                color: VeridiaColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_photoTaken)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 220,
                            decoration: BoxDecoration(
                              color: VeridiaColors.outlineVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _selectedImageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : _selectedImageFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.file(
                                      _selectedImageFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 64,
                                      color: VeridiaColors.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: VeridiaBotonTactil(
                              // El único botón de la app con destello
                              // permanente: es la acción estrella (la IA) y
                              // en la referencia el botón "premium" es
                              // justamente el que brilla solo.
                              destelloContinuo: !_isAnalyzing,
                              radius: VeridiaRadii.pill,
                              child: OutlinedButton.icon(
                                onPressed: _isAnalyzing ? null : _analizarConIA,
                                icon: _isAnalyzing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: VeridiaColors.primary,
                                        ),
                                      )
                                    : const VeridiaChispaIA(
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: VeridiaColors.primary,
                                        ),
                                      ),
                                label: Text(
                                  _isAnalyzing
                                      ? 'Analizando foto...'
                                      : _aiResult == null
                                      ? 'Analizar con IA'
                                      : 'Analizar de nuevo',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: VeridiaColors.primary,
                                  side: const BorderSide(
                                    color: VeridiaColors.primary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  // Píldora, como el resto de botones. El
                                  // radio fijo de 10 que había aquí anulaba
                                  // la forma del tema y dejaba este botón
                                  // rectangular en medio de puras píldoras.
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          ),
                          if (_aiError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: VeridiaColors.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: VeridiaColors.error),
                              ),
                              child: Text(
                                _aiError!,
                                style: TextStyle(
                                  color: VeridiaColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          if (_aiResult != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: VeridiaColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: _aiResult!.identified
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.auto_awesome,
                                              size: 18,
                                              color: VeridiaColors.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _aiResult!.commonName ??
                                                    'Especie identificada',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: VeridiaColors.primary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Confianza: ${_aiResult!.confidence}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: VeridiaColors
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_aiResult!.scientificName != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              _aiResult!.scientificName!,
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                fontSize: 12,
                                                color: VeridiaColors
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        if (_aiResult!.description != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              _aiResult!.description!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  : Text(
                                      _aiResult!.reason ??
                                          'La IA no pudo identificar una especie en esta foto.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: VeridiaColors.onSurfaceVariant,
                                      ),
                                    ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: VeridiaBotonTactil(
                              child: ElevatedButton(
                                onPressed: _isSaving
                                    ? null
                                    : _guardarObservacion,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: VeridiaColors.onSurface,
                                        ),
                                      )
                                    : const Text(
                                        'Guardar observación',
                                        style: TextStyle(
                                          color: VeridiaColors.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: VeridiaBottomNav(
        currentIndex: 1,
        onTap: (i) => VeridiaNav.ir(context, VeridiaSeccion.values[i], 1),
      ),
    );
  }

  Widget _captureOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: veridiaCaraClay(VeridiaColors.surfaceContainer),
          borderRadius: BorderRadius.circular(VeridiaRadii.md),
          border: Border.all(color: VeridiaCard.bordePorDefecto),
          boxShadow: veridiaRelieve(),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: VeridiaColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: VeridiaColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrusel con las especies que el propio explorador ya identificó.
/// Sustituye a la antigua lista de ejemplo: aquí todo lo que se ve es real.
class _MisIdentificaciones extends StatelessWidget {
  const _MisIdentificaciones({required this.onSeleccionar});

  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final uid = UserRepository.instance.currentUser.value?.userId;
    if (uid == null) return const SizedBox.shrink();

    return SizedBox(
      height: 190,
      child: StreamBuilder<List<Observation>>(
        stream: ObservationRepository.instance.streamForUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const VeridiaLoader();
          }

          final observaciones = snapshot.data ?? const <Observation>[];
          if (observaciones.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VeridiaCard(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: VeridiaColors.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(VeridiaRadii.md),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        color: VeridiaColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Todavía no identificaste ninguna especie. '
                        'Toma o sube una foto para empezar.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final visibles = observaciones.take(10).toList();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: visibles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final obs = visibles[index];
              return SizedBox(
                width: 170,
                child: VeridiaCard(
                  padding: EdgeInsets.zero,
                  onTap: () => onSeleccionar(obs.commonName),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(VeridiaRadii.lg),
                        ),
                        child: SizedBox(
                          height: 104,
                          width: double.infinity,
                          child: obs.hasPhoto
                              ? Image.network(
                                  obs.imagePath!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const _SinFoto(),
                                )
                              : const _SinFoto(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              obs.commonName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              obs.scientificName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VeridiaColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: const Icon(
        Icons.eco_outlined,
        color: VeridiaColors.primary,
        size: 24,
      ),
    );
  }
}

/// Lo que la mascota adelanta sobre la foto que se va a tomar.
///
/// Verde cuando la mejora va a pagar, apagada cuando no — y en ese caso dice
/// qué faltaría. Un "+0" mudo no le enseña a nadie que su rana rinde en los
/// humedales; "no hay humedal cerca" sí.
class _PreviaMascota extends StatelessWidget {
  const _PreviaMascota({required this.contexto});

  final ContextoFoto contexto;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: UserRepository.instance.currentUser,
      builder: (context, perfil, _) => ValueListenableBuilder<Set<String>>(
        valueListenable: MascotaRepository.instance.inventario,
        builder: (context, _, _) {
          final repo = MascotaRepository.instance;
          final mascota = repo.mascotaActiva(perfil);
          if (mascota == null) return const SizedBox.shrink();

          final previa = previaDeMascota(mascota.id, contexto);
          final acento = previa.suma
              ? VeridiaColors.secondary
              : VeridiaColors.outline;

          return VeridiaCard(
            padding: const EdgeInsets.all(12),
            borderColor: acento.withValues(alpha: 0.45),
            onTap: () => abrirRefugio(context),
            // Su propio contenido YA es la mascota: no se le suma la
            // animación de prensado encima.
            animarPresion: false,
            child: Row(
              children: [
                MascotaVista(
                  mascota: mascota,
                  equipado: repo.equipados(perfil),
                  tamano: 44,
                  animar: previa.suma,
                  opacidad: previa.suma ? 1 : 0.55,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mascota.mejora,
                            style: TextStyle(
                              fontFamily: VeridiaFonts.body,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: mascota.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (previa.suma)
                            VeridiaTag(
                              label: '+${previa.veridiums}',
                              icon: Icons.bolt_rounded,
                              color: VeridiaColors.secondary,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        previa.mensaje,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
