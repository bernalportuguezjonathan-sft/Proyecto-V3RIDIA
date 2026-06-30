import 'dart:async';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'home.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'historial.dart';
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
      builder: (context) => AlertDialog(
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E5631).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
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
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
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
                                borderRadius: BorderRadius.circular(12),
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
                          onTap: () {},
                        ),
                        _crearOpcionPerfil(
                          icon: Icons.bookmark_outline,
                          titulo: 'Mis publicaciones',
                          onTap: () {},
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
                          onTap: () {},
                        ),
                        _crearOpcionPerfil(
                          icon: Icons.info_outline,
                          titulo: 'Acerca de Veridia',
                          onTap: () {},
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
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
