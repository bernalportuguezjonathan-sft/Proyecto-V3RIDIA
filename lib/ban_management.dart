import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

class BanManagementScreen extends StatefulWidget {
  const BanManagementScreen({super.key});

  @override
  State<BanManagementScreen> createState() => _BanManagementScreenState();
}

class _BanManagementScreenState extends State<BanManagementScreen> {
  /// Stream creado una sola vez: recrearlo en cada build reabre el listener
  /// de Firestore y la lista parpadea en cada rebuild.
  late final Stream<List<UserProfile>> _usuarios = UserRepository.instance
      .streamAllUsers();

  String _filtro = '';

  Future<void> _showBanDialog(UserProfile user) async {
    final daysOptions = [3, 7, 30];
    int selectedDays = 7;
    bool permanentBan = false;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.gavel_rounded,
            color: VeridiaColors.error,
            size: 26,
          ),
          title: const Text('Suspender usuario'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VeridiaTag(
                    label: user.displayName,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Duración de la suspensión',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final days in daysOptions)
                        ChoiceChip(
                          label: Text('$days días'),
                          selected: !permanentBan && selectedDays == days,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                permanentBan = false;
                                selectedDays = days;
                              });
                            }
                          },
                        ),
                      ChoiceChip(
                        label: const Text('Permanente'),
                        selected: permanentBan,
                        onSelected: (selected) {
                          setDialogState(() => permanentBan = selected);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: reasonController,
                    minLines: 3,
                    maxLines: 5,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de la suspensión',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El motivo es obligatorio.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: VeridiaColors.errorContainer,
                foregroundColor: VeridiaColors.onErrorContainer,
              ),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext);

                try {
                  await UserRepository.instance.banUser(
                    userId: user.userId,
                    isPermanent: permanentBan,
                    days: selectedDays,
                    reason: reasonController.text.trim(),
                  );
                  if (!mounted) return;
                  mostrarMensajeVeridia(
                    context,
                    '${user.displayName} fue suspendido.',
                  );
                } catch (e) {
                  if (!mounted) return;
                  mostrarMensajeVeridia(
                    context,
                    'No se pudo suspender: $e',
                    esError: true,
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unbanUser(UserProfile user) async {
    try {
      await UserRepository.instance.unbanUser(userId: user.userId);
      if (!mounted) return;
      mostrarMensajeVeridia(
        context,
        '${user.displayName} ya puede volver a explorar.',
      );
    } catch (e) {
      if (!mounted) return;
      mostrarMensajeVeridia(
        context,
        'No se pudo levantar la suspensión: $e',
        esError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderación y Gamificación')),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<UserProfile>>(
            stream: _usuarios,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorModeracion(error: '${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const VeridiaLoader(message: 'Cargando usuarios...');
              }

              final todos = snapshot.data ?? const <UserProfile>[];
              if (todos.isEmpty) {
                return const VeridiaEmptyState(
                  icon: Icons.people_outline,
                  title: 'Sin usuarios registrados',
                  message:
                      'Cuando alguien cree una cuenta aparecerá aquí para '
                      'poder moderarla.',
                );
              }

              final consulta = _filtro.trim().toLowerCase();
              final visibles = consulta.isEmpty
                  ? todos
                  : todos
                        .where(
                          (u) =>
                              u.displayName.toLowerCase().contains(consulta) ||
                              u.email.toLowerCase().contains(consulta),
                        )
                        .toList();
              final suspendidos = todos.where((u) => u.isBanned).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: VeridiaStat(
                          value: '${todos.length}',
                          label: 'Usuarios',
                          icon: Icons.groups_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VeridiaStat(
                          value: '${todos.length - suspendidos}',
                          label: 'Activos',
                          icon: Icons.verified_user_outlined,
                          color: VeridiaColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VeridiaStat(
                          value: '$suspendidos',
                          label: 'Suspendidos',
                          icon: Icons.block,
                          color: VeridiaColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (v) => setState(() => _filtro = v),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o correo',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(
                        'Ningún usuario coincide con "$_filtro".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    for (final user in visibles) ...[
                      _FilaUsuario(
                        user: user,
                        onBan: () => _showBanDialog(user),
                        onUnban: () => _unbanUser(user),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({
    required this.user,
    required this.onBan,
    required this.onUnban,
  });

  final UserProfile user;
  final VoidCallback onBan;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final estado = user.isBanned
        ? (user.banExpires == null
              ? 'Suspensión permanente'
              : 'Hasta ${user.banExpires!.day}/${user.banExpires!.month}/${user.banExpires!.year}')
        : 'Activo';

    return VeridiaCard(
      borderColor: user.isBanned
          ? VeridiaColors.error.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: VeridiaColors.surfaceContainerHighest,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: text.titleMedium?.copyWith(
                    color: VeridiaColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              VeridiaTag(
                label: user.role,
                icon: user.role == 'Administrador'
                    ? Icons.admin_panel_settings_outlined
                    : Icons.travel_explore,
                dense: true,
              ),
              VeridiaTag(
                label: estado,
                icon: user.isBanned ? Icons.block : Icons.check_circle_outline,
                color: user.isBanned
                    ? VeridiaColors.error
                    : VeridiaColors.secondary,
                dense: true,
              ),
              VeridiaTag(
                label: '${user.tokens} V',
                icon: Icons.savings_outlined,
                color: VeridiaColors.veridium,
                dense: true,
              ),
            ],
          ),
          if (user.isBanned && user.banReason != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VeridiaColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(VeridiaRadii.sm),
              ),
              child: Text(
                'Motivo: ${user.banReason}',
                style: text.bodySmall?.copyWith(color: VeridiaColors.error),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: user.isBanned
                ? OutlinedButton.icon(
                    onPressed: onUnban,
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text('Levantar suspensión'),
                  )
                : FilledButton.icon(
                    onPressed: onBan,
                    icon: const Icon(Icons.gavel_rounded, size: 18),
                    label: const Text('Suspender'),
                    style: FilledButton.styleFrom(
                      backgroundColor: VeridiaColors.errorContainer,
                      foregroundColor: VeridiaColors.onErrorContainer,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorModeracion extends StatelessWidget {
  const _ErrorModeracion({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return VeridiaEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'No se pudo cargar la lista',
      message:
          'Firestore rechazó la lectura de usuarios. Revisa tu conexión y '
          'que tu cuenta tenga rol Administrador.\n\n$error',
    );
  }
}
