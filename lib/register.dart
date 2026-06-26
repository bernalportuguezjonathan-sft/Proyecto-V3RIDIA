import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Función para las alertas modernas y flotantes
  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars(); // Evita que se acumulen
    
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
        backgroundColor: const Color(0xFF1E5631), // Verde ambiental
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(seconds: 2), // Desaparece rápido
      ),
    );
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

    // Si todo está perfecto, mostramos el círculo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E5631)),
      ),
    );

    try {
      // Intentamos crear el usuario en Firebase
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) Navigator.pop(context); // Cerramos el círculo de carga

      // Mostramos éxito y lo devolvemos al Login
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Registro exitoso! Ya puedes iniciar sesión.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); 
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);

      if (e.code == 'email-already-in-use') {
        _mostrarAlerta('Este correo ya está registrado. Por favor, inicia sesión.');
      } else {
        _mostrarAlerta('Ocurrió un error al registrarse. Intenta de nuevo.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Diseño de un campo de texto reutilizable para no repetir código
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
                  'Regístrate',
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
                          controller: _nameController,
                          hintText: 'Nombre completo',
                          icon: Icons.person_outline,
                        ),
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
                        _crearCampoTexto(
                          controller: _confirmPasswordController,
                          hintText: 'Confirmar contraseña',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _registrarUsuario,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E5631),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Registrarse',
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 16, 
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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