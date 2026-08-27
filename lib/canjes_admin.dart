import 'package:flutter/material.dart';

import 'models/recompensa.dart';
import 'services/repositorio_r.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Historial de canjes, solo de consulta.
///
/// El administrador no aprueba nada: el explorador paga sus Veridiums y
/// recibe la recompensa en el acto. Esta pantalla existe para poder ver en
/// qué se está gastando la moneda y qué recompensas tiran más.
class CanjesAdminScreen extends StatelessWidget {
  const CanjesAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Canjes de recompensas')),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<Canje>>(
            stream: RewardRepository.instance.streamTodos(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return VeridiaEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'No se pudieron cargar los canjes',
                  message: '${snapshot.error}',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const VeridiaLoader(message: 'Cargando canjes...');
              }

              final canjes = snapshot.data ?? const <Canje>[];
              if (canjes.isEmpty) {
                return const VeridiaEmptyState(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Sin canjes todavía',
                  message:
                      'Cuando un explorador cambie sus Veridiums por una '
                      'recompensa, aparecerá aquí.',
                );
              }

              final veridiumsGastados = canjes.fold<int>(
                0,
                (suma, c) => suma + c.costo,
              );
              final exploradores = canjes.map((c) => c.userId).toSet().length;
              final masCanjeada = _masCanjeada(canjes);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: VeridiaStat(
                          value: '${canjes.length}',
                          label: 'Canjes totales',
                          icon: Icons.redeem_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VeridiaStat(
                          value: '$exploradores',
                          label: 'Exploradores que canjearon',
                          icon: Icons.groups_outlined,
                          color: VeridiaColors.tertiary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VeridiaStat(
                          value: '$veridiumsGastados',
                          label: 'Veridiums gastados',
                          icon: Icons.savings_outlined,
                          color: VeridiaColors.veridium,
                        ),
                      ),
                    ],
                  ),
                  if (masCanjeada != null) ...[
                    const SizedBox(height: 12),
                    VeridiaCard(
                      borderColor: VeridiaColors.secondary.withValues(
                        alpha: 0.4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: VeridiaColors.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'La más canjeada es "${masCanjeada.key}" '
                              '(${masCanjeada.value} veces).',
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const VeridiaSectionTitle(
                    title: 'Historial',
                    subtitle: 'Cada canje se entrega al instante al pagarlo',
                  ),
                  ...canjes.map((canje) {
                    final recompensa = canje.recompensa;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VeridiaCard(
                        child: Row(
                          children: [
                            Icon(
                              recompensa?.icono ?? Icons.redeem_rounded,
                              color: recompensa?.color ?? VeridiaColors.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(canje.nombre, style: text.titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${canje.userDisplayName} · '
                                    '${formatoFecha(canje.fecha)} · '
                                    '${canje.costo} Veridiums',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            VeridiaTag(
                              label: canje.estado.etiqueta,
                              color: canje.estado.color,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Recompensa con más canjes, para saber qué le interesa a la comunidad.
  MapEntry<String, int>? _masCanjeada(List<Canje> canjes) {
    final conteo = <String, int>{};
    for (final canje in canjes) {
      conteo[canje.nombre] = (conteo[canje.nombre] ?? 0) + 1;
    }
    if (conteo.isEmpty) return null;
    return conteo.entries.reduce((a, b) => b.value > a.value ? b : a);
  }
}
