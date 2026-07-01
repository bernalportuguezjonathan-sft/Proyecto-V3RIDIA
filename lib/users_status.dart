import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/repositorioU.dart';

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
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        title: const Text('Usuarios y tokens'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('No hay usuarios registrados aún.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                      const SizedBox(height: 6),
                      Text('Correo: ${user.email}'),
                      const SizedBox(height: 6),
                      Text('Rol: ${user.role}'),
                      const SizedBox(height: 6),
                      Text('Tokens: ${user.tokens}'),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
