import 'package:flutter/material.dart';

import 'models/observation.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';

class PublicationsScreen extends StatelessWidget {
  const PublicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis publicaciones')),
      body: StreamBuilder<List<Observation>>(
        stream: ObservationRepository.instance.streamForUser(
          UserRepository.instance.currentUser.value?.userId ?? '',
        ),
        builder: (context, snapshot) {
          final observations = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.bookmark_outline,
                      color: VeridiaColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${observations.length} publicaciones',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tus observaciones más recientes están aquí. Revísalas, edítalas o compártelas con tu comunidad.',
                  style: TextStyle(
                    fontSize: 15,
                    color: VeridiaColors.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: observations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 72,
                                color: VeridiaColors.primary,
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Aún no tienes publicaciones cargadas.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: VeridiaColors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sube tu primera foto para empezar a construir tu colección natural.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: VeridiaColors.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: observations.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final observation = observations[index];
                            return _publicationCard(observation);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _publicationCard(Observation observation) {
    return Container(
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
          Row(
            children: [
              const Icon(Icons.nature, color: VeridiaColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  observation.commonName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            observation.scientificName,
            style: const TextStyle(
              fontSize: 13,
              color: VeridiaColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: VeridiaColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  observation.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: VeridiaColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            observation.notes,
            style: const TextStyle(
              fontSize: 14,
              color: VeridiaColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fecha: ${formatoFecha(observation.dateTime)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: VeridiaColors.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
