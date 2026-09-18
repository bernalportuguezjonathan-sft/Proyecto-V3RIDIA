import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/repositorio_u.dart';
import '../theme/veridia_theme.dart';

/// Cuánto BAJA una pieza al presionarla. La referencia usa `translateY(2px)`;
/// aquí son 3 porque el gesto va acompañado de un encogido al 98% y con 2px
/// apenas se percibía en pantallas de alta densidad.
const double _hundido = 3;

/// El relieve "clay": DOS sombras OPUESTAS.
///
/// Es lo que reemplazó al canto sólido tipo Duolingo que tenía esta app. Un
/// canto es una pieza recortada de cartón —un solo bloque de color debajo—;
/// esto es una pieza MOLDEADA: pesa hacia abajo-derecha (negro) y recibe una
/// contraluz jade desde arriba-izquierda, como si el material fuera del
/// mismo verde que el fondo y estuviera iluminado en diagonal. En CSS es
/// `8px 8px 16px rgba(0,0,0,.4)` + `-8px -8px 16px rgba(16,185,129,.1)`.
///
/// [i] baja de 1 a ~0 al hundirse: las dos sombras se cierran a la vez y la
/// pieza queda pegada al fondo, que es como se lee un "presionado".
///
/// `Colors.black` no es un color nuevo: es el mismo `shadow` que ya declara
/// `_colorScheme` en veridia_theme.dart.
List<BoxShadow> _relieveClay({
  double i = 1,
  bool glow = false,
  bool hover = false,
}) => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.42 * i),
    offset: Offset(7 * i, 7 * i),
    blurRadius: 16 * i,
    spreadRadius: -2,
  ),
  BoxShadow(
    color: VeridiaColors.primary.withValues(alpha: 0.13 * i),
    offset: Offset(-6 * i, -6 * i),
    blurRadius: 15 * i,
    spreadRadius: -4,
  ),
  // Halo jade: permanente en las piezas marcadas con `glow`, y al pasar el
  // mouse en cualquiera. Es el `box-shadow: 0 0 15px rgba(16,185,129,.4)`
  // que la referencia le pone al `:hover` de sus botones.
  if (glow || hover)
    BoxShadow(
      color: VeridiaColors.primary.withValues(alpha: hover ? 0.34 : 0.18),
      blurRadius: hover ? 26 : 20,
      spreadRadius: hover ? 0 : -3,
    ),
];

/// El reflejo especular de una pieza clay: la cara de arriba-izquierda recibe
/// luz, la de abajo-derecha no.
///
/// En CSS esto es `inset 1px 1px 2px rgba(255,255,255,.1)`. Flutter no tiene
/// sombras INTERIORES, así que se pinta como un degradado muy tenue sobre el
/// color propio de la pieza: mismo efecto, sin apilar una capa de más.
/// Hundida, el degradado se invierte a oscuro —el hueco deja de recibir luz—,
/// que es el `clay-inset` de la referencia.
LinearGradient _caraClay(Color base, {double hundida = 0}) {
  final claro = Color.alphaBlend(VeridiaColors.brilloClay, base);
  final oscuro = Color.alphaBlend(Colors.black.withValues(alpha: 0.26), base);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(claro, oscuro, hundida)!, base],
    stops: const [0.0, 0.6],
  );
}

/// El relieve clay, para superficies que NO son una [VeridiaCard].
///
/// Existe porque media docena de pantallas (Ajustes, Acerca de, Actividad,
/// Publicaciones, Historial...) dibujan a mano su propio panel en vez de usar
/// [VeridiaCard], cada una con una sombra negra plana distinta. Sin esto,
/// esos paneles se quedarían lisos al lado de las piezas moldeadas y la app
/// se vería a dos estilos. Va junto con [veridiaCaraClay] -sombra y reflejo
/// son las dos mitades del mismo efecto y por separado no se leen-.
List<BoxShadow> veridiaRelieve({bool glow = false}) => _relieveClay(glow: glow);

/// El reflejo de una pieza clay, para las mismas superficies que
/// [veridiaRelieve]. Se pasa a `BoxDecoration.gradient` en lugar de `color`.
LinearGradient veridiaCaraClay(Color base) => _caraClay(base);

/// Fondo de la app: esmeralda profundo con un halo difuso arriba a la
/// izquierda, en la misma diagonal de la que viene la luz en todo el relieve
/// clay (ver [_relieveClay]). No es decoración suelta: es la fuente de luz
/// que justifica por qué cada pieza se ilumina por esa esquina.
class VeridiaBackground extends StatelessWidget {
  const VeridiaBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -1.0),
          radius: 1.4,
          // #0B4A39 es `surfaceContainer` apenas subido de brillo: el halo
          // se nota como profundidad, no como una mancha de otro color.
          colors: [Color(0xFF0B4A39), VeridiaColors.background],
          stops: [0.0, 0.75],
        ),
      ),
      child: child,
    );
  }
}

/// En qué estado está una pieza del juego: disponible, aún por desbloquear, o
/// ya conseguida.
///
/// Es un enum y no dos booleanos sueltos porque los tres estados se excluyen
/// entre sí: una mascota no puede estar bloqueada y completada a la vez, y
/// con `bool bloqueado, bool completado` esa combinación imposible se puede
/// escribir sin que nada se queje.
///
/// Solo cubre lo que PERSISTE en el contenido. Los estados momentáneos del
/// dedo —presionado, hover— ya los resuelve el relieve clay, y los de una
/// operación en curso —cargando, éxito, error— son de la pantalla, no de la
/// tarjeta.
enum EstadoPieza {
  /// Disponible. El aspecto normal de la app.
  normal,

  /// Todavía no se ha ganado o no alcanza el nivel. Se atenúa.
  bloqueado,

  /// Ya conseguido. Se subraya con el contorno jade.
  completado,
}

/// Tarjeta de superficie translúcida con borde fino (nivel 1 de elevación).
class VeridiaCard extends StatelessWidget {
  const VeridiaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
    this.radius = VeridiaRadii.lg,
    this.glow = false,
    this.animarPresion = true,
    this.estado = EstadoPieza.normal,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final double radius;
  final bool glow;

  /// Estado del contenido de la tarjeta (ver [EstadoPieza]).
  ///
  /// Cambia el contorno y la opacidad, y añade la etiqueta correspondiente
  /// para el lector de pantalla. Lo que NO hace es poner un candado ni un
  /// visto: la tarjeta no sabe qué contiene. **Quien la usa tiene que añadir
  /// ese ícono**, porque atenuar es una diferencia de color y el color no
  /// puede ser la única señal de que algo está bloqueado.
  ///
  /// Si se pasa [borderColor] a mano, ese color manda: hay tarjetas con
  /// contorno propio (rechazo de la IA, avisos) que no deben retenirse.
  final EstadoPieza estado;

  /// Apaga la animación de "prensado" en tarjetas tocables cuyo contenido YA
  /// es una mascota o un accesorio (ver identify_species.dart y
  /// refugio.dart): siguen siendo tocables, solo sin este efecto encima.
  final bool animarPresion;

  /// Contorno jade por defecto, al 20%: el mismo
  /// `border: 1px solid rgba(16,185,129,.2)` que la referencia le pone a cada
  /// pieza clay. Hace que cada superficie se lea como una pieza propia y no
  /// como un rectángulo más oscuro sobre el fondo.
  static const bordePorDefecto = Color(0x3310B981); // primary al 20%

  @override
  Widget build(BuildContext context) {
    // Sin sombras cuando la tarjeta es tocable: en ese caso las dibuja
    // _VeridiaCardTocable, que necesita animar el relieve al presionar.
    final animada = onTap != null && animarPresion;
    final base = color ?? VeridiaColors.surfaceContainer;

    // Una pieza conseguida se subraya con el contorno jade a plena fuerza; una
    // por desbloquear pierde el contorno de color y se queda en el gris verde
    // del sistema, para que no compita con lo que sí está disponible.
    final borde =
        borderColor ??
        switch (estado) {
          EstadoPieza.normal => bordePorDefecto,
          EstadoPieza.bloqueado => VeridiaColors.outlineVariant,
          EstadoPieza.completado => VeridiaColors.primary,
        };

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Degradado en vez de color plano: es el reflejo del relieve, no un
        // color nuevo -arranca del mismo `base` y solo le suma luz en la
        // esquina superior izquierda. Ver [_caraClay].
        gradient: _caraClay(base),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borde),
        boxShadow: animada
            ? null
            : _relieveClay(glow: glow || estado == EstadoPieza.completado),
      ),
      child: child,
    );

    Widget pieza;
    if (onTap == null) {
      pieza = content;
    } else if (!animarPresion) {
      pieza = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: VeridiaColors.primary.withValues(alpha: 0.10),
          highlightColor: VeridiaColors.primary.withValues(alpha: 0.06),
          child: content,
        ),
      );
    } else {
      pieza = _VeridiaCardTocable(
        onTap: onTap!,
        radius: radius,
        glow: glow || estado == EstadoPieza.completado,
        content: content,
      );
    }

    if (estado == EstadoPieza.normal) return pieza;

    // 0.55 y no menos: por debajo de ahí el texto de la tarjeta baja de la
    // relación de contraste mínima y "bloqueado" pasa a significar
    // "ilegible". Una pieza bloqueada tiene que poder leerse -para eso está,
    // para que se vea lo que falta por conseguir-.
    if (estado == EstadoPieza.bloqueado) {
      pieza = Opacity(opacity: 0.55, child: pieza);
    }

    // La etiqueta para el lector de pantalla: el atenuado y el contorno son
    // señales visuales, y por sí solas no llegan a quien no las ve.
    return Semantics(
      enabled: estado != EstadoPieza.bloqueado,
      label: estado == EstadoPieza.bloqueado ? 'Bloqueado' : 'Completado',
      child: pieza,
    );
  }
}

/// Rama animada de [VeridiaCard]: la tarjeta se HUNDE contra su propio canto
/// al presionar, en vez de solo cambiar de sombra. Aislada en su propio widget
/// con estado para que las tarjetas estáticas -la inmensa mayoría- no carguen
/// con ningún estado ni reconstrucción de más.
class _VeridiaCardTocable extends StatefulWidget {
  const _VeridiaCardTocable({
    required this.onTap,
    required this.radius,
    required this.glow,
    required this.content,
  });

  final VoidCallback onTap;
  final double radius;
  final bool glow;
  final Widget content;

  @override
  State<_VeridiaCardTocable> createState() => _VeridiaCardTocableState();
}

class _VeridiaCardTocableState extends State<_VeridiaCardTocable> {
  bool _presionado = false;

  /// Solo lo pone `true` un mouse real; en touch nunca se dispara. Mejora
  /// progresiva para quien usa la web con mouse, igual que en
  /// [VeridiaBotonTactil].
  bool _hover = false;

  void _fijar(bool valor) {
    if (_presionado != valor) setState(() => _presionado = valor);
  }

  void _alPasarMouse(bool entrando) {
    if (_hover != entrando) setState(() => _hover = entrando);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);

    return MouseRegion(
      onEnter: (_) => _alPasarMouse(true),
      onExit: (_) => _alPasarMouse(false),
      child: Listener(
        onPointerDown: (_) => _fijar(true),
        onPointerUp: (_) => _fijar(false),
        onPointerCancel: (_) => _fijar(false),
        child: _Hundible(
          presionado: _presionado,
          hover: _hover,
          radius: radius,
          glow: widget.glow,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: radius,
              splashColor: VeridiaColors.primary.withValues(alpha: 0.10),
              highlightColor: VeridiaColors.primary.withValues(alpha: 0.06),
              child: widget.content,
            ),
          ),
        ),
      ),
    );
  }
}

/// El mecanismo de "pieza moldeada que se hunde", compartido por las tarjetas
/// y los botones para que ambos se sientan exactamente igual.
///
/// Todo lo que anima es PINTADO (`Transform` + sombras): no toca el tamaño ni
/// la posición que el padre asignó, así que no puede descuadrar una
/// cuadrícula -que es justo lo que pasó cuando esto se intentó con un `Stack`
/// de ajuste flojo-.
class _Hundible extends StatelessWidget {
  const _Hundible({
    required this.presionado,
    required this.hover,
    required this.radius,
    required this.child,
    this.glow = false,
    this.opaco = true,
  });

  final bool presionado;
  final bool hover;
  final BorderRadius radius;
  final Widget child;
  final bool glow;

  /// `false` en superficies TRANSPARENTES (`OutlinedButton`). Flutter dibuja
  /// las sombras como la silueta completa por detrás, no recortada al
  /// exterior: a través de un centro transparente se verían como un relleno
  /// gris sucio. Ahí queda solo el halo, que vive en el borde.
  final bool opaco;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: presionado ? 1 : 0),
      // Bajar es inmediato -responde al dedo-; subir rebota un poco, que es
      // lo que da la sensación "jugosa" que ya tenía la app y que la
      // referencia conserva en su `transition: all .2s ease`.
      duration: Duration(milliseconds: presionado ? 90 : 320),
      curve: presionado ? Curves.easeOut : Curves.easeOutBack,
      builder: (context, t, hijo) {
        return Transform.translate(
          offset: Offset(0, _hundido * t),
          // El 0.98 del `clay-card:active` de la referencia. Se combina con
          // el descenso: la pieza se aplasta contra el fondo en vez de solo
          // resbalar hacia abajo.
          child: Transform.scale(
            scale: 1 - 0.02 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: opaco
                    ? _relieveClay(i: 1 - t * 0.85, glow: glow, hover: hover)
                    : [
                        if (glow || hover)
                          BoxShadow(
                            color: VeridiaColors.primary.withValues(
                              alpha: hover ? 0.30 : 0.16,
                            ),
                            blurRadius: hover ? 24 : 18,
                            spreadRadius: -3,
                          ),
                      ],
              ),
              child: hijo,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Envuelve un botón de Material (Filled/Outlined/Elevated) con la misma
/// profundidad que [_VeridiaCardTocable]: encoge levemente al tocar y hace
/// *cross-fade* hacia un halo de sombra ya pre-pintado -no anima `boxShadow`
/// cuadro a cuadro-, y vuelve a su estado normal al soltar.
///
/// [radius] es solo una aproximación para dibujar ese halo: no necesita
/// calzar exacto con el `shape` real del botón envuelto -con un desenfoque
/// tan grande, un par de píxeles de diferencia en la esquina no se nota-, así
/// que por defecto usa el radio que ya define el tema para los botones
/// (`VeridiaRadii.md`) en vez de pedir el dato en cada sitio de uso.
///
/// Usa [Listener] y no [GestureDetector] a propósito: un GestureDetector de
/// afuera competiría por el mismo gesto con el reconocedor de tap que el
/// botón YA tiene adentro (su InkWell interno), y esa disputa de gestos a
/// veces se traga el onPressed real. Listener solo observa el puntero sin
/// entrar en esa disputa, así que el tap de verdad sigue llegando intacto.
///
/// Usa `Stack(fit: StackFit.passthrough)` y no el `loose` por defecto por la
/// misma razón que [_VeridiaCardTocable]: `loose` deja que el contenido se
/// encoja a su tamaño natural en vez de llenar el espacio que le dieron -el
/// mismo bug que rompió el ancho de los Accesos rápidos-, evitado aquí desde
/// el principio.
///
/// Por eso mismo es puramente cosmético: no lee si el botón está habilitado,
/// así que uno deshabilitado también hace el gesto al tocarlo. Se deja así a
/// propósito -el color ya apagado del tema comunica que no hace nada- en vez
/// de duplicar en cada sitio de uso la condición de si está habilitado.
class VeridiaBotonTactil extends StatefulWidget {
  const VeridiaBotonTactil({
    super.key,
    required this.child,
    this.radius = VeridiaRadii.pill,
    this.destelloContinuo = false,
  });

  final Widget child;

  /// Radio con el que se recortan el destello y el halo de sombra.
  ///
  /// **Tiene que coincidir con la forma REAL del botón envuelto.** Por
  /// defecto es [VeridiaRadii.pill] porque el tema da `StadiumBorder` a los
  /// tres tipos de botón (elevado, relleno y con contorno), así que
  /// prácticamente todos los de la app son pastillas.
  ///
  /// Antes el valor por defecto era [VeridiaRadii.md] (18) y eso pintaba un
  /// rectángulo de esquinas casi rectas DETRÁS de una pastilla: en los
  /// extremos, el recorte sobresalía de la curva y el destello se veía como
  /// una banda clara con una esquina cuadrada asomando por fuera del botón.
  /// Se notaba en toda la app —entrar, cerrar sesión, suspender, modificar
  /// perfil— y solo tres sitios lo habían corregido pasando el radio a mano.
  ///
  /// Un botón con forma propia distinta de la pastilla tiene que declarar
  /// aquí SU radio; si no, el error vuelve al revés (el brillo recortado de
  /// más, dejando las esquinas apagadas).
  final double radius;

  /// Deja el destello corriendo en bucle en vez de dispararlo solo al tocar
  /// o al pasar el mouse. Es el `animation: shimmer 3s infinite linear` que
  /// la referencia reserva para su botón "premium".
  ///
  /// Pensado para UN botón por pantalla como mucho: si varios brillan a la
  /// vez dejan de señalar nada y la pantalla parpadea. Hoy solo lo usa
  /// "Analizar con IA" en identify_species.dart.
  final bool destelloContinuo;

  @override
  State<VeridiaBotonTactil> createState() => _VeridiaBotonTactilState();
}

class _VeridiaBotonTactilState extends State<VeridiaBotonTactil>
    with SingleTickerProviderStateMixin {
  bool _presionado = false;

  /// Solo lo pone `true` un mouse real (`MouseRegion.onEnter`); en touch
  /// nunca llega a dispararse -no hay puntero que "entre" sin tocar-, así
  /// que esto es pura mejora progresiva para quien usa la web con mouse.
  bool _hover = false;

  /// Destello diagonal que cruza el botón una vez al entrar el mouse, o al
  /// tocar en touch (así ambos mundos reciben el mismo gesto de bienvenida,
  /// no solo el mouse). 600ms porque es lo que dura el `sh02` de referencia.
  late final AnimationController _destello = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  /// El bucle es MÁS LENTO que el destello puntual (3s contra 600ms): un
  /// brillo permanente al ritmo del de un toque sería un parpadeo. Son los
  /// 3s del `animation: shimmer 3s infinite linear` de la referencia.
  static const _periodoContinuo = Duration(seconds: 3);

  /// Cuánto se inclina la banda de brillo, en radianes. 0.35 rad ≈ 20°, que
  /// es el `skewX(-20deg)` de la referencia.
  ///
  /// No es solo decorativo: de este ángulo salen el largo que necesita la
  /// banda para tapar el botón entero y el recorrido que tiene que hacer para
  /// cruzarlo, así que cambiarlo recalcula las dos cosas solo (ver `build`).
  static const _inclinacion = 0.35;

  /// Grosor de la banda como fracción del ancho del botón. Proporcional a
  /// propósito: un grosor fijo se traga entero un botón angosto y pasa
  /// desapercibido en uno de ancho completo.
  static const _anchoBanda = 0.28;

  @override
  void initState() {
    super.initState();
    if (widget.destelloContinuo) _destello.repeat(period: _periodoContinuo);
  }

  @override
  void didUpdateWidget(VeridiaBotonTactil anterior) {
    super.didUpdateWidget(anterior);
    // El botón de IA apaga su bucle mientras analiza (ver
    // identify_species.dart): un botón deshabilitado que sigue brillando
    // parece que aún invita a pulsarlo.
    if (widget.destelloContinuo == anterior.destelloContinuo) return;
    if (widget.destelloContinuo) {
      _destello.repeat(period: _periodoContinuo);
    } else {
      _destello.stop();
      _destello.value = 0;
    }
  }

  @override
  void dispose() {
    _destello.dispose();
    super.dispose();
  }

  void _fijar(bool valor) {
    if (_presionado == valor) return;
    setState(() => _presionado = valor);
    // Con el bucle corriendo, un `forward` lo cortaría y dejaría el destello
    // parado a media pasada: ahí el brillo ya está, no hace falta relanzarlo.
    if (valor && !widget.destelloContinuo) _destello.forward(from: 0);
  }

  void _alPasarMouse(bool entrando) {
    if (_hover == entrando) return;
    setState(() => _hover = entrando);
    if (entrando && !widget.destelloContinuo) _destello.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);

    // Un OutlinedButton es transparente por dentro: el canto sólido se vería
    // a través del centro y parecería relleno. La comprobación es sobre la
    // instancia real, así que un botón que cambia de tipo según su estado
    // (los hay en desafíos y en moderación) recibe el trato correcto en cada
    // caso sin tener que declararlo en el sitio de uso.
    final transparente = widget.child is OutlinedButton;

    final contenido = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        widget.child,
        // El destello, recortado a la forma del botón (ClipRRect) para que no
        // se salga del contorno, y medido en píxeles reales del propio botón
        // (LayoutBuilder) en vez de un tamaño fijo: así se ve igual de bien en
        // uno angosto de 34px que en uno de ancho completo.
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: radius,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ancho = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 120.0;
                  // El alto también se mide. Antes no se leía y era justo el
                  // dato que faltaba para poder inclinar bien la banda.
                  final alto = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 48.0;

                  final banda = ancho * _anchoBanda;

                  // Largo MÍNIMO para que la banda, ya inclinada, tape el
                  // botón de arriba abajo en todo su ancho.
                  //
                  // Aquí estaba el fallo que dejaba el brillo "de la mitad
                  // para abajo": la banda no podía pasar del alto del botón
                  // -las restricciones que recibía lo impedían-, y una banda
                  // tan alta como el botón, al girarla, saca sus dos puntas
                  // fuera y dentro solo queda un trozo corto y caído hacia
                  // abajo. La mitad de arriba no se iluminaba nunca.
                  //
                  // `alto / cos` es lo que hay que estirarla para volver a
                  // llegar de borde a borde una vez torcida; el segundo
                  // sumando cubre lo que se desfasa un lado de la banda
                  // respecto al otro por su propio grosor.
                  final largo =
                      alto / math.cos(_inclinacion) +
                      banda * math.tan(_inclinacion);

                  // Lo que mide la banda inclinada de lado a lado, más el
                  // botón: es exactamente el viaje que tiene que hacer para
                  // entrar por un borde y salir por el otro. Sale de las
                  // medidas reales, así que cruza igual de limpio un botón de
                  // ancho completo que uno diminuto, sin factores a ojo.
                  final recorrido =
                      ancho +
                      banda * math.cos(_inclinacion) +
                      largo * math.sin(_inclinacion);

                  return AnimatedBuilder(
                    animation: _destello,
                    builder: (context, _) {
                      // Mientras no esté cruzando, NO se pinta nada.
                      //
                      // Este era el motivo por el que se veía una banda clara
                      // fija en los botones: el destello estaba siempre
                      // montado, aparcado en el extremo izquierdo, y como su
                      // borde es un degradado su parte luminosa seguía
                      // cayendo dentro del botón. El brillo es un gesto de
                      // respuesta al dedo o al mouse; sin gesto no tiene por
                      // qué haber brillo.
                      //
                      // La condición mira si ANIMA, no si está en el punto de
                      // partida: al acabar la pasada la banda se queda en el
                      // 1, no en el 0, y preguntando solo por el arranque se
                      // quedaba montada para siempre después del primer toque.
                      if (!widget.destelloContinuo && !_destello.isAnimating) {
                        return const SizedBox.shrink();
                      }

                      return Transform.translate(
                        // Centrado en el botón y desplazado medio recorrido a
                        // cada lado: empieza justo fuera por la izquierda y
                        // termina justo fuera por la derecha.
                        offset: Offset((_destello.value - 0.5) * recorrido, 0),
                        // `OverflowBox` para que la banda pueda ser MÁS ALTA
                        // que el botón.
                        //
                        // Dentro de un `Positioned.fill` las restricciones
                        // llegan ajustadas al botón, así que el `width` y el
                        // `height` que pide el Container se recortaban a esa
                        // caja: primero la banda salía tan ancha como el botón
                        // entero, y al arreglar eso con un `Align` se quedó
                        // igual de limitada en alto. `OverflowBox` suelta las
                        // dos medidas y la deja medir lo que necesita; el
                        // ClipRRect de arriba sigue siendo quien decide qué se
                        // ve, así que no se sale nada.
                        child: OverflowBox(
                          minWidth: 0,
                          minHeight: 0,
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: Transform.rotate(
                            // 0.35 rad son los `skewX(-20deg)` exactos del
                            // `sh02` de referencia. Gira sobre la banda misma,
                            // centrada en el botón: cuando giraba sobre la
                            // caja completa con la banda pegada a un lado, el
                            // propio giro se la llevaba hacia abajo.
                            angle: -_inclinacion,
                            child: Container(
                              width: banda,
                              height: largo,
                              decoration: const BoxDecoration(
                                // Blanco puro, no `onSurface`: el destello es
                                // un reflejo de luz sobre la pieza, no un
                                // tinte de la paleta. Sobre el esmeralda
                                // profundo un verde claro al 16% no llegaba a
                                // leerse.
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0x47FFFFFF), // blanco al 28%
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => _alPasarMouse(true),
      onExit: (_) => _alPasarMouse(false),
      child: Listener(
        onPointerDown: (_) => _fijar(true),
        onPointerUp: (_) => _fijar(false),
        onPointerCancel: (_) => _fijar(false),
        child: AnimatedScale(
          // Solo el mouse agranda; al presionar ya no encoge, porque
          // ahora el gesto es hundirse contra el canto (ver _Hundible)
          // y las dos cosas juntas se peleaban.
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: _Hundible(
            presionado: _presionado,
            hover: _hover,
            radius: radius,
            opaco: !transparente,
            child: contenido,
          ),
        ),
      ),
    );
  }
}

/// Entrada escalonada: el elemento aparece subiendo y creciendo con un
/// rebote corto. [indice] retrasa el arranque para que una cuadrícula o una
/// lista se arme en cascada en vez de aparecer toda de golpe.
///
/// El retraso se topa a 8 posiciones a propósito: en una lista larga, un
/// escalón por elemento haría esperar segundos al último. Después de ese
/// tope todos entran juntos, que a esa altura ya no se nota.
///
/// Anima UNA vez, al montarse. Como el estado sobrevive a las
/// reconstrucciones del padre, no se vuelve a disparar cada vez que cambia
/// algo de la pantalla -que sería mareante-.
class VeridiaAparece extends StatefulWidget {
  const VeridiaAparece({super.key, required this.child, this.indice = 0});

  final Widget child;
  final int indice;

  @override
  State<VeridiaAparece> createState() => _VeridiaApareceState();
}

class _VeridiaApareceState extends State<VeridiaAparece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    final retraso = 55 * widget.indice.clamp(0, 8);
    Future<void>.delayed(Duration(milliseconds: retraso), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_c.value);
        return Opacity(
          // La opacidad se recorta a [0,1]: easeOutBack se pasa de 1 al
          // rebotar y Opacity no acepta valores fuera de ese rango.
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Chispa animada para acentos de IA: el ícono "respira" en un pulso suave y
/// continuo -escala y opacidad, nada de partículas ni colores nuevos-, la
/// misma idea del `Icons.auto_awesome` que ya usa la app para identificar
/// especies. Pensado para UN acento puntual (el botón "Analizar con IA"), no
/// para aplicarse a los botones comunes: un ícono pulsando todo el tiempo en
/// cada botón de la app sería ruido, no un acento.
class VeridiaChispaIA extends StatefulWidget {
  const VeridiaChispaIA({super.key, required this.child});

  final Widget child;

  @override
  State<VeridiaChispaIA> createState() => _VeridiaChispaIAState();
}

class _VeridiaChispaIAState extends State<VeridiaChispaIA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulso.value);
        return Transform.scale(
          scale: 1 + t * 0.14,
          child: Opacity(opacity: 0.7 + t * 0.3, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Encabezado de sección: título en Manrope + acción opcional a la derecha.
class VeridiaSectionTitle extends StatelessWidget {
  const VeridiaSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Métrica compacta (valor grande + etiqueta) usada en perfil y panel admin.
class VeridiaStat extends StatelessWidget {
  const VeridiaStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = color ?? VeridiaColors.primary;

    return VeridiaCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.headlineSmall?.copyWith(color: accent),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Cápsula de categoría / estado.
class VeridiaTag extends StatelessWidget {
  const VeridiaTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? VeridiaColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        // OPACA, no translucida. Antes era el acento al 16% dejando pasar el
        // fondo, asi que la capsula valia lo que valiera lo que tuviera
        // detras: sobre una tarjeta oscura se leia bien, pero sobre la
        // cabecera clara del perfil quedaba lavada y las insignias
        // desaparecian. Componer el acento sobre una base oscura fija da el
        // mismo aspecto y ademas la vuelve independiente del fondo.
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.20),
          VeridiaColors.surfaceContainerLowest,
        ),
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: VeridiaFonts.body,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío: icono en halo, título y mensaje, con acción opcional.
class VeridiaEmptyState extends StatelessWidget {
  const VeridiaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Con el mismo relieve que las tarjetas: es la pieza más
                // grande de una pantalla vacía y, plana, quedaba como un
                // agujero gris en medio de una app de superficies moldeadas.
                gradient: _caraClay(VeridiaColors.surfaceContainerHigh),
                border: Border.all(
                  color: VeridiaColors.primary.withValues(alpha: 0.35),
                ),
                boxShadow: _relieveClay(),
              ),
              child: Icon(icon, size: 36, color: VeridiaColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: text.bodySmall),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              VeridiaBotonTactil(
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Píldora de Veridiums para el AppBar. Fondo dorado translúcido y borde:
/// legible sobre el fondo negro/verde (antes el icono se perdía).
/// Un número que RECORRE el camino hasta su nuevo valor en vez de saltar.
///
/// Es la pieza que faltaba para que ganar se sintiera como ganar. Un saldo
/// que pasa de 24 a 27 de golpe no se percibe: el ojo lee "27" y no registra
/// que subió. Viéndolo contar, la recompensa existe.
///
/// Solo celebra cuando SUBE. Al gastar, el número baja sin pulso ni adorno,
/// porque en Veridia la moneda compra expansión y nunca rescate: subrayar el
/// gasto con la misma fanfarria que el premio enseñaría a no gastar, que es
/// justo el comportamiento que el ranking por acumulado ya corrigió una vez.
///
/// No crea `AnimationController` propio: la escala sale del mismo recorrido
/// del número, como un arco de seno que sube y vuelve. Un contador en la
/// AppBar está presente en casi toda la app y no puede permitirse un
/// controlador por pantalla.
class VeridiaContador extends StatefulWidget {
  const VeridiaContador({
    super.key,
    required this.valor,
    this.estilo,
    this.duracion = VeridiaDuraciones.recompensa,
  });

  final int valor;
  final TextStyle? estilo;
  final Duration duracion;

  @override
  State<VeridiaContador> createState() => _VeridiaContadorState();
}

class _VeridiaContadorState extends State<VeridiaContador> {
  /// De dónde viene el número. Arranca igual al valor actual para que la
  /// primera aparición NO cuente desde cero: al abrir una pantalla el saldo
  /// ya estaba ahí, y verlo subir desde 0 sería contar un premio que no se
  /// acaba de ganar.
  late int _desde = widget.valor;
  late int _hasta = widget.valor;

  @override
  void didUpdateWidget(covariant VeridiaContador anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.valor != widget.valor) {
      setState(() {
        _desde = anterior.valor;
        _hasta = widget.valor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilo = widget.estilo;

    // Nada que animar todavía: un Text normal, sin widget de animación
    // montado. Importa porque este contador vive en la AppBar de casi todas
    // las pantallas.
    if (_desde == _hasta) {
      return Text('$_hasta', style: estilo);
    }

    final sube = _hasta > _desde;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _desde.toDouble(), end: _hasta.toDouble()),
      duration: widget.duracion,
      curve: VeridiaCurvas.entrada,
      builder: (context, valor, _) {
        final recorrido = (_hasta - _desde).abs();
        // 0 al empezar, 1 al llegar. El guardia del divisor nunca debería
        // dispararse -si no hay recorrido no se llega aquí-, pero una
        // división por cero en un widget de AppBar tumbaría la app entera.
        final t = recorrido == 0
            ? 1.0
            : ((valor - _desde) / (_hasta - _desde)).clamp(0.0, 1.0);

        // Un solo arco: crece hasta 1.08 a mitad de camino y vuelve a 1.
        final escala = sube ? 1 + 0.08 * math.sin(math.pi * t) : 1.0;

        return Transform.scale(
          scale: escala,
          child: Text('${valor.round()}', style: estilo),
        );
      },
    );
  }
}

class VeridiaTokenBadge extends StatelessWidget {
  const VeridiaTokenBadge({super.key, required this.tokens, this.onTap});

  final int tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VeridiaColors.veridium.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
        border: Border.all(
          color: VeridiaColors.veridium.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE083), Color(0xFFE8A020)],
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'V',
              style: TextStyle(
                fontFamily: VeridiaFonts.headline,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A3400),
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // El saldo CUENTA hacia su nuevo valor. Como esta píldora es la que
          // aparece en la AppBar de casi todas las pantallas, cambiarla aquí
          // basta para que ganar Veridiums se note en toda la app.
          VeridiaContador(
            valor: tokens,
            estilo: const TextStyle(
              fontFamily: VeridiaFonts.headline,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: VeridiaColors.veridium,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VeridiaRadii.pill),
      child: pill,
    );
  }
}

/// Botón circular de acción para AppBar, con contraste garantizado.
class VeridiaAppBarAction extends StatelessWidget {
  const VeridiaAppBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? VeridiaColors.primary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent.withValues(alpha: 0.14),
        shape: CircleBorder(
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: accent),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior de las 5 secciones del EXPLORADOR.
///
/// No se le muestra al administrador. Pantallas como el mapa las usan los dos
/// roles, y al administrador esta barra lo sacaba de su propia sesión: tocar
/// cualquier pestaña lo llevaba a Inicio/Cámara/Diario del explorador y, de
/// paso, borraba el Panel de Administración de la pila de navegación (ver
/// [VeridiaNav.ir], que conserva solo la primera ruta). El administrador llega
/// a estas pantallas desde su panel y vuelve con el botón de atrás.
class VeridiaBottomNav extends StatelessWidget {
  const VeridiaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: UserRepository.instance.currentUser,
      builder: (context, perfil, _) =>
          perfil?.role == rolAdministrador ? const SizedBox.shrink() : _barra(),
    );
  }

  Widget _barra() {
    return Container(
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainerLow,
        // Mismo filo jade que la barra SUPERIOR (ver `appBarTheme` en
        // veridia_theme.dart): las dos barras enmarcan el contenido con la
        // misma línea en vez de una gris y otra verde.
        border: Border(
          top: BorderSide(color: VeridiaColors.primary.withValues(alpha: 0.18)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          height: 66,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          // Sin el indicador de Material: la capsula de [_IconoNavActivo] ya
          // hace ese papel, y las dos juntas dibujaban una pastilla dentro de
          // otra.
          indicatorColor: Colors.transparent,
          // SOLO al presionar.
          //
          // Antes era un `WidgetStatePropertyAll`, que devuelve el mismo
          // color en TODOS los estados —incluidos hover y foco—. El resultado
          // era una pastilla de jade al 10% con la forma exacta de la cápsula
          // de selección, que se quedaba pegada en la pestaña por la que
          // había pasado el cursor o que había recibido el foco tras un clic.
          // Con el indicador de Material en transparente, esa pastilla era lo
          // único redondeado que podía dibujarse sobre una pestaña NO
          // seleccionada: se veía "Diario" marcado estando en Inicio.
          //
          // Devolver transparente en el resto de estados lo cierra de raíz:
          // el único resalte que queda es el del dedo, y ese dura lo que dura
          // el toque. Quien navegue con teclado pierde el anillo de foco
          // aquí; a cambio, la barra deja de mentir sobre en qué sección
          // estás, que es la información que esta barra existe para dar.
          overlayColor: WidgetStateProperty.resolveWith((estados) {
            if (estados.contains(WidgetState.pressed)) {
              return VeridiaColors.primary.withValues(alpha: 0.12);
            }
            return Colors.transparent;
          }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: _IconoNavActivo(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: _IconoNavActivo(Icons.camera_alt_rounded),
              label: 'Cámara',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: _IconoNavActivo(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: _IconoNavActivo(Icons.menu_book_rounded),
              label: 'Diario',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: _IconoNavActivo(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de carga estándar.
class VeridiaLoader extends StatelessWidget {
  const VeridiaLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: VeridiaColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Campo de texto del sistema; `isPassword` incluye el ojo funcional.
class VeridiaTextField extends StatefulWidget {
  const VeridiaTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  final int maxLines;

  @override
  State<VeridiaTextField> createState() => _VeridiaTextFieldState();
}

class _VeridiaTextFieldState extends State<VeridiaTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final obscure = widget.isPassword && _obscured;

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: obscure,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      maxLines: obscure ? 1 : widget.maxLines,
      cursorColor: VeridiaColors.primary,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                tooltip: _obscured
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                color: VeridiaColors.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}

/// Niveles de fortaleza de contraseña usados por [VeridiaPasswordStrength].
enum PasswordStrength { vacia, debil, media, fuerte }

/// Evalúa una contraseña según longitud y variedad de caracteres.
PasswordStrength evaluarFortalezaContrasena(String password) {
  if (password.isEmpty) return PasswordStrength.vacia;

  final tieneMinuscula = password.contains(RegExp(r'[a-z]'));
  final tieneMayuscula = password.contains(RegExp(r'[A-Z]'));
  final tieneNumero = password.contains(RegExp(r'[0-9]'));
  final tieneSimbolo = password.contains(RegExp(r'[^a-zA-Z0-9]'));

  final variedad = [
    tieneMinuscula,
    tieneMayuscula,
    tieneNumero,
    tieneSimbolo,
  ].where((v) => v).length;

  if (password.length < 8 || variedad <= 1) return PasswordStrength.debil;
  if (password.length < 12 || variedad <= 2) return PasswordStrength.media;
  return PasswordStrength.fuerte;
}

/// Indicador visual de fortaleza de contraseña: barra + checklist de
/// requisitos que se van marcando en verde a medida que se cumplen.
class VeridiaPasswordStrength extends StatelessWidget {
  const VeridiaPasswordStrength({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final fortaleza = evaluarFortalezaContrasena(password);
    final (double valor, Color color, String etiqueta) = switch (fortaleza) {
      PasswordStrength.vacia => (0.0, VeridiaColors.outlineVariant, ''),
      PasswordStrength.debil => (1 / 3, VeridiaColors.error, 'Débil'),
      PasswordStrength.media => (2 / 3, Colors.amber, 'Media'),
      PasswordStrength.fuerte => (1.0, VeridiaColors.primary, 'Fuerte'),
    };

    final requisitos = <(bool, String)>[
      (password.length >= 8, 'Mínimo 8 caracteres'),
      (password.contains(RegExp(r'[A-Z]')), 'Una mayúscula'),
      (password.contains(RegExp(r'[a-z]')), 'Una minúscula'),
      (password.contains(RegExp(r'[0-9]')), 'Un número'),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VeridiaColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        border: Border.all(color: VeridiaColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeridiaProgressBar(value: valor, height: 5, color: color),
          if (etiqueta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Seguridad de la contraseña: $etiqueta',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (cumplido, etiquetaReq) in requisitos)
                _VeridiaRequisitoPassword(
                  cumplido: cumplido,
                  label: etiquetaReq,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VeridiaRequisitoPassword extends StatelessWidget {
  const _VeridiaRequisitoPassword({
    required this.cumplido,
    required this.label,
  });

  final bool cumplido;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = cumplido
        ? VeridiaColors.primary
        : VeridiaColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Icon(
            cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(cumplido),
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: VeridiaFonts.body,
            fontSize: 11.5,
            fontWeight: cumplido ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Barra de progreso con relleno en verde neón.
class VeridiaProgressBar extends StatelessWidget {
  const VeridiaProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
  });

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final relleno = color ?? VeridiaColors.secondary;
    final radio = BorderRadius.circular(VeridiaRadii.pill);

    return Container(
      height: height,
      decoration: BoxDecoration(
        // Canal EXCAVADO (`clay-inset`): fondo oscuro con la luz invertida,
        // para que la parte llena se lea como algo que BRILLA dentro del
        // hueco. Antes el carril era `surfaceContainerHighest`, casi tan
        // claro como el relleno, y la barra apenas se distinguía de su fondo.
        gradient: _caraClay(VeridiaColors.surfaceContainerLowest, hundida: 1),
        borderRadius: radio,
        border: Border.all(
          color: VeridiaColors.primary.withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radio,
        // El llenado se ANIMA hacia su nuevo valor en vez de saltar. Importa
        // donde la barra cambia a la vista -al ganar XP en el refugio, al
        // completar un desafío-: el recorrido es la recompensa.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radio,
                gradient: LinearGradient(
                  colors: [relleno.withValues(alpha: 0.72), relleno],
                ),
                boxShadow: [
                  BoxShadow(
                    color: relleno.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SnackBar de error legible.
///
/// El fondo [VeridiaColors.error] es un salmón claro, pero el texto que pone
/// el tema por defecto también es claro: el aviso quedaba a 1.3:1 de
/// contraste, ilegible. Aquí se usa [VeridiaColors.onError], su color de
/// contraste en la paleta, que sube la relación a 7.7:1.
///
/// Se expone como constructor (y no solo como función que lo muestra) para
/// las pantallas que capturan el `ScaffoldMessenger` antes de un `await`.
SnackBar veridiaSnackBarError(String mensaje) {
  return SnackBar(
    backgroundColor: VeridiaColors.error,
    // Los errores de la IA son frases largas; 3 s no alcanzan a leerse.
    duration: const Duration(seconds: 5),
    margin: const EdgeInsets.all(16),
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: VeridiaColors.onError, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mensaje,
            style: const TextStyle(
              color: VeridiaColors.onError,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Muestra [veridiaSnackBarError] reemplazando el aviso anterior.
void mostrarErrorVeridia(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(veridiaSnackBarError(mensaje));
}

/// SnackBar unificado del sistema.
void mostrarMensajeVeridia(
  BuildContext context,
  String mensaje, {
  bool esError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.check_circle_outline,
            color: esError ? VeridiaColors.error : VeridiaColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(mensaje)),
        ],
      ),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    ),
  );
}

/// Marco vacío para una foto que no existe o no cargó.
///
/// Estaba duplicado en cuatro pantallas (inicio, mapa, detalle de zona e
/// historial), cada una con su propio tamaño de icono y su propio color.
class VeridiaFotoVacia extends StatelessWidget {
  const VeridiaFotoVacia({super.key, this.tamanoIcono = 26});

  final double tamanoIcono;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VeridiaColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.eco_outlined,
        color: VeridiaColors.primary,
        size: tamanoIcono,
      ),
    );
  }
}

/// El icono de la pestaña ACTIVA de la barra inferior: una cápsula de cristal
/// jade que entra con un rebote corto.
///
/// Sustituye al destello diagonal que llevaban antes estos iconos. Aquel era
/// el mismo efecto de los botones grandes —una banda blanca cruzando la
/// pieza—, y a 24 píxeles no se lee como brillo sino como un parpadeo: barría
/// el icono entero en medio segundo y quedaba incómodo de mirar en el móvil.
///
/// Aquí el brillo no se mueve por encima del icono: ES el fondo del icono. El
/// degradado va de arriba-izquierda a abajo-derecha, la misma diagonal de la
/// que viene la luz en todo el relieve clay de la app, y el halo exterior lo
/// despega de la barra. Lo único que anima es la entrada, y solo cuando
/// cambias de pestaña, que es cuando hay algo que comunicar.
class _IconoNavActivo extends StatelessWidget {
  const _IconoNavActivo(this.icono);

  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, hijo) => Transform.scale(
        // easeOutBack se pasa de 1 al rebotar: la escala lo aprovecha, pero
        // la opacidad se recorta porque Opacity no acepta valores fuera
        // de [0,1].
        scale: 0.80 + 0.20 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: hijo),
      ),
      child: Container(
        // Vertical 4 y no mas: NavigationBar reserva unos 32 px de alto
        // para el icono cuando las etiquetas van siempre visibles, y 24 de
        // icono mas 5+5 de relleno se pasaban de ese hueco.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VeridiaRadii.pill),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              VeridiaColors.primary.withValues(alpha: 0.36),
              VeridiaColors.primary.withValues(alpha: 0.10),
            ],
          ),
          border: Border.all(
            color: VeridiaColors.primary.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: VeridiaColors.primary.withValues(alpha: 0.32),
              blurRadius: 14,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Icon(icono, size: 24, color: VeridiaColors.secondary),
      ),
    );
  }
}
