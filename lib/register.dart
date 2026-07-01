import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/repositorioU.dart';
import 'models/user.dart';
import 'home.dart';
import 'admin_home.dart';

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
  String? _selectedRole;

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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E5631), // Verde ambiental
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    // 5. Validación de rol seleccionado
    if (_selectedRole == null) {
      _mostrarAlerta('Por favor selecciona el tipo de usuario');
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
        );

        UserRepository.instance.currentUser.value = localProfile;

        // Attempt to persist the profile, but don't block navigation on failure
        try {
          await UserRepository.instance.createUserProfile(
            userId: credential.user!.uid,
            email: email,
            displayName: name,
            role: _selectedRole!,
          );
        } catch (e) {
          debugPrint('Could not persist user profile to Firestore: $e');
          // Asegurar caché aunque Firestore falle
          await UserRepository.instance.cacheUserProfile(
            credential.user!.uid,
            0,
            _selectedRole!,
            name,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Advertencia: perfil no guardado en servidor.'),
              ),
            );
          }
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
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 18,
          ),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.32)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 28.0,
                ),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
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
                      'Regístrate',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Crea tu cuenta para explorar observaciones y proteger ecosistemas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
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
                            color: Color.fromRGBO(0, 0, 0, 0.12),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
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
                            icon: Icons.email_outlined,
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
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.black87),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: theme.colorScheme.primary,
                            ),
                            dropdownColor: theme.colorScheme.surface,
                            decoration: InputDecoration(
                              hintText: 'Selecciona tipo de usuario',
                              filled: true,
                              fillColor: theme.colorScheme.surface,
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
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _registrarUsuario,
                            child: const Text('Registrarse'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Volver al inicio de sesión'),
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
