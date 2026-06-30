import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/desafio.dart';
import 'services/repositorioD.dart';
import 'services/repositorioU.dart';
import 'widgets/token_icon.dart';
import 'login.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _agregarDesafioDiario() {
    final now = DateTime.now();
    final id = 'admin-${now.millisecondsSinceEpoch}';
    ChallengeRepository.instance.addChallenge(
      Challenge(
        id: id,
        title: 'Desafío diario ${now.day}/${now.month}',
        description: 'Desafío agregado por administrador',
        targetSpecies: 'General',
        targetGoal: 5,
        dueDate: now.add(const Duration(days: 1)),
        createdDate: now,
        currentProgress: 0,
        isCompleted: false,
        tokensReward: 100,
      ),
    );
  }

  void _mostrarPuntosDeInteres() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Puntos de Interés'),
        content: const Text('Aquí se mostrarían los puntos de interés gestionados por el administrador.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = UserRepository.instance.currentUser.value;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        title: const Text('Panel Administrador'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Row(
                children: [
                  TokenIcon(size: 24),
                  const SizedBox(width: 6),
                  Text(
                    '${userProfile?.tokens ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bienvenido, Administrador',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${userProfile?.email ?? ''}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _agregarDesafioDiario,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Agregar desafío diario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _mostrarPuntosDeInteres,
              icon: const Icon(Icons.place),
              label: const Text('Ver puntos de interés'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tareas del administrador',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('- Agregar desafíos diarios'),
            const Text('- Supervisar puntos de interés'),
            const Text('- Ver y gestionar retos creados'),
          ],
        ),
      ),
    );
  }
}
