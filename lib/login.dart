import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/repositorioU.dart';
import 'admin_home.dart';
import 'home.dart'; // Importamos la pantalla de inicio
import 'register.dart'; // Importamos tu pantalla de registro

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // La misma función de alertas modernas que usamos en el registro
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
        backgroundColor: const Color(0xFF1E5631), // Verde ambiental de Veridia
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Función para iniciar sesión
  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validación de campos vacíos
    if (email.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Correo electrónico');
      return;
    }
    if (password.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Contraseña');
      return;
    }

    // Círculo de carga
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
        // Mostrar error más descriptivo para depuración
        if (mounted) Navigator.pop(context);
        debugPrint('Error initializing user: $e\n$st');
        _mostrarAlerta('Error al inicializar usuario: ${e.toString()}');
        return;
      }

      if (mounted) Navigator.pop(context); // Cerramos el loader

      // Redirigir al usuario según su rol
      if (mounted) {
        final userProfile = UserRepository.instance.currentUser.value;
        final nextPage = userProfile?.role == 'Administrador'
            ? const AdminHomeScreen()
            : const HomeScreen();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextPage),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Cerramos el loader

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Widget reutilizable para los campos de texto
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.12),
                            blurRadius: 18,
                            offset: Offset(0, 12),
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
                        color: const Color.fromRGBO(255, 255, 255, 0.96),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.10),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.9),
                        ),
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
        ],
      ),
    );
  }
}
