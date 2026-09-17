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
            VeridiaBotonTactil(
              child: FilledButton(
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

  /// Muestra las cuentas sobrantes de un correo para poder borrarlas.
  ///
  /// Se enseña de cada una el saldo, el acumulado y la fecha de creación,
  /// que son los tres datos con los que se distingue un duplicado vacío del
  /// que tiene el progreso de la persona. Borrar el equivocado se lleva por
  /// delante sus Veridiums y sus insignias, y eso no se deshace.
  Future<void> _mostrarDuplicados(GrupoDeCorreo grupo) async {
    final aBorrar = await showDialog<UserProfile>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.copy_all_outlined,
          color: VeridiaColors.error,
          size: 26,
        ),
        title: Text('${grupo.cuantas} cuentas con este correo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                grupo.principal.email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: VeridiaColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'En la lista se muestra solo la que tiene más recorrido. '
                'Estas son las demás: comprueba que están vacías antes de '
                'borrarlas.',
              ),
              const SizedBox(height: 16),
              _LineaDuplicado(
                perfil: grupo.principal,
                esPrincipal: true,
                onBorrar: null,
              ),
              for (final duplicado in grupo.duplicados)
                _LineaDuplicado(
                  perfil: duplicado,
                  esPrincipal: false,
                  onBorrar: () => Navigator.pop(dialogContext, duplicado),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    // Se reutiliza el borrado normal, con su propia confirmación: no hay una
    // vía rápida que se salte el aviso solo por venir de aquí.
    if (aBorrar != null && mounted) await _eliminarUsuario(aBorrar);
  }

  /// Borra el perfil de Firestore.
  ///
  /// Existe porque eliminar la cuenta en Firebase Authentication NO borra su
  /// documento en Firestore: la app lee `users`, así que esas cuentas
  /// fantasma seguían apareciendo en la lista aunque ya no pudieran entrar.
  Future<void> _eliminarUsuario(UserProfile user) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_rounded,
          color: VeridiaColors.error,
          size: 26,
        ),
        title: const Text('Eliminar de la base de datos'),
        content: Text(
          'Se borrará el perfil de ${user.displayName} (${user.email}) y '
          'dejará de aparecer en la app.\n\n'
          'Sus avistamientos ya publicados NO se borran: siguen en el mapa a '
          'nombre suyo.\n\n'
          'Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          VeridiaBotonTactil(
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: VeridiaColors.errorContainer,
                foregroundColor: VeridiaColors.onErrorContainer,
              ),
              child: const Text('Eliminar'),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await UserRepository.instance.eliminarPerfil(user.userId);
      if (!mounted) return;
      mostrarMensajeVeridia(
        context,
        '${user.displayName} se eliminó de la base de datos.',
      );
    } catch (e) {
      if (!mounted) return;
      mostrarMensajeVeridia(context, 'No se pudo eliminar: $e', esError: true);
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

              // UNA tarjeta por correo. En `users` conviven documentos
              // distintos con el mismo correo —registrarse con contraseña y
              // luego entrar con Google da otro uid, así que es otro
              // documento—, y la lista mostraba cuatro "Daniel Mahecha"
              // idénticos.
              //
              // Los sobrantes NO se esconden y ya está: cuelgan de su
              // principal y se pueden borrar desde ahí. Esta es la única
              // pantalla desde la que se borra un perfil; ocultarlos dejaría
              // la lista limpia y los documentos atrapados para siempre.
              final grupos = agruparPorCorreo(todos);

              final consulta = _filtro.trim().toLowerCase();
              final visibles = consulta.isEmpty
                  ? grupos
                  : grupos
                        .where(
                          (g) =>
                              g.principal.displayName.toLowerCase().contains(
                                consulta,
                              ) ||
                              g.principal.email.toLowerCase().contains(
                                consulta,
                              ),
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
                    for (final grupo in visibles) ...[
                      _FilaUsuario(
                        user: grupo.principal,
                        esYo:
                            grupo.principal.userId ==
                            UserRepository.instance.currentUser.value?.userId,
                        onBan: () => _showBanDialog(grupo.principal),
                        onUnban: () => _unbanUser(grupo.principal),
                        onEliminar: () => _eliminarUsuario(grupo.principal),
                        duplicados: grupo.duplicados.length,
                        onVerDuplicados: grupo.hayDuplicados
                            ? () => _mostrarDuplicados(grupo)
                            : null,
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
    required this.esYo,
    required this.onBan,
    required this.onUnban,
    required this.onEliminar,
    this.duplicados = 0,
    this.onVerDuplicados,
  });

  final UserProfile user;

  /// El administrador con la sesión abierta no puede suspenderse ni
  /// borrarse a sí mismo: se quedaría fuera de su propio panel.
  final bool esYo;

  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onEliminar;

  /// Cuántas cuentas MÁS comparten este correo. 0 en el caso normal.
  final int duplicados;

  /// Abre la lista de esas cuentas para poder borrarlas.
  final VoidCallback? onVerDuplicados;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final estado = user.isBanned
        ? (user.banExpires == null
              ? 'Suspensión permanente'
              : 'Hasta ${formatoFecha(user.banExpires!)}')
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
              // Aviso de que este correo tiene más de una cuenta. Se toca
              // para ver cuáles y borrarlas: el duplicado se esconde de la
              // lista, pero sigue existiendo en la base de datos y hay que
              // poder llegar a él.
              if (duplicados > 0)
                GestureDetector(
                  onTap: onVerDuplicados,
                  child: VeridiaTag(
                    label: duplicados == 1
                        ? '1 duplicado'
                        : '$duplicados duplicados',
                    icon: Icons.copy_all_outlined,
                    color: VeridiaColors.error,
                    dense: true,
                  ),
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
          if (esYo)
            Text(
              'Es tu propia cuenta: no puedes suspenderla ni eliminarla.',
              style: text.bodySmall,
            )
          else
            Row(
              children: [
                Expanded(
                  child: VeridiaBotonTactil(
                    child: user.isBanned
                        ? OutlinedButton.icon(
                            onPressed: onUnban,
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('Levantar'),
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
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onEliminar,
                  tooltip: 'Eliminar de la base de datos',
                  icon: const Icon(Icons.delete_forever_rounded),
                  color: VeridiaColors.error,
                ),
              ],
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

/// Una cuenta dentro del diálogo de duplicados.
class _LineaDuplicado extends StatelessWidget {
  const _LineaDuplicado({
    required this.perfil,
    required this.esPrincipal,
    required this.onBorrar,
  });

  final UserProfile perfil;
  final bool esPrincipal;

  /// null en la principal: esa no se borra desde aquí, se borra con la
  /// papelera de su tarjeta y con el aviso completo.
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPrincipal ? 'Esta es la que se muestra' : 'Duplicada',
                  style: text.labelSmall?.copyWith(
                    color: esPrincipal
                        ? VeridiaColors.secondary
                        : VeridiaColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${perfil.tokens} V · ${perfil.tokensTotales} ganados · '
                  'creada ${formatoFecha(perfil.createdDate)}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (onBorrar != null)
            IconButton(
              onPressed: onBorrar,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: VeridiaColors.error,
              tooltip: 'Borrar esta cuenta duplicada',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
