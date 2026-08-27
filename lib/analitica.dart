import 'package:flutter/material.dart';

import 'models/bird_zone.dart';
import 'models/desafio.dart';
import 'models/observation.dart';
import 'models/recompensa.dart';
import 'models/user.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_r.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Cuántos avistamientos se traen como máximo. La analítica lo dice en
/// pantalla para que nadie interprete una muestra como el total.
const int limiteAnalitica = 500;

/// Ventanas de tiempo que ofrece el panel.
enum RangoAnalitica {
  semana(7, '7 días'),
  mes(30, '30 días'),
  trimestre(90, '90 días');

  const RangoAnalitica(this.dias, this.etiqueta);

  final int dias;
  final String etiqueta;
}

/// Nombre con el que se guarda una especie que la IA no logró identificar.
/// No cuenta como "especie única": inflaría la cifra sin aportar nada.
const _especieSinIdentificar = {
  'especie observada',
  'sin confirmar',
  'referencia visual',
};

bool especieIdentificada(Observation observacion) => !_especieSinIdentificar
    .contains(observacion.commonName.trim().toLowerCase());

/// Observaciones registradas dentro de los últimos [dias] días.
List<Observation> enRango(List<Observation> observaciones, int dias) {
  final desde = DateTime.now().subtract(Duration(days: dias));
  return observaciones.where((o) => o.dateTime.isAfter(desde)).toList();
}

/// Conteo ordenado de mayor a menor: la base de los rankings de la analítica.
List<MapEntry<String, int>> ranking(Iterable<String> valores, {int top = 5}) {
  final conteo = <String, int>{};
  for (final valor in valores) {
    final clave = valor.trim();
    if (clave.isEmpty) continue;
    conteo[clave] = (conteo[clave] ?? 0) + 1;
  }
  final lista = conteo.entries.toList()
    ..sort((a, b) {
      final porCantidad = b.value.compareTo(a.value);
      return porCantidad != 0 ? porCantidad : a.key.compareTo(b.key);
    });
  return lista.take(top).toList();
}

/// Ranking sobre identificadores estables que devuelve la etiqueta legible.
///
/// Contar por nombre visible fusionaba a dos exploradores que se llamaran
/// igual; se cuenta por id y solo al final se traduce a nombre.
List<MapEntry<String, int>> rankingPorId(
  Iterable<String> ids, {
  required String Function(String id) etiqueta,
  int top = 5,
}) {
  return ranking(
    ids,
    top: top,
  ).map((e) => MapEntry(etiqueta(e.key), e.value)).toList();
}

/// Observaciones por día en los últimos [dias] días, del más antiguo al de hoy.
List<int> actividadPorDia(List<Observation> observaciones, {int dias = 7}) {
  final hoy = DateTime.now();
  final inicioDeHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final serie = List<int>.filled(dias, 0);

  for (final observacion in observaciones) {
    final fecha = observacion.dateTime;
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = inicioDeHoy.difference(dia).inDays;
    if (diferencia >= 0 && diferencia < dias) {
      serie[dias - 1 - diferencia]++;
    }
  }
  return serie;
}

/// Agrupa una serie diaria en [columnas] barras sumando días consecutivos.
///
/// 90 barras de un píxel no se leen; agrupándolas en semanas el gráfico dice
/// lo mismo y se entiende de un vistazo.
List<int> agruparSerie(List<int> serie, int columnas) {
  if (columnas <= 0 || serie.length <= columnas) return serie;
  final porColumna = (serie.length / columnas).ceil();

  final agrupada = <int>[];
  for (var i = 0; i < serie.length; i += porColumna) {
    final fin = (i + porColumna).clamp(0, serie.length);
    agrupada.add(serie.sublist(i, fin).fold(0, (a, b) => a + b));
  }
  return agrupada;
}

/// Panel de analítica del administrador: qué se está registrando, dónde y
/// quién está activo. Todo se calcula en vivo desde Firestore.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<BirdZone> _zonas = const [];
  bool _zonasCargadas = false;
  RangoAnalitica _rango = RangoAnalitica.mes;

  @override
  void initState() {
    super.initState();
    loadBirdZones().then((zonas) {
      if (!mounted) return;
      setState(() {
        _zonas = zonas;
        _zonasCargadas = true;
      });
    });
  }

  /// Nombre de la zona de cada observación con coordenadas. Las que caen
  /// lejos de toda zona se agrupan aparte en vez de descartarse.
  Iterable<String> _zonasDeObservaciones(List<Observation> observaciones) {
    if (_zonas.isEmpty) return const [];
    return observaciones.where((o) => o.hasCoordinates).map((o) {
      final zona = zonaDePunto(_zonas, o.latitude!, o.longitude!);
      return zona?.name ?? 'Fuera de zonas registradas';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analítica'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: VeridiaTag(
                label: 'En vivo',
                icon: Icons.bolt,
                color: VeridiaColors.secondary,
                dense: true,
              ),
            ),
          ),
        ],
      ),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<Observation>>(
            stream: ObservationRepository.instance.streamAll(
              limit: limiteAnalitica,
            ),
            builder: (context, snapObs) {
              if (snapObs.hasError) {
                return VeridiaEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'No se pudo cargar la analítica',
                  message: '${snapObs.error}',
                );
              }
              if (snapObs.connectionState == ConnectionState.waiting) {
                return const VeridiaLoader(message: 'Calculando métricas...');
              }

              final observaciones = snapObs.data ?? const <Observation>[];

              return StreamBuilder<List<UserProfile>>(
                stream: UserRepository.instance.streamAllUsers(),
                builder: (context, snapUsers) {
                  final usuarios = snapUsers.data ?? const <UserProfile>[];
                  return ValueListenableBuilder<List<Challenge>>(
                    valueListenable: ChallengeRepository.instance.challenges,
                    builder: (context, desafios, _) => _contenido(
                      historico: observaciones,
                      usuarios: usuarios,
                      desafios: desafios,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _contenido({
    required List<Observation> historico,
    required List<UserProfile> usuarios,
    required List<Challenge> desafios,
  }) {
    final periodo = enRango(historico, _rango.dias);

    final exploradores = usuarios.where((u) => u.role == 'Explorador').toList();
    final nombrePorId = {for (final u in usuarios) u.userId: u.displayName};

    final especiesUnicas = periodo
        .where(especieIdentificada)
        .map((o) => o.commonName.trim().toLowerCase())
        .toSet()
        .length;

    final veridiumsEnCirculacion = exploradores.fold<int>(
      0,
      (suma, u) => suma + u.tokens,
    );
    // Los desafíos guardan cuántos exploradores los cerraron; el progreso en
    // sí es privado de cada cuenta, así que este contador es la única lectura
    // agregada posible sin invadir datos personales.
    final completados = desafios.fold<int>(0, (s, d) => s + d.completadoPor);

    final activos = periodo
        .map((o) => o.userId)
        .whereType<String>()
        .toSet()
        .length;

    final conFoto = periodo.where((o) => o.hasPhoto).length;
    final conGps = periodo.where((o) => o.hasCoordinates).length;
    final identificadas = periodo.where(especieIdentificada).length;

    final serie = agruparSerie(
      actividadPorDia(periodo, dias: _rango.dias),
      _rango == RangoAnalitica.semana ? 7 : 10,
    );
    final topEspecies = ranking(
      periodo.where(especieIdentificada).map((o) => o.commonName),
    );
    final topExploradores = rankingPorId(
      periodo.map((o) => o.userId).whereType<String>(),
      etiqueta: (id) => nombrePorId[id] ?? 'Cuenta eliminada',
    );
    final topZonas = ranking(_zonasDeObservaciones(periodo));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _SelectorRango(
          rango: _rango,
          onCambiar: (r) => setState(() => _rango = r),
        ),
        const SizedBox(height: 20),
        VeridiaSectionTitle(
          title: 'Resumen de los últimos ${_rango.etiqueta}',
          subtitle: periodo.isEmpty
              ? 'No hubo actividad en este periodo'
              : '${periodo.length} de ${historico.length} avistamientos '
                    'caen en esta ventana',
        ),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.78,
          children: [
            VeridiaStat(
              value: '${periodo.length}',
              label: 'Avistamientos',
              icon: Icons.photo_camera_outlined,
            ),
            VeridiaStat(
              value: '$especiesUnicas',
              label: 'Especies distintas',
              icon: Icons.pets_outlined,
              color: VeridiaColors.secondary,
            ),
            VeridiaStat(
              value: '$activos/${exploradores.length}',
              label: 'Exploradores que aportaron',
              icon: Icons.groups_outlined,
              color: VeridiaColors.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const VeridiaSectionTitle(
          title: 'Estado general',
          subtitle: 'Cifras acumuladas de toda la app, no del periodo',
        ),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.78,
          children: [
            VeridiaStat(
              value: '${historico.length}',
              label: 'Avistamientos totales',
              icon: Icons.inventory_2_outlined,
            ),
            VeridiaStat(
              value: '$veridiumsEnCirculacion',
              label: 'Veridiums sin gastar',
              icon: Icons.savings_outlined,
              color: VeridiaColors.veridium,
            ),
            VeridiaStat(
              value: '$completados',
              label: 'Desafíos completados',
              icon: Icons.emoji_events_outlined,
              color: VeridiaColors.veridium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _ResumenCanjes(),
        const SizedBox(height: 24),
        VeridiaSectionTitle(
          title: 'Actividad',
          subtitle: _rango == RangoAnalitica.semana
              ? 'Avistamientos registrados cada día'
              : 'Avistamientos agrupados por bloques de días',
        ),
        _GraficoBarras(serie: serie, dias: _rango.dias),
        const SizedBox(height: 24),
        const VeridiaSectionTitle(
          title: 'Especies más registradas',
          subtitle: 'Lo que más está viendo la comunidad',
        ),
        _ListaRanking(
          datos: topEspecies,
          icono: Icons.pets_rounded,
          color: VeridiaColors.primary,
          vacio: 'Nadie identificó especies en este periodo.',
        ),
        const SizedBox(height: 24),
        const VeridiaSectionTitle(
          title: 'Zonas más visitadas',
          subtitle: 'Dónde se están tomando las fotos',
        ),
        _ListaRanking(
          datos: topZonas,
          icono: Icons.place_rounded,
          color: VeridiaColors.secondary,
          vacio: _zonasCargadas
              ? 'Ninguna foto del periodo trae ubicación.'
              : 'Cargando las zonas del mapa...',
        ),
        const SizedBox(height: 24),
        const VeridiaSectionTitle(
          title: 'Exploradores más activos',
          subtitle: 'Quién está aportando más registros',
        ),
        _ListaRanking(
          datos: topExploradores,
          icono: Icons.person_rounded,
          color: VeridiaColors.tertiary,
          vacio: 'Nadie registró especies en este periodo.',
        ),
        const SizedBox(height: 24),
        const VeridiaSectionTitle(
          title: 'Calidad de los datos',
          subtitle: 'Qué tan completos llegan los registros del periodo',
        ),
        VeridiaCard(
          child: Column(
            children: [
              _FilaPorcentaje(
                etiqueta: 'Con especie identificada por la IA',
                parte: identificadas,
                total: periodo.length,
                color: VeridiaColors.primary,
              ),
              const SizedBox(height: 16),
              _FilaPorcentaje(
                etiqueta: 'Con foto guardada',
                parte: conFoto,
                total: periodo.length,
                color: VeridiaColors.secondary,
              ),
              const SizedBox(height: 16),
              _FilaPorcentaje(
                etiqueta: 'Con ubicación en el mapa',
                parte: conGps,
                total: periodo.length,
                color: VeridiaColors.tertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _NotaMetodo(
          totalCargado: historico.length,
          suspendidos: exploradores.where((u) => u.isBanned).length,
        ),
      ],
    );
  }
}

/// Selector de ventana temporal.
class _SelectorRango extends StatelessWidget {
  const _SelectorRango({required this.rango, required this.onCambiar});

  final RangoAnalitica rango;
  final ValueChanged<RangoAnalitica> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opcion in RangoAnalitica.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onCambiar(opcion),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: EdgeInsets.only(
                  right: opcion == RangoAnalitica.values.last ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  color: opcion == rango
                      ? VeridiaColors.secondaryContainer
                      : VeridiaColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(VeridiaRadii.pill),
                  border: Border.all(
                    color: opcion == rango
                        ? VeridiaColors.secondary.withValues(alpha: 0.6)
                        : VeridiaColors.outlineVariant,
                  ),
                ),
                child: Text(
                  opcion.etiqueta,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: opcion == rango
                        ? VeridiaColors.onSecondaryContainer
                        : VeridiaColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Cuántos Veridiums se han gastado de verdad, leído de los canjes.
class _ResumenCanjes extends StatelessWidget {
  const _ResumenCanjes();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return StreamBuilder<List<Canje>>(
      stream: RewardRepository.instance.streamTodos(),
      builder: (context, snapshot) {
        final canjes = snapshot.data ?? const <Canje>[];
        final gastados = canjes.fold<int>(0, (s, c) => s + c.costo);

        return VeridiaCard(
          child: Row(
            children: [
              const Icon(
                Icons.redeem_rounded,
                color: VeridiaColors.veridium,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  canjes.isEmpty
                      ? 'Todavía nadie ha canjeado recompensas.'
                      : '${canjes.length} canjes han retirado $gastados '
                            'Veridiums de circulación.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barras de actividad dibujadas con Containers para no arrastrar una
/// librería de gráficas por un solo widget.
class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({required this.serie, required this.dias});

  final List<int> serie;
  final int dias;

  static const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maximo = serie.fold<int>(0, (a, b) => a > b ? a : b);
    final total = serie.fold<int>(0, (a, b) => a + b);
    final hoy = DateTime.now();
    final porColumna = (dias / serie.length).ceil();

    if (total == 0) {
      return VeridiaCard(
        child: SizedBox(
          height: 90,
          child: Center(
            child: Text(
              'Sin avistamientos en los últimos $dias días.\n'
              'Prueba con un rango más amplio.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
        ),
      );
    }

    return VeridiaCard(
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(serie.length, (i) {
                final valor = serie[i];
                final diasAtras = (serie.length - 1 - i) * porColumna;
                final dia = hoy.subtract(Duration(days: diasAtras));
                // Con un día por barra basta la inicial; agrupadas, el día
                // del mes ubica mejor el bloque.
                final etiqueta = porColumna == 1
                    ? _iniciales[dia.weekday - 1]
                    : '${dia.day}';
                final proporcion = maximo == 0 ? 0.0 : valor / maximo;
                final esUltima = i == serie.length - 1;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$valor',
                          style: text.labelSmall?.copyWith(
                            color: esUltima
                                ? VeridiaColors.secondary
                                : VeridiaColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 8 + proporcion * 86,
                          decoration: BoxDecoration(
                            color: esUltima
                                ? VeridiaColors.secondary
                                : VeridiaColors.primary.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(
                              VeridiaRadii.sm,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          etiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: text.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            porColumna == 1
                ? '$total avistamientos · el pico fue de $maximo en un día'
                : '$total avistamientos · cada barra suma $porColumna días',
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _ListaRanking extends StatelessWidget {
  const _ListaRanking({
    required this.datos,
    required this.icono,
    required this.color,
    required this.vacio,
  });

  final List<MapEntry<String, int>> datos;
  final IconData icono;
  final Color color;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (datos.isEmpty) {
      return VeridiaCard(child: Text(vacio, style: text.bodySmall));
    }

    final maximo = datos.first.value;
    return VeridiaCard(
      child: Column(
        children: [
          for (var i = 0; i < datos.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              datos[i].key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge,
                            ),
                          ),
                          Text(
                            '${datos[i].value}',
                            style: text.labelSmall?.copyWith(color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      VeridiaProgressBar(
                        value: maximo == 0 ? 0 : datos[i].value / maximo,
                        height: 6,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaPorcentaje extends StatelessWidget {
  const _FilaPorcentaje({
    required this.etiqueta,
    required this.parte,
    required this.total,
    required this.color,
  });

  final String etiqueta;
  final int parte;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final proporcion = total == 0 ? 0.0 : parte / total;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(etiqueta, style: text.labelLarge)),
            Text(
              total == 0
                  ? 'sin datos'
                  : '$parte de $total · ${(proporcion * 100).round()}%',
              style: text.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        VeridiaProgressBar(value: proporcion, height: 6, color: color),
      ],
    );
  }
}

/// Aclara de dónde salen las cifras. Sin esto, un cero se lee como un fallo
/// de la app y no como "no hubo actividad".
class _NotaMetodo extends StatelessWidget {
  const _NotaMetodo({required this.totalCargado, required this.suspendidos});

  final int totalCargado;
  final int suspendidos;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final truncado = totalCargado >= limiteAnalitica;

    return VeridiaCard(
      color: VeridiaColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: VeridiaColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text('Cómo leer estos datos', style: text.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '· Cada avistamiento es una foto que un explorador guardó en su '
            'diario.\n'
            '· "Especies distintas" solo cuenta las que la IA logró '
            'identificar.\n'
            '· El progreso de cada desafío es privado de cada cuenta; aquí '
            'solo se ve cuántos se completaron en total.\n'
            '· Las fotos sin ubicación no aparecen en "zonas más visitadas".'
            '${suspendidos > 0 ? '\n· Hay $suspendidos cuenta(s) suspendida(s), que siguen contando en los totales históricos.' : ''}'
            '${truncado ? '\n· Se analizan los $limiteAnalitica avistamientos más recientes.' : ''}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
