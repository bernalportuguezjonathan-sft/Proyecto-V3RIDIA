import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'desafios.dart';
import 'historial.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'models/observation.dart';
import 'models/user.dart';
import 'navegacion.dart';
import 'recompensas.dart';
import 'refugio.dart';
import 'services/economia.dart';
import 'services/repositorio_m.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/mascota_vista.dart';
import 'widgets/veridia_logo.dart';
import 'widgets/veridia_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _buscarController = TextEditingController();

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  void _buscar(String query) {
    final texto = query.trim();
    if (texto.isEmpty) return;
    VeridiaNav.abrir(context, MapScreen(initialQuery: texto));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        centerTitle: false,
        title: Row(
          children: [
            const VeridiaSymbol(size: 32, glow: false),
            const SizedBox(width: 10),
            Text('Veridia', style: text.titleLarge),
          ],
        ),
        actions: [
          ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, perfil, _) => VeridiaTokenBadge(
              tokens: perfil?.tokens ?? 0,
              onTap: () => abrirRecompensas(context),
            ),
          ),
          const SizedBox(width: 10),
          VeridiaAppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar sesión',
            onPressed: () => VeridiaNav.cerrarSesion(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ValueListenableBuilder<UserProfile?>(
                valueListenable: UserRepository.instance.currentUser,
                builder: (context, perfil, _) {
                  final nombre = perfil == null
                      ? 'Explorador'
                      : (perfil.displayName.isNotEmpty
                            ? perfil.displayName
                            : perfil.email.split('@').first);
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, $nombre', style: text.headlineSmall),
                            const SizedBox(height: 4),
                            Text(
                              '¿Qué especie vas a descubrir hoy?',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _MascotaSaludo(perfil: perfil),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _buscarController,
                textInputAction: TextInputAction.search,
                onSubmitted: _buscar,
                style: text.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Buscar especies, rutas, lugares...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    tooltip: 'Buscar en el mapa',
                    onPressed: () => _buscar(_buscarController.text),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const VeridiaSectionTitle(
                title: 'Accesos rápidos',
                subtitle: 'Lo esencial para tu expedición',
              ),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  _AccesoRapido(
                    icon: Icons.camera_alt_rounded,
                    titulo: 'Cámara IA',
                    descripcion: 'Identifica especies',
                    destacado: true,
                    onTap: () => VeridiaNav.abrir(
                      context,
                      const IdentifySpeciesScreen(),
                    ),
                  ),
                  _AccesoRapido(
                    icon: Icons.pets_rounded,
                    titulo: 'El Refugio',
                    descripcion: 'Tu mascota y su mejora',
                    destacado: true,
                    onTap: () => abrirRefugio(context),
                  ),
                  _AccesoRapido(
                    icon: Icons.map_rounded,
                    titulo: 'Mapa',
                    descripcion: 'Explora la zona',
                    onTap: () => VeridiaNav.abrir(context, const MapScreen()),
                  ),
                  _AccesoRapido(
                    icon: Icons.menu_book_rounded,
                    titulo: 'Diario',
                    descripcion: 'Tus avistamientos',
                    onTap: () =>
                        VeridiaNav.abrir(context, const HistoryScreen()),
                  ),
                  _AccesoRapido(
                    icon: Icons.emoji_events_rounded,
                    titulo: 'Desafíos',
                    descripcion: 'Gana Veridiums',
                    onTap: () =>
                        VeridiaNav.abrir(context, const ChallengesScreen()),
                  ),
                  _AccesoRapido(
                    icon: Icons.card_giftcard_rounded,
                    titulo: 'Recompensas',
                    descripcion: 'Canjea tus Veridiums',
                    onTap: () => abrirRecompensas(context),
                  ),
                  _AccesoRapido(
                    icon: Icons.travel_explore_rounded,
                    titulo: 'Fotos por zona',
                    descripcion: 'Qué se ha visto cerca',
                    onTap: () => VeridiaNav.abrir(context, const MapScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              VeridiaSectionTitle(
                title: 'Últimas capturas',
                subtitle: 'Tus avistamientos más recientes',
                actionLabel: 'Ver todas',
                onAction: () =>
                    VeridiaNav.abrir(context, const HistoryScreen()),
              ),
              SizedBox(
                height: 172,
                child: uid == null
                    ? const _CapturasVacias()
                    : StreamBuilder<List<Observation>>(
                        stream: ObservationRepository.instance.streamForUser(
                          uid,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const VeridiaLoader();
                          }
                          final capturas = snapshot.data ?? const [];
                          if (capturas.isEmpty) return const _CapturasVacias();

                          final visibles = capturas.take(8).toList();
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: visibles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) =>
                                _TarjetaCaptura(observacion: visibles[i]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: VeridiaBottomNav(
        currentIndex: 0,
        onTap: (i) => VeridiaNav.ir(context, VeridiaSeccion.values[i], 0),
      ),
    );
  }
}

class _AccesoRapido extends StatelessWidget {
  const _AccesoRapido({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
    this.destacado = false,
  });

  final IconData icon;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = destacado ? VeridiaColors.secondary : VeridiaColors.primary;

    return VeridiaCard(
      onTap: onTap,
      glow: destacado,
      borderColor: destacado
          ? VeridiaColors.secondary.withValues(alpha: 0.45)
          : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(VeridiaRadii.md),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(
                descripcion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaCaptura extends StatelessWidget {
  const _TarjetaCaptura({required this.observacion});

  final Observation observacion;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SizedBox(
      width: 136,
      child: VeridiaCard(
        padding: EdgeInsets.zero,
        onTap: () => VeridiaNav.abrir(context, const HistoryScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(VeridiaRadii.lg),
              ),
              child: SizedBox(
                height: 96,
                width: double.infinity,
                child: observacion.hasPhoto
                    ? Image.network(
                        observacion.imagePath!,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        errorBuilder: (_, _, _) => const VeridiaFotoVacia(),
                      )
                    : const VeridiaFotoVacia(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    observacion.commonName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    observacion.scientificName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturasVacias extends StatelessWidget {
  const _CapturasVacias();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return VeridiaCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VeridiaColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(VeridiaRadii.md),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: VeridiaColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Aún no tienes capturas', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Usa la Cámara IA para registrar tu primera especie.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La mascota saludando desde la cabecera de Inicio, con su nivel.
///
/// Es la puerta más visible al Refugio: en Perfil quedaba a tres toques de
/// distancia y casi nadie la habría encontrado. Aquí es lo primero que se ve
/// al abrir la app, que es lo que hace que la mascota se sienta parte de
/// Veridia y no una pantalla escondida.
class _MascotaSaludo extends StatelessWidget {
  const _MascotaSaludo({required this.perfil});

  final UserProfile? perfil;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: MascotaRepository.instance.inventario,
      builder: (context, _, _) {
        final mascota = MascotaRepository.instance.mascotaActiva(perfil);
        if (mascota == null) return const SizedBox.shrink();

        return Semantics(
          button: true,
          label: 'Abrir el Refugio de ${mascota.nombre}',
          child: InkWell(
            onTap: () => abrirRefugio(context),
            borderRadius: BorderRadius.circular(VeridiaRadii.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MascotaVista(
                    mascota: mascota,
                    equipado: MascotaRepository.instance.equipados(perfil),
                    tamano: 52,
                  ),
                  const SizedBox(height: 4),
                  VeridiaTag(
                    label: 'Nv ${nivelDesde(perfil?.tokensTotales ?? 0)}',
                    color: VeridiaColors.veridium,
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
