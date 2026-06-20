import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';

// Convertimos el main en 'async' porque iniciar Firebase toma un instante
void main() async {
  // Esta línea es obligatoria antes de iniciar cualquier cosa nativa como Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // ¡Aquí es donde ocurre la magia! Iniciamos Firebase con las opciones correctas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const VeridiaApp());
}

class VeridiaApp extends StatelessWidget {
  const VeridiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veridia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E5631),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5631)),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2), // Empuja el contenido hacia el centro de forma dinámica
            
            // 1. El Logo de Veridia
            // Nota: Cambia por Image.asset('assets/images/logo.png') cuando tengas el archivo listo
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200], // Color temporal por si no tienes el asset cargado aún
              ),
              child: const Icon(Icons.eco, size: 80, color: Color(0xFF1E5631)), // Icono temporal
            ),
            
            const SizedBox(height: 24),
            
            // 2. Título de la App
            const Text(
              'Veridia',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E5631), // El verde característico de tu diseño
                letterSpacing: 1.2,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 3. Eslogan
            const Text(
              'Explora, conserva, protege',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            
            const Spacer(flex: 2), // Espacio intermedio
            
            // 4. Ilustración del fondo (Montañas y pinos)
            // Cuando la tengas en assets, usa Image.asset('assets/images/background.png')
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.green[50], // Fondo simulado
              child: const Center(
                child: Text('[Espacio para ilustración de montañas]', 
                  style: TextStyle(color: Colors.grey)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 5. Indicador de páginas (Los tres puntitos abajo de tu captura)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(isActive: true),
                const SizedBox(width: 8),
                _buildDot(isActive: false),
                const SizedBox(width: 8),
                _buildDot(isActive: false),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Botón temporal para saltar a la pantalla de Login que haremos después
           ElevatedButton(
              onPressed: () {
                // Navegación hacia la pantalla de Login
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
                foregroundColor: Colors.white,
              ),
              child: const Text('Siguiente'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para pintar los puntitos de navegación del carrusel
  Widget _buildDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E5631) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}