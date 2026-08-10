import 'package:flutter/material.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
    await UserRepository.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final userProfile = UserRepository.instance.currentUser.value;
    final banLabel = userProfile?.banExpires == null
        ? 'Suspensión permanente'
        : 'Suspendido hasta ${userProfile!.banExpires!.day}/${userProfile.banExpires!.month}/${userProfile.banExpires!.year}';
    final banReason = userProfile?.banReason ?? 'Motivo no disponible';

    return Scaffold(
      body: VeridiaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VeridiaColors.error.withValues(alpha: 0.12),
                      border: Border.all(
                        color: VeridiaColors.error.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.block,
                      size: 44,
                      color: VeridiaColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Acceso restringido',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 16),
                Center(
                  child: VeridiaTag(
                    label: banLabel,
                    icon: Icons.schedule,
                    color: VeridiaColors.error,
                  ),
                ),
                const SizedBox(height: 20),
                VeridiaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Motivo', style: text.labelLarge),
                      const SizedBox(height: 6),
                      Text(banReason, style: text.bodyMedium),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Cerrar sesión y volver al inicio'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
