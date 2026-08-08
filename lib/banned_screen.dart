import 'package:flutter/material.dart';
import 'services/repositorio_u.dart';

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await UserRepository.instance.signOut();
    if (!context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = UserRepository.instance.currentUser.value;
    final banLabel = userProfile?.banExpires == null
        ? 'Suspensión Permanente'
        : 'Suspendido hasta ${userProfile!.banExpires!.day}/${userProfile.banExpires!.month}/${userProfile.banExpires!.year}';
    final banReason = userProfile?.banReason ?? 'Motivo no disponible';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        title: const Text('Cuenta Suspendida'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.block, size: 78, color: Color(0xFF1E5631)),
            const SizedBox(height: 20),
            Text(
              'Acceso restringido',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              banLabel,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Text(
              banReason,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
              ),
              onPressed: () => _signOut(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text('Cerrar sesión y volver al inicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
