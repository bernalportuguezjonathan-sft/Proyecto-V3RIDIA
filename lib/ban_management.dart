import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/repositorio_u.dart';

class BanManagementScreen extends StatefulWidget {
  const BanManagementScreen({super.key});

  @override
  State<BanManagementScreen> createState() => _BanManagementScreenState();
}

class _BanManagementScreenState extends State<BanManagementScreen> {
  bool _isLoading = true;
  List<UserProfile> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await UserRepository.instance.fetchAllUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _showBanDialog(UserProfile user) async {
    final daysOptions = [3, 7, 30];
    int selectedDays = 7;
    bool permanentBan = false;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Banear usuario',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuario: ${user.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Duración del baneo',
                  style: TextStyle(fontSize: 14),
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
                            setState(() {
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
                        setState(() {
                          permanentBan = selected;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Motivo del baneo',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final dialogContext = context;
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }

                  await UserRepository.instance.banUser(
                    userId: user.userId,
                    isPermanent: permanentBan,
                    days: selectedDays,
                    reason: reasonController.text.trim(),
                  );

                  await _loadUsers();
                  if (!mounted) return;
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text('Usuario baneado correctamente.'),
                      backgroundColor: Color(0xFF1E5631),
                    ),
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

  Widget _buildUserRow(UserProfile user) {
    final banStatus = user.isBanned
        ? user.banExpires == null
              ? 'Suspendido permanentemente'
              : 'Suspendido hasta ${user.banExpires!.day}/${user.banExpires!.month}/${user.banExpires!.year}'
        : 'Activo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
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
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.isBanned
                      ? const Color(0xFFB71C1C)
                      : const Color(0xFF1E5631),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  if (user.isBanned) {
                    _unbanUser(user);
                  } else {
                    _showBanDialog(user);
                  }
                },
                child: Text(user.isBanned ? 'Desbanear' : 'Banear'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              Chip(label: Text(user.role)),
              Chip(label: Text(banStatus)),
            ],
          ),
          if (user.isBanned && user.banReason != null) ...[
            const SizedBox(height: 10),
            Text(
              'Motivo: ${user.banReason}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _unbanUser(UserProfile user) async {
    await UserRepository.instance.unbanUser(userId: user.userId);
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Usuario desbaneado correctamente.'),
        backgroundColor: Color(0xFF1E5631),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        title: const Text('Moderación y Gamificación'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.people_outline, size: 60, color: Colors.black38),
                  SizedBox(height: 14),
                  Text(
                    'No hay usuarios registrados aún.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF1E5631),
              onRefresh: _loadUsers,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, index) => _buildUserRow(_users[index]),
              ),
            ),
    );
  }
}
