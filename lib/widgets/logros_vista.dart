import 'package:flutter/material.dart';

import '../models/logro.dart';
import '../models/observation.dart';
import '../models/user.dart';
import '../services/repositorio_d.dart';
import '../services/repositorio_o.dart';
import '../services/repositorio_u.dart';
import '../theme/veridia_theme.dart';
import 'veridia_ui.dart';

/// Calcula las estadísticas del explorador con la sesión abierta y las
/// entrega a quien las pide.
///
/// Perfil y carnet necesitan exactamente lo mismo (avistamientos propios +
/// desafíos cerrados + Veridiums ganados), así que la consulta se escribe una
/// vez. Si cada pantalla la montara por su cuenta acabarían contando distinto.
class ConEstadisticas extends StatelessWidget {
  const ConEstadisticas({super.key, required this.builder});

  final Widget Function(BuildContext, EstadisticasExplorador) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: UserRepository.instance.currentUser,
      builder: (context, perfil, _) {
        if (perfil == null) {
          return builder(context, const EstadisticasExplorador());
        }
        return StreamBuilder<List<Observation>>(
          stream: ObservationRepository.instance.streamForUser(perfil.userId),
          builder: (context, snapshot) {
            final stats = EstadisticasExplorador.de(
              veridiumsGanados: perfil.tokensTotales,
              fotos: snapshot.data ?? const <Observation>[],
              desafios: ChallengeRepository.instance.completadosPorMi(
                perfil.userId,
              ),
            );
            return builder(context, stats);
          },
        );
      },
    );
  }
}

/// Un logro conseguido, en formato exhibición.
///
/// Es lo que se enseña: en el perfil junto al nombre y en el carnet. Los que
/// faltan no salen aquí — un muro de logros grises es una lista de deberes,
/// no una vitrina.
class LogroInsignia extends StatelessWidget {
  const LogroInsignia({super.key, required this.logro, this.dense = true});

  final Logro logro;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: logro.descripcion,
      child: VeridiaTag(
        label: logro.emblema == null
            ? logro.nombre
            : '${logro.emblema} ${logro.nombre}',
        color: logro.color,
        dense: dense,
      ),
    );
  }
}

/// Sección de logros: lo conseguido arriba, lo siguiente con su barra.
///
/// Enseñar SOLO el próximo pendiente y no los cinco que faltan es a propósito:
/// una meta cercana empuja, cinco lejanas desaniman. En cuanto se consigue,
/// aparece la siguiente.
class PanelLogros extends StatelessWidget {
  const PanelLogros({
    super.key,
    required this.stats,
    this.mostrarSiguiente = true,
  });

  final EstadisticasExplorador stats;
  final bool mostrarSiguiente;

  @override
  Widget build(BuildContext context) {
    final conseguidos = logrosConseguidos(stats);
    final pendientes = logrosPendientes(stats);

    return VeridiaCard(
      // Contorno DORADO y no el jade de las demas: los logros son la unica
      // seccion del perfil que habla de merito, y con el borde estandar la
      // tarjeta se perdia entre las otras tres a pesar de ser la que la gente
      // baja a mirar. El dorado ya era el color de la medalla del titulo y de
      // los Veridiums, asi que no entra ningun color nuevo a la paleta.
      borderColor: VeridiaColors.veridium.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech_rounded,
                size: 18,
                color: VeridiaColors.veridium,
              ),
              const SizedBox(width: 8),
              Text('Logros', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                '${conseguidos.length} de ${catalogoLogros.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (conseguidos.isEmpty)
            Text(
              'Todavía no tienes ninguno. No se compran: se ganan saliendo a '
              'registrar especies.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conseguidos
                  .map((logro) => LogroInsignia(logro: logro))
                  .toList(),
            ),
          if (mostrarSiguiente && pendientes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: VeridiaColors.outlineVariant),
            const SizedBox(height: 12),
            _ProximoLogro(logro: pendientes.first, stats: stats),
          ],
        ],
      ),
    );
  }
}

/// El siguiente logro alcanzable, con cuánto falta exactamente.
class _ProximoLogro extends StatelessWidget {
  const _ProximoLogro({required this.logro, required this.stats});

  final Logro logro;
  final EstadisticasExplorador stats;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final falta = logro.restante(stats);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: logro.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(VeridiaRadii.md),
            border: Border.all(color: logro.color.withValues(alpha: 0.4)),
          ),
          child: Icon(logro.icono, size: 19, color: logro.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(logro.nombre, style: texto.titleSmall)),
                  Text(
                    '${stats.valorDe(logro.metrica)} / ${logro.meta}',
                    style: texto.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(logro.descripcion, style: texto.bodySmall),
              const SizedBox(height: 8),
              VeridiaProgressBar(
                value: logro.progreso(stats),
                height: 6,
                color: logro.color,
              ),
              const SizedBox(height: 4),
              Text(
                'Te faltan $falta ${logro.metrica.unidad(falta)}',
                style: texto.bodySmall?.copyWith(
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
