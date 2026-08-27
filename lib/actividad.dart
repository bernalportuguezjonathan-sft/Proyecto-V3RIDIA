import 'package:flutter/material.dart';

import 'desafios.dart';
import 'historial.dart';
import 'models/desafio.dart';
import 'models/observation.dart';
import 'models/user.dart';
import 'navegacion.dart';
import 'recompensas.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi actividad')),
      body: StreamBuilder<List<Observation>>(
        stream: ObservationRepository.instance.streamForUser(
          UserRepository.instance.currentUser.value?.userId ?? '',
        ),
        builder: (context, snapshot) {
          final observations = snapshot.data ?? [];
          final totalObservations = observations.length;
          final uniqueSpecies = observations
              .map((observation) => observation.commonName)
              .toSet()
              .length;
          final lastObservation = observations.isNotEmpty
              ? observations.first.dateTime
              : null;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu huella en la naturaleza',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sigue tus descubrimientos y comprueba cómo cada aporte suma al cuidado de la flora y fauna.',
                  style: TextStyle(
                    fontSize: 15,
                    color: VeridiaColors.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard(
                      icon: Icons.nature,
                      title: '$totalObservations',
                      subtitle: 'Observaciones',
                    ),
                    _statCard(
                      icon: Icons.flare,
                      title: '$uniqueSpecies',
                      subtitle: 'Especies únicas',
                    ),
                    _statCard(
                      icon: Icons.schedule,
                      title: lastObservation != null
                          ? formatoFecha(lastObservation)
                          : '-',
                      subtitle: 'Última fecha',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _infoCard(
                        icon: Icons.photo_camera,
                        title: 'Observaciones recientes',
                        description:
                            'Revisa las últimas fotos y datos que has registrado en tu viaje natural.',
                        onTap: () =>
                            VeridiaNav.abrir(context, const HistoryScreen()),
                      ),
                      ValueListenableBuilder<Map<String, ProgresoDesafio>>(
                        valueListenable:
                            ChallengeRepository.instance.misProgresos,
                        builder: (context, _, _) {
                          final uid =
                              UserRepository.instance.currentUser.value?.userId;
                          final mios = ChallengeRepository.instance
                              .challengesForUser(uid);
                          // Progreso propio: dos cuentas distintas ven
                          // números distintos aunque el desafío sea global.
                          final completados = ChallengeRepository.instance
                              .completadosPorMi(uid);
                          return _infoCard(
                            icon: Icons.emoji_events,
                            title: 'Retos completados',
                            description: mios.isEmpty
                                ? 'Todavía no tienes desafíos asignados.'
                                : 'Llevas $completados de ${mios.length} desafíos completados.',
                            onTap: () => VeridiaNav.abrir(
                              context,
                              const ChallengesScreen(),
                            ),
                          );
                        },
                      ),
                      ValueListenableBuilder<UserProfile?>(
                        valueListenable: UserRepository.instance.currentUser,
                        builder: (context, perfil, _) => _infoCard(
                          icon: Icons.monetization_on,
                          title: 'Recompensas',
                          description:
                              'Tienes ${perfil?.tokens ?? 0} Veridiums. Cámbialos por '
                              'insignias, marcos y experiencias.',
                          onTap: () => abrirRecompensas(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: VeridiaColors.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: VeridiaColors.primary, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: VeridiaColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de acceso de "Mi actividad".
  ///
  /// Lleva siempre a una pantalla: antes eran texto muerto y tocarlas no
  /// hacía nada, que es justo lo que se reportó en la revisión del sprint.
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: VeridiaCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: VeridiaColors.primary, size: 28),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VeridiaColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: VeridiaColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
