import 'dart:async';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'acerca_de.dart';
import 'actividad.dart';
import 'ajustes.dart';
import 'models/observation.dart';
import 'models/recompensa.dart';
import 'models/user.dart';
import 'publicaciones.dart';
import 'recompensas.dart';
import 'services/foto_service.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_r.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
import 'widgets/veridia_ui.dart';

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

  /// Recompensas digitales que el explorador ya canjeó: marco del avatar,
  /// título junto al nombre e insignias.
  Recompensa? get _marco => RewardRepository.instance.marcoActivo();
  String? get _titulo => RewardRepository.instance.tituloActivo();
  List<Recompensa> get _insignias => RewardRepository.instance
      .desbloqueadas()
      .where((r) => r.tipo == TipoRecompensa.insignia)
      .toList();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
    _loadCachedProfileImage();

    UserRepository.instance.currentUser.addListener(_onUserProfileChanged);
    // Sin esto, una recompensa recién canjeada no se vería en el perfil
    // hasta reabrir la pantalla.
    RewardRepository.instance.misCanjes.addListener(_onCanjesChanged);
  }

  void _onCanjesChanged() {
    if (mounted) setState(() {});
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
    RewardRepository.instance.misCanjes.removeListener(_onCanjesChanged);
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
                color: VeridiaColors.onSurface,
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

  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VeridiaColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil',
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
                          VeridiaColors.primary,
                          VeridiaColors.primaryContainer,
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
                                color: VeridiaColors.surfaceContainer,
                                shape: BoxShape.circle,
                                // El marco es una recompensa canjeada: si no
                                // tiene ninguno, el avatar va sin borde.
                                border: _marco == null
                                    ? null
                                    : Border.all(
                                        color: _marco!.color,
                                        width: 3,
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _marco?.color.withValues(alpha: 0.35) ??
                                        const Color.fromRGBO(0, 0, 0, 0.2),
                                    blurRadius: _marco == null ? 8 : 16,
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
                                                    color:
                                                        VeridiaColors.primary,
                                                  ),
                                                ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 48,
                                          color: VeridiaColors.primary,
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
                                      ? VeridiaColors.onSurface
                                      : VeridiaColors.onSurfaceVariant,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: VeridiaColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: _isEditingProfile
                                      ? VeridiaColors.primary
                                      : VeridiaColors.onSurfaceVariant,
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
                            color: VeridiaColors.onSurface,
                          ),
                        ),
                        if (_titulo != null) ...[
                          const SizedBox(height: 6),
                          VeridiaTag(
                            label: _titulo!,
                            icon: Icons.workspace_premium_rounded,
                            color: VeridiaColors.veridium,
                            dense: true,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _currentUser?.email ?? 'email@example.com',
                          style: const TextStyle(
                            fontSize: 14,
                            color: VeridiaColors.onSurfaceVariant,
                          ),
                        ),
                        if (_insignias.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _insignias
                                .map(
                                  (insignia) => VeridiaTag(
                                    label:
                                        '${insignia.valor ?? ''} ${insignia.nombre}'
                                            .trim(),
                                    color: insignia.color,
                                    dense: true,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_isEditingProfile) ...[
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              color: VeridiaColors.onSurface,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: VeridiaColors.surfaceContainerHighest,
                              hintText: 'Nombre de usuario',
                              hintStyle: const TextStyle(
                                color: VeridiaColors.onSurfaceVariant,
                              ),
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
                                    backgroundColor:
                                        VeridiaColors.surfaceContainer,
                                    foregroundColor: VeridiaColors.primary,
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
                                              color: VeridiaColors.primary,
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
                                    foregroundColor: VeridiaColors.onSurface,
                                    side: const BorderSide(
                                      color: VeridiaColors.outlineVariant,
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
                              backgroundColor: VeridiaColors.surfaceContainer,
                              foregroundColor: VeridiaColors.primary,
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
                            color: VeridiaColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<List<Observation>>(
                          stream: ObservationRepository.instance.streamForUser(
                            UserRepository.instance.currentUser.value?.userId ??
                                '',
                          ),
                          builder: (context, snapshot) {
                            final observations = snapshot.data ?? [];
                            final especies = observations
                                .map((o) => o.commonName.toLowerCase())
                                .toSet()
                                .length;
                            final lugares = observations
                                .map((o) => o.location)
                                .where((l) => l.isNotEmpty)
                                .toSet()
                                .length;
                            return ValueListenableBuilder<UserProfile?>(
                              valueListenable:
                                  UserRepository.instance.currentUser,
                              builder: (context, profile, child) {
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _crearEstadistica('$especies', 'Especies'),
                                    _crearEstadistica('$lugares', 'Lugares'),
                                    _crearEstadistica(
                                      '${profile?.tokens ?? 0}',
                                      'Veridiums',
                                    ),
                                  ],
                                );
                              },
                            );
                          },
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
                            color: VeridiaColors.onSurface,
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
                        _crearOpcionPerfil(
                          icon: Icons.card_giftcard_outlined,
                          titulo: 'Recompensas y canjes',
                          onTap: () => abrirRecompensas(context),
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
                            color: VeridiaColors.onSurface,
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
        backgroundColor: VeridiaColors.surfaceContainer,
        selectedItemColor: VeridiaColors.primary,
        unselectedItemColor: VeridiaColors.onSurfaceVariant,
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
        // Delegado en VeridiaNav: hacer pushReplacement a mano aquí era
        // otra vía por la que la ruta raíz se perdía (ver navegacion.dart).
        onTap: (index) =>
            VeridiaNav.ir(context, VeridiaSeccion.values[index], 4),
      ),
    );
  }

  Widget _crearEstadistica(String valor, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: VeridiaColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: VeridiaColors.onSurfaceVariant,
            ),
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
        color: VeridiaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: VeridiaColors.primary, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: VeridiaColors.onSurface,
                    ),
                  ),
                ),
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
