import 'package:flutter/material.dart';
import 'login.dart';
import 'home.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'perfil.dart';
import 'models/observation.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';

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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await UserRepository.instance.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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

  void _showEditDialog(Observation captura) {
    final commonNameController = TextEditingController(
      text: captura.commonName,
    );
    final scientificNameController = TextEditingController(
      text: captura.scientificName,
    );
    final locationController = TextEditingController(text: captura.location);
    final notesController = TextEditingController(text: captura.notes);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar especie'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: commonNameController,
                  decoration: const InputDecoration(labelText: 'Nombre común'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                TextFormField(
                  controller: scientificNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre científico',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                await ObservationRepository.instance.updateObservation(
                  Observation(
                    id: captura.id,
                    commonName: commonNameController.text.trim(),
                    scientificName: scientificNameController.text.trim(),
                    location: locationController.text.trim(),
                    notes: notesController.text.trim(),
                    dateTime: captura.dateTime,
                    imagePath: captura.imagePath,
                    latitude: captura.latitude,
                    longitude: captura.longitude,
                    type: captura.type,
                    userId: captura.userId,
                    userDisplayName: captura.userDisplayName,
                  ),
                );
                navigator.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5631),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historial',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Almacenamientos'),
            Tab(text: 'Lugares'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F9F7)),
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
                    color: Color(0xFF1E5631),
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
                    borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
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
                    child: Text('Ninguna observación coincide con tu búsqueda.'),
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
                  Expanded(
                    child: _resumenCard('Observaciones', '$total'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _resumenCard('Especies distintas', '$especiesUnicas'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Insignias',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5631),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildLugaresTab() {
    final userId = UserRepository.instance.currentUser.value?.userId;
    if (userId == null) {
      return const Center(
        child: Text('Inicia sesión para ver tus lugares.'),
      );
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

  Widget _crearTarjetaCaptura(Observation captura) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade200,
                child: captura.hasPhoto
                    ? Image.network(
                        captura.imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 36,
                        ),
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                      )
                    : const Icon(Icons.image, color: Colors.grey, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    captura.commonName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    captura.scientificName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${captura.dateTime}',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    captura.location,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    captura.notes,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF1E5631)),
                  onPressed: () => _showEditDialog(captura),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(captura.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _crearInsignia(String titulo, IconData icon, bool desbloqueada) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8),
        ],
      ),
      child: Opacity(
        opacity: desbloqueada ? 1 : 0.35,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              desbloqueada ? icon : Icons.lock_outline,
              size: 32,
              color: const Color(0xFF1E5631),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1E5631),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
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
              MaterialPageRoute(
                builder: (context) => const IdentifySpeciesScreen(),
              ),
            );
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
            break;
          case 3:
            break; // Ya estamos en historial
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Cámara'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}
