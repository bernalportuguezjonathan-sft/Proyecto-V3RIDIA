import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'models/logro.dart';
import 'models/observation.dart';
import 'models/recompensa.dart';
import 'models/user.dart';
import 'services/economia.dart';
import 'services/marca_logros.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_m.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_r.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/foto_perfil.dart';
import 'widgets/mascota_vitrina.dart';
import 'widgets/logros_vista.dart';
import 'widgets/veridia_logo.dart';
import 'widgets/veridia_ui.dart';

/// Carnet de explorador: todo lo que alguien ha construido en Veridia, en una
/// sola tarjeta.
///
/// Es la respuesta a "¿para qué sirve todo esto?". El marco, el título, las
/// insignias y la mascota estaban repartidos por cuatro pantallas y no se
/// veían nunca juntos; aquí forman una sola cosa que se puede capturar y
/// mostrar. Un cosmético que nadie más ve no es estatus — el carnet es lo que
/// convierte la colección en algo enseñable.
///
/// No inventa ningún dato: todo sale del perfil, de los canjes, del inventario
/// y de los avistamientos que ya existen.
class CarnetScreen extends StatefulWidget {
  const CarnetScreen({super.key});

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen> {
  Uint8List? _foto;
  bool _compartiendo = false;

  /// Marca en el árbol la parte que se convierte en imagen al compartir: solo
  /// la tarjeta, sin el fondo de la pantalla ni el texto de abajo.
  final GlobalKey _claveCarnet = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cargarFoto();
    // El carnet tambien pinta logros: sin esto saldria con los conteos vivos
    // hasta que otra pantalla cargara las marcas.
    MarcaLogros.instance.cargar();
  }

  /// Lee la foto de perfil del mismo caché que usa ProfileScreen, para que el
  /// carnet no muestre un avatar distinto del que la persona ya se puso.
  ///
  /// Toda la lógica de DÓNDE puede estar esa foto vive en [FotoPerfil], que
  /// mira las tres fuentes posibles. Aquí solo se piden los bytes.
  Future<void> _cargarFoto() async {
    final bytes = await FotoPerfil.bytesGuardados();
    if (bytes == null || !mounted) return;
    setState(() => _foto = bytes);
  }

  /// Convierte el carnet en un PNG y abre el menú de compartir del sistema.
  ///
  /// La captura la hace Flutter solo: [RepaintBoundary] ya guarda esa parte
  /// del árbol en su propia capa, así que pedirle una imagen no necesita
  /// ningún paquete. `pixelRatio: 3` la saca a triple resolución para que no
  /// se vea pixelada al abrirla en un chat.
  Future<void> _compartir() async {
    if (_compartiendo) return;
    setState(() => _compartiendo = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final limite =
          _claveCarnet.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (limite == null) throw StateError('El carnet aún no está dibujado.');

      final imagen = await limite.toImage(pixelRatio: 3);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      if (datos == null) throw StateError('No se pudo generar la imagen.');

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              datos.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'carnet-veridia.png',
            ),
          ],
          text: 'Mi carnet de explorador de Veridia.',
          subject: 'Carnet de explorador · Veridia',
        ),
      );
    } catch (e) {
      debugPrint('No se pudo compartir el carnet: $e');
      if (mounted) {
        messenger.showSnackBar(
          veridiaSnackBarError('No se pudo compartir el carnet.'),
        );
      }
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet de explorador'),
        actions: [
          VeridiaAppBarAction(
            icon: Icons.ios_share_rounded,
            tooltip: 'Compartir mi carnet',
            onPressed: _compartiendo ? () {} : _compartir,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, perfil, _) {
              if (perfil == null) return const Center(child: VeridiaLoader());
              return StreamBuilder<List<Observation>>(
                stream: ObservationRepository.instance.streamForUser(
                  perfil.userId,
                ),
                builder: (context, snapshot) {
                  final fotos = snapshot.data ?? const <Observation>[];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      RepaintBoundary(
                        key: _claveCarnet,
                        child: _Carnet(
                          perfil: perfil,
                          fotos: fotos,
                          foto: _foto,
                        ),
                      ),
                      const SizedBox(height: 18),
                      VeridiaBotonTactil(
                        radius: VeridiaRadii.pill,
                        child: FilledButton.icon(
                          onPressed: _compartiendo ? null : _compartir,
                          icon: _compartiendo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: VeridiaColors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.ios_share_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Compartir mi carnet'),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Todo lo que aparece aquí lo ganaste registrando '
                        'especies reales de Cundinamarca.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Atajo para abrir el carnet desde cualquier pantalla.
Future<void> abrirCarnet(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CarnetScreen()),
  );
}

// ---------------------------------------------------------------------------

/// Fondo del carnet: casi negro, NO el verde de las demás tarjetas.
///
/// El carnet es lo único de la app pensado para salir de la app: se captura y
/// se comparte por fuera. Por eso no debe leerse como una tarjeta más del
/// montón. Sobre este casi negro, el dorado del nivel, el retrato y los
/// sprites de la mascota recuperan todo el contraste que verde sobre verde se
/// comía, y la captura funciona igual pegada en un chat claro o en uno oscuro.
const _fondoCarnet = Color(0xFF03110C);

/// Hueco donde se apoyan las cuatro cifras. Aún más oscuro que el carnet, para
/// que los números queden dentro de algo excavado y no flotando en el negro.
const _huecoCarnet = Color(0xFF010A07);

class _Carnet extends StatelessWidget {
  const _Carnet({required this.perfil, required this.fotos, this.foto});

  final UserProfile perfil;
  final List<Observation> fotos;
  final Uint8List? foto;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final recompensas = RewardRepository.instance;
    final mascotas = MascotaRepository.instance;

    final marco = recompensas.marcoActivo();
    final titulo = recompensas.tituloActivo();
    final insignias = recompensas
        .desbloqueadas()
        .where((r) => r.tipo == TipoRecompensa.insignia)
        .toList();

    final mascota = mascotas.mascotaActiva(perfil);
    final nivel = nivelDesde(perfil.tokensTotales);

    final desafios = ChallengeRepository.instance.completadosPorMi(
      perfil.userId,
    );
    // Un solo sitio cuenta especies, registros y desafíos: si el carnet y el
    // perfil discreparan, el que se ve peor parece roto.
    final stats = MarcaLogros.instance.aplicar(
      EstadisticasExplorador.de(
        veridiumsGanados: perfil.tokensTotales,
        fotos: fotos,
        desafios: desafios,
      ),
    );
    final logros = logrosConseguidos(stats);

    final acento = marco?.color ?? VeridiaColors.primary;

    return VeridiaCard(
      glow: true,
      color: _fondoCarnet,
      borderColor: acento.withValues(alpha: 0.55),
      radius: VeridiaRadii.xl,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VeridiaLogo(size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'EXPLORADOR ACREDITADO',
                  style: TextStyle(
                    fontFamily: VeridiaFonts.body,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: VeridiaColors.onSurfaceVariant,
                  ),
                ),
              ),
              VeridiaTag(
                label: 'Nivel $nivel',
                icon: Icons.military_tech_rounded,
                color: VeridiaColors.veridium,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Retrato(
                foto: foto,
                // La URL pasa por [FotoPerfil] y no directo desde el perfil:
                // así el carnet también alcanza el avatar de Google, que solo
                // existe en FirebaseAuth y era el caso que fallaba.
                photoURL: FotoPerfil.urlDeRespaldo(perfil.photoURL),
                marco: marco,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil.displayName,
                      style: texto.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (titulo != null) ...[
                      const SizedBox(height: 6),
                      VeridiaTag(
                        label: titulo,
                        icon: Icons.workspace_premium_rounded,
                        color: VeridiaColors.veridium,
                        dense: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Miembro desde ${formatoFecha(perfil.createdDate)}',
                      style: texto.bodySmall,
                    ),
                  ],
                ),
              ),
              if (mascota != null)
                Column(
                  children: [
                    // Enmarcada en su habitat: en el carnet la mascota es una
                    // credencial mas -como el nivel o las insignias- y suelta
                    // sobre el negro se leia como un sticker pegado encima.
                    MascotaVitrina(
                      mascota: mascota,
                      equipado: mascotas.equipados(perfil),
                      tamano: 64,
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 68,
                      child: Text(
                        mascota.nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: texto.bodySmall?.copyWith(
                          fontSize: 10,
                          color: mascota.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Las cuatro cifras, hundidas en su propio panel: es lo primero que
          // mira quien recibe la captura, y suelto sobre el fondo se leía como
          // texto cualquiera en vez de como el marcador del carnet.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              gradient: veridiaCaraClay(_huecoCarnet),
              borderRadius: BorderRadius.circular(VeridiaRadii.md),
              border: Border.all(
                color: VeridiaColors.veridium.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Cifra(
                    valor: '${stats.especiesDistintas}',
                    etiqueta: 'especies',
                  ),
                ),
                Expanded(
                  child: _Cifra(
                    valor: '${fotos.length}',
                    etiqueta: 'registros',
                  ),
                ),
                Expanded(
                  child: _Cifra(valor: '$desafios', etiqueta: 'desafíos'),
                ),
                Expanded(
                  child: _Cifra(
                    valor: '${perfil.tokensTotales}',
                    etiqueta: 'ganados',
                    acento: VeridiaColors.veridium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VeridiaProgressBar(
            value: progresoHaciaSiguienteNivel(perfil.tokensTotales),
            color: acento,
          ),
          const SizedBox(height: 6),
          Text(
            umbralSiguienteNivel(perfil.tokensTotales) == null
                ? 'Nivel máximo alcanzado'
                : 'Nivel ${nivel + 1} a los '
                      '${umbralSiguienteNivel(perfil.tokensTotales)} Veridiums '
                      'ganados',
            style: texto.bodySmall,
          ),
          if (logros.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: VeridiaColors.outlineVariant, height: 1),
            const SizedBox(height: 12),
            Text(
              'ACREDITACIONES',
              style: TextStyle(
                fontFamily: VeridiaFonts.body,
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: VeridiaColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: logros
                  .map((logro) => LogroInsignia(logro: logro))
                  .toList(),
            ),
          ],
          if (insignias.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insignias
                  .map(
                    (insignia) => VeridiaTag(
                      label: '${insignia.valor ?? ''} ${insignia.nombre}'
                          .trim(),
                      color: insignia.color,
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Foto de perfil con el marco canjeado alrededor.
class _Retrato extends StatelessWidget {
  const _Retrato({required this.foto, required this.photoURL, this.marco});

  final Uint8List? foto;
  final String? photoURL;
  final Recompensa? marco;

  @override
  Widget build(BuildContext context) {
    final color = marco?.color ?? VeridiaColors.outlineVariant;
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        // Hueco, no `surfaceContainerLow`: sobre el casi negro del carnet ese
        // verde dibujaba un círculo claro alrededor del retrato.
        color: _huecoCarnet,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: marco == null ? 1.5 : 3),
        boxShadow: marco == null
            ? null
            : [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14)],
      ),
      child: ClipOval(child: _imagen()),
    );
  }

  Widget _imagen() {
    if (foto != null) return Image.memory(foto!, fit: BoxFit.cover);
    if (photoURL != null && photoURL!.isNotEmpty) {
      return Image.network(
        photoURL!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _SinRetrato(),
      );
    }
    return const _SinRetrato();
  }
}

class _SinRetrato extends StatelessWidget {
  const _SinRetrato();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.person, size: 34, color: VeridiaColors.primary),
  );
}

/// Una cifra del carnet: número grande, etiqueta pequeña.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    this.acento = VeridiaColors.onSurface,
  });

  final String valor;
  final String etiqueta;

  /// Los Veridiums ganados van en dorado: es la cifra que resume todo lo
  /// demás, y en el mismo blanco que las otras tres no se distinguía.
  final Color acento;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: VeridiaFonts.headline,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: acento,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: VeridiaFonts.body,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: VeridiaColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
