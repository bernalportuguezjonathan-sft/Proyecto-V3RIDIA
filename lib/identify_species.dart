import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'login.dart';
import 'home.dart';
import 'mapa.dart';
import 'historial.dart';
import 'perfil.dart';
import 'models/observation.dart';
import 'services/especie_ia_service.dart';
import 'services/foto_service.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';

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

  final List<_BirdSpeciesGuide> _speciesGuides = [
    _BirdSpeciesGuide(
      name: 'Garza blanca',
      scientificName: 'Egretta thula',
      location: 'Humedal de Mosquera, sector este',
      description: 'Ave frecuente en humedales y zonas de agua quieta.',
      imageUrl:
          'https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&w=800&q=80',
      region: 'Humedal',
    ),
    _BirdSpeciesGuide(
      name: 'Tórtola',
      scientificName: 'Columbina talpacoti',
      location: 'Bosque del Cerro El Chical',
      description: 'Se observa en zonas abiertas y bordes de bosque.',
      imageUrl:
          'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=800&q=80',
      region: 'Bosque',
    ),
    _BirdSpeciesGuide(
      name: 'Cotorra',
      scientificName: 'Amazona autumnalis',
      location: 'Laguna de la Vereda Norte',
      description:
          'Ave llamativa de áreas con árboles grandes y vegetación densa.',
      imageUrl:
          'https://images.unsplash.com/photo-1444464666168-49d633b86797?auto=format&fit=crop&w=800&q=80',
      region: 'Laguna',
    ),
    _BirdSpeciesGuide(
      name: 'Cucarachero',
      scientificName: 'Troglodytes aedon',
      location: 'Sendero El Jardín',
      description: 'Pequeña ave de sotobosque y jardines con vegetación alta.',
      imageUrl:
          'https://images.unsplash.com/photo-1470115636492-6d2b56f9596d?auto=format&fit=crop&w=800&q=80',
      region: 'Sendero',
    ),
  ];

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
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red.shade700),
    );
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await UserRepository.instance.signOut();
              if (!mounted) return;
              if (navigator.canPop()) {
                navigator.pop();
              }
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Identificar especie',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F9F7)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Guía de observación en Mosquera',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tu ubicación actual: $_currentLocation',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Recomendación: dirige tu recorrido hacia humedales o zonas de bosque temprano en la mañana.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Especies reales para identificar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _speciesGuides.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final guide = _speciesGuides[index];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSpecies = guide.name),
                          child: Container(
                            width: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    guide.imageUrl,
                                    height: 110,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        guide.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        guide.scientificName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        guide.region,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E5631),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
                              color: const Color(
                                0xFF1E5631,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Seleccionada: $_selectedSpecies',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5631),
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
                          color: Colors.white,
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
                                color: Colors.grey.shade700,
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
                              color: Colors.grey.shade300,
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
                                      color: Colors.grey,
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
                                        color: Color(0xFF1E5631),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome,
                                      color: Color(0xFF1E5631),
                                    ),
                              label: Text(
                                _isAnalyzing
                                    ? 'Analizando foto...'
                                    : _aiResult == null
                                    ? 'Analizar con IA'
                                    : 'Analizar de nuevo',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1E5631),
                                side: const BorderSide(
                                  color: Color(0xFF1E5631),
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
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _aiError!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
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
                                color: const Color(
                                  0xFF1E5631,
                                ).withValues(alpha: 0.08),
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
                                              color: Color(0xFF1E5631),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _aiResult!.commonName ??
                                                    'Especie identificada',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E5631),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Confianza: ${_aiResult!.confidence}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
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
                                                color: Colors.grey.shade700,
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
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : _guardarObservacion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E5631),
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
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Guardar observación',
                                      style: TextStyle(
                                        color: Colors.white,
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E5631),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Cámara',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
              break;
            case 1:
              break; // Ya estamos aquí
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              break;
          }
        },
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
          color: Colors.white,
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
            Icon(icon, size: 24, color: const Color(0xFF1E5631)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E5631),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BirdSpeciesGuide {
  const _BirdSpeciesGuide({
    required this.name,
    required this.scientificName,
    required this.location,
    required this.description,
    required this.imageUrl,
    required this.region,
  });

  final String name;
  final String scientificName;
  final String location;
  final String description;
  final String imageUrl;
  final String region;
}
