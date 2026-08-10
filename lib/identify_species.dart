import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'historial.dart';
import 'models/observation.dart';
import 'services/especie_ia_service.dart';
import 'services/foto_service.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
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
  String _currentLocation = 'Obteniendo ubicación...';
  double? _latitude;
  double? _longitude;
  String? _selectedSpecies;
  final ImagePicker _imagePicker = ImagePicker();
  final EspecieIAService _especieIAService = EspecieIAService();

  bool _isAnalyzing = false;
  bool _isSaving = false;
  SpeciesIdentification? _aiResult;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    if (kIsWeb) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!mounted) return;
          setState(() {
            _currentLocation = 'Permiso de ubicación no otorgado';
          });
          return;
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (!mounted) return;
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _currentLocation =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _currentLocation = 'No se pudo obtener la ubicación en el navegador';
        });
      }
      return;
    }

    final status = await Permission.location.request();
    if (!mounted) return;

    if (status.isGranted) {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _currentLocation =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } else {
      if (!mounted) return;
      setState(() {
        _currentLocation = 'Permiso de ubicación no otorgado';
      });
    }
  }

  Future<void> _takePhotoFromCamera() async {
    await _pickPhoto(ImageSource.camera, 'cámara');
  }

  Future<void> _pickPhotoFromGallery() async {
    await _pickPhoto(ImageSource.gallery, 'galería');
  }

  Future<void> _pickPhoto(ImageSource source, String sourceLabel) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (photo == null) {
        return;
      }

      final mimeType = photo.mimeType ?? 'image/jpeg';

      if (kIsWeb) {
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFile = null;
          _selectedImageMimeType = mimeType;
          _photoTaken = true;
          _aiResult = null;
          _aiError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _selectedImageFile = File(photo.path);
          _selectedImageBytes = null;
          _selectedImageMimeType = mimeType;
          _photoTaken = true;
          _aiResult = null;
          _aiError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la $sourceLabel: $e')),
        );
      }
    }
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
      final result = await _especieIAService.identify(
        bytes,
        _selectedImageMimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        if (result.identified && result.commonName != null) {
          _selectedSpecies = result.commonName;
        }
      });
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

    final observationId = DateTime.now().millisecondsSinceEpoch.toString();

    String? imageUrl;
    final bytes =
        _selectedImageBytes ?? await _selectedImageFile?.readAsBytes();
    if (bytes != null) {
      imageUrl = await FotoService.instance.subirFotoObservacion(
        bytes: bytes,
        userId: currentUser.userId,
        observationId: observationId,
        mimeType: _selectedImageMimeType ?? 'image/jpeg',
      );
    }

    final observation = Observation(
      id: observationId,
      commonName: aiIdentified
          ? _aiResult!.commonName ?? 'Especie observada'
          : _selectedSpecies ?? 'Especie observada',
      scientificName: aiIdentified
          ? _aiResult!.scientificName ?? 'Sin confirmar'
          : _selectedSpecies != null
          ? 'Referencia visual'
          : 'Sin confirmar',
      location: _currentLocation,
      notes: aiIdentified
          ? (_aiResult!.description ?? 'Identificado con IA')
          : 'Registrado desde la guía de observación',
      dateTime: DateTime.now(),
      imagePath: imageUrl,
      latitude: _latitude,
      longitude: _longitude,
      type: aiIdentified ? _aiResult!.type : null,
      userId: currentUser.userId,
      userDisplayName: currentUser.displayName,
    );

    try {
      await ObservationRepository.instance.addObservation(observation);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      _mostrarError('No se pudo guardar la observación: $e');
      return;
    }

    final mensajesDesafios = aiIdentified
        ? await _actualizarDesafios(_aiResult!)
        : <String>[];

    if (mounted) setState(() => _isSaving = false);
    if (!mounted) return;

    if (mensajesDesafios.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¡Desafío actualizado!'),
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  /// Suma progreso a los desafíos activos cuya especie objetivo coincide con
  /// lo que identificó la IA. Devuelve los mensajes a mostrar al usuario.
  Future<List<String>> _actualizarDesafios(SpeciesIdentification ia) async {
    final mensajes = <String>[];
    final currentUserId = UserRepository.instance.currentUser.value?.userId;

    final coincidencias = ChallengeRepository.instance.challenges.value.where((
      c,
    ) {
      if (c.isCompleted) return false;
      // Solo desafíos globales o asignados a este usuario.
      if (!c.isGlobal && c.assignedToUserId != currentUserId) return false;
      return especieCoincide(c.targetSpecies, ia);
    }).toList();

    for (final challenge in coincidencias) {
      final nuevoProgreso = (challenge.currentProgress + 1).clamp(
        0,
        challenge.targetGoal,
      );
      final ganados = nuevoProgreso - challenge.currentProgress;
      if (ganados <= 0) continue;

      try {
        await ChallengeRepository.instance.updateProgress(
          challenge.id,
          nuevoProgreso,
        );
      } catch (e) {
        debugPrint('No se pudo actualizar el desafío ${challenge.id}: $e');
        continue;
      }

      final completado = nuevoProgreso >= challenge.targetGoal;
      final premio = completado ? challenge.tokensReward : ganados;
      final palabra = premio == 1 ? 'Veridium' : 'Veridiums';
      mensajes.add(
        completado
            ? '🏆 Completaste "${challenge.title}" — ¡+$premio $palabra!'
            : '🎯 Avanzaste en "${challenge.title}": $nuevoProgreso/${challenge.targetGoal} (+$premio $palabra)',
      );
    }

    return mensajes;
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: VeridiaColors.error),
    );
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
                                'Tu ubicación',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentLocation,
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
                          color: VeridiaColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
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
                                  : const Icon(
                                      Icons.auto_awesome,
                                      color: VeridiaColors.primary,
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _guardarObservacion,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
          color: VeridiaColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
