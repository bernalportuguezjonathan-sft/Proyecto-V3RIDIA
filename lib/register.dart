import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/repositorio_u.dart';
import 'models/user.dart';
import 'home.dart';
import 'admin_home.dart';
import 'theme/veridia_theme.dart';
import 'widgets/animated_visibility.dart';
import 'widgets/google_logo_icon.dart';
import 'widgets/google_web_button.dart';
import 'widgets/veridia_logo.dart';
import 'widgets/veridia_montanas.dart';
import 'widgets/veridia_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminCodeController = TextEditingController();
  String? _selectedRole;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: kIsWeb ? webGoogleClientId : null,
  );
  StreamSubscription<GoogleSignInAccount?>? _googleSignInSub;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Curves.easeOutCubic,
        ),
      );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _googleSignInSub = _googleSignIn.onCurrentUserChanged.listen((account) {
        if (account != null) {
          _completeGoogleSignIn(account);
        }
      });
    }
  }

  void _mostrarAlerta(String mensaje) {
    mostrarMensajeVeridia(context, mensaje, esError: true);
  }

  // Función principal de registro con tus validaciones
  Future<void> _registrarUsuario() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. Validación de campos en blanco
    if (name.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Nombre completo');
      return;
    }
    if (email.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Correo electrónico');
      return;
    }
    if (password.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Contraseña');
      return;
    }
    if (confirmPassword.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Confirmar contraseña');
      return;
    }

    // 2. Validación de la @
    if (!email.contains('@')) {
      _mostrarAlerta('Le hace falta la @');
      return;
    }

    // 3. Validación de 8 características
    if (password.length < 8) {
      _mostrarAlerta('La contraseña debe de tener minimo 8 caracteristicas');
      return;
    }

    // 4. Validación de que sean iguales
    if (password != confirmPassword) {
      _mostrarAlerta('Las contraseñas no coinciden');
      return;
    }

    // 5. Validación de rol seleccionado
    if (_selectedRole == null) {
      _mostrarAlerta('Por favor selecciona el tipo de usuario');
      return;
    }

    final adminCode = _adminCodeController.text.trim();
    if (_selectedRole == 'Administrador' && adminCode.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código requerido'),
          content: const Text(
            'Ingresa el código privado de administrador para continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }
    // El código NO se valida aquí: Firestore lo compara del lado del
    // servidor (ver firestore.rules) contra config/secrets, que ningún
    // cliente puede leer. Si es incorrecto, createUserProfile lanzará
    // permission-denied más abajo.

    // Si todo está perfecto, mostramos el círculo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: VeridiaLoader()),
    );

    try {
      // Intentamos crear el usuario en Firebase
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        // Create a local profile immediately so app UI can proceed even if Firestore write is blocked
        final localProfile = UserProfile(
          userId: credential.user!.uid,
          email: email,
          displayName: name,
          photoURL: null,
          tokens: 0,
          role: _selectedRole!,
          createdDate: DateTime.now(),
          isBanned: false,
          banExpires: null,
          banReason: null,
        );

        UserRepository.instance.currentUser.value = localProfile;

        try {
          await UserRepository.instance.createUserProfile(
            userId: credential.user!.uid,
            email: email,
            displayName: name,
            role: _selectedRole!,
            adminCode: adminCode.isEmpty ? null : adminCode,
          );
        } on FirebaseException catch (e) {
          if (_selectedRole == 'Administrador' &&
              e.code == 'permission-denied') {
            // Código de administrador incorrecto: no dejamos el perfil a
            // medias, deshacemos la cuenta recién creada.
            UserRepository.instance.currentUser.value = null;
            try {
              await credential.user!.delete();
            } catch (_) {
              await FirebaseAuth.instance.signOut();
            }
            if (mounted) Navigator.pop(context);
            _mostrarAlerta(
              'El código de administrador es incorrecto. Intenta de nuevo.',
            );
            return;
          }
          debugPrint('Could not persist user profile to Firestore: $e');
          await UserRepository.instance.cacheUserProfile(
            credential.user!.uid,
            0,
            _selectedRole!,
            name,
          );
          // Reintenta ya mismo: si fue un fallo de red pasajero, esto evita
          // que la cuenta quede "fantasma" (existe en Auth, invisible para
          // el admin) hasta el próximo reinicio de sesión.
          await UserRepository.instance.initializeUser();
        }
      }

      if (mounted) Navigator.pop(context); // Cerramos el círculo de carga

      // Redirigir según rol (Admin recibe diálogo de bienvenida)
      if (mounted) {
        if (_selectedRole == 'Administrador') {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Bienvenido, Administrador'),
              content: const Text('Has sido registrado como Administrador.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);

      if (e.code == 'email-already-in-use') {
        _mostrarAlerta(
          'Este correo ya está registrado. Por favor, inicia sesión.',
        );
      } else {
        _mostrarAlerta('Ocurrió un error al registrarse. Intenta de nuevo.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleGoogleAuthenticatedUser(
    User firebaseUser,
    String role,
  ) async {
    UserProfile? userProfile = await UserRepository.instance.getUserProfileById(
      firebaseUser.uid,
    );

    if (userProfile == null) {
      userProfile = UserProfile(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'Usuario',
        photoURL: firebaseUser.photoURL,
        tokens: 0,
        role: role,
        createdDate: DateTime.now(),
        isBanned: false,
        banExpires: null,
        banReason: null,
      );
      UserRepository.instance.currentUser.value = userProfile;
      try {
        await UserRepository.instance.createUserProfile(
          userId: firebaseUser.uid,
          email: userProfile.email,
          displayName: userProfile.displayName,
          role: role,
          adminCode: role == 'Administrador'
              ? _adminCodeController.text.trim()
              : null,
        );
      } on FirebaseException catch (e) {
        if (role == 'Administrador' && e.code == 'permission-denied') {
          UserRepository.instance.currentUser.value = null;
          try {
            await firebaseUser.delete();
          } catch (_) {
            await FirebaseAuth.instance.signOut();
          }
          _mostrarAlerta(
            'El código de administrador es incorrecto. Intenta de nuevo.',
          );
          return;
        }
        debugPrint('Could not persist Google profile to Firestore: $e');
        await UserRepository.instance.initializeUser();
      }
    } else {
      UserRepository.instance.currentUser.value = userProfile;
    }

    if (userProfile.role != role) {
      _mostrarAlerta(
        'Ya tienes una cuenta registrada como ${userProfile.role}. '
        'Inicia sesión con ese rol en su lugar.',
      );
      return;
    }

    final nextPage = userProfile.role == 'Administrador'
        ? const AdminHomeScreen()
        : const HomeScreen();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  Future<void> _registrarseConGoogle() async {
    if (_selectedRole == null) {
      _mostrarAlerta('Por favor selecciona el tipo de usuario');
      return;
    }

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } catch (e) {
      _mostrarAlerta('Error al abrir la ventana de Google. Intenta de nuevo.');
      return;
    }

    if (googleUser == null) return;

    await _completeGoogleSignIn(googleUser);
  }

  Future<void> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    if (_selectedRole == null) {
      _mostrarAlerta('Por favor selecciona el tipo de usuario');
      return;
    }
    final role = _selectedRole!;

    if (role == 'Administrador') {
      return;
    }

    if (!mounted) return;
    var dialogClosed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: VeridiaLoader()),
    );

    try {
      debugPrint('Google Sign-In: obteniendo tokens...');
      final googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('authentication'),
      );
      debugPrint('Google Sign-In: tokens obtenidos.');
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        _mostrarAlerta('No se pudieron obtener las credenciales de Google.');
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Google Sign-In: iniciando sesión en Firebase...');
      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('signInWithCredential'),
          );
      debugPrint(
        'Google Sign-In: sesión de Firebase OK, uid=${userCredential.user?.uid}',
      );
      await UserRepository.instance.initializeUser();

      if (mounted) {
        Navigator.pop(context);
        dialogClosed = true;
      }

      if (userCredential.user != null) {
        await _handleGoogleAuthenticatedUser(userCredential.user!, role);
      }
    } on TimeoutException catch (e) {
      _mostrarAlerta(
        'Se agotó el tiempo esperando a Google (paso: ${e.message}). '
        'Intenta de nuevo.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _mostrarAlerta('Esta cuenta ya existe con otro método de acceso.');
      } else {
        _mostrarAlerta('Error al registrarse con Google. Intenta de nuevo.');
      }
    } catch (e) {
      debugPrint('Google Sign-In: error inesperado -> $e');
      _mostrarAlerta('Error en la autenticación con Google.');
    } finally {
      if (!dialogClosed && mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _googleSignInSub?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  Widget _crearCampoTexto({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: VeridiaTextField(
        controller: controller,
        hintText: hintText,
        icon: icon,
        isPassword: isPassword,
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: VeridiaMontanas(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: const VeridiaSymbol(size: 92),
                        ),
                        const SizedBox(height: 18),
                        Text('Crea tu cuenta', style: text.headlineSmall),
                        const SizedBox(height: 6),
                        Text(
                          'Únete a Veridia y empieza a registrar la '
                          'biodiversidad que te rodea.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 26),
                        VeridiaCard(
                          padding: const EdgeInsets.all(20),
                          glow: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _crearCampoTexto(
                                controller: _nameController,
                                hintText: 'Nombre completo',
                                icon: Icons.person_outline,
                              ),
                              _crearCampoTexto(
                                controller: _emailController,
                                hintText: 'Correo electrónico',
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              _crearCampoTexto(
                                controller: _passwordController,
                                hintText: 'Contraseña',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),
                              _crearCampoTexto(
                                controller: _confirmPasswordController,
                                hintText: 'Confirmar contraseña',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                isExpanded: true,
                                style: text.bodyLarge,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: VeridiaColors.primary,
                                ),
                                dropdownColor:
                                    VeridiaColors.surfaceContainerHigh,
                                decoration: const InputDecoration(
                                  hintText: 'Selecciona tipo de usuario',
                                  prefixIcon: Icon(
                                    Icons.badge_outlined,
                                    size: 20,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Explorador',
                                    child: Text('Explorador'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Administrador',
                                    child: Text('Administrador'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedRole = value);
                                  }
                                },
                              ),
                              AnimatedVisibility(
                                visible: _selectedRole == 'Administrador',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 14),
                                    // Campo sensible: oculto siempre, sin ojo.
                                    TextField(
                                      controller: _adminCodeController,
                                      obscureText: true,
                                      cursorColor: VeridiaColors.primary,
                                      style: text.bodyLarge,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Código privado de administrador',
                                        prefixIcon: Icon(
                                          Icons.vpn_key_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 15,
                                          color: VeridiaColors.secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Solicita el código de '
                                            'administrador antes de continuar.',
                                            style: text.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _registrarUsuario,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                ),
                                child: const Text('Registrarse'),
                              ),
                              AnimatedVisibility(
                                visible: _selectedRole != 'Administrador',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'o continúa con',
                                            style: text.labelSmall,
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (kIsWeb)
                                      Center(child: buildGoogleWebButton())
                                    else
                                      OutlinedButton.icon(
                                        onPressed: _registrarseConGoogle,
                                        icon: const GoogleLogoIcon(size: 20),
                                        label: const Text(
                                          'Registrarse con Google',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(
                                            double.infinity,
                                            52,
                                          ),
                                          foregroundColor:
                                              VeridiaColors.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Volver al inicio de sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
