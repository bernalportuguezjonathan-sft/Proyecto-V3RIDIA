import 'package:flutter/material.dart';
import 'identify_species.dart';
import 'models/bird_zone.dart';
import 'models/observation.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
import 'widgets/veridia_ui.dart';

class MapDetailScreen extends StatefulWidget {
  final BirdZone zone;

  /// Fotos que los exploradores ya registraron dentro de esta zona. El mapa
  /// las calcula una sola vez y las pasa hechas para no repetir aquí el
  /// cruce de coordenadas contra los polígonos.
  final List<Observation> avistamientos;

  const MapDetailScreen({
    super.key,
    required this.zone,
    this.avistamientos = const [],
  });

  @override
  State<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends State<MapDetailScreen> {
  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.zone.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: VeridiaColors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          VeridiaAppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VeridiaColors.primaryContainer,
                      VeridiaColors.tertiaryContainer,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: VeridiaColors.surfaceContainer.withValues(
                              alpha: 0.3,
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: widget.zone.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: VeridiaColors.surfaceContainer,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.18),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.nature,
                              color: VeridiaColors.onSurface,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: VeridiaColors.surfaceContainer.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.zone.location,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: VeridiaColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.zone.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: VeridiaColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VeridiaColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VeridiaColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.eco,
                              color: VeridiaColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hábitat: ${widget.zone.habitat}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.zone.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: VeridiaColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Especies que puedes encontrar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: VeridiaColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: widget.zone.species.map((species) {
                        return _crearTarjetaEspecie(species);
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Fotos registradas en la zona',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: VeridiaColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        VeridiaTag(
                          label: '${widget.avistamientos.length}',
                          icon: Icons.photo_camera_outlined,
                          color: VeridiaColors.secondary,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.avistamientos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: VeridiaColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Nadie ha fotografiado especies aquí todavía. '
                          'Puedes ser el primero.',
                          style: TextStyle(
                            fontSize: 12,
                            color: VeridiaColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: widget.avistamientos
                            .map((o) => _TarjetaAvistamiento(observacion: o))
                            .toList(),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: VeridiaBotonTactil(
                        child: ElevatedButton.icon(
                          onPressed: () => VeridiaNav.abrir(
                            context,
                            const IdentifySpeciesScreen(),
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Capturar observación aquí'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crearTarjetaEspecie(BirdSpecies species) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              species.imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 48,
                height: 48,
                color: species.color.withValues(alpha: 0.15),
                child: Center(
                  child: Text(
                    species.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  species.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  species.scientificName,
                  style: TextStyle(
                    fontSize: 10,
                    color: VeridiaColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  species.descriptionHabitat,
                  style: TextStyle(
                    fontSize: 9,
                    color: VeridiaColors.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de una foto registrada en la zona, con el nombre de la especie.
class _TarjetaAvistamiento extends StatelessWidget {
  const _TarjetaAvistamiento({required this.observacion});

  final Observation observacion;

  void _mostrarDetalle(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(observacion.commonName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (observacion.hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  observacion.imagePath!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              observacion.scientificName,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(observacion.notes, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              'Por ${observacion.userDisplayName ?? 'Explorador'} · '
              '${formatoFecha(observacion.dateTime)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarDetalle(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (observacion.hasPhoto)
              Image.network(
                observacion.imagePath!,
                fit: BoxFit.cover,
                cacheWidth: 320,
                errorBuilder: (_, _, _) => Container(
                  color: VeridiaColors.surfaceContainerHigh,
                  child: const Icon(
                    Icons.eco_outlined,
                    color: VeridiaColors.primary,
                  ),
                ),
              )
            else
              Container(
                color: VeridiaColors.surfaceContainerHigh,
                child: const Icon(
                  Icons.eco_outlined,
                  color: VeridiaColors.primary,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  observacion.commonName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: VeridiaColors.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
