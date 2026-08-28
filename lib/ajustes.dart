import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';

import 'models/user.dart';
import 'privacidad_seguridad.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _openNotificationSettings() {
    AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  void _abrirPrivacidadYSeguridad() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder<UserProfile?>(
          valueListenable: UserRepository.instance.currentUser,
          builder: (context, user, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ajustes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Revisa los datos de tu cuenta y los permisos de la app.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                _infoTile(
                  icon: Icons.person,
                  title: 'Nombre',
                  subtitle: user?.displayName ?? 'Explorador',
                ),
                _infoTile(
                  icon: Icons.email,
                  title: 'Email',
                  subtitle: user?.email ?? 'No disponible',
                ),
                _infoTile(
                  icon: Icons.monetization_on,
                  title: 'Monedas',
                  subtitle: '${user?.tokens ?? 0}',
                ),
                const SizedBox(height: 16),
                _settingTile(
                  icon: Icons.notifications,
                  title: 'Notificaciones',
                  subtitle: 'Abrir ajustes de notificaciones del sistema.',
                  onTap: _openNotificationSettings,
                ),
                _settingTile(
                  icon: Icons.lock_outline,
                  title: 'Privacidad y seguridad',
                  subtitle: 'Cambiar contraseña y ver qué datos usamos.',
                  onTap: _abrirPrivacidadYSeguridad,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: VeridiaColors.primary, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: VeridiaColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: VeridiaColors.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: VeridiaColors.primary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: VeridiaColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: VeridiaColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
