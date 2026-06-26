import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register.dart'; // Importamos tu pantalla de registro
import 'home.dart'; // Importamos la pantalla de inicio

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
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E5631), // Verde ambiental de Veridia
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

      if (mounted) Navigator.pop(context); // Cerramos el loader

      // Redirigir al usuario a la pantalla principal (home) cuando el login sea exitoso
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Cerramos el loader

      // AQUÍ CUMPLIMOS TU REGLA #1: 
      // Si el correo no existe (user-not-found) o las credenciales no cuadran (invalid-credential en nuevas versiones de Firebase)
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _mostrarAlerta('Primero te debes registrar antes de iniciar sesión.');
      } else if (e.code == 'wrong-password') {
        _mostrarAlerta('La contraseña es incorrecta.');
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black87, size: 22),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD3D3D3), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD3D3D3), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E5631), width: 1.2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo que cubre toda la pantalla
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Fondo decorativo',
            ),
          ),
          // Gradiente desvanecimiento para mejor legibilidad
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Contenido principal
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const Spacer(flex: 1),
                // Logo con decoración
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color.fromRGBO(30, 86, 49, 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.08),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 150,
                        width: 150,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'Logo Veridia',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(flex: 1),
                // Campos de formulario
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _crearCampoTexto(
                          controller: _emailController,
                          hintText: 'Correo electrónico',
                          icon: Icons.hourglass_empty,
                        ),
                        _crearCampoTexto(
                          controller: _passwordController,
                          hintText: 'Contraseña',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _iniciarSesion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E5631),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Entrar',
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 16, 
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            '¿No tienes cuenta? Regístrate aquí',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}