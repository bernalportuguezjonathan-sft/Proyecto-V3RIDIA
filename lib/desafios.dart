import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'home.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'historial.dart';
import 'perfil.dart';
import 'models/desafio.dart';
import 'models/user.dart';
import 'services/repositorioD.dart';
import 'services/repositorioU.dart';
import 'widgets/token_icon.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showChallengeForm({Challenge? challenge}) {
    final titleController = TextEditingController(text: challenge?.title ?? '');
    final descriptionController = TextEditingController(text: challenge?.description ?? '');
    final speciesController = TextEditingController(text: challenge?.targetSpecies ?? '');
    final goalController = TextEditingController(text: challenge?.targetGoal.toString() ?? '5');
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = challenge?.dueDate ?? DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(challenge == null ? 'Nuevo Desafío' : 'Editar Desafío'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Título del desafío'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: speciesController,
                  decoration: const InputDecoration(labelText: 'Especie objetivo'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: goalController,
                  decoration: const InputDecoration(labelText: 'Meta (cantidad)'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fecha límite: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          selectedDate = picked;
                        }
                      },
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                if (challenge == null) {
                  ChallengeRepository.instance.addChallenge(
                    Challenge(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      targetSpecies: speciesController.text.trim(),
                      targetGoal: int.parse(goalController.text),
                      dueDate: selectedDate,
                      createdDate: DateTime.now(),
                      currentProgress: 0,
                      isCompleted: false,
                    ),
                  );
                } else {
                  ChallengeRepository.instance.updateChallenge(
                    Challenge(
                      id: challenge.id,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      targetSpecies: speciesController.text.trim(),
                      targetGoal: int.parse(goalController.text),
                      dueDate: selectedDate,
                      createdDate: challenge.createdDate,
                      currentProgress: challenge.currentProgress,
                      isCompleted: challenge.isCompleted,
                    ),
                  );
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 246, 246, 246)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar desafío'),
        content: const Text('¿Deseas eliminar este desafío?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ChallengeRepository.instance.deleteChallenge(id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Desafíos Mensuales',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, userProfile, child) {
              return Padding(
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
              );
            },
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Challenge>>(
        valueListenable: ChallengeRepository.instance.challenges,
        builder: (context, challenges, child) {
          return Stack(
            children: [
              Container(color: const Color(0xFFF5F9F7)),
              SafeArea(
                child: challenges.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay desafíos aún',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crea tu primer desafío mensual',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: challenges.length,
                        itemBuilder: (context, index) {
                          final challenge = challenges[index];
                          final progress = (challenge.currentProgress / challenge.targetGoal * 100).clamp(0, 100).toInt();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              challenge.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Objetivo: ${challenge.targetSpecies}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (challenge.isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.emoji_events, size: 12, color: Colors.green),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${challenge.tokensReward}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    challenge.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Progreso: ${challenge.currentProgress}/${challenge.targetGoal}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Vence: ${challenge.dueDate.day}/${challenge.dueDate.month}/${challenge.dueDate.year}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: challenge.currentProgress / challenge.targetGoal,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        challenge.isCompleted ? Colors.green : const Color(0xFF1E5631),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              ChallengeRepository.instance.updateProgress(
                                                challenge.id,
                                                (challenge.currentProgress - 1).clamp(0, challenge.targetGoal),
                                              );
                                            },
                                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              ChallengeRepository.instance.updateProgress(
                                                challenge.id,
                                                (challenge.currentProgress + 1).clamp(0, challenge.targetGoal),
                                              );
                                            },
                                            icon: const Icon(Icons.add_circle_outline, size: 20),
                                            color: const Color(0xFF1E5631),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => _showChallengeForm(challenge: challenge),
                                            icon: const Icon(Icons.edit, size: 18),
                                            color: const Color(0xFF1E5631),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          IconButton(
                                            onPressed: () => _showDeleteConfirm(challenge.id),
                                            icon: const Icon(Icons.delete, size: 18),
                                            color: Colors.red,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showChallengeForm(),
        backgroundColor: const Color(0xFF1E5631),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E5631),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Cámara'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const IdentifySpeciesScreen()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              break;
          }
        },
      ),
    );
  }
}
