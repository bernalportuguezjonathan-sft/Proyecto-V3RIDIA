import 'dart:async';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/foto_service.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
import 'widgets/veridia_ui.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
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
        profile?.displayName ?? _currentUser?.displayName ?? 'Administrador';
    _photoURL = profile?.photoURL ?? _currentUser?.photoURL;
    _nameController.text = _userName;
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
      backgroundColor: VeridiaColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Cambiar foto de perfil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: VeridiaColors.primary,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: VeridiaColors.primary,
              ),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: VeridiaColors.primary,
                ),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: VeridiaColors.error),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Sube la foto de perfil a Supabase Storage.
  ///
  /// Lanza si no se pudo subir, para que quien llama distinga "quedó solo en
  /// este dispositivo" de "quedó guardada de verdad".
  Future<String?> _uploadProfilePhoto(Uint8List imageData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final fileName = _selectedProfileImageName ?? '';
    final contentType = fileName.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    final resultado = await FotoService.instance.subirFotoPerfil(
      bytes: imageData,
      userId: user.uid,
      mimeType: contentType,
    );

    if (!resultado.exitosa) throw Exception(resultado.error);
    return resultado.url;
  }

  Future<void> _saveProfileChanges() async {
    if (!mounted) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? newPhotoURL;
      if (_selectedProfileImageBytes != null) {
        await _saveProfileImageLocally(_selectedProfileImageBytes!);
        try {
          newPhotoURL = await _uploadProfilePhoto(_selectedProfileImageBytes!);
        } catch (uploadError) {
          // Se guardó en este dispositivo pero no en el servidor: hay que
          // decirlo, si no la foto "desaparece" al entrar desde otro equipo.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'La foto se guardó en este dispositivo, pero no se pudo '
                  'sincronizar: $uploadError',
                ),
              ),
            );
          }
        }
      }

      await user.updateDisplayName(newName);
      if (newPhotoURL != null) {
        await user.updatePhotoURL(newPhotoURL);
      }
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;
      final currentProfile = UserRepository.instance.currentUser.value;
      if (currentProfile != null) {
        UserRepository.instance.currentUser.value = currentProfile.copyWith(
          displayName: newName,
          photoURL: newPhotoURL ?? refreshedUser?.photoURL ?? _photoURL,
        );
      }

      await UserRepository.instance.initializeUser();

      setState(() {
        _currentUser = refreshedUser;
        _userName = newName;
        _photoURL = newPhotoURL ?? refreshedUser?.photoURL;
        _selectedProfileImageBytes = null;
        _selectedProfileImageName = null;
        _isEditingProfile = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserRepository.instance.currentUser.value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VeridiaColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            color: VeridiaColors.onSurface,
            fontWeight: FontWeight.bold,
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VeridiaColors.primary,
                    VeridiaColors.primaryContainer,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: VeridiaColors.surfaceContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: VeridiaColors.primary.withAlpha(77),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
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
                              : (_photoURL != null)
                              ? Image.network(
                                  _photoURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: VeridiaColors.primary,
                                      ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: VeridiaColors.primary,
                                ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isEditingProfile
                            ? _showPhotoSourceOptions
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isEditingProfile
                                ? VeridiaColors.onSurface
                                : VeridiaColors.onSurfaceVariant,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: VeridiaColors.primary,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: VeridiaColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: VeridiaColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email ?? '',
                    style: const TextStyle(
                      color: VeridiaColors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: VeridiaColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: VeridiaColors.onSurface,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Administrador',
                          style: const TextStyle(
                            color: VeridiaColors.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isEditingProfile
                      ? TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre',
                            labelStyle: const TextStyle(
                              color: VeridiaColors.primary,
                            ),
                            filled: true,
                            fillColor: VeridiaColors.surfaceContainerHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: VeridiaColors.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: VeridiaColors.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: VeridiaColors.primary,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: VeridiaColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Información',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: VeridiaColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nombre: $_userName',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Email: ${profile?.email ?? ''}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 20),
                  if (_isEditingProfile)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfileChanges,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: VeridiaColors.onSurface,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Guardar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isEditingProfile = false;
                                _selectedProfileImageBytes = null;
                                _nameController.text = _userName;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: VeridiaColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => _isEditingProfile = true),
                        icon: const Icon(
                          Icons.edit,
                          color: VeridiaColors.onSurface,
                        ),
                        label: const Text(
                          'Editar Perfil',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: VeridiaColors.onSurface,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Acciones rápidas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: VeridiaColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // "Volver al Panel" se quitó: la flecha de la barra
                  // superior ya hace exactamente lo mismo.
                  _buildActionButton(
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    onTap: _cerrarSesion,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: VeridiaColors.primary),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
