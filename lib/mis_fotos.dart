import 'package:flutter/material.dart';

import 'models/bird_zone.dart';
import 'models/observation.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Grupo al que van las fotos que caen lejos de cualquier zona registrada.
const _sinZona = 'Fuera de zonas registradas';

/// Galería de las fotos PROPIAS, a pantalla completa.
///
/// El panel del mapa mostraba las fotos de todo el mundo en una franja de
/// 200 px: para ver las tuyas había que reconocerlas entre las ajenas, y las
/// miniaturas eran tan pequeñas que no se distinguía una garza de un pato.
///
/// Los marcadores del mapa siguen siendo COMUNITARIOS a propósito —el mapa de
/// Cundinamarca se construye entre todos, ver [[project-veridia-datos-por-usuario]]—
/// pero esta galería es solo tuya: responde a "¿qué he registrado yo?", que es
/// una pregunta distinta.
Future<void> abrirMisFotos(BuildContext context, List<BirdZone> zonas) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: VeridiaColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => MisFotosSheet(zonas: zonas),
  );
}

class MisFotosSheet extends StatelessWidget {
  const MisFotosSheet({super.key, required this.zonas});

  /// Zonas ya cargadas por el mapa: se pasan en vez de releer el JSON para no
  /// hacer el mismo trabajo dos veces al abrir la hoja.
  final List<BirdZone> zonas;

  @override
  Widget build(BuildContext context) {
    final uid = UserRepository.instance.currentUser.value?.userId;

    // Casi toda la pantalla, pero dejando ver un poco del mapa detrás: así se
    // entiende que es una capa encima y no se perdió el contexto.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: VeridiaColors.outline,
              borderRadius: BorderRadius.circular(VeridiaRadii.pill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_rounded,
                  color: VeridiaColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis fotos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Solo lo que has registrado tú',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: VeridiaColors.outlineVariant),
          Expanded(
            child: uid == null
                ? const VeridiaEmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'Sin sesión',
                    message: 'Inicia sesión para ver tus fotos.',
                  )
                : StreamBuilder<List<Observation>>(
                    stream: ObservationRepository.instance.streamForUser(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: VeridiaLoader());
                      }
                      // El filtro de verdad ya lo hace la consulta
                      // (`where userId == uid`), pero se repite aquí porque
                      // el stream puede traer caché local de una sesión
                      // anterior antes de que el servidor responda.
                      final mias = (snapshot.data ?? const <Observation>[])
                          .where((o) => o.userId == uid)
                          .toList();
                      if (mias.isEmpty) {
                        return const VeridiaEmptyState(
                          icon: Icons.photo_camera_outlined,
                          title: 'Todavía no tienes fotos',
                          message:
                              'Registra una especie con la cámara y aparecerá '
                              'aquí, agrupada por la zona donde la tomaste.',
                        );
                      }
                      return _Galeria(fotos: mias, zonas: zonas);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Galeria extends StatelessWidget {
  const _Galeria({required this.fotos, required this.zonas});

  final List<Observation> fotos;
  final List<BirdZone> zonas;

  /// Agrupa por NOMBRE de zona. Las que caen lejos de todo van a un grupo
  /// aparte en vez de desaparecer de la galería.
  Map<String, List<Observation>> _porZona() {
    final grupos = <String, List<Observation>>{};
    for (final foto in fotos) {
      final zona = foto.hasCoordinates
          ? zonaDePunto(zonas, foto.latitude!, foto.longitude!)
          : null;
      grupos.putIfAbsent(zona?.name ?? _sinZona, () => []).add(foto);
    }
    for (final lista in grupos.values) {
      lista.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }
    final ordenadas = grupos.entries.toList()
      ..sort((a, b) {
        if (a.key == _sinZona) return 1;
        if (b.key == _sinZona) return -1;
        return b.value.length.compareTo(a.value.length);
      });
    return Map.fromEntries(ordenadas);
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _porZona();
    final especies = fotos
        .map((o) => o.commonName.trim().toLowerCase())
        .toSet()
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          children: [
            VeridiaTag(
              label: '${fotos.length} fotos',
              icon: Icons.photo_camera_rounded,
              color: VeridiaColors.primary,
              dense: true,
            ),
            const SizedBox(width: 8),
            VeridiaTag(
              label: '$especies especies',
              icon: Icons.eco_rounded,
              color: VeridiaColors.secondary,
              dense: true,
            ),
            const SizedBox(width: 8),
            VeridiaTag(
              label: '${grupos.length} zonas',
              icon: Icons.terrain_rounded,
              color: VeridiaColors.tertiary,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...grupos.entries.map(
          (grupo) => Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      grupo.key == _sinZona
                          ? Icons.explore_off_rounded
                          : Icons.place_rounded,
                      size: 16,
                      color: VeridiaColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        grupo.key,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${grupo.value.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: grupo.value.length,
                  itemBuilder: (context, i) => _Miniatura(foto: grupo.value[i]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.foto});

  final Observation foto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarDetalle(context, foto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(VeridiaRadii.md),
              child: foto.hasPhoto
                  ? Image.network(
                      foto.imagePath!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      // Sin cacheWidth, Flutter decodifica la foto original
                      // completa por cada miniatura y la galería se traga la
                      // memoria en cuanto hay treinta.
                      cacheWidth: 240,
                      errorBuilder: (_, _, _) =>
                          const VeridiaFotoVacia(tamanoIcono: 20),
                    )
                  : const VeridiaFotoVacia(tamanoIcono: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            foto.commonName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

void _mostrarDetalle(BuildContext context, Observation foto) {
  showDialog<void>(
    context: context,
    builder: (dialogo) => Dialog(
      backgroundColor: VeridiaColors.surfaceContainer,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (foto.hasPhoto)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                foto.imagePath!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) =>
                    const VeridiaFotoVacia(tamanoIcono: 32),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foto.commonName,
                  style: Theme.of(dialogo).textTheme.titleMedium,
                ),
                Text(
                  foto.scientificName,
                  style: Theme.of(
                    dialogo,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
                Text(
                  '${foto.location} · ${formatoFechaHora(foto.dateTime)}',
                  style: Theme.of(dialogo).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
