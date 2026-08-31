import 'package:flutter/material.dart';
import 'models/observation.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
import 'widgets/veridia_ui.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Observation> _filtrar(List<Observation> items) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (o) =>
              o.commonName.toLowerCase().contains(q) ||
              o.scientificName.toLowerCase().contains(q) ||
              o.location.toLowerCase().contains(q) ||
              o.notes.toLowerCase().contains(q),
        )
        .toList();
  }

  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar especie'),
        content: const Text('¿Deseas eliminar esta especie del historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await ObservationRepository.instance.deleteObservation(id);
              navigator.pop();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: VeridiaColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VeridiaColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historial',
          style: TextStyle(
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: VeridiaColors.onSurface,
          unselectedLabelColor: VeridiaColors.onSurfaceVariant,
          indicatorColor: VeridiaColors.onSurface,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Almacenamientos'),
            Tab(text: 'Lugares'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(color: VeridiaColors.background),
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: TODAS
                _buildHistorialTab(),
                // TAB 2: ALMACENAMIENTOS
                _buildAlmacenamientosTab(),
                // TAB 3: LUGARES
                _buildLugaresTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(3),
    );
  }

  Widget _buildHistorialTab() {
    final userId = UserRepository.instance.currentUser.value?.userId;
    if (userId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: Text('Inicia sesión para ver tu historial.'),
        ),
      );
    }
    return StreamBuilder<List<Observation>>(
      stream: ObservationRepository.instance.streamForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo cargar el historial: ${snapshot.error}'),
            ),
          );
        }
        final observations = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtros
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar por especie, lugar o nota',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: VeridiaColors.primary,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: VeridiaColors.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: VeridiaColors.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (observations.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No hay especies en el historial aún.'),
                  ),
                )
              else if (_filtrar(observations).isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'Ninguna observación coincide con tu búsqueda.',
                    ),
                  ),
                )
              else
                Column(
                  children: _filtrar(observations).map((captura) {
                    return _crearTarjetaCaptura(captura);
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlmacenamientosTab() {
    final userId = UserRepository.instance.currentUser.value?.userId;
    if (userId == null) {
      return const Center(child: Text('Inicia sesión para ver tus insignias.'));
    }

    return StreamBuilder<List<Observation>>(
      stream: ObservationRepository.instance.streamForUser(userId),
      builder: (context, snapshot) {
        final observations = snapshot.data ?? [];
        final total = observations.length;
        final especiesUnicas = observations
            .map((o) => o.commonName.toLowerCase())
            .toSet()
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _resumenCard('Observaciones', '$total')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _resumenCard(
                      'Especies distintas',
                      '$especiesUnicas',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Insignias',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: VeridiaColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _crearInsignia('Primera captura', Icons.star, total >= 1),
                  _crearInsignia('5 observaciones', Icons.star, total >= 5),
                  _crearInsignia(
                    '10 especies',
                    Icons.emoji_events,
                    especiesUnicas >= 10,
                  ),
                  _crearInsignia(
                    '50 observaciones',
                    Icons.military_tech,
                    total >= 50,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _resumenCard(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: veridiaCaraClay(VeridiaColors.surfaceContainer),
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        border: Border.all(color: VeridiaCard.bordePorDefecto),
        boxShadow: veridiaRelieve(),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: VeridiaColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: VeridiaColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLugaresTab() {
    final userId = UserRepository.instance.currentUser.value?.userId;
    if (userId == null) {
      return const Center(child: Text('Inicia sesión para ver tus lugares.'));
    }
    return StreamBuilder<List<Observation>>(
      stream: ObservationRepository.instance.streamForUser(userId),
      builder: (context, snapshot) {
        final observations = snapshot.data ?? [];
        if (observations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No hay lugares registrados aún.')),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: observations
                .take(3)
                .map((captura) => _crearTarjetaCaptura(captura))
                .toList(),
          ),
        );
      },
    );
  }

  /// Ficha de una observación del diario.
  ///
  /// La versión anterior metía nombre, especie, fecha, coordenadas y toda la
  /// descripción en una sola columna estrecha al lado de la miniatura: seis
  /// líneas de texto de anchos distintos apiladas contra el borde, sin nada
  /// que dijera cuál era el dato principal. Ahora la ficha tiene dos zonas
  /// —una cabecera de identificación y, debajo, la descripción a todo el
  /// ancho— y los dos metadatos van en cápsulas en vez de sueltos, que es lo
  /// que los separa de la prosa.
  Widget _crearTarjetaCaptura(Observation captura) {
    final tieneNota = captura.notes.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: veridiaCaraClay(VeridiaColors.surfaceContainer),
        borderRadius: BorderRadius.circular(VeridiaRadii.lg),
        border: Border.all(color: VeridiaCard.bordePorDefecto),
        boxShadow: veridiaRelieve(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _miniaturaCaptura(captura),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        captura.commonName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: VeridiaFonts.headline,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                          height: 1.15,
                          color: VeridiaColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        captura.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: VeridiaFonts.body,
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: VeridiaColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Wrap y no Row: en un móvil angosto la fecha y las
                      // coordenadas no caben en una sola línea, y dentro de
                      // un Row la segunda cápsula se desbordaba por el lado.
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _metaCaptura(
                            Icons.schedule_rounded,
                            formatoFechaHora(captura.dateTime),
                          ),
                          if (captura.location.trim().isNotEmpty)
                            _metaCaptura(
                              Icons.place_outlined,
                              captura.location,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _borrarCaptura(captura.id),
              ],
            ),
            if (tieneNota) ...[
              const SizedBox(height: 14),
              Container(
                height: 1,
                color: VeridiaColors.primary.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 12),
              Text(
                captura.notes,
                style: const TextStyle(
                  fontFamily: VeridiaFonts.body,
                  fontSize: 12.5,
                  height: 1.5,
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// La foto de la observación, o el hueco cuando no la hay.
  Widget _miniaturaCaptura(Observation captura) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(VeridiaRadii.sm),
      child: Container(
        width: 92,
        height: 92,
        // Hueco oscuro: la miniatura es un nicho excavado en la ficha, y en
        // un verde claro una foto oscura se recorta mal contra el marco.
        color: VeridiaColors.surfaceContainerLowest,
        child: captura.hasPhoto
            ? Image.network(
                captura.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: VeridiaColors.onSurfaceVariant,
                    size: 26,
                  ),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.no_photography_outlined,
                    color: VeridiaColors.onSurfaceVariant,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sin foto',
                    style: TextStyle(
                      fontFamily: VeridiaFonts.body,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: VeridiaColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Cápsula de un dato de contexto: cuándo y dónde.
  Widget _metaCaptura(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
        border: Border.all(
          color: VeridiaColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: VeridiaColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(
              fontFamily: VeridiaFonts.body,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: VeridiaColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Solo borrar: el lápiz de editar se quitó porque lo que hay en la ficha
  /// son datos de la IA y coordenadas de campo, y reescribirlos a mano
  /// convierte el diario en algo que ya no prueba nada.
  Widget _borrarCaptura(String id) {
    return Tooltip(
      message: 'Borrar del diario',
      child: Material(
        color: VeridiaColors.error.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VeridiaRadii.sm),
          side: BorderSide(color: VeridiaColors.error.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDeleteDialog(id),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.delete_outline_rounded,
              color: VeridiaColors.error,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  Widget _crearInsignia(String titulo, IconData icon, bool desbloqueada) {
    return Container(
      decoration: BoxDecoration(
        gradient: veridiaCaraClay(VeridiaColors.surfaceContainer),
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        border: Border.all(color: VeridiaCard.bordePorDefecto),
        boxShadow: veridiaRelieve(),
      ),
      child: Opacity(
        opacity: desbloqueada ? 1 : 0.35,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              desbloqueada ? icon : Icons.lock_outline,
              size: 32,
              color: VeridiaColors.primary,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: VeridiaColors.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(int currentIndex) {
    return VeridiaBottomNav(
      currentIndex: 3,
      onTap: (i) => VeridiaNav.ir(context, VeridiaSeccion.values[i], 3),
    );
  }
}
