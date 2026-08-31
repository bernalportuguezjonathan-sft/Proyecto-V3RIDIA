import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta "Deep Emerald" (Google Stitch — VitalClay). Material 3, modo
/// oscuro, headline Manrope / body Hanken Grotesk.
///
/// Sustituye a la "Eco-Esmeralda" anterior, que era verde OLIVA (fondo
/// #09160A, primario #A1D494 salvia): la escala nueva es esmeralda profundo
/// —fondo #022C22, primario jade #10B981— con más saturación y más contraste
/// entre niveles, que es lo que hace legible el relieve "clay" de
/// veridia_ui.dart. Los nombres de los tokens no cambian, así que las ~60
/// pantallas que ya leen de aquí se retiñen solas.
abstract final class VeridiaColors {
  static const background = Color(0xFF022C22);
  static const surface = Color(0xFF022C22);
  static const surfaceDim = Color(0xFF011E17);
  static const surfaceBright = Color(0xFF0A5741);
  static const surfaceContainerLowest = Color(0xFF011A14);
  static const surfaceContainerLow = Color(0xFF04352A);

  /// Base de las tarjetas "clay" (emerald-900 de la referencia).
  static const surfaceContainer = Color(0xFF064E3B);
  static const surfaceContainerHigh = Color(0xFF065F46);
  static const surfaceContainerHighest = Color(0xFF047857);
  static const surfaceVariant = Color(0xFF065F46);

  static const onSurface = Color(0xFFE4FFF4);
  static const onSurfaceVariant = Color(0xFF8BD6B7);
  static const outline = Color(0xFF5E9E86);
  static const outlineVariant = Color(0xFF14503E);

  /// Jade vibrante: el acento principal de la referencia (`vibrant-jade`).
  static const primary = Color(0xFF10B981);
  static const onPrimary = Color(0xFF012A20);
  static const primaryContainer = Color(0xFF065F46);
  static const onPrimaryContainer = Color(0xFFA6F2D1);
  static const inversePrimary = Color(0xFF047857);

  /// Menta neón de acento: usada en brillos, progreso y datos destacados.
  static const secondary = Color(0xFF6FFBBE);
  static const onSecondary = Color(0xFF00281B);
  static const secondaryContainer = Color(0xFF047857);
  static const onSecondaryContainer = Color(0xFFD6FFEE);

  static const tertiary = Color(0xFFA6F2D1);
  static const onTertiary = Color(0xFF013A2A);
  static const tertiaryContainer = Color(0xFF0A5741);
  static const onTertiaryContainer = Color(0xFF97D4B4);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  static const inverseSurface = Color(0xFFDCFCE9);
  static const inverseOnSurface = Color(0xFF0B3B2C);

  /// Dorado de los Veridiums (moneda). Alto contraste sobre fondo oscuro.
  static const veridium = Color(0xFFFFD166);

  /// Verde del relleno de los botones sólidos de la referencia
  /// (`clay-button`, emerald-600). Un paso por debajo de [primary]: deja que
  /// el jade siga siendo lo más brillante de la pantalla.
  static const jadeProfundo = Color(0xFF059669);

  /// Luz que "rebota" en el cuarto superior izquierdo de cada pieza clay.
  /// Es blanco puro a muy baja opacidad: no es un color nuevo de la paleta,
  /// es el reflejo especular del relieve.
  static const brilloClay = Color(0x1AFFFFFF);
}

abstract final class VeridiaFonts {
  static const headline = 'Manrope';
  static const body = 'HankenGrotesk';
}

/// Estilo del mapa, centralizado para que todas las pantallas que dibujan
/// un mapa se vean igual.
abstract final class VeridiaMapa {
  /// Base cartográfica legible: conserva nombres de calles, parques y
  /// cuerpos de agua.
  ///
  /// Antes usaba la base "Voyager" de CARTO (`basemaps.cartocdn.com`), que
  /// dejó de servir teselas gratis sin cuenta propia y empezó a devolver un
  /// mosaico con el texto "API KEY REQUIRED" en vez del mapa. Los tiles
  /// oficiales de OpenStreetMap no piden clave, pero solo existen en una
  /// resolución (256 px, sin variante @2x): de ahí que `retinaMode` esté
  /// apagado donde se usa esta URL.
  static const urlTeselas = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const atribucion = '© OpenStreetMap';

  /// Conserva los colores PROPIOS de OpenStreetMap y solo les quita el brillo.
  ///
  /// Las dos versiones anteriores de esta matriz teñían el mapa entero a un
  /// solo color —primero menta, después pizarra— para que casara con la
  /// paleta de la app. Las dos estaban mal por la misma razón: en un mapa el
  /// color ES información. El verde dice parque, el azul dice agua, el blanco
  /// dice calle. Aplastar los tres a un mismo tono deja un plano bonito y
  /// mudo, que se ve peor cuanto más se mira, y encima no se parece a ningún
  /// mapa que alguien haya usado nunca.
  ///
  /// Así que aquí no hay tinte de color, solo una calma: desatura apenas al
  /// 88%, baja el brillo un 10% y resta 8 a cada canal. Eso basta para que el
  /// blanco del papel caiga a (222, 222, 222) y no deslumbre junto a una
  /// interfaz oscura, mientras un parque sigue llegando verde a (174, 198,
  /// 174) y el agua sigue llegando azul a (149, 180, 204). El mapa se lee
  /// como un mapa; lo que lo ata a la app son los marcadores de abajo, que
  /// para eso son lo único saturado en pantalla.
  static const tinte = ColorFilter.matrix(<double>[
    0.81496, 0.07724, 0.00779, 0, -8, //
    0.02296, 0.86924, 0.00779, 0, -8, //
    0.02296, 0.07724, 0.79979, 0, -8, //
    0, 0, 0, 1, 0, //
  ]);

  /// Los cuatro tipos de marcador del mapa, cada uno con un tono propio.
  ///
  /// Antes cada capa elegía su color por su cuenta y dos de ellas cayeron casi
  /// en el mismo naranja quemado, así que "una zona" y "una foto mía" se
  /// distinguían solo por el ícono de dentro —a 20 px, por nada—. Sobre la
  /// base pizarra estos cuatro se separan de un vistazo.
  ///
  /// [zona] va en ÁMBAR porque es el complementario del pizarra: es el tono
  /// que más salta de ese fondo, y las zonas son el contenido principal del
  /// mapa. El mismo ámbar marca el punto en la lista de zonas, para que la
  /// ficha de abajo y el pin de arriba se lean como la misma cosa.
  static const zona = Color(0xFFFFB020);
  static const avistamiento = Color(0xFF10B981);
  static const lugarBuscado = Color(0xFFFF6B4A);
  static const tuPosicion = Color(0xFF2563EB);

  /// Aplica [tinte] a cada tesela. Se pasa a `TileLayer.tileBuilder`.
  static Widget teselaTenida(BuildContext context, Widget tesela, Object _) =>
      ColorFiltered(colorFilter: tinte, child: tesela);
}

/// Radios de la referencia "clay": redondeos MÁS generosos que los de antes
/// (8/12/16/24). Una pieza con relieve necesita esquinas amplias para leerse
/// como algo moldeado; con 12px el mismo relieve parece un rectángulo con
/// sombra pegada.
abstract final class VeridiaRadii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

const _colorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: VeridiaColors.primary,
  onPrimary: VeridiaColors.onPrimary,
  primaryContainer: VeridiaColors.primaryContainer,
  onPrimaryContainer: VeridiaColors.onPrimaryContainer,
  inversePrimary: VeridiaColors.inversePrimary,
  secondary: VeridiaColors.secondary,
  onSecondary: VeridiaColors.onSecondary,
  secondaryContainer: VeridiaColors.secondaryContainer,
  onSecondaryContainer: VeridiaColors.onSecondaryContainer,
  tertiary: VeridiaColors.tertiary,
  onTertiary: VeridiaColors.onTertiary,
  tertiaryContainer: VeridiaColors.tertiaryContainer,
  onTertiaryContainer: VeridiaColors.onTertiaryContainer,
  error: VeridiaColors.error,
  onError: VeridiaColors.onError,
  errorContainer: VeridiaColors.errorContainer,
  onErrorContainer: VeridiaColors.onErrorContainer,
  surface: VeridiaColors.surface,
  onSurface: VeridiaColors.onSurface,
  surfaceDim: VeridiaColors.surfaceDim,
  surfaceBright: VeridiaColors.surfaceBright,
  surfaceContainerLowest: VeridiaColors.surfaceContainerLowest,
  surfaceContainerLow: VeridiaColors.surfaceContainerLow,
  surfaceContainer: VeridiaColors.surfaceContainer,
  surfaceContainerHigh: VeridiaColors.surfaceContainerHigh,
  surfaceContainerHighest: VeridiaColors.surfaceContainerHighest,
  onSurfaceVariant: VeridiaColors.onSurfaceVariant,
  outline: VeridiaColors.outline,
  outlineVariant: VeridiaColors.outlineVariant,
  inverseSurface: VeridiaColors.inverseSurface,
  onInverseSurface: VeridiaColors.inverseOnSurface,
  surfaceTint: VeridiaColors.primary,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

TextTheme _buildTextTheme() {
  const display = TextStyle(
    fontFamily: VeridiaFonts.headline,
    color: VeridiaColors.onSurface,
  );
  const body = TextStyle(
    fontFamily: VeridiaFonts.body,
    color: VeridiaColors.onSurface,
  );

  // Interletrado NEGATIVO en los tamaños grandes, como en la referencia
  // (-0.04em en display, -0.02em en headline). A 44px el espaciado por
  // defecto deja los titulares sueltos; apretarlos los compacta en un bloque
  // y es la mitad de lo que hace que un número grande se lea "de tablero".
  return TextTheme(
    displayLarge: display.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.76,
    ),
    displayMedium: display.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.44,
    ),
    displaySmall: display.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
    ),
    headlineLarge: display.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
    ),
    headlineMedium: display.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineSmall: display.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: display.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: display.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: display.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: body.copyWith(fontSize: 16, height: 1.45),
    bodyMedium: body.copyWith(fontSize: 14, height: 1.45),
    bodySmall: body.copyWith(
      fontSize: 12,
      height: 1.4,
      color: VeridiaColors.onSurfaceVariant,
    ),
    labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: body.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: VeridiaColors.onSurfaceVariant,
    ),
  );
}

/// Etiqueta en VERSALES espaciadas (`label-caps` de la referencia: 12px,
/// +0.1em, bold). Es el rótulo pequeño que acompaña a un número grande —
/// "PASOS", "RACHA"— y se separa de él justamente por el espaciado.
///
/// No entra en el [TextTheme] porque Material no tiene una ranura para este
/// papel: `labelSmall` ya está ocupado por los rótulos normales de la barra
/// inferior y de las métricas, que NO van en versales.
const veridiaLabelCaps = TextStyle(
  fontFamily: VeridiaFonts.body,
  fontSize: 12,
  height: 1.33,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: VeridiaColors.onSurfaceVariant,
);

ThemeData buildVeridiaTheme() {
  final textTheme = _buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: VeridiaColors.background,
    canvasColor: VeridiaColors.background,
    fontFamily: VeridiaFonts.body,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      backgroundColor: VeridiaColors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      foregroundColor: VeridiaColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      // Alto contraste para los iconos de acción (Veridiums / cerrar sesión).
      iconTheme: const IconThemeData(color: VeridiaColors.onSurface, size: 24),
      actionsIconTheme: const IconThemeData(
        color: VeridiaColors.primary,
        size: 24,
      ),
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Filo jade al pie de la barra: la separa del contenido sin recurrir a
      // una sombra. Es el `border-b border-vibrant-jade/10` de la referencia,
      // y aquí hace falta porque la barra y el fondo son ahora dos verdes muy
      // cercanos (#04352A sobre #022C22) y sin línea se fundían.
      shape: Border(
        bottom: BorderSide(
          color: VeridiaColors.primary.withValues(alpha: 0.18),
        ),
      ),
    ),

    cardTheme: CardThemeData(
      color: VeridiaColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.lg),
        // Jade al 20%, el mismo contorno que la referencia le pone a cada
        // pieza clay. El `outlineVariant` gris de antes desaparecía contra
        // el fondo y dejaba la tarjeta sin canto visible.
        side: BorderSide(color: VeridiaColors.primary.withValues(alpha: 0.20)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: VeridiaColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    iconTheme: const IconThemeData(color: VeridiaColors.onSurfaceVariant),

    listTileTheme: ListTileThemeData(
      iconColor: VeridiaColors.primary,
      textColor: VeridiaColors.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // Más OSCURO que la tarjeta que lo contiene, no más claro: en la
      // referencia un campo es un `clay-inset`, un hueco excavado en la
      // pieza. El relleno claro de antes lo hacía sobresalir, que es lo
      // contrario de lo que debe comunicar un sitio donde se escribe.
      fillColor: VeridiaColors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: VeridiaColors.onSurfaceVariant,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: VeridiaColors.onSurfaceVariant,
      ),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: VeridiaColors.primary,
      ),
      prefixIconColor: VeridiaColors.primary,
      suffixIconColor: VeridiaColors.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        borderSide: const BorderSide(color: VeridiaColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        borderSide: const BorderSide(color: VeridiaColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        borderSide: const BorderSide(color: VeridiaColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        borderSide: const BorderSide(color: VeridiaColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        borderSide: const BorderSide(color: VeridiaColors.error, width: 1.6),
      ),
    ),

    // Los tres tipos de botón van en PÍLDORA (`clay-button` de la
    // referencia: `border-radius: 9999px`). Antes eran rectángulos de 12px
    // de radio; la píldora es lo que separa visualmente un botón —algo que
    // se pulsa— de una tarjeta, ahora que ambos comparten el mismo relieve.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VeridiaColors.primary,
        foregroundColor: VeridiaColors.onPrimary,
        disabledBackgroundColor: VeridiaColors.surfaceContainerHigh,
        disabledForegroundColor: VeridiaColors.onSurfaceVariant,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.headline,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VeridiaColors.primary,
        foregroundColor: VeridiaColors.onPrimary,
        disabledBackgroundColor: VeridiaColors.surfaceContainerHigh,
        disabledForegroundColor: VeridiaColors.onSurfaceVariant,
        minimumSize: const Size(0, 50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.headline,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VeridiaColors.primary,
        minimumSize: const Size(0, 50),
        // Verde y de 1.6 en vez del gris `outline` de 1: el contorno es lo
        // único que dibuja a un botón sin relleno, y en gris se perdía contra
        // el fondo oscuro en vez de leerse como algo que se puede pulsar.
        side: const BorderSide(color: VeridiaColors.primary, width: 1.6),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.headline,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VeridiaColors.primary,
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: VeridiaColors.primary,
      foregroundColor: VeridiaColors.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: VeridiaColors.surfaceContainerHigh,
      selectedColor: VeridiaColors.primaryContainer,
      side: BorderSide(color: VeridiaColors.primary.withValues(alpha: 0.22)),
      labelStyle: textTheme.labelMedium!,
      secondaryLabelStyle: textTheme.labelMedium!,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: VeridiaColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.xl),
        side: BorderSide(color: VeridiaColors.primary.withValues(alpha: 0.22)),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: VeridiaColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: VeridiaColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VeridiaRadii.xl),
        ),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: VeridiaColors.surfaceContainerLow,
      selectedItemColor: VeridiaColors.primary,
      unselectedItemColor: VeridiaColors.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: textTheme.labelSmall?.copyWith(
        color: VeridiaColors.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: textTheme.labelSmall,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VeridiaColors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      // Jade translúcido, no el verde sólido `primaryContainer`: en la
      // referencia la pestaña activa es un halo detrás del ícono, no una
      // pastilla opaca que compite con él.
      indicatorColor: VeridiaColors.primary.withValues(alpha: 0.20),
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? textTheme.labelSmall!.copyWith(
                color: VeridiaColors.primary,
                fontWeight: FontWeight.w700,
              )
            : textTheme.labelSmall!,
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? VeridiaColors.primary
              : VeridiaColors.onSurfaceVariant,
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: VeridiaColors.surfaceContainerHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: VeridiaColors.onSurface,
      ),
      actionTextColor: VeridiaColors.secondary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        side: BorderSide(color: VeridiaColors.primary.withValues(alpha: 0.28)),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: VeridiaColors.primary,
      // El carril va OSCURO (era `surfaceContainerHighest`, casi tan claro
      // como el relleno): así la barra llena se lee como luz dentro de un
      // canal excavado, que es el gesto de la referencia.
      linearTrackColor: VeridiaColors.surfaceContainerLowest,
      circularTrackColor: Colors.transparent,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? VeridiaColors.onPrimary
            : VeridiaColors.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? VeridiaColors.primary
            : VeridiaColors.surfaceContainerHighest,
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: VeridiaColors.primary,
      unselectedLabelColor: VeridiaColors.onSurfaceVariant,
      indicatorColor: VeridiaColors.primary,
      dividerColor: VeridiaColors.outlineVariant,
      labelStyle: textTheme.titleSmall,
      unselectedLabelStyle: textTheme.titleSmall,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: VeridiaColors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        side: BorderSide(color: VeridiaColors.primary.withValues(alpha: 0.22)),
      ),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyMedium,
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(
          VeridiaColors.surfaceContainerHigh,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VeridiaRadii.md),
          ),
        ),
      ),
    ),
  );
}

/// Fecha corta con ceros a la izquierda: 05/08/2026, no 5/8/2026.
///
/// Estaba escrita a mano en una decena de pantallas y cada una la formateaba
/// distinto. Aquí también se normaliza a hora local: las fechas se guardan en
/// UTC (ver [aIsoUtc]) y pintarlas sin convertir corría el día en Colombia.
String formatoFecha(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year}';
}

/// Fecha y hora cortas: 05/08/2026 14:30.
String formatoFechaHora(DateTime fecha) {
  final local = fecha.toLocal();
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '${formatoFecha(local)} $hora:$minuto';
}

/// Serializa una fecha para Firestore SIEMPRE en UTC.
///
/// `DateTime.now().toIso8601String()` escribe la hora local sin indicar la
/// zona horaria. Como Firestore ordena esos campos como texto, dos
/// dispositivos en zonas distintas producían un orden cronológico falso.
String aIsoUtc(DateTime fecha) => fecha.toUtc().toIso8601String();

/// Lee una fecha de Firestore y la devuelve en hora local.
///
/// Tolera los dos formatos que conviven en la base: el UTC nuevo (con `Z`) y
/// el local antiguo sin zona horaria.
DateTime? deIso(String? texto) => DateTime.tryParse(texto ?? '')?.toLocal();
