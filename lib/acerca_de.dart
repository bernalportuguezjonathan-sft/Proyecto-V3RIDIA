import 'package:flutter/material.dart';

import 'models/observation.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';

class AboutVeridiaScreen extends StatelessWidget {
  const AboutVeridiaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Veridia')),
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

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verídia',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verídia es una app pensada para gamificar de forma intuitiva y divertida el aprendizaje sobre ambientes naturales, fauna y flora. Aquí puedes explorar ecosistemas, descubrir especies y ganar recompensas mientras te conviertes en un guardián activo de la naturaleza.',
                  style: TextStyle(
                    fontSize: 16,
                    color: VeridiaColors.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _aboutStatTile(
                      icon: Icons.nature_people,
                      label: 'Observaciones',
                      value: '$totalObservations',
                    ),
                    const SizedBox(width: 12),
                    _aboutStatTile(
                      icon: Icons.eco,
                      label: 'Especies',
                      value: '$uniqueSpecies',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '¿Qué puedes hacer en Verídia?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Completar retos con fotos reales de la naturaleza.',
                ),
                const Text(
                  '• Aprender sobre especies y hábitats desde tu propia experiencia.',
                ),
                const Text(
                  '• Ganar monedas y logros por cada contribución ecológica.',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Únete a una comunidad que valora la curiosidad, el respeto por el medio ambiente y la diversión mientras aprendes.',
                  style: TextStyle(
                    fontSize: 15,
                    color: VeridiaColors.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _aboutStatTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              label,
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
}
