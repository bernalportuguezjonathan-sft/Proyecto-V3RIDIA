import 'package:flutter/material.dart';
import 'models/desafio.dart';
import 'models/user.dart';
import 'models/asignacion.dart';
import 'services/repositorio_a.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_u.dart';
import 'admin_profile.dart';
import 'ban_management.dart';
import 'mapa.dart';
import 'assignment_history.dart';
import 'navegacion.dart';
import 'theme/veridia_theme.dart';
import 'users_status.dart';
import 'widgets/veridia_logo.dart';
import 'widgets/veridia_ui.dart';

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

  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
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
        title: const Text('Eliminar desafío'),
        content: const Text(
          '¿Deseas eliminar este desafío de forma permanente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ChallengeRepository.instance.deleteChallenge(id);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('No se pudo eliminar: $e')),
                );
                return;
              }
              navigator.pop();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: VeridiaColors.error),
            ),
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
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String selectedTarget = 'global';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Crear o asignar desafío'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: speciesController,
                    decoration: const InputDecoration(
                      labelText: 'Especie objetivo',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: goalController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Meta (fotos a capturar)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final meta = int.tryParse(goalController.text) ?? 0;
                      final bono = calcularBonoCompletar(meta);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: VeridiaColors.secondary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '1 Veridium por cada foto verificada por la IA '
                          '+ $bono de bono al completar el desafío ($meta/$meta).',
                          style: const TextStyle(
                            fontSize: 12,
                            color: VeridiaColors.secondary,
                          ),
                        ),
                      );
                    },
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
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Cambiar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoadingPlayers
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<String>(
                          initialValue: selectedTarget,
                          dropdownColor: VeridiaColors.surfaceContainerHigh,
                          decoration: const InputDecoration(
                            labelText: 'Destino',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'global',
                              child: Text('Global (todos)'),
                            ),
                            ..._players.map(
                              (player) => DropdownMenuItem(
                                value: player.userId,
                                child: Text('Jugador: ${player.displayName}'),
                              ),
                            ),
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
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
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
                    assignedToUserId: selectedPlayer?.userId,
                    assignedToDisplayName: selectedPlayer?.displayName,
                    assignedToEmail: selectedPlayer?.email,
                    assignedByAdmin:
                        UserRepository.instance.currentUser.value?.email,
                  );

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await ChallengeRepository.instance.addChallenge(challenge);
                    await AssignmentRepository.instance.addRecord(
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
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('No se pudo guardar: $e')),
                    );
                    return;
                  }

                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isGlobal
                            ? 'Desafío global creado'
                            : 'Asignado a ${selectedPlayer?.displayName}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final userProfile = UserRepository.instance.currentUser.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        centerTitle: false,
        title: Row(
          children: [
            const VeridiaSymbol(size: 32, glow: false),
            const SizedBox(width: 10),
            Text('Panel Admin', style: text.titleLarge),
          ],
        ),
        actions: [
          VeridiaAppBarAction(
            icon: Icons.person_rounded,
            tooltip: 'Perfil',
            onPressed: () =>
                VeridiaNav.abrir(context, const AdminProfileScreen()),
          ),
          const SizedBox(width: 10),
          VeridiaAppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: VeridiaColors.primary,
            backgroundColor: VeridiaColors.surfaceContainerHigh,
            onRefresh: _loadPlayers,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VeridiaCard(
                    padding: const EdgeInsets.all(20),
                    glow: true,
                    borderColor: VeridiaColors.primary.withValues(alpha: 0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const VeridiaTag(
                          label: 'Administrador',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                        const SizedBox(height: 14),
                        Text('Centro de control', style: text.headlineSmall),
                        const SizedBox(height: 6),
                        Text(
                          userProfile?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: VeridiaStat(
                                value: _isLoadingPlayers
                                    ? '—'
                                    : '${_players.length}',
                                label: 'Exploradores',
                                icon: Icons.groups_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ValueListenableBuilder<List<Challenge>>(
                                valueListenable:
                                    ChallengeRepository.instance.challenges,
                                builder: (context, challenges, _) =>
                                    VeridiaStat(
                                      value: '${challenges.length}',
                                      label: 'Desafíos activos',
                                      icon: Icons.emoji_events_outlined,
                                      color: VeridiaColors.secondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const VeridiaSectionTitle(
                    title: 'Acciones rápidas',
                    subtitle: 'Gestiona la comunidad y el contenido',
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.92,
                    children: [
                      _buildActionCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'Gestión de Desafíos',
                        subtitle:
                            'Crear y asignar desafíos de captura por especie',
                        color: VeridiaColors.secondary,
                        onTap: _showAssignChallengeDialog,
                      ),
                      _buildActionCard(
                        icon: Icons.map_rounded,
                        label: 'Mapa & Zonas',
                        subtitle:
                            'Zonas protegidas y monitoreo de especies invasoras',
                        color: VeridiaColors.primary,
                        onTap: _mostrarPuntosDeInteres,
                      ),
                      _buildActionCard(
                        icon: Icons.timeline_rounded,
                        label: 'Feed & Monitoreo',
                        subtitle:
                            'Registro de asignaciones y auditoría del sistema',
                        color: VeridiaColors.tertiary,
                        onTap: () => VeridiaNav.abrir(
                          context,
                          const AssignmentHistoryScreen(),
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.gavel_rounded,
                        label: 'Moderación',
                        subtitle:
                            'Suspender o reactivar usuarios que incumplan',
                        color: VeridiaColors.error,
                        onTap: () => VeridiaNav.abrir(
                          context,
                          const BanManagementScreen(),
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.leaderboard_rounded,
                        label: 'Ranking & Veridiums',
                        subtitle:
                            'Clasificación en vivo de exploradores por saldo',
                        color: VeridiaColors.veridium,
                        onTap: () => VeridiaNav.abrir(
                          context,
                          const UsersStatusScreen(),
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.travel_explore_rounded,
                        label: 'Avistamientos',
                        subtitle: 'Todas las especies fotografiadas en el mapa',
                        color: VeridiaColors.primary,
                        onTap: _mostrarPuntosDeInteres,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const VeridiaSectionTitle(
                    title: 'Desafíos creados',
                    subtitle: 'Toca la papelera para eliminarlos',
                  ),
                  ValueListenableBuilder<List<Challenge>>(
                    valueListenable: ChallengeRepository.instance.challenges,
                    builder: (context, challenges, child) {
                      if (challenges.isEmpty) {
                        return const VeridiaEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No hay desafíos creados',
                          message:
                              'Usa "Gestión de Desafíos" para crear el primero.',
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: challenges.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final challenge = challenges[index];
                          final isGlobal = challenge.assignedToUserId == null;
                          return VeridiaCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        challenge.title,
                                        style: text.titleSmall,
                                      ),
                                      if (challenge.description.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          challenge.description,
                                          style: text.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          VeridiaTag(
                                            label: isGlobal
                                                ? 'Global'
                                                : '${challenge.assignedToDisplayName}',
                                            icon: isGlobal
                                                ? Icons.public
                                                : Icons.person_outline,
                                            dense: true,
                                          ),
                                          VeridiaTag(
                                            label: challenge.targetSpecies,
                                            icon: Icons.pets_outlined,
                                            color: VeridiaColors.secondary,
                                            dense: true,
                                          ),
                                          VeridiaTag(
                                            label:
                                                'Vence ${challenge.dueDate.day}/${challenge.dueDate.month}',
                                            icon: Icons.event_outlined,
                                            color: VeridiaColors.tertiary,
                                            dense: true,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showDeleteConfirm(challenge.id),
                                  tooltip: 'Eliminar desafío',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: VeridiaColors.error,
                                  ),
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
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final text = Theme.of(context).textTheme;

    return VeridiaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(VeridiaRadii.md),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(label, style: text.titleSmall),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              subtitle,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
