import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/repositorio_u.dart';
import 'widgets/token_icon.dart';

/// Ranking de exploradores por Veridiums. Solo accesible para administradores
/// desde el panel de administración.
class UsersStatusScreen extends StatefulWidget {
  const UsersStatusScreen({super.key});

  @override
  State<UsersStatusScreen> createState() => _UsersStatusScreenState();
}

class _UsersStatusScreenState extends State<UsersStatusScreen> {
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
    users.sort((a, b) => b.tokens.compareTo(a.tokens));
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Color _colorPuesto(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFD4AF37);
      case 1:
        return const Color(0xFF9CA3AF);
      case 2:
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF1E5631);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        foregroundColor: Colors.white,
        title: const Text('Ranking de exploradores'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('No hay usuarios registrados aún.'))
          : RefreshIndicator(
              color: const Color(0xFF1E5631),
              onRefresh: _loadUsers,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.06),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _colorPuesto(index),
                          radius: 18,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  _chip(user.role),
                                  if (user.isBanned) _chip('Suspendido'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TokenIcon(size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${user.tokens}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E5631),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E5631).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
