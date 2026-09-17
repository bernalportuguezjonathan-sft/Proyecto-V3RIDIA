/// Primitivas de diseño adaptable de Veridia.
///
/// Antes de este archivo la app resolvía el tamaño de pantalla con tres
/// `LayoutBuilder` y un `MediaQuery` en 19.000 líneas, así que en la práctica
/// no se adaptaba: en un navegador de escritorio las tarjetas se estiraban de
/// borde a borde y una línea de texto llegaba a 300 caracteres. El
/// desbordamiento del panel de chips del mapa no fue un caso aislado, fue el
/// primer sitio donde ese vacío se hizo visible.
///
/// La regla del proyecto es medir el ESPACIO DISPONIBLE, no el dispositivo.
/// Un teléfono en horizontal es más ancho que una tablet en vertical, y una
/// tablet con un panel lateral abierto tiene el ancho útil de un teléfono.
/// Preguntar "¿es una tablet?" da la respuesta equivocada en los tres casos;
/// preguntar "¿cuánto ancho tengo aquí?" acierta siempre.
library;

import 'package:flutter/material.dart';

import '../theme/veridia_theme.dart';

/// El ancho útil de un trozo de interfaz, ya clasificado.
///
/// No se llama "móvil / tablet / escritorio" a propósito: el mismo widget
/// puede estar [compacto] dentro de un panel lateral en un monitor grande, y
/// nombrar los tramos por dispositivo invita justo al error que este archivo
/// existe para evitar.
enum VeridiaAncho {
  /// Una sola columna, controles al alcance del pulgar.
  compacto,

  /// Cabe una segunda columna o una fila de tarjetas más holgada.
  medio,

  /// Cabe contenido dividido en dos paneles.
  amplio;

  bool get esCompacto => this == VeridiaAncho.compacto;
  bool get esMedio => this == VeridiaAncho.medio;
  bool get esAmplio => this == VeridiaAncho.amplio;

  /// Verdadero en [medio] y [amplio]: el caso "hay sitio de sobra", que es la
  /// pregunta que de verdad hace la mayoría de las pantallas.
  bool get tieneEspacio => this != VeridiaAncho.compacto;

  /// Clasifica un ancho en píxeles lógicos.
  static VeridiaAncho deAncho(double ancho) {
    if (ancho >= VeridiaBreakpoints.escritorio) return VeridiaAncho.amplio;
    if (ancho >= VeridiaBreakpoints.tablet) return VeridiaAncho.medio;
    return VeridiaAncho.compacto;
  }

  /// Clasifica el ancho de la VENTANA.
  ///
  /// Es el atajo para decisiones de pantalla completa —si la barra inferior
  /// se dibuja abajo o al lado, por ejemplo—. Para decidir cómo se acomoda un
  /// bloque DENTRO de la pantalla hay que usar [VeridiaSegunAncho], que mide
  /// el hueco real y no la ventana entera.
  static VeridiaAncho de(BuildContext context) =>
      deAncho(MediaQuery.sizeOf(context).width);

  /// El margen lateral que le corresponde a este tramo.
  ///
  /// Crece con el ancho porque en una pantalla grande un margen de 16 px deja
  /// el contenido pegado al borde y se lee como un descuido, mientras que en
  /// un teléfono pequeño 32 px se comen el contenido.
  double get margen => switch (this) {
    VeridiaAncho.compacto => VeridiaSpacing.lg,
    VeridiaAncho.medio => VeridiaSpacing.xl,
    VeridiaAncho.amplio => VeridiaSpacing.xxl,
  };
}

/// Resuelve el [VeridiaAncho] del hueco que ocupa este widget y lo entrega.
///
/// Usa los constraints del padre, que es la medida honesta del sitio
/// disponible. Cuando el padre no acota el ancho —dentro de una lista
/// horizontal, por ejemplo, donde `maxWidth` llega infinito— cae al ancho de
/// la ventana, que es lo más parecido a la verdad que hay a mano.
class VeridiaSegunAncho extends StatelessWidget {
  const VeridiaSegunAncho({super.key, required this.builder});

  final Widget Function(BuildContext context, VeridiaAncho ancho) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return builder(context, VeridiaAncho.deAncho(ancho));
      },
    );
  }
}

/// La columna de contenido de una pantalla: centrada, con tope de ancho y con
/// el margen lateral que toca.
///
/// Es el widget que arregla la web de un plumazo. Sin él, en un monitor de
/// 2560 px una tarjeta de desafío mide dos metros de ancho y su texto queda
/// en líneas imposibles de leer; el contenido "cabe", pero no se puede usar.
///
/// Envuelve el cuerpo de una pantalla, no cada tarjeta suelta: si se anida
/// dos veces el margen se aplica dos veces y el contenido se estrecha sin
/// motivo.
class VeridiaContenido extends StatelessWidget {
  const VeridiaContenido({
    super.key,
    required this.child,
    this.anchoMaximo = VeridiaBreakpoints.anchoMaximoContenido,
    this.margenVertical = 0,
    this.margenLateral,
  });

  /// Variante estrecha para lo que se LEE o se RELLENA: formularios de login
  /// y registro, fichas de especie, textos largos. Una línea cómoda ronda los
  /// 60-75 caracteres, y a [VeridiaBreakpoints.anchoMaximoFormulario] eso se
  /// cumple sin forzar el tamaño de letra.
  const VeridiaContenido.estrecho({
    super.key,
    required this.child,
    this.margenVertical = 0,
    this.margenLateral,
  }) : anchoMaximo = VeridiaBreakpoints.anchoMaximoFormulario;

  final Widget child;
  final double anchoMaximo;
  final double margenVertical;

  /// Fuerza un margen lateral en vez del que corresponde al tramo. Para
  /// pantallas cuyo contenido llega al borde a propósito (el mapa).
  final double? margenLateral;

  @override
  Widget build(BuildContext context) {
    return VeridiaSegunAncho(
      builder: (context, ancho) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: anchoMaximo),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: margenLateral ?? ancho.margen,
                vertical: margenVertical,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Rejilla que decide su número de columnas por el ancho disponible.
///
/// Se le dice cuánto mide CÓMODO un elemento, no cuántas columnas hay: así la
/// misma rejilla da una columna en un teléfono pequeño, dos en uno grande y
/// cuatro en un monitor, sin escribir un solo punto de quiebre en la pantalla
/// que la usa.
///
/// Usa `Wrap` y no `GridView` a propósito: estas rejillas viven dentro de
/// pantallas que ya hacen scroll (Refugio, Desafíos, Logros) y meter un
/// `GridView` con su propio scroll dentro de otro scroll obliga a
/// `shrinkWrap`, que mide TODOS los hijos en cada reconstrucción. Con `Wrap`
/// los elementos se acomodan y nada se mide dos veces.
class VeridiaRejilla extends StatelessWidget {
  const VeridiaRejilla({
    super.key,
    required this.hijos,
    this.anchoComodo = 260,
    this.espacio = VeridiaSpacing.lg,
    this.maximoColumnas = 4,
  });

  final List<Widget> hijos;

  /// Ancho por debajo del cual un elemento empieza a verse apretado.
  final double anchoComodo;

  final double espacio;

  /// Tope duro de columnas. Sin él, un monitor ultrapanorámico llega a poner
  /// seis o siete tarjetas en fila y la pantalla se lee como una hoja de
  /// cálculo, no como una app.
  final int maximoColumnas;

  /// Cuántas columnas caben en [disponible], contando los huecos entre ellas.
  ///
  /// Función aparte y no una línea dentro de `build` para poder probarla: los
  /// casos que importan son los bordes —un ancho justo por debajo de dos
  /// elementos, un ancho negativo durante un primer diseño— y esos no se ven
  /// mirando la pantalla, se ven en una prueba.
  ///
  /// Nunca devuelve menos de 1: cero columnas sería una división por cero al
  /// repartir el ancho.
  static int columnasPara({
    required double disponible,
    required double anchoComodo,
    required double espacio,
    required int maximoColumnas,
  }) {
    if (!disponible.isFinite || disponible <= 0) return 1;
    return ((disponible + espacio) / (anchoComodo + espacio)).floor().clamp(
      1,
      maximoColumnas < 1 ? 1 : maximoColumnas,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hijos.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final disponible = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final columnas = columnasPara(
          disponible: disponible,
          anchoComodo: anchoComodo,
          espacio: espacio,
          maximoColumnas: maximoColumnas,
        );

        // Se reparte el sobrante: los elementos crecen hasta llenar la fila en
        // vez de dejar un hueco muerto a la derecha.
        //
        // El suelo en 0 cubre el primer diseño de un padre que todavía no
        // tiene ancho: ahí la resta da negativo y un `SizedBox` de ancho
        // negativo revienta el diseño entero.
        final anchoElemento = ((disponible - espacio * (columnas - 1)) /
                columnas)
            .clamp(0.0, double.infinity);

        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final hijo in hijos)
              SizedBox(width: anchoElemento, child: hijo),
          ],
        );
      },
    );
  }
}

/// Fila que se convierte en columna cuando no hay sitio.
///
/// Es el patrón que faltaba en media docena de sitios donde un `Row` con tres
/// piezas desbordaba en pantallas estrechas —el panel de chips del mapa fue
/// el primero en dar la cara—. En vez de recortar con puntos suspensivos, las
/// piezas se apilan, que casi siempre es lo que el usuario preferiría.
class VeridiaFilaFlexible extends StatelessWidget {
  const VeridiaFilaFlexible({
    super.key,
    required this.hijos,
    this.espacio = VeridiaSpacing.md,
    this.anchoMinimo = 420,
    this.alineacion = CrossAxisAlignment.start,
  });

  final List<Widget> hijos;
  final double espacio;

  /// Por debajo de este ancho la fila se apila.
  final double anchoMinimo;

  final CrossAxisAlignment alineacion;

  @override
  Widget build(BuildContext context) {
    if (hijos.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final disponible = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (disponible < anchoMinimo) {
          return Column(
            crossAxisAlignment: alineacion,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < hijos.length; i++) ...[
                if (i > 0) SizedBox(height: espacio),
                hijos[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: alineacion,
          children: [
            for (var i = 0; i < hijos.length; i++) ...[
              if (i > 0) SizedBox(width: espacio),
              Expanded(child: hijos[i]),
            ],
          ],
        );
      },
    );
  }
}
