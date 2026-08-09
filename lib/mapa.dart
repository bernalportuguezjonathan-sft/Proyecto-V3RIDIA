import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'login.dart';
import 'home.dart';
import 'identify_species.dart';
import 'historial.dart';
import 'perfil.dart';
import 'detallemapa.dart';
import 'models/bird_zone.dart';
import 'models/observation.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';

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
  StreamSubscription<List<Observation>>? _sightingsSub;
  bool _showSightings = true;

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
      });
    }, onError: (_) {});
  }

  /// Pide permiso de ubicación y guarda la posición del usuario para poder
  /// ordenar las zonas por cercanía.
  Future<void> _locateUser({bool moveCamera = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _locationMessage = 'Activa el GPS para ver zonas cercanas');
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
    return _distance.as(LengthUnit.Kilometer, user, LatLng(lat, lng))
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
      _isLoadingZones = false;
    });

    if (zones.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(LatLng(zones.first.latitude, zones.first.longitude), 13.0);
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
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
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
                          color: Colors.grey.shade600,
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
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            const SizedBox(height: 8),
            Text(
              'Avistado por: ${sighting.userDisplayName ?? 'Explorador'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${sighting.dateTime.day}/${sighting.dateTime.month}/${sighting.dateTime.year}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await UserRepository.instance.signOut();
              if (!mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredZones = filterBirdZones(
        _birdZones,
        query: _searchController.text,
        selectedSpecies: _selectedSpecies,
      );
    });
  }

  void _resetView() {
    setState(() {
      _searchController.clear();
      _selectedSpecies = null;
      _filteredZones = _birdZones;
    });
    final center = _birdZones.isNotEmpty
        ? LatLng(_birdZones.first.latitude, _birdZones.first.longitude)
        : _defaultCenter;
    _mapController.move(center, 12.0);
  }

  void _focusZone(BirdZone zone) {
    _mapController.move(LatLng(zone.latitude, zone.longitude), 13.0);
    _showZoneSheet(zone);
  }

  void _showZoneSheet(BirdZone zone) {
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
                    child: const Icon(Icons.nature, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zone.location,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                zone.description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Text(
                'Especies destacadas',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MapDetailScreen(zone: zone)),
                    );
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Ver misión y especies'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5631),
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
                border: Border.all(color: Colors.white, width: 3),
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
                color: Colors.white,
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
    return _sightings.map((sighting) {
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
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
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
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                constraints: const BoxConstraints(maxWidth: 110),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                  ],
                ),
                child: Text(
                  zone.name,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
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
        backgroundColor: const Color(0xFFF5F9F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E5631),
          title: const Text('Mapa de especies - Cundinamarca'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mapa De Especies - Cundinamarca',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explora zonas de avistamiento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5631),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recoge fotos de especies en la región y completa tus misiones.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Buscar zonas o especies',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1E5631)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: speciesList.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = _selectedSpecies == null || _selectedSpecies!.isEmpty;
                        return ChoiceChip(
                          label: const Text('Todas'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1E5631).withValues(alpha: 0.15),
                          onSelected: (_) {
                            setState(() {
                              _selectedSpecies = null;
                            });
                            _applyFilters();
                          },
                        );
                      }
                      final species = speciesList[index - 1];
                      final isSelected = _selectedSpecies == species;
                      return ChoiceChip(
                        label: Text(species),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1E5631).withValues(alpha: 0.15),
                        onSelected: (_) {
                          setState(() {
                            _selectedSpecies = isSelected ? null : species;
                          });
                          _applyFilters();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.example.veridia_app',
                    ),
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.veridia_app',
                      tileBuilder: (context, tileWidget, tile) {
                        return Opacity(opacity: 0.65, child: tileWidget);
                      },
                    ),
                    PolygonLayer(polygons: _buildPolygons()),
                    MarkerLayer(markers: _buildMarkers()),
                    MarkerLayer(markers: _buildSightingMarkers()),
                    MarkerLayer(markers: _buildUserMarker()),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mapa híbrido de la Sabana de Bogotá',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _filteredZones.isEmpty
                              ? 'Sin zonas visibles'
                              : '${_filteredZones.length} zonas activas',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Humedales, lagunas y parques urbanos',
                          style: TextStyle(fontSize: 10, color: Color(0xFF1E5631), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'reset-map',
                        backgroundColor: Colors.white,
                        onPressed: _resetView,
                        child: const Icon(Icons.refresh, color: Color(0xFF1E5631)),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'center-map',
                        backgroundColor: const Color(0xFF1E5631),
                        tooltip: 'Ir a mi ubicación',
                        onPressed: () {
                          final user = _userLocation;
                          if (user != null) {
                            _mapController.move(user, 14.0);
                          } else {
                            _locateUser(moveCamera: true);
                          }
                        },
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'toggle-sightings',
                        backgroundColor: _showSightings
                            ? const Color(0xFFB45309)
                            : Colors.white,
                        onPressed: () =>
                            setState(() => _showSightings = !_showSightings),
                        child: Icon(
                          Icons.camera_alt,
                          color: _showSightings
                              ? Colors.white
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _userLocation != null
                                  ? 'Zonas más cercanas a ti'
                                  : 'Zonas destacadas',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_locationMessage != null)
                              Flexible(
                                child: Text(
                                  _locationMessage!,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_zonasOrdenadas.isEmpty)
                          const Text('No hay zonas para esta búsqueda.')
                        else
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _zonasOrdenadas.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final zone = _zonasOrdenadas[index];
                                final km = _distanciaKm(
                                  zone.latitude,
                                  zone.longitude,
                                );
                                return GestureDetector(
                                  onTap: () => _focusZone(zone),
                                  child: Container(
                                    width: 150,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7FBF7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: zone.color.withValues(alpha: 0.25)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: zone.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                zone.name,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          zone.location,
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (km != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.near_me,
                                                size: 11,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'a ${_etiquetaDistancia(km)}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1D4ED8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E5631),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Cámara'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const IdentifySpeciesScreen()),
              );
              break;
            case 2:
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              break;
          }
        },
      ),
    );
  }
}
