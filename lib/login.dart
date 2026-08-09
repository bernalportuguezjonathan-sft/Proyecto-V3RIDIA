import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/repositorio_u.dart';
import 'models/user.dart';
import 'admin_home.dart';
import 'home.dart';
import 'register.dart';
import 'widgets/animated_visibility.dart';
import 'widgets/google_logo_icon.dart';
import 'widgets/google_web_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminCodeController = TextEditingController();
  String _selectedRole = 'Explorador';

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
      _googleSignIn.signInSilently();
    }
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E5631),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Correo electrónico');
      return;
    }
    if (password.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Contraseña');
      return;
    }

    // El rol real vive en Firestore y ya no se puede autoasignar (ver
    // firestore.rules); _handleAuthenticatedUser rechaza el login si el rol
    // elegido aquí no coincide con el guardado.

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E5631)),
      ),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      try {
        await UserRepository.instance.initializeUser();
      } catch (e, st) {
        if (mounted) Navigator.pop(context);
        debugPrint('Error initializing user: $e\n$st');
        _mostrarAlerta('Error al inicializar usuario: ${e.toString()}');
        return;
      }

      if (mounted) Navigator.pop(context);

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _mostrarAlerta('No se pudo obtener el usuario autenticado.');
        return;
      }

      await _handleAuthenticatedUser(firebaseUser);
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);

      if (e.code == 'wrong-password') {
        _mostrarAlerta('La contraseña es incorrecta.');
      } else if (e.code == 'user-not-found') {
        _mostrarAlerta('El correo no existe o es incorrecto.');
      } else if (e.code == 'invalid-email') {
        _mostrarAlerta('El formato del correo es incorrecto.');
      } else if (e.code == 'user-disabled') {
        _mostrarAlerta('La cuenta ha sido deshabilitada.');
      } else {
        _mostrarAlerta('Error al iniciar sesión. Verifica tus datos.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarAlerta('Ocurrió un error inesperado de conexión.');
    }
  }

  Future<void> _handleAuthenticatedUser(User firebaseUser) async {
    UserProfile? userProfile = UserRepository.instance.currentUser.value;
    final dbProfile = await UserRepository.instance.getUserProfileById(
      firebaseUser.uid,
    );
    if (dbProfile != null) {
      userProfile = dbProfile;
      UserRepository.instance.currentUser.value = userProfile;
    }

    if (userProfile == null) {
      // Sin documento en Firestore no hay forma de confiar en ningún rol
      // elegido en pantalla; se crea siempre como Explorador.
      userProfile = UserProfile(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'Usuario',
        photoURL: firebaseUser.photoURL,
        tokens: 0,
        role: 'Explorador',
        createdDate: DateTime.now(),
        isBanned: false,
        banExpires: null,
        banReason: null,
      );
      UserRepository.instance.currentUser.value = userProfile;
    }

    if (userProfile.isBanned) {
      final now = DateTime.now();
      if (userProfile.banExpires != null &&
          userProfile.banExpires!.isBefore(now)) {
        await UserRepository.instance.unbanUser(userId: userProfile.userId);
        userProfile = userProfile.copyWith(
          isBanned: false,
          banExpires: null,
          banReason: null,
        );
        UserRepository.instance.currentUser.value = userProfile;
      } else {
        final banLabel = userProfile.banExpires == null
            ? 'Suspensión Permanente'
            : 'Suspendido hasta ${userProfile.banExpires!.day}/${userProfile.banExpires!.month}/${userProfile.banExpires!.year}';
        final banReason = userProfile.banReason ?? 'Motivo no disponible';
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Cuenta Suspendida',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banLabel,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  banReason,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
        if (mounted) {
          await UserRepository.instance.signOut();
        }
        return;
      }
    }

    if (userProfile.role != _selectedRole) {
      _mostrarAlerta(
        'El usuario ingresado no tiene el rol seleccionado. '
        'Selecciona ${userProfile.role} o corrige el rol.',
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

  Future<void> _signInWithGoogle() async {
    GoogleSignInAccount? googleUser;

    try {
      googleUser = await _googleSignIn.signIn();
    } catch (e) {
      if (mounted) {
        _mostrarAlerta(
          'Error al abrir la ventana de Google. Intenta de nuevo.',
        );
      }
      return;
    }

    if (googleUser == null) {
      return;
    }

    await _completeGoogleSignIn(googleUser);
  }

  Future<void> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    if (_selectedRole == 'Administrador') {
      return;
    }

    var didShowDialog = false;
    if (!mounted) return;
    didShowDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E5631)),
      ),
    );

    try {
      debugPrint('Google Sign-In: obteniendo tokens...');
      final googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('authentication'),
      );
      debugPrint('Google Sign-In: tokens obtenidos.');
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        if (mounted) {
          _mostrarAlerta('No se pudieron obtener las credenciales de Google.');
        }
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

      if (didShowDialog && mounted) {
        Navigator.pop(context);
        didShowDialog = false;
      }

      if (mounted && userCredential.user != null) {
        await _handleAuthenticatedUser(userCredential.user!);
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        _mostrarAlerta(
          'Se agotó el tiempo esperando a Google (paso: ${e.message}). '
          'Intenta de nuevo.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'account-exists-with-different-credential') {
        _mostrarAlerta('Esta cuenta ya existe con otro método de acceso.');
      } else {
        _mostrarAlerta('Error al iniciar sesión con Google. Intenta de nuevo.');
      }
    } catch (e) {
      debugPrint('Google Sign-In: error inesperado -> $e');
      if (mounted) {
        _mostrarAlerta('Error en la autenticación con Google.');
      }
    } finally {
      if (didShowDialog && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _googleSignInSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  Widget _crearCampoTexto({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        cursorColor: theme.colorScheme.primary,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 22),
          hintText: hintText,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCAD2C5), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCAD2C5), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Fondo decorativo',
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.35)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                physics: const BouncingScrollPhysics(),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 118,
                            height: 118,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                const BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.10),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                semanticLabel: 'Logo Veridia',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.97),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              const BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.08),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _crearCampoTexto(
                                controller: _emailController,
                                hintText: 'Correo electrónico',
                                icon: Icons.email_outlined,
                              ),
                              _crearCampoTexto(
                                controller: _passwordController,
                                hintText: 'Contraseña',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Iniciar sesión como',
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCAD2C5),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCAD2C5),
                                      width: 1,
                                    ),
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
                                    setState(() {
                                      _selectedRole = value;
                                    });
                                  }
                                },
                              ),
                              AnimatedVisibility(
                                visible: _selectedRole == 'Administrador',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 10),
                                    const Text(
                                      'El rol Administrador requiere el código privado.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4F4F4F),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _crearCampoTexto(
                                      controller: _adminCodeController,
                                      hintText: 'Código de administrador',
                                      icon: Icons.vpn_key,
                                      isPassword: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _iniciarSesion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E5631),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedVisibility(
                                visible: _selectedRole != 'Administrador',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 12),
                                    if (kIsWeb)
                                      Center(child: buildGoogleWebButton())
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: _signInWithGoogle,
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black87,
                                            side: const BorderSide(
                                              color: Color(0xFFB0B0B0),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 0,
                                              horizontal: 0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                height: 36,
                                                width: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFDDDDDD,
                                                    ),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(6.0),
                                                  child: GoogleLogoIcon(
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Iniciar sesión con Google',
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            '¿No tienes cuenta? Regístrate aquí',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
