import 'dart:async';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'login.dart';
import 'home.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'historial.dart';
import 'models/observation.dart';
import 'models/user.dart';
import 'services/repositorioO.dart';
import 'services/repositorioU.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User? _currentUser;
  String _userName = '';
  String? _photoURL;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _selectedProfileImageBytes;
  Uint8List? _cachedProfileImageBytes;
  String? _selectedProfileImageName;
  bool _isSaving = false;
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
    _loadCachedProfileImage();

    UserRepository.instance.currentUser.addListener(_onUserProfileChanged);
  }

  void _onUserProfileChanged() {
    final profile = UserRepository.instance.currentUser.value;
    if (mounted &&
        (profile?.photoURL != null || profile?.displayName != null)) {
      setState(() {
        if (profile?.photoURL != null) _photoURL = profile!.photoURL;
        if (profile?.displayName != null) {
          _userName = profile!.displayName;
          _nameController.text = _userName;
        }
      });
    }
  }

  void _loadUserProfile() {
    final profile = UserRepository.instance.currentUser.value;
    _userName =
        profile?.displayName ??
        _currentUser?.displayName ??
        _currentUser?.email?.split('@').first ??
        'Explorador';
    _photoURL = profile?.photoURL ?? _currentUser?.photoURL;
    _nameController.text = _userName;
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadUserProfile();
  }

  @override
  void dispose() {
    UserRepository.instance.currentUser.removeListener(_onUserProfileChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_getProfileImageCacheKey(user.uid));
    if (encoded != null && encoded.isNotEmpty && mounted) {
      setState(() {
        _cachedProfileImageBytes = base64Decode(encoded);
      });
    } else if (mounted) {
      setState(() {
        _cachedProfileImageBytes = null;
      });
    }
  }

  Future<void> _saveProfileImageLocally(Uint8List imageData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final encoded = base64Encode(imageData);
    await prefs.setString(_getProfileImageCacheKey(user.uid), encoded);

    if (mounted) {
      setState(() {
        _cachedProfileImageBytes = Uint8List.fromList(imageData);
      });
    }
  }

  String _getProfileImageCacheKey(String userId) => 'profile_image_$userId';

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 50,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();

        final compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 30,
          format: CompressFormat.jpeg,
          minWidth: 512,
          minHeight: 512,
        );

        if (compressedBytes.isEmpty) {
          throw Exception('No se pudo comprimir la imagen seleccionada.');
        }

        String fileName = photo.name;
        if (fileName.isEmpty || !fileName.contains('.')) {
          fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
        fileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        setState(() {
          _selectedProfileImageBytes = Uint8List.fromList(compressedBytes);
          _selectedProfileImageName = fileName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar la imagen: $e')),
        );
      }
    }
  }

  void _showPhotoSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar desde galería'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadProfilePhoto(Uint8List imageData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final fileName =
        _selectedProfileImageName ??
        '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child(user.uid)
        .child(fileName);

    final uploadTask = storageRef.putData(
      imageData,
      SettableMetadata(contentType: contentType),
    );

    final TaskSnapshot snapshot = await uploadTask.snapshotEvents
        .where(
          (event) =>
              event.state == TaskState.success ||
              event.state == TaskState.error ||
              event.state == TaskState.canceled,
        )
        .first
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            uploadTask.cancel();
            throw TimeoutException(
              'La subida tardó demasiado. La foto ya quedó guardada localmente.',
            );
          },
        );

    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'No se pudo subir la imagen de perfil.',
      );
    }

    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _saveProfileChanges() async {
    if (!mounted) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('El nombre de usuario no puede quedar vacío.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Guardando cambios...'),
          ],
        ),
        duration: Duration(days: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado.');
      }

      String? newPhotoURL;
      if (_selectedProfileImageBytes != null &&
          _selectedProfileImageBytes!.isNotEmpty) {
        await _saveProfileImageLocally(_selectedProfileImageBytes!);

        try {
          newPhotoURL = await _uploadProfilePhoto(_selectedProfileImageBytes!);
        } catch (uploadError) {
          if (mounted) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'La foto se guardó localmente, pero hubo un problema al sincronizarla: $uploadError',
                ),
              ),
            );
          }
        }
      }

      await user
          .updateDisplayName(newName)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException(
              'No se pudo actualizar el nombre de usuario. Revisa tu conexión e inténtalo de nuevo.',
            ),
          );
      if (newPhotoURL != null) {
        await user
            .updatePhotoURL(newPhotoURL)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw TimeoutException(
                'No se pudo actualizar la foto de perfil. Revisa tu conexión e inténtalo de nuevo.',
              ),
            );
      }

      await user.reload().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException(
          'La sesión tardó demasiado en actualizarse. Inténtalo de nuevo.',
        ),
      );

      final refreshedUser = FirebaseAuth.instance.currentUser;

      final updatedPhotoURL =
          newPhotoURL ?? refreshedUser?.photoURL ?? _photoURL;

      _photoURL = updatedPhotoURL;

      final currentProfile = UserRepository.instance.currentUser.value;
      if (currentProfile != null) {
        UserRepository.instance.currentUser.value = currentProfile.copyWith(
          displayName: newName,
          photoURL: updatedPhotoURL,
        );
      }

      setState(() {
        _currentUser = refreshedUser;
        _userName = newName;
        _photoURL = updatedPhotoURL;
        _selectedProfileImageBytes = null;
        _selectedProfileImageName = null;
        _isEditingProfile = false;
      });

      await UserRepository.instance.initializeUser();

      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Error guardando cambios: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de perfil
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E5631),
                          const Color(0xFF2D7A3F),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(30, 86, 49, 0.2),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _selectedProfileImageBytes != null
                                    ? Image.memory(
                                        _selectedProfileImageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_cachedProfileImageBytes != null)
                                    ? Image.memory(
                                        _cachedProfileImageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_photoURL != null &&
                                          _photoURL!.isNotEmpty)
                                    ? Image.network(
                                        _photoURL!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 48,
                                                    color: Color(0xFF1E5631),
                                                  ),
                                                ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 48,
                                          color: Color(0xFF1E5631),
                                        ),
                                      ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isEditingProfile
                                  ? _showPhotoSourceOptions
                                  : null,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _isEditingProfile
                                      ? Colors.white
                                      : Colors.white54,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF1E5631),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: _isEditingProfile
                                      ? const Color(0xFF1E5631)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser?.email ?? 'email@example.com',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isEditingProfile) ...[
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white24,
                              hintText: 'Nombre de usuario',
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : _saveProfileChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1E5631),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 24,
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF1E5631),
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Guardar cambios',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () {
                                          setState(() {
                                            _isEditingProfile = false;
                                            _selectedProfileImageBytes = null;
                                            _selectedProfileImageName = null;
                                            _nameController.text = _userName;
                                          });
                                        },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white70,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 24,
                                    ),
                                    child: Text('Cancelar'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isEditingProfile = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1E5631),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 24,
                              ),
                              child: Text(
                                'Modificar perfil',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Estadísticas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mi actividad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _crearEstadistica('58', 'Especies'),
                            _crearEstadistica('12', 'Rutas'),
                            _crearEstadistica('1,250', 'Puntos'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Opciones del perfil
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _crearOpcionPerfil(
                          icon: Icons.person_outline,
                          titulo: 'Mi actividad',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ActivityScreen(),
                              ),
                            );
                          },
                        ),
                        _crearOpcionPerfil(
                          icon: Icons.bookmark_outline,
                          titulo: 'Mis publicaciones',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PublicationsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Configuración
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Más',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _crearOpcionPerfil(
                          icon: Icons.settings_outlined,
                          titulo: 'Configuración',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                        _crearOpcionPerfil(
                          icon: Icons.info_outline,
                          titulo: 'Acerca de Veridia',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AboutVeridiaScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón de cerrar sesión (ahora en AppBar superior)
                  const SizedBox(height: 20),
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
        currentIndex: 4,
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const IdentifySpeciesScreen(),
                ),
              );
              break;
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
              break; // Ya estamos aquí
          }
        },
      ),
    );
  }

  Widget _crearEstadistica(String valor, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5631),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _crearOpcionPerfil({
    required IconData icon,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1E5631), size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi actividad'),
        backgroundColor: const Color(0xFF1E5631),
      ),
      body: ValueListenableBuilder<List<Observation>>(
        valueListenable: ObservationRepository.instance.observations,
        builder: (context, observations, child) {
          final totalObservations = observations.length;
          final uniqueSpecies = observations
              .map((observation) => observation.commonName)
              .toSet()
              .length;
          final lastObservation = observations.isNotEmpty
              ? observations.first.dateTime
              : null;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu huella en la naturaleza',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sigue tus descubrimientos y comprueba cómo cada aporte suma al cuidado de la flora y fauna.',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard(
                      icon: Icons.nature,
                      title: '$totalObservations',
                      subtitle: 'Observaciones',
                    ),
                    _statCard(
                      icon: Icons.flare,
                      title: '$uniqueSpecies',
                      subtitle: 'Especies únicas',
                    ),
                    _statCard(
                      icon: Icons.schedule,
                      title: lastObservation != null
                          ? '${lastObservation.day}/${lastObservation.month}/${lastObservation.year}'
                          : '-',
                      subtitle: 'Última fecha',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _infoCard(
                  icon: Icons.photo_camera,
                  title: 'Observaciones recientes',
                  description:
                      'Revisa las últimas fotos y datos que has registrado en tu viaje natural.',
                ),
                _infoCard(
                  icon: Icons.emoji_events,
                  title: 'Retos completados',
                  description:
                      'Sigue tu progreso y mira cómo avanzas con cada desafío superado.',
                ),
                _infoCard(
                  icon: Icons.monetization_on,
                  title: 'Recompensas',
                  description:
                      'Consigue monedas por cada contribución y conviértelas en logros dentro de Verídia.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1E5631), size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1E5631), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicationsScreen extends StatelessWidget {
  const PublicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis publicaciones'),
        backgroundColor: const Color(0xFF1E5631),
      ),
      body: ValueListenableBuilder<List<Observation>>(
        valueListenable: ObservationRepository.instance.observations,
        builder: (context, observations, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.bookmark_outline,
                      color: Color(0xFF1E5631),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${observations.length} publicaciones',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tus observaciones más recientes están aquí. Revísalas, edítalas o compártelas con tu comunidad.',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: observations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 72,
                                color: Color(0xFF1E5631),
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Aún no tienes publicaciones cargadas.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sube tu primera foto para empezar a construir tu colección natural.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: observations.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final observation = observations[index];
                            return _publicationCard(observation);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _publicationCard(Observation observation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nature, color: Color(0xFF1E5631), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  observation.commonName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            observation.scientificName,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  observation.location,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            observation.notes,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fecha: ${observation.dateTime.day}/${observation.dateTime.month}/${observation.dateTime.year}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'Español';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('preferred_language') ?? 'Español';
    });
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_language', language);
    setState(() {
      _selectedLanguage = language;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Idioma establecido a $language.')),
      );
    }
  }

  Future<void> _showLanguageDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Selecciona un idioma',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('Español'),
              trailing: _selectedLanguage == 'Español'
                  ? const Icon(Icons.check, color: Color(0xFF1E5631))
                  : null,
              onTap: () {
                _saveLanguage('Español');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: _selectedLanguage == 'English'
                  ? const Icon(Icons.check, color: Color(0xFF1E5631))
                  : null,
              onTap: () {
                _saveLanguage('English');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _openNotificationSettings() {
    AppSettings.openNotificationSettings();
  }

  void _openPrivacySettings() {
    AppSettings.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFF1E5631),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder<UserProfile?>(
          valueListenable: UserRepository.instance.currentUser,
          builder: (context, user, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ajustes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Personaliza tu experiencia y revisa los datos de tu cuenta en Verídia.',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                _infoTile(
                  icon: Icons.person,
                  title: 'Nombre',
                  subtitle: user?.displayName ?? 'Explorador',
                ),
                _infoTile(
                  icon: Icons.email,
                  title: 'Email',
                  subtitle: user?.email ?? 'No disponible',
                ),
                _infoTile(
                  icon: Icons.monetization_on,
                  title: 'Monedas',
                  subtitle: '${user?.tokens ?? 0}',
                ),
                const SizedBox(height: 16),
                _settingTile(
                  icon: Icons.notifications,
                  title: 'Notificaciones',
                  subtitle: 'Abrir ajustes de notificaciones del sistema.',
                  onTap: _openNotificationSettings,
                ),
                _settingTile(
                  icon: Icons.lock_outline,
                  title: 'Privacidad',
                  subtitle: 'Abrir configuración de permisos de la aplicación.',
                  onTap: _openPrivacySettings,
                ),
                _settingTile(
                  icon: Icons.language,
                  title: 'Idioma',
                  subtitle: 'Idioma actual: $_selectedLanguage',
                  onTap: _showLanguageDialog,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E5631), size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E5631), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class AboutVeridiaScreen extends StatelessWidget {
  const AboutVeridiaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de Veridia'),
        backgroundColor: const Color(0xFF1E5631),
      ),
      body: ValueListenableBuilder<List<Observation>>(
        valueListenable: ObservationRepository.instance.observations,
        builder: (context, observations, child) {
          final totalObservations = observations.length;
          final uniqueSpecies = observations
              .map((observation) => observation.commonName)
              .toSet()
              .length;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verídia',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verídia es una app pensada para gamificar de forma intuitiva y divertida el aprendizaje sobre ambientes naturales, fauna y flora. Aquí puedes explorar ecosistemas, descubrir especies y ganar recompensas mientras te conviertes en un guardián activo de la naturaleza.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _aboutStatTile(
                      icon: Icons.nature_people,
                      label: 'Observaciones',
                      value: '$totalObservations',
                    ),
                    const SizedBox(width: 12),
                    _aboutStatTile(
                      icon: Icons.eco,
                      label: 'Especies',
                      value: '$uniqueSpecies',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '¿Qué puedes hacer en Verídia?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Completar retos con fotos reales de la naturaleza.',
                ),
                const Text(
                  '• Aprender sobre especies y hábitats desde tu propia experiencia.',
                ),
                const Text(
                  '• Ganar monedas y logros por cada contribución ecológica.',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Únete a una comunidad que valora la curiosidad, el respeto por el medio ambiente y la diversión mientras aprendes.',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _aboutStatTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1E5631), size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
