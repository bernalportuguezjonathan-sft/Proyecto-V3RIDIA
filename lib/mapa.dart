import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'detallemapa.dart';
import 'models/bird_zone.dart';
import 'models/observation.dart';
import 'services/geocodificacion.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'identify_species.dart';
import 'navegacion.dart';
import 'widgets/veridia_ui.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialQuery});

  /// Búsqueda con la que abrir el mapa (por ejemplo desde el buscador de
  /// Inicio). Filtra zonas y especies apenas se carga la pantalla.
  final String? initialQuery;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final TextEditingController _searchController;
  late final MapController _mapController;
  String? _selectedSpecies;
  List<BirdZone> _birdZones = [];
  List<BirdZone> _filteredZones = [];
  bool _isLoadingZones = true;
  final LatLng _defaultCenter = const LatLng(4.7120, -74.2000);

  List<Observation> _sightings = [];
  List<Observation> _filteredSightings = [];
  StreamSubscription<List<Observation>>? _sightingsSub;
  bool _showSightings = true;

  /// Qué lista muestra el panel inferior: las zonas curadas del mapa, las
  /// fotos ya registradas, o los lugares reales que se buscaron por nombre.
  _PanelMapa _panel = _PanelMapa.zonas;

  /// El panel arranca plegado para que el mapa se vea completo; se despliega
  /// al tocar una pestaña o arrastrarlo hacia arriba.
  bool _panelAbierto = false;

  /// Resultados de buscar un lugar real (Nominatim/OpenStreetMap): existen
  /// aunque ese lugar no esté entre las zonas curadas del JSON, igual que en
  /// Google Maps se puede buscar cualquier sitio del mundo.
  List<LugarEncontrado> _lugaresEncontrados = [];
  bool _buscandoLugar = false;
  String? _errorLugar;

  /// Lugar que el explorador eligió de los resultados: se marca en el mapa
  /// con un pin propio y se le muestran las fotos tomadas cerca.
  LugarEncontrado? _lugarSeleccionado;

  /// Avistamientos indexados por id de zona, con `_sinZona` para los que caen
  /// lejos de todo. Se recalcula solo cuando cambian las fotos o las zonas:
  /// cruzar cada foto contra cada polígono dentro de `build` hacía ese
  /// trabajo decenas de veces por segundo mientras se arrastra el mapa.
  Map<String, List<Observation>> _fotosPorZonaId = const {};

  LatLng? _userLocation;
  String? _locationMessage;
  static const Distance _distance = Distance();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _mapController = MapController();
    _loadBirdZones();
    _locateUser();
    _sightingsSub = ObservationRepository.instance.streamAll().listen((
      sightings,
    ) {
      if (!mounted) return;
      setState(() {
        _sightings = sightings.where((s) => s.hasCoordinates).toList();
        _filteredSightings = _filtrarAvistamientos();
        _indexarFotosPorZona();
      });
    }, onError: (_) {});
  }

  /// Avistamientos que responden a la búsqueda actual.
  ///
  /// El chip de especies filtra zonas por nombre exacto de especie; sobre las
  /// fotos se aplica el mismo texto, así "Garza" deja ver tanto la zona como
  /// las fotos de garzas que ya se tomaron allí.
  List<Observation> _filtrarAvistamientos() {
    return filtrarObservaciones(
      _sightings,
      query: _searchController.text,
      especie: _selectedSpecies,
    );
  }

  /// Reconstruye el índice de fotos por zona. Se llama al llegar fotos
  /// nuevas o al cargar las zonas, nunca desde `build`.
  void _indexarFotosPorZona() {
    final indice = <String, List<Observation>>{};
    for (final avistamiento in _sightings) {
      final zona = zonaDePunto(
        _birdZones,
        avistamiento.latitude!,
        avistamiento.longitude!,
      );
      indice.putIfAbsent(zona?.id ?? _sinZona, () => []).add(avistamiento);
    }
    _fotosPorZonaId = indice;
  }

  /// Agrupa por NOMBRE de zona las fotos que pasan el filtro actual. Las que
  /// caen lejos de toda zona van a un grupo aparte en vez de desaparecer.
  Map<String, List<Observation>> _avistamientosPorZona() {
    final visibles = _filteredSightings.toSet();
    final nombrePorId = {for (final z in _birdZones) z.id: z.name};

    final grupos = <String, List<Observation>>{};
    _fotosPorZonaId.forEach((zonaId, fotos) {
      final coinciden = fotos.where(visibles.contains).toList();
      if (coinciden.isEmpty) return;
      grupos[nombrePorId[zonaId] ?? _sinZona] = coinciden;
    });

    final ordenadas = grupos.entries.toList()
      ..sort((a, b) {
        // El grupo "fuera de zonas" siempre va al final.
        if (a.key == _sinZona) return 1;
        if (b.key == _sinZona) return -1;
        return b.value.length.compareTo(a.value.length);
      });
    return Map.fromEntries(ordenadas);
  }

  /// Fotos tomadas dentro de una zona concreta (sin filtrar por búsqueda).
  List<Observation> _avistamientosDeZona(BirdZone zona) =>
      _fotosPorZonaId[zona.id] ?? const [];

  /// Pide permiso de ubicación y guarda la posición del usuario para poder
  /// ordenar las zonas por cercanía.
  Future<void> _locateUser({bool moveCamera = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(
            () => _locationMessage = 'Activa el GPS para ver zonas cercanas',
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationMessage = 'Permiso de ubicación denegado');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = location;
        _locationMessage = null;
      });
      if (moveCamera) {
        _mapController.move(location, 14.0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationMessage = 'No se pudo obtener tu ubicación');
    }
  }

  /// Distancia en kilómetros entre el usuario y una zona (null si no hay GPS).
  double? _distanciaKm(double lat, double lng) {
    final user = _userLocation;
    if (user == null) return null;
    return _distance
        .as(LengthUnit.Kilometer, user, LatLng(lat, lng))
        .toDouble();
  }

  String _etiquetaDistancia(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  /// Zonas visibles ordenadas por cercanía al usuario (si hay ubicación).
  List<BirdZone> get _zonasOrdenadas {
    final zones = List<BirdZone>.from(_filteredZones);
    if (_userLocation == null) return zones;
    zones.sort((a, b) {
      final da = _distanciaKm(a.latitude, a.longitude) ?? double.infinity;
      final db = _distanciaKm(b.latitude, b.longitude) ?? double.infinity;
      return da.compareTo(db);
    });
    return zones;
  }

  Future<void> _loadBirdZones() async {
    final zones = await loadBirdZones();
    if (!mounted) return;
    setState(() {
      _birdZones = zones;
      _filteredZones = filterBirdZones(
        zones,
        query: _searchController.text,
        selectedSpecies: _selectedSpecies,
      );
      _filteredSightings = _filtrarAvistamientos();
      _indexarFotosPorZona();
      _isLoadingZones = false;
    });

    if (zones.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(
          LatLng(zones.first.latitude, zones.first.longitude),
          13.0,
        );
      });
    }
  }

  @override
  void dispose() {
    _sightingsSub?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _showSightingSheet(Observation sighting) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFB45309),
                  child: Icon(
                    Icons.camera_alt,
                    color: VeridiaColors.onSurface,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sighting.commonName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sighting.scientificName,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: VeridiaColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sighting.hasPhoto) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  sighting.imagePath!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (sighting.notes.isNotEmpty)
              Text(
                sighting.notes,
                style: TextStyle(
                  fontSize: 13,
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Avistado por: ${sighting.userDisplayName ?? 'Explorador'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              formatoFecha(sighting.dateTime),
              style: TextStyle(
                fontSize: 11,
                color: VeridiaColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  void _applyFilters() {
    setState(() {
      _filteredZones = filterBirdZones(
        _birdZones,
        query: _searchController.text,
        selectedSpecies: _selectedSpecies,
      );
      _filteredSightings = _filtrarAvistamientos();
      // Si la búsqueda no da zonas pero sí fotos, mostramos las fotos: es lo
      // que el explorador está buscando.
      if (_searchController.text.trim().isNotEmpty &&
          _filteredZones.isEmpty &&
          _filteredSightings.isNotEmpty) {
        _panel = _PanelMapa.fotos;
        _panelAbierto = true;
      }
    });
  }

  void _resetView() {
    setState(() {
      _searchController.clear();
      _selectedSpecies = null;
      _filteredZones = _birdZones;
      _filteredSightings = _sightings;
      _panel = _PanelMapa.zonas;
      _panelAbierto = false;
      _lugaresEncontrados = [];
      _lugarSeleccionado = null;
      _errorLugar = null;
    });
    final center = _birdZones.isNotEmpty
        ? LatLng(_birdZones.first.latitude, _birdZones.first.longitude)
        : _defaultCenter;
    _mapController.move(center, 12.0);
  }

  /// Busca un lugar real por nombre (calles, veredas, laguna de la Herrera,
  /// barrios...), no solo entre las zonas curadas del JSON.
  ///
  /// Se dispara al enviar la búsqueda (tecla o botón "buscar" del teclado),
  /// nunca en cada letra: Nominatim, el geocodificador gratuito que se usa
  /// aquí, pide como máximo ~1 petición por segundo.
  Future<void> _buscarLugar() async {
    final texto = _searchController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _buscandoLugar = true;
      _errorLugar = null;
    });

    try {
      final resultados = await GeocodificacionService.buscar(texto);
      if (!mounted) return;
      setState(() {
        _lugaresEncontrados = resultados;
        _buscandoLugar = false;
        _errorLugar = resultados.isEmpty
            ? 'No se encontró "$texto". Prueba con otro nombre o revisa la ortografía.'
            : null;
        // Si la búsqueda local no encontró zonas ni fotos, el lugar real es
        // lo único que hay que mostrar: se salta directo a esa pestaña.
        if (resultados.isNotEmpty &&
            _filteredZones.isEmpty &&
            _filteredSightings.isEmpty) {
          _panel = _PanelMapa.lugares;
          _panelAbierto = true;
        }
      });
    } on LugarBusquedaException catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoLugar = false;
        _lugaresEncontrados = [];
        _errorLugar = e.message;
      });
    }
  }

  /// Avistamientos con foto a menos de [radioKm] de un punto cualquiera del
  /// mapa mundial (no solo dentro de una zona curada).
  ///
  /// Es lo que conecta "busqué la laguna de la Herrera" con "aquí están las
  /// fotos que la gente ya tomó cerca", aunque esa laguna no tenga zona
  /// dibujada ni polígono en el JSON.
  List<Observation> _avistamientosCercaDe(
    double lat,
    double lng, {
    double radioKm = 2,
  }) {
    final centro = LatLng(lat, lng);
    return _sightings.where((o) {
      if (!o.hasCoordinates) return false;
      final km = _distance.as(
        LengthUnit.Kilometer,
        centro,
        LatLng(o.latitude!, o.longitude!),
      );
      return km <= radioKm;
    }).toList();
  }

  void _seleccionarLugar(LugarEncontrado lugar) {
    setState(() => _lugarSeleccionado = lugar);
    _mapController.move(LatLng(lugar.latitude, lugar.longitude), 15.0);
    _showLugarSheet(lugar);
  }

  void _focusZone(BirdZone zone) {
    _mapController.move(LatLng(zone.latitude, zone.longitude), 14.0);
    _showZoneSheet(zone);
  }

  void _showZoneSheet(BirdZone zone) {
    final fotosZona = _avistamientosDeZona(zone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: zone.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.nature,
                      color: VeridiaColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zone.location,
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
              const SizedBox(height: 12),
              Text(
                zone.description,
                style: TextStyle(
                  fontSize: 13,
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Especies destacadas',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: zone.species.map((species) {
                  return Chip(
                    avatar: Text(species.emoji),
                    label: Text(species.name),
                    backgroundColor: species.color.withValues(alpha: 0.15),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: VeridiaColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    fotosZona.isEmpty
                        ? 'Sin fotos registradas todavía'
                        : '${fotosZona.length} ${fotosZona.length == 1 ? 'foto registrada' : 'fotos registradas'} aquí',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: VeridiaColors.secondary,
                    ),
                  ),
                ],
              ),
              if (fotosZona.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 74,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: fotosZona.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final avistamiento = fotosZona[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showSightingSheet(avistamiento);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 74,
                            height: 74,
                            child: avistamiento.hasPhoto
                                ? Image.network(
                                    avistamiento.imagePath!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    errorBuilder: (_, _, _) =>
                                        const VeridiaFotoVacia(tamanoIcono: 16),
                                  )
                                : const VeridiaFotoVacia(tamanoIcono: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapDetailScreen(
                          zone: zone,
                          avistamientos: fotosZona,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Ver misión y especies'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Polygon> _buildPolygons() {
    return _filteredZones.map((zone) {
      return Polygon(
        points: zone.areaPoints,
        color: zone.color.withValues(alpha: 0.22),
        borderStrokeWidth: 2,
        borderColor: zone.color,
      );
    }).toList();
  }

  /// Panel inferior del mapa: alterna entre las zonas y las fotos ya
  /// registradas, que es lo que se busca cuando se escribe una especie.
  /// Buscador flotante sobre el mapa: campo de búsqueda y, debajo, los chips
  /// de especie. Van encima del mapa y no en una franja fija para no robarle
  /// altura al mapa en pantallas de celular.
  Widget _buscadorFlotante(List<String> speciesList) {
    final hayFiltro =
        _searchController.text.trim().isNotEmpty || _selectedSpecies != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(VeridiaRadii.pill),
          color: VeridiaColors.surfaceContainerHigh,
          child: TextField(
            controller: _searchController,
            // Filtra zonas y fotos ya guardadas en cada letra (es local y
            // gratis); buscar un lugar real del mundo espera a que se envíe
            // la búsqueda, porque eso sí sale a internet.
            onChanged: (_) => _applyFilters(),
            onSubmitted: (_) => _buscarLugar(),
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar zonas, especies, fotos o un lugar...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: VeridiaColors.onSurfaceVariant,
              ),
              prefixIcon: IconButton(
                icon: _buscandoLugar
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VeridiaColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.search,
                        size: 20,
                        color: VeridiaColors.primary,
                      ),
                tooltip: 'Buscar el lugar en el mapa',
                onPressed: _buscandoLugar ? null : _buscarLugar,
              ),
              suffixIcon: hayFiltro
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Limpiar búsqueda',
                      onPressed: _resetView,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VeridiaRadii.pill),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: speciesList.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ChipEspecie(
                  etiqueta: 'Todas',
                  activo: _selectedSpecies == null || _selectedSpecies!.isEmpty,
                  onTap: () {
                    setState(() => _selectedSpecies = null);
                    _applyFilters();
                  },
                );
              }
              final species = speciesList[index - 1];
              final activo = _selectedSpecies == species;
              return _ChipEspecie(
                etiqueta: species,
                activo: activo,
                onTap: () {
                  setState(() => _selectedSpecies = activo ? null : species);
                  _applyFilters();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Controles del mapa en una sola fila: ocupan una franja de 40 px en vez
  /// de la columna de tres botones que antes tapaba media pantalla.
  Widget _controlesMapa() {
    final esAdmin =
        UserRepository.instance.currentUser.value?.role == 'Administrador';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotonMapa(
          icono: _showSightings ? Icons.visibility : Icons.visibility_off,
          tooltip: _showSightings
              ? 'Ocultar fotos en el mapa'
              : 'Mostrar fotos en el mapa',
          activo: _showSightings,
          onTap: () => setState(() => _showSightings = !_showSightings),
        ),
        const SizedBox(width: 8),
        _BotonMapa(
          icono: Icons.my_location_rounded,
          tooltip: 'Ir a mi ubicación',
          onTap: () {
            final user = _userLocation;
            if (user != null) {
              _mapController.move(user, 14.0);
            } else {
              _locateUser(moveCamera: true);
            }
          },
        ),
        if (!esAdmin) ...[
          const SizedBox(width: 8),
          _BotonMapa(
            icono: Icons.add_a_photo_rounded,
            tooltip: 'Registrar especie',
            // Mismo tamaño y diseño que el resto de la fila; el único
            // acento es el color verde, prestado del botón "ver fotos"
            // cuando está activo, para que siga siendo el más visible sin
            // desentonar del conjunto.
            activo: true,
            onTap: () =>
                VeridiaNav.abrir(context, const IdentifySpeciesScreen()),
          ),
        ],
      ],
    );
  }

  /// Atribución de las teselas del mapa.
  ///
  /// La licencia de OpenStreetMap exige mostrarla en algún punto de la
  /// pantalla del mapa; no se puede quitar del todo sin dejar de tener
  /// derecho a usar sus teselas gratis. Para que pese lo menos posible se
  /// reduce a un icono "ⓘ" del tamaño de una uña: el texto completo solo
  /// aparece si alguien lo toca a propósito, en vez de quedar siempre
  /// escrito encima del mapa.
  Widget _atribucion() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: VeridiaColors.background.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Datos del mapa'),
              content: Text(VeridiaMapa.atribucion),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: VeridiaColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// Cierra el panel al tocar el mapa, para poder mirarlo sin estorbos.
  void _cerrarPanel() {
    if (_panelAbierto) setState(() => _panelAbierto = false);
  }

  void _abrirPanel(_PanelMapa destino) {
    setState(() {
      // Tocar la pestaña ya abierta lo pliega: sirve de interruptor.
      _panelAbierto = !(_panelAbierto && _panel == destino);
      _panel = destino;
    });
  }

  /// Panel inferior desplegable con las zonas y las fotos por zona.
  ///
  /// Plegado son 44 px (solo las pestañas con sus contadores) y desplegado
  /// crece lo justo para la lista. Se puede arrastrar hacia arriba o abajo.
  Widget _panelInferior() {
    final zonas = _zonasOrdenadas;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocidad = details.primaryVelocity ?? 0;
        if (velocidad < -80) {
          setState(() => _panelAbierto = true);
        } else if (velocidad > 80) {
          setState(() => _panelAbierto = false);
        }
      },
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(VeridiaRadii.lg),
        color: VeridiaColors.surfaceContainer,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VeridiaRadii.lg),
            border: Border.all(
              color: VeridiaColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Asa: da a entender que el panel se arrastra.
              Container(
                width: 34,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: VeridiaColors.outline,
                  borderRadius: BorderRadius.circular(VeridiaRadii.pill),
                ),
              ),
              Row(
                children: [
                  _ChipPanel(
                    etiqueta: 'Zonas',
                    cantidad: zonas.length,
                    icono: Icons.terrain_rounded,
                    activo: _panelAbierto && _panel == _PanelMapa.zonas,
                    onTap: () => _abrirPanel(_PanelMapa.zonas),
                  ),
                  const SizedBox(width: 6),
                  _ChipPanel(
                    etiqueta: 'Fotos',
                    cantidad: _filteredSightings.length,
                    icono: Icons.photo_camera_rounded,
                    activo: _panelAbierto && _panel == _PanelMapa.fotos,
                    onTap: () => _abrirPanel(_PanelMapa.fotos),
                  ),
                  const SizedBox(width: 6),
                  _ChipPanel(
                    etiqueta: 'Lugares',
                    cantidad: _lugaresEncontrados.length,
                    icono: Icons.travel_explore_rounded,
                    activo: _panelAbierto && _panel == _PanelMapa.lugares,
                    onTap: () => _abrirPanel(_PanelMapa.lugares),
                  ),
                  const Spacer(),
                  if (_locationMessage != null)
                    Flexible(
                      child: Text(
                        _locationMessage!,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: VeridiaColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _panelAbierto = !_panelAbierto),
                    tooltip: _panelAbierto ? 'Contraer' : 'Desplegar',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    icon: AnimatedRotation(
                      turns: _panelAbierto ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: VeridiaColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_panelAbierto
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: switch (_panel) {
                          _PanelMapa.zonas => _listaZonas(zonas),
                          _PanelMapa.fotos => _listaFotos(
                            _avistamientosPorZona(),
                          ),
                          _PanelMapa.lugares => _listaLugares(),
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaZonas(List<BirdZone> zonas) {
    if (zonas.isEmpty) {
      return const _PanelVacio(mensaje: 'No hay zonas para esta búsqueda.');
    }

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: zonas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final zone = zonas[index];
          final km = _distanciaKm(zone.latitude, zone.longitude);
          final fotos = _fotosPorZonaId[zone.id]?.length ?? 0;

          return GestureDetector(
            onTap: () => _focusZone(zone),
            child: Container(
              width: 142,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: VeridiaColors.background,
                borderRadius: BorderRadius.circular(VeridiaRadii.md),
                border: Border.all(color: zone.color.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: zone.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          zone.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    zone.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: VeridiaColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        size: 10,
                        color: VeridiaColors.secondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$fotos',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: VeridiaColors.secondary,
                        ),
                      ),
                      if (km != null) ...[
                        const Spacer(),
                        Text(
                          _etiquetaDistancia(km),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7FB2FF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Fotos agrupadas por zona: una columna por zona con sus miniaturas.
  Widget _listaFotos(Map<String, List<Observation>> grupos) {
    if (grupos.isEmpty) {
      return _PanelVacio(
        mensaje: _sightings.isEmpty
            ? 'Todavía nadie ha registrado fotos en el mapa.'
            : 'Ninguna foto coincide con esta búsqueda.',
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: grupos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entrada = grupos.entries.elementAt(index);
          return _GrupoZonaFotos(
            zona: entrada.key,
            avistamientos: entrada.value,
            onSeleccionar: (avistamiento) {
              _mapController.move(
                LatLng(avistamiento.latitude!, avistamiento.longitude!),
                15.0,
              );
              _showSightingSheet(avistamiento);
            },
          );
        },
      ),
    );
  }

  /// Lugares reales encontrados por nombre, con las fotos que ya se tomaron
  /// cerca de cada uno (aunque el lugar no tenga zona dibujada en el mapa).
  Widget _listaLugares() {
    if (_buscandoLugar) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_errorLugar != null) {
      return _PanelVacio(mensaje: _errorLugar!);
    }

    if (_lugaresEncontrados.isEmpty) {
      return const _PanelVacio(
        mensaje:
            'Escribe un lugar (p. ej. "Laguna de la Herrera") y pulsa la '
            'lupa o Enter para buscarlo en todo el mapa, esté o no marcado '
            'aquí.',
      );
    }

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _lugaresEncontrados.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final lugar = _lugaresEncontrados[index];
          final fotosCerca = _avistamientosCercaDe(
            lugar.latitude,
            lugar.longitude,
          ).length;
          final elegido = _lugarSeleccionado?.nombre == lugar.nombre;

          return GestureDetector(
            onTap: () => _seleccionarLugar(lugar),
            child: Container(
              width: 190,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: VeridiaColors.background,
                borderRadius: BorderRadius.circular(VeridiaRadii.md),
                border: Border.all(
                  color: elegido
                      ? const Color(0xFFE85D4E)
                      : VeridiaColors.outlineVariant,
                  width: elegido ? 1.4 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 13,
                        color: Color(0xFFE85D4E),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          lugar.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        lugar.categoria,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: VeridiaColors.onSurfaceVariant,
                        ),
                      ),
                      if (fotosCerca > 0) ...[
                        const Spacer(),
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 10,
                          color: VeridiaColors.secondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$fotosCerca',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: VeridiaColors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pin del lugar buscado, distinto en color e icono a las zonas curadas
  /// (círculo verde) y a las fotos (icono marrón de cámara), para que sea
  /// obvio que es un resultado de búsqueda y no un punto de siempre.
  List<Marker> _buildLugarMarker() {
    final lugar = _lugarSeleccionado;
    if (lugar == null) return [];
    return [
      Marker(
        point: LatLng(lugar.latitude, lugar.longitude),
        width: 46,
        height: 46,
        child: GestureDetector(
          onTap: () => _showLugarSheet(lugar),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE85D4E),
              shape: BoxShape.circle,
              border: Border.all(color: VeridiaColors.onSurface, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.place_rounded,
              color: VeridiaColors.onSurface,
              size: 24,
            ),
          ),
        ),
      ),
    ];
  }

  /// Ficha del lugar buscado: nombre completo y las fotos que ya se
  /// registraron cerca, aunque el lugar no tenga zona dibujada en el mapa.
  void _showLugarSheet(LugarEncontrado lugar) {
    final fotosCerca = _avistamientosCercaDe(lugar.latitude, lugar.longitude);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE85D4E),
                  child: Icon(
                    Icons.place_rounded,
                    color: VeridiaColors.onSurface,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lugar.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              fotosCerca.isEmpty
                  ? 'Nadie ha registrado fotos cerca de aquí todavía.'
                  : '${fotosCerca.length} ${fotosCerca.length == 1 ? 'foto registrada' : 'fotos registradas'} a menos de 2 km.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: VeridiaColors.secondary,
              ),
            ),
            if (fotosCerca.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fotosCerca.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final avistamiento = fotosCerca[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showSightingSheet(avistamiento);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 74,
                          height: 74,
                          child: avistamiento.hasPhoto
                              ? Image.network(
                                  avistamiento.imagePath!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 160,
                                  errorBuilder: (_, _, _) =>
                                      const VeridiaFotoVacia(tamanoIcono: 16),
                                )
                              : const VeridiaFotoVacia(tamanoIcono: 16),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Marker> _buildUserMarker() {
    final user = _userLocation;
    if (user == null) return [];
    return [
      Marker(
        point: user,
        width: 90,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                shape: BoxShape.circle,
                border: Border.all(color: VeridiaColors.onSurface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: VeridiaColors.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Tú',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Marker> _buildSightingMarkers() {
    if (!_showSightings) return [];
    return _filteredSightings.map((sighting) {
      return Marker(
        point: LatLng(sighting.latitude!, sighting.longitude!),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showSightingSheet(sighting),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFB45309),
              shape: BoxShape.circle,
              border: Border.all(color: VeridiaColors.onSurface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt,
              color: VeridiaColors.onSurface,
              size: 18,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildMarkers() {
    return _filteredZones.map((zone) {
      return Marker(
        point: LatLng(zone.latitude, zone.longitude),
        width: 120,
        height: 66,
        child: GestureDetector(
          onTap: () => _showZoneSheet(zone),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: zone.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: VeridiaColors.onSurface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  color: VeridiaColors.onSurface,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                constraints: const BoxConstraints(maxWidth: 110),
                decoration: BoxDecoration(
                  color: VeridiaColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  zone.name,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final speciesList = getAvailableSpecies(_birdZones);

    if (_isLoadingZones) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mapa de especies - Cundinamarca'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Sin flecha de retroceso: el mapa es una sección de la barra
        // inferior, no una pantalla apilada de la que haya que "salir".
        automaticallyImplyLeading: false,
        title: const Text(
          'Mapa De Especies - Cundinamarca',
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
      ),
      // El mapa ocupa TODA la pantalla y los controles flotan encima. Antes
      // el buscador y las fichas vivían en una franja fija arriba y, en un
      // celular, al mapa le quedaban apenas unos centímetros.
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 12.0,
                onTap: (_, _) => _cerrarPanel(),
              ),
              children: [
                TileLayer(
                  urlTemplate: VeridiaMapa.urlTeselas,
                  // Exigido por la política de uso de OpenStreetMap: sin un
                  // User-Agent que identifique la app, el servidor de teselas
                  // puede bloquear las peticiones.
                  userAgentPackageName: 'com.example.veridia_app',
                  tileBuilder: VeridiaMapa.teselaTenida,
                  maxZoom: 19,
                ),
                PolygonLayer(polygons: _buildPolygons()),
                MarkerLayer(markers: _buildMarkers()),
                MarkerLayer(markers: _buildSightingMarkers()),
                MarkerLayer(markers: _buildLugarMarker()),
                MarkerLayer(markers: _buildUserMarker()),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _buscadorFlotante(speciesList),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _controlesMapa(),
                const SizedBox(height: 8),
                _atribucion(),
                const SizedBox(height: 6),
                _panelInferior(),
              ],
            ),
          ),
        ],
      ),
      // Registrar especies es tarea del explorador: el administrador modera
      // y asigna desafíos, así que el botón solo le estorbaría.
      // Sin floatingActionButton del Scaffold: el botón de registrar vive en
      // la fila de controles para que no se monte encima del panel cuando
      // este se despliega.
      bottomNavigationBar: VeridiaBottomNav(
        currentIndex: 2,
        onTap: (i) => VeridiaNav.ir(context, VeridiaSeccion.values[i], 2),
      ),
    );
  }
}

/// Grupo de las fotos que caen lejos de cualquier zona registrada.
const _sinZona = 'Fuera de zonas registradas';

/// Las dos vistas del panel inferior del mapa.
enum _PanelMapa { zonas, fotos, lugares }

/// Chip de filtro por especie, flotando sobre el mapa.
class _ChipEspecie extends StatelessWidget {
  const _ChipEspecie({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(VeridiaRadii.pill),
      color: activo
          ? VeridiaColors.primaryContainer
          : VeridiaColors.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: activo
                  ? VeridiaColors.onPrimaryContainer
                  : VeridiaColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular de los controles del mapa. Todos miden lo mismo: la única
/// diferencia entre ellos es si están "activos" (verde) o no.
class _BotonMapa extends StatelessWidget {
  const _BotonMapa({
    required this.icono,
    required this.tooltip,
    required this.onTap,
    this.activo = false,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final fondo = activo
        ? VeridiaColors.secondaryContainer
        : VeridiaColors.surfaceContainer;
    final tinte = activo
        ? VeridiaColors.onSecondaryContainer
        : VeridiaColors.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        color: fondo,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icono, size: 20, color: tinte),
          ),
        ),
      ),
    );
  }
}

/// Mensaje corto cuando una pestaña del panel no tiene nada que mostrar.
class _PanelVacio extends StatelessWidget {
  const _PanelVacio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: Center(
        child: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: VeridiaColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Pestaña del panel inferior con su contador.
class _ChipPanel extends StatelessWidget {
  const _ChipPanel({
    required this.etiqueta,
    required this.cantidad,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final int cantidad;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activo ? VeridiaColors.secondary : VeridiaColors.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VeridiaRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: activo ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(VeridiaRadii.pill),
          border: Border.all(
            color: color.withValues(alpha: activo ? 0.6 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              '$etiqueta ($cantidad)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Columna con el nombre de una zona y las miniaturas de lo fotografiado ahí.
class _GrupoZonaFotos extends StatelessWidget {
  const _GrupoZonaFotos({
    required this.zona,
    required this.avistamientos,
    required this.onSeleccionar,
  });

  final String zona;
  final List<Observation> avistamientos;
  final ValueChanged<Observation> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    // Se muestran hasta 6: el panel es una vista rápida, el detalle completo
    // está en la ficha de cada zona.
    final visibles = avistamientos.take(6).toList();

    return Container(
      width: 186,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VeridiaColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VeridiaColors.secondary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 12,
                color: VeridiaColors.secondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  zona,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${avistamientos.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VeridiaColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final avistamiento = visibles[i];
                return GestureDetector(
                  onTap: () => onSeleccionar(avistamiento),
                  child: SizedBox(
                    width: 54,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 40,
                            width: 54,
                            child: avistamiento.hasPhoto
                                ? Image.network(
                                    avistamiento.imagePath!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    errorBuilder: (_, _, _) =>
                                        const VeridiaFotoVacia(tamanoIcono: 16),
                                  )
                                : const VeridiaFotoVacia(tamanoIcono: 16),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          avistamiento.commonName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
