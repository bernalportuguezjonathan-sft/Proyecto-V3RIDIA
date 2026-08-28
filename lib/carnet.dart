import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/logro.dart';
import 'models/observation.dart';
import 'models/recompensa.dart';
import 'models/user.dart';
import 'services/economia.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_m.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_r.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/mascota_vista.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarFoto();
  }

  /// Lee la foto de perfil del mismo caché que usa ProfileScreen, para que el
  /// carnet no muestre un avatar distinto del que la persona ya se puso.
  Future<void> _cargarFoto() async {
    final uid = UserRepository.instance.currentUser.value?.userId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final codificada = prefs.getString('profile_image_$uid');
      if (codificada == null || !mounted) return;
      setState(() => _foto = base64Decode(codificada));
    } catch (e) {
      debugPrint('Carnet: no se pudo leer la foto de perfil: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carnet de explorador')),
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
                      _Carnet(perfil: perfil, fotos: fotos, foto: _foto),
                      const SizedBox(height: 16),
                      Text(
                        'Captura la pantalla para compartir tu carnet. Todo lo '
                        'que aparece aquí lo ganaste registrando especies '
                        'reales de Cundinamarca.',
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
    final stats = EstadisticasExplorador.de(
      veridiumsGanados: perfil.tokensTotales,
      fotos: fotos,
      desafios: desafios,
    );
    final logros = logrosConseguidos(stats);

    final acento = marco?.color ?? VeridiaColors.primary;

    return VeridiaCard(
      glow: true,
      borderColor: acento.withValues(alpha: 0.55),
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
              _Retrato(foto: foto, photoURL: perfil.photoURL, marco: marco),
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
                    MascotaVista(
                      mascota: mascota,
                      equipado: mascotas.equipados(perfil),
                      tamano: 64,
                    ),
                    const SizedBox(height: 4),
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
          Row(
            children: [
              Expanded(
                child: _Cifra(
                  valor: '${stats.especiesDistintas}',
                  etiqueta: 'especies',
                ),
              ),
              Expanded(
                child: _Cifra(valor: '${fotos.length}', etiqueta: 'registros'),
              ),
              Expanded(
                child: _Cifra(valor: '$desafios', etiqueta: 'desafíos'),
              ),
              Expanded(
                child: _Cifra(
                  valor: '${perfil.tokensTotales}',
                  etiqueta: 'ganados',
                ),
              ),
            ],
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
        color: VeridiaColors.surfaceContainerLow,
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
  const _Cifra({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontFamily: VeridiaFonts.headline,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: VeridiaColors.onSurface,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(
            fontFamily: VeridiaFonts.body,
            fontSize: 10,
            color: VeridiaColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
