import 'package:flutter/material.dart';

import 'carnet.dart';
import 'models/mascota.dart';
import 'models/user.dart';
import 'services/economia.dart';
import 'services/repositorio_m.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/mascota_vista.dart';
import 'widgets/pixel_sprite.dart';
import 'widgets/veridia_ui.dart';

/// El Refugio: donde vive la mascota del explorador.
///
/// Tres cosas en una pantalla, porque son la misma decisión: con quién sales
/// al campo, qué le pones, y cuánto te falta para la siguiente. Separarlas en
/// pantallas distintas obligaría a ir y volver para comparar mejoras.
class RefugioScreen extends StatelessWidget {
  const RefugioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('El Refugio'),
        actions: [
          VeridiaAppBarAction(
            icon: Icons.badge_outlined,
            tooltip: 'Mi carnet de explorador',
            onPressed: () => abrirCarnet(context),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, perfil, _) =>
                VeridiaTokenBadge(tokens: perfil?.tokens ?? 0),
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
              return ValueListenableBuilder<Set<String>>(
                valueListenable: MascotaRepository.instance.inventario,
                builder: (context, inventario, _) {
                  final repo = MascotaRepository.instance;
                  final activa = repo.mascotaActiva(perfil);
                  final equipados = repo.equipados(perfil);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      const _AvisoInventario(),
                      _Cabecera(
                        perfil: perfil,
                        mascota: activa,
                        equipados: equipados,
                      ),
                      const SizedBox(height: 24),
                      const VeridiaSectionTitle(
                        title: 'Compañeros',
                        subtitle:
                            'Solo uno sale contigo: elegir mascota es elegir '
                            'cómo explorar',
                      ),
                      ...catalogoMascotas.map(
                        (mascota) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TarjetaMascota(
                            mascota: mascota,
                            perfil: perfil,
                            activa: activa?.id == mascota.id,
                            equipados: equipados,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const VeridiaSectionTitle(
                        title: 'Accesorios',
                        subtitle:
                            'Puro adorno: no dan Veridiums, sirven en las '
                            'cinco mascotas y no se pierden nunca',
                      ),
                      ...RanuraAccesorio.values.map(
                        (ranura) => _BloqueRanura(
                          ranura: ranura,
                          perfil: perfil,
                          equipado: equipados[ranura],
                        ),
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

/// Atajo para abrir el Refugio desde cualquier pantalla.
Future<void> abrirRefugio(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RefugioScreen()),
  );
}

// ---------------------------------------------------------------------------

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.perfil,
    required this.mascota,
    required this.equipados,
  });

  final UserProfile? perfil;
  final Mascota? mascota;
  final Map<RanuraAccesorio, Accesorio> equipados;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = perfil?.tokensTotales ?? 0;
    final nivel = nivelDesde(total);
    final siguiente = umbralSiguienteNivel(total);

    return VeridiaCard(
      glow: true,
      child: Column(
        children: [
          Row(
            children: [
              if (mascota != null)
                MascotaAvatar(
                  mascota: mascota!,
                  equipado: equipados,
                  tamano: 96,
                )
              else
                const VeridiaLoader(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascota?.nombre ?? 'Sin compañero',
                      style: texto.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    if (mascota != null)
                      VeridiaTag(
                        label: mascota!.mejora,
                        icon: Icons.auto_awesome_rounded,
                        color: mascota!.color,
                        dense: true,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      mascota?.descripcionMejora ??
                          'Equipa una mascota para llevarte su mejora al campo.',
                      style: texto.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              VeridiaTag(
                label: 'Nivel $nivel',
                icon: Icons.military_tech_rounded,
                color: VeridiaColors.veridium,
                dense: true,
              ),
              const Spacer(),
              Text(
                siguiente == null
                    ? 'Nivel máximo'
                    : '$total / $siguiente Veridiums ganados',
                style: texto.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          VeridiaProgressBar(value: progresoHaciaSiguienteNivel(total)),
          const SizedBox(height: 8),
          Text(
            'El nivel sale de todo lo que has GANADO, no de tu saldo: gastar '
            'en el Refugio nunca te baja de nivel ni del ranking.',
            style: texto.bodySmall?.copyWith(
              color: VeridiaColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Fondo de las fichas del refugio: más OSCURO que el resto de la app.
///
/// El refugio es una vitrina, y lo que tiene que destacar son los sprites de
/// 16 bits y las etiquetas de color de cada mejora — no la tarjeta que los
/// contiene. El verde `surfaceContainer` es más CLARO que el fondo de la
/// pantalla, así que cada ficha competía en brillo con su propio contenido y
/// la rejilla entera se leía como un bloque verde uniforme. Sobre este casi
/// negro, cada mascota queda iluminada dentro de su nicho.
///
/// Los sprites no se tocan: siguen exactamente con su paleta original.
const _fondoFicha = Color(0xFF02150F);

/// Hueco dentro de una ficha (el desplegable "¿Por qué esa mejora?").
const _huecoFicha = Color(0xFF010A07);

class _TarjetaMascota extends StatelessWidget {
  const _TarjetaMascota({
    required this.mascota,
    required this.perfil,
    required this.activa,
    required this.equipados,
  });

  final Mascota mascota;
  final UserProfile? perfil;
  final bool activa;
  final Map<RanuraAccesorio, Accesorio> equipados;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final repo = MascotaRepository.instance;
    final tiene = repo.tieneMascota(mascota.id);
    final nivel = nivelDesde(perfil?.tokensTotales ?? 0);
    // Bloqueada por nivel: la tarjeta entera baja de intensidad. Un botón
    // gris dentro de una tarjeta normal se lee como un fallo de la app; la
    // tarjeta apagada se lee como "todavía no", que es lo que es.
    final bloqueada = !tiene && nivel < mascota.nivelRequerido;

    return Opacity(
      opacity: bloqueada ? 0.55 : 1,
      child: VeridiaCard(
        color: _fondoFicha,
        borderColor: activa ? mascota.color.withValues(alpha: 0.6) : null,
        glow: activa,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MascotaAvatar(
                  mascota: mascota,
                  equipado: activa ? equipados : const {},
                  tamano: 96,
                  animar: tiene,
                  apagada: !tiene,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mascota.nombre,
                              style: texto.titleSmall,
                            ),
                          ),
                          if (activa)
                            VeridiaTag(
                              label: 'En el mapa',
                              icon: Icons.check_rounded,
                              color: mascota.color,
                              dense: true,
                            ),
                        ],
                      ),
                      Text(
                        mascota.nombreCientifico,
                        style: texto.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: VeridiaColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          VeridiaTag(
                            label: mascota.mejora,
                            icon: Icons.auto_awesome_rounded,
                            color: mascota.color,
                            dense: true,
                          ),
                          // La rareza justifica el precio: dice de un vistazo
                          // por qué una cuesta 160 y otra viene gratis.
                          VeridiaTag(
                            label:
                                '${mascota.rareza.etiqueta} · x'
                                '${mascota.rareza.multiplicador}',
                            icon: Icons.workspace_premium_rounded,
                            color: _colorRareza(mascota.rareza),
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(mascota.descripcionMejora, style: texto.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DatoPlegable(dato: mascota.dato),
            const SizedBox(height: 12),
            _AccionArticulo(
              tiene: tiene,
              equipado: activa,
              costo: mascota.costo,
              nivelRequerido: mascota.nivelRequerido,
              nivelActual: nivel,
              saldo: perfil?.tokens ?? 0,
              etiquetaEquipar: 'Sacar al campo',
              etiquetaEquipado: 'Te acompaña',
              onComprar: () => repo.comprarMascota(mascota),
              onEquipar: () => repo.equiparMascota(mascota.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Una ranura con sus accesorios en una fila horizontal.
///
/// Antes era una lista vertical de once tarjetas grandes: el Refugio se
/// convertía en un scroll interminable en el que las mascotas —lo importante—
/// quedaban enterradas arriba. En fila se ven todos los de una ranura de un
/// vistazo y se comparan, que es como se elige un cosmético.
class _BloqueRanura extends StatelessWidget {
  const _BloqueRanura({
    required this.ranura,
    required this.perfil,
    required this.equipado,
  });

  final RanuraAccesorio ranura;
  final UserProfile? perfil;
  final Accesorio? equipado;

  @override
  Widget build(BuildContext context) {
    final accesorios = accesoriosDeRanura(ranura);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ranura.icono,
                size: 16,
                color: VeridiaColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                ranura.etiqueta,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (equipado != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      MascotaRepository.instance.quitarAccesorio(ranura),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Quitar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VeridiaColors.onSurfaceVariant,
                    side: BorderSide(
                      color: VeridiaColors.onSurfaceVariant.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                      fontFamily: VeridiaFonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: accesorios.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _FichaAccesorio(
                accesorio: accesorios[i],
                perfil: perfil,
                equipado: equipado?.id == accesorios[i].id,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un accesorio como ficha compacta: sprite, nombre y estado.
///
/// La tarjeta ENTERA es el botón. Con once accesorios, un botón aparte dentro
/// de cada uno era ruido: aquí tocar la ficha compra si no la tienes y la
/// pone si ya es tuya, que es lo único que se puede querer hacer con ella.
class _FichaAccesorio extends StatefulWidget {
  const _FichaAccesorio({
    required this.accesorio,
    required this.perfil,
    required this.equipado,
  });

  final Accesorio accesorio;
  final UserProfile? perfil;
  final bool equipado;

  @override
  State<_FichaAccesorio> createState() => _FichaAccesorioState();
}

class _FichaAccesorioState extends State<_FichaAccesorio> {
  bool _ocupado = false;

  Future<void> _actuar() async {
    final repo = MascotaRepository.instance;
    final accesorio = widget.accesorio;
    setState(() => _ocupado = true);

    if (widget.equipado) {
      // Tocar algo YA puesto lo quita. Antes no hacia nada: quitar un
      // accesorio solo era posible desde el enlace "Quitar" de la esquina de
      // la seccion, que casi nadie encuentra, asi que en la practica ponerse
      // un accesorio era irreversible y no habia forma de dejar a la mascota
      // sin nada. Alternar en el propio accesorio es donde la gente lo busca.
      await repo.quitarAccesorio(accesorio.ranura);
    } else if (repo.tiene(accesorio.id)) {
      await repo.equiparAccesorio(accesorio);
    } else {
      final resultado = await repo.comprarAccesorio(accesorio);
      if (!mounted) return;
      if (resultado == ResultadoCompra.exito ||
          resultado == ResultadoCompra.yaLoTienes) {
        // Comprar y ponérselo en el mismo gesto: nadie compra un sombrero
        // para dejarlo guardado.
        await repo.equiparAccesorio(accesorio);
      } else {
        mostrarFalloDeCompra(context, resultado, accesorio.nivelRequerido);
      }
    }
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final accesorio = widget.accesorio;
    final repo = MascotaRepository.instance;
    final tiene = repo.tiene(accesorio.id);
    final nivel = nivelDesde(widget.perfil?.tokensTotales ?? 0);
    final faltaNivel = nivel < accesorio.nivelRequerido;
    final faltaSaldo = (widget.perfil?.tokens ?? 0) < accesorio.costo;
    final bloqueado = !tiene && (faltaNivel || faltaSaldo);

    return SizedBox(
      width: 106,
      child: Tooltip(
        message: accesorio.descripcion,
        child: VeridiaCard(
          // Mismo nicho oscuro que las fichas de mascota: los accesorios son
          // sprites igual que ellas y necesitan el mismo fondo para leerse.
          color: _fondoFicha,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          borderColor: widget.equipado
              ? VeridiaColors.secondary.withValues(alpha: 0.7)
              : null,
          glow: widget.equipado,
          onTap: (_ocupado || bloqueado) ? null : _actuar,
          // Su propio contenido YA es el sprite del accesorio: no se le
          // suma la animación de prensado encima.
          animarPresion: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PixelSprite(
                capas: [accesorio.sprite],
                tamano: accesorio.ranura == RanuraAccesorio.objeto ? 34 : 48,
                opacidad: tiene ? 1 : 0.35,
              ),
              Text(
                accesorio.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: tiene
                      ? VeridiaColors.onSurface
                      : VeridiaColors.onSurfaceVariant,
                ),
              ),
              _estado(faltaNivel: faltaNivel, tiene: tiene),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estado({required bool faltaNivel, required bool tiene}) {
    if (widget.equipado) {
      return const VeridiaTag(
        label: 'Puesto',
        icon: Icons.check_rounded,
        color: VeridiaColors.secondary,
        dense: true,
      );
    }
    if (tiene) {
      return const VeridiaTag(
        label: 'Ponérselo',
        color: VeridiaColors.primary,
        dense: true,
      );
    }
    if (faltaNivel) {
      return VeridiaTag(
        label: 'Nivel ${widget.accesorio.nivelRequerido}',
        icon: Icons.lock_rounded,
        color: VeridiaColors.outline,
        dense: true,
      );
    }
    return VeridiaTag(
      label: '${widget.accesorio.costo}',
      color: VeridiaColors.veridium,
      dense: true,
    );
  }
}

/// Explica por qué NO se pudo comprar algo, con el mismo texto en todas
/// partes: las mascotas y los accesorios fallan por las mismas razones.
void mostrarFalloDeCompra(
  BuildContext context,
  ResultadoCompra resultado,
  int nivelRequerido,
) {
  final mensajero = ScaffoldMessenger.of(context);
  switch (resultado) {
    case ResultadoCompra.exito:
    case ResultadoCompra.yaLoTienes:
      return;
    case ResultadoCompra.sinSaldo:
      mensajero.showSnackBar(
        veridiaSnackBarError('No te alcanzan los Veridiums todavía.'),
      );
    case ResultadoCompra.nivelInsuficiente:
      mensajero.showSnackBar(
        veridiaSnackBarError('Necesitas ser nivel $nivelRequerido para esto.'),
      );
    case ResultadoCompra.sinSesion:
      mensajero.showSnackBar(veridiaSnackBarError('Inicia sesión primero.'));
    case ResultadoCompra.sinPermisos:
      mensajero.showSnackBar(
        veridiaSnackBarError(
          'El servidor rechazó la escritura. Faltan desplegar las reglas del '
          'Refugio: firebase deploy --only firestore:rules',
        ),
      );
    case ResultadoCompra.error:
      mensajero.showSnackBar(
        veridiaSnackBarError('No se pudo completar la compra.'),
      );
  }
}

// ---------------------------------------------------------------------------

/// Botón de comprar / equipar, con el motivo cuando no se puede.
///
/// Los tres estados —no lo tengo, lo tengo, lo llevo puesto— comparten
/// suficiente lógica como para no repetirla en mascotas y accesorios.
class _AccionArticulo extends StatefulWidget {
  const _AccionArticulo({
    required this.tiene,
    required this.equipado,
    required this.costo,
    required this.nivelRequerido,
    required this.nivelActual,
    required this.saldo,
    required this.etiquetaEquipar,
    required this.etiquetaEquipado,
    required this.onComprar,
    required this.onEquipar,
  });

  final bool tiene;
  final bool equipado;
  final int costo;
  final int nivelRequerido;
  final int nivelActual;
  final int saldo;
  final String etiquetaEquipar;
  final String etiquetaEquipado;
  final Future<ResultadoCompra> Function() onComprar;
  final Future<bool> Function() onEquipar;

  @override
  State<_AccionArticulo> createState() => _AccionArticuloState();
}

class _AccionArticuloState extends State<_AccionArticulo> {
  bool _ocupado = false;

  Future<void> _comprar() async {
    setState(() => _ocupado = true);
    final resultado = await widget.onComprar();
    if (!mounted) return;
    setState(() => _ocupado = false);

    if (resultado == ResultadoCompra.exito ||
        resultado == ResultadoCompra.yaLoTienes) {
      // Comprar y equipar en el mismo gesto: nadie adopta una mascota para
      // dejarla en el Refugio.
      await widget.onEquipar();
      if (!mounted) return;
      if (resultado == ResultadoCompra.exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Listo! Ya te acompaña.')),
        );
      }
      return;
    }
    mostrarFalloDeCompra(context, resultado, widget.nivelRequerido);
  }

  Future<void> _equipar() async {
    setState(() => _ocupado = true);
    await widget.onEquipar();
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.equipado) {
      return VeridiaTag(
        label: widget.etiquetaEquipado,
        icon: Icons.check_circle_rounded,
        color: VeridiaColors.secondary,
        dense: true,
      );
    }

    if (widget.tiene) {
      return SizedBox(
        height: 34,
        child: VeridiaBotonTactil(
          child: OutlinedButton(
            onPressed: _ocupado ? null : _equipar,
            child: Text(widget.etiquetaEquipar),
          ),
        ),
      );
    }

    final faltaNivel = widget.nivelActual < widget.nivelRequerido;
    final faltaSaldo = widget.saldo < widget.costo;

    // Lo gratuito no se "compra": un botón con el precio 0 y un icono de
    // bolsa hacía dudar de si iba a cobrar algo, y encima se deshabilitaba
    // solo si el saldo no alcanzaba, que para 0 no tiene sentido.
    if (widget.costo == 0) {
      return SizedBox(
        height: 34,
        child: VeridiaBotonTactil(
          child: FilledButton.icon(
            onPressed: (_ocupado || faltaNivel) ? null : _comprar,
            icon: Icon(
              faltaNivel ? Icons.lock_rounded : Icons.favorite_rounded,
              size: 16,
            ),
            label: Text(
              faltaNivel ? 'Nivel ${widget.nivelRequerido}' : 'Adoptar',
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 34,
          child: VeridiaBotonTactil(
            child: FilledButton.icon(
              onPressed: (_ocupado || faltaNivel || faltaSaldo)
                  ? null
                  : _comprar,
              // El candado dice POR QUÉ no se puede pulsar. Un botón gris sin
              // más se lee como algo roto.
              icon: Icon(
                faltaNivel ? Icons.lock_rounded : Icons.shopping_bag_outlined,
                size: 16,
              ),
              label: Text('${widget.costo}'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (faltaNivel)
          Expanded(
            child: Text(
              'Se abre en nivel ${widget.nivelRequerido}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VeridiaColors.onSurfaceVariant,
              ),
            ),
          )
        else if (faltaSaldo)
          Expanded(
            child: Text(
              'Te faltan ${widget.costo - widget.saldo} Veridiums',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VeridiaColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Aviso cuando Firestore ni siquiera deja LEER el inventario.
///
/// Sin esto, unas reglas sin desplegar se ven exactamente igual que una
/// cuenta nueva —todo bloqueado, nada comprado— y no hay forma de saber que
/// el problema es de configuración y no del juego.
class _AvisoInventario extends StatelessWidget {
  const _AvisoInventario();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MascotaRepository.instance.inventarioLegible,
      builder: (context, legible, _) {
        if (legible) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: VeridiaCard(
            color: VeridiaColors.errorContainer,
            borderColor: VeridiaColors.error,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 18,
                  color: VeridiaColors.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'El servidor no deja leer tu Refugio, así que todo '
                        'aparece bloqueado. Faltan desplegar las reglas de '
                        'Firestore:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VeridiaColors.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const SelectableText(
                        'firebase deploy --only firestore:rules',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: VeridiaColors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// El dato biológico de la mascota, plegado hasta que alguien lo pide.
///
/// Con cinco mascotas, cinco párrafos abiertos convertían el Refugio en un
/// muro de texto que nadie leía y que empujaba las mascotas de abajo fuera de
/// la pantalla. Plegado sigue estando —la mascota también enseña— pero solo
/// para quien tiene curiosidad en ese momento.
class _DatoPlegable extends StatefulWidget {
  const _DatoPlegable({required this.dato});

  final String dato;

  @override
  State<_DatoPlegable> createState() => _DatoPlegableState();
}

class _DatoPlegableState extends State<_DatoPlegable> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _abierto = !_abierto),
          borderRadius: BorderRadius.circular(VeridiaRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 15,
                  color: VeridiaColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _abierto ? 'Ocultar el dato' : '¿Por qué esa mejora?',
                  style: texto.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: VeridiaColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _abierto
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: VeridiaColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // Hueco excavado en la ficha oscura. Con el verde de antes este
              // desplegable salía más CLARO que la tarjeta que lo abre, y
              // parecía una tarjeta nueva encima en vez de un cajón abierto.
              color: _huecoFicha,
              borderRadius: BorderRadius.circular(VeridiaRadii.md),
              border: Border.all(
                color: VeridiaColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              widget.dato,
              style: texto.bodySmall?.copyWith(
                color: VeridiaColors.onSurfaceVariant,
              ),
            ),
          ),
          crossFadeState: _abierto
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
        ),
      ],
    );
  }
}

/// Color de cada rareza. Sube en calidez con la dificultad, como en cualquier
/// juego de colección: quien ha visto uno antes lo lee sin leer el texto.
Color _colorRareza(Rareza rareza) => switch (rareza) {
  Rareza.comun => VeridiaColors.outline,
  Rareza.rara => VeridiaColors.secondary,
  Rareza.epica => const Color(0xFFB98BE8),
  Rareza.legendaria => VeridiaColors.veridium,
};
