import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/desafio.dart';
import 'models/user.dart';
import 'models/asignacion.dart';
import 'services/repositorioA.dart';
import 'services/repositorioD.dart';
import 'services/repositorioU.dart';
import 'admin_profile.dart';
import 'login.dart';
import 'mapa.dart';
import 'assignment_history.dart';
import 'users_status.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final List<UserProfile> _players = [];
  bool _isLoadingPlayers = true;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final players = await UserRepository.instance.fetchAllUsers();
    if (!mounted) return;
    setState(() {
      _players.clear();
      _players.addAll(players.where((user) => user.role == 'Explorador'));
      _isLoadingPlayers = false;
    });
  }

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
        assignedByAdmin: UserRepository.instance.currentUser.value?.email,
      ),
    );
  }

  void _mostrarPuntosDeInteres() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar desafío', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Deseas eliminar este desafío de forma permanente?'),
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

  void _showAssignChallengeDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final speciesController = TextEditingController();
    final goalController = TextEditingController(text: '5');
    final tokensController = TextEditingController(text: '100');
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String selectedTarget = 'global';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Crear o asignar desafío',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      labelStyle: const TextStyle(color: Color(0xFF1E5631)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCAD2C5)),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      labelStyle: const TextStyle(color: Color(0xFF1E5631)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCAD2C5)),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: speciesController,
                    decoration: InputDecoration(
                      labelText: 'Especie objetivo',
                      labelStyle: const TextStyle(color: Color(0xFF1E5631)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCAD2C5)),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: goalController,
                          decoration: InputDecoration(
                            labelText: 'Meta',
                            labelStyle: const TextStyle(color: Color(0xFF1E5631)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCAD2C5)),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: tokensController,
                          decoration: InputDecoration(
                            labelText: 'Tokens',
                            labelStyle: const TextStyle(color: Color(0xFF1E5631)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCAD2C5)),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vence: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(fontSize: 13),
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
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Cambiar',
                            style: TextStyle(color: Color(0xFF1E5631))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoadingPlayers
                      ? const LinearProgressIndicator(color: Color(0xFF1E5631))
                      : DropdownButtonFormField<String>(
                          initialValue: selectedTarget,
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Destino',
                            labelStyle: const TextStyle(color: Color(0xFF1E5631)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCAD2C5)),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'global',
                              child: Text('Global (todos)'),
                            ),
                            ..._players.map((player) => DropdownMenuItem(
                                  value: player.userId,
                                  child: Text('Jugador: ${player.displayName}'),
                                )),
                          ],
                          onChanged: (value) => setState(() {
                            selectedTarget = value ?? 'global';
                          }),
                        ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final bool isGlobal = selectedTarget == 'global';
                  final selectedPlayer = isGlobal
                      ? null
                      : _players.firstWhere(
                          (e) => e.userId == selectedTarget,
                          orElse: () => _players.first,
                        );
                  final now = DateTime.now();
                  final challenge = Challenge(
                    id: 'admin-${now.millisecondsSinceEpoch}',
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    targetSpecies: speciesController.text.trim(),
                    targetGoal: int.parse(goalController.text),
                    dueDate: selectedDate,
                    createdDate: now,
                    currentProgress: 0,
                    isCompleted: false,
                    tokensReward: int.parse(tokensController.text),
                    assignedToUserId: selectedPlayer?.userId,
                    assignedToDisplayName: selectedPlayer?.displayName,
                    assignedToEmail: selectedPlayer?.email,
                    assignedByAdmin: UserRepository.instance.currentUser.value?.email,
                  );

                  ChallengeRepository.instance.addChallenge(challenge);
                  AssignmentRepository.instance.addRecord(
                    AssignmentRecord(
                      id: 'assignment-${now.millisecondsSinceEpoch}',
                      challengeId: challenge.id,
                      challengeTitle: challenge.title,
                      eventType: isGlobal ? 'Creación global' : 'Asignación',
                      note: isGlobal
                          ? 'Disponible para todos los jugadores.'
                          : 'Asignado a ${selectedPlayer?.displayName}',
                      targetUserId: selectedPlayer?.userId,
                      targetUserDisplayName: selectedPlayer?.displayName,
                      targetUserEmail: selectedPlayer?.email,
                      assignedByAdmin: challenge.assignedByAdmin,
                      dateTime: now,
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isGlobal
                          ? 'Desafío global creado'
                          : 'Asignado a ${selectedPlayer?.displayName}'),
                      backgroundColor: const Color(0xFF1E5631),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
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
        elevation: 0,
        title: const Text('Panel Administrador',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
              );
            },
            icon: const Icon(Icons.person, color: Colors.white, size: 22),
            tooltip: 'Perfil',
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: Colors.white, size: 22),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1E5631),
        onRefresh: _loadPlayers,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E5631), Color(0xFF2D7A3F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E5631).withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Bienvenido, Administrador!',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(userProfile?.email ?? '',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          const Text('Administrador',
                              style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Acciones rápidas',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildActionCard(
                    icon: Icons.add_circle_outline,
                    label: 'Desafío diario',
                    color: const Color(0xFF1E5631),
                    onTap: _agregarDesafioDiario,
                  ),
                  _buildActionCard(
                    icon: Icons.place,
                    label: 'Puntos de interés',
                    color: const Color(0xFF2D7A3F),
                    onTap: _mostrarPuntosDeInteres,
                  ),
                  _buildActionCard(
                    icon: Icons.assignment_ind,
                    label: 'Crear desafío',
                    color: const Color(0xFF3A8D5B),
                    onTap: _showAssignChallengeDialog,
                  ),
                  _buildActionCard(
                    icon: Icons.history,
                    label: 'Historial',
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AssignmentHistoryScreen()),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.people,
                    label: 'Usuarios',
                    color: const Color(0xFF66BB6A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const UsersStatusScreen()),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.person,
                    label: 'Mi Perfil',
                    color: const Color(0xFF81C784),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminProfileScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Desafíos creados',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 12),
              ValueListenableBuilder<List<Challenge>>(
                valueListenable: ChallengeRepository.instance.challenges,
                builder: (context, challenges, child) {
                  if (challenges.isEmpty) {
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 64, color: Color(0xFF1E5631)),
                          SizedBox(height: 12),
                          Text('No hay desafíos creados',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: challenges.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      final isGlobal = challenge.assignedToUserId == null;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.06),
                                blurRadius: 8),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(challenge.title,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(challenge.description,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black87)),
                                  const SizedBox(height: 8),
                                  Text(
                                      isGlobal
                                          ? 'Global: todos los jugadores'
                                          : 'Asignado a: ${challenge.assignedToDisplayName}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                  Text(
                                      'Vence: ${challenge.dueDate.day}/${challenge.dueDate.month}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showDeleteConfirm(challenge.id),
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}