import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta "Eco-Esmeralda" (Google Stitch — Veridia Biodiversity Explorer).
/// Material 3, modo oscuro, headline Manrope / body Hanken Grotesk.
abstract final class VeridiaColors {
  static const background = Color(0xFF09160A);
  static const surface = Color(0xFF09160A);
  static const surfaceDim = Color(0xFF09160A);
  static const surfaceBright = Color(0xFF2F3D2E);
  static const surfaceContainerLowest = Color(0xFF051106);
  static const surfaceContainerLow = Color(0xFF121F12);
  static const surfaceContainer = Color(0xFF162315);
  static const surfaceContainerHigh = Color(0xFF202D1F);
  static const surfaceContainerHighest = Color(0xFF2B382A);
  static const surfaceVariant = Color(0xFF2B382A);

  static const onSurface = Color(0xFFD7E7D2);
  static const onSurfaceVariant = Color(0xFFC2C9BB);
  static const outline = Color(0xFF8C9387);
  static const outlineVariant = Color(0xFF42493E);

  static const primary = Color(0xFFA1D494);
  static const onPrimary = Color(0xFF0A3909);
  static const primaryContainer = Color(0xFF2D5A27);
  static const onPrimaryContainer = Color(0xFF9DD090);
  static const inversePrimary = Color(0xFF3B6934);

  /// Verde neón de acento: usado en brillos, progreso y datos destacados.
  static const secondary = Color(0xFF9FD75B);
  static const onSecondary = Color(0xFF1F3700);
  static const secondaryContainer = Color(0xFF4C7C00);
  static const onSecondaryContainer = Color(0xFFDFFFB5);

  static const tertiary = Color(0xFFBCCABC);
  static const onTertiary = Color(0xFF27332A);
  static const tertiaryContainer = Color(0xFF465348);
  static const onTertiaryContainer = Color(0xFFB7C6B8);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  static const inverseSurface = Color(0xFFD7E7D2);
  static const inverseOnSurface = Color(0xFF263425);

  /// Dorado de los Veridiums (moneda). Alto contraste sobre fondo oscuro.
  static const veridium = Color(0xFFFFD166);
}

abstract final class VeridiaFonts {
  static const headline = 'Manrope';
  static const body = 'HankenGrotesk';
}

/// Estilo del mapa, centralizado para que todas las pantallas que dibujan
/// un mapa se vean igual.
abstract final class VeridiaMapa {
  /// Base cartográfica legible (CartoDB Voyager): conserva nombres de calles,
  /// parques y cuerpos de agua. Sustituye a la base `dark_all`, que dejaba
  /// las etiquetas casi invisibles sobre el fondo oscuro de la app.
  static const urlTeselas =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

  static const atribucion = '© OpenStreetMap, © CARTO';

  /// Baja la saturación de la base clara, la oscurece un poco y la inclina
  /// hacia el verde de la paleta. El resultado es un mapa en tono medio:
  /// se leen calles y lugares, pero no desentona con el resto de la app.
  static const tinte = ColorFilter.matrix(<double>[
    0.7414, 0.1259, 0.0127, 0, -8, //
    0.0383, 0.8487, 0.0130, 0, 2, //
    0.0357, 0.1202, 0.6841, 0, -10, //
    0, 0, 0, 1, 0, //
  ]);

  /// Aplica [tinte] a cada tesela. Se pasa a `TileLayer.tileBuilder`.
  static Widget teselaTenida(
    BuildContext context,
    Widget tesela,
    Object _,
  ) => ColorFiltered(colorFilter: tinte, child: tesela);
}

abstract final class VeridiaRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
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

  return TextTheme(
    displayLarge: display.copyWith(fontSize: 44, fontWeight: FontWeight.w800),
    displayMedium: display.copyWith(fontSize: 36, fontWeight: FontWeight.w800),
    displaySmall: display.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
    headlineLarge: display.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
    headlineMedium: display.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
    headlineSmall: display.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
    titleLarge: display.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
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
    ),

    cardTheme: CardThemeData(
      color: VeridiaColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.lg),
        side: const BorderSide(color: VeridiaColors.outlineVariant),
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
      fillColor: VeridiaColors.surfaceContainerHigh,
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

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VeridiaColors.primary,
        foregroundColor: VeridiaColors.onPrimary,
        disabledBackgroundColor: VeridiaColors.surfaceContainerHighest,
        disabledForegroundColor: VeridiaColors.onSurfaceVariant,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VeridiaRadii.md),
        ),
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.headline,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VeridiaColors.primary,
        foregroundColor: VeridiaColors.onPrimary,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VeridiaRadii.md),
        ),
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.headline,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VeridiaColors.primary,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: VeridiaColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VeridiaRadii.md),
        ),
        textStyle: const TextStyle(
          fontFamily: VeridiaFonts.headline,
          fontSize: 15,
          fontWeight: FontWeight.w600,
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
      side: const BorderSide(color: VeridiaColors.outlineVariant),
      labelStyle: textTheme.labelMedium!,
      secondaryLabelStyle: textTheme.labelMedium!,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: VeridiaColors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.xl),
        side: const BorderSide(color: VeridiaColors.outlineVariant),
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
      indicatorColor: VeridiaColors.primaryContainer,
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
              ? VeridiaColors.onPrimaryContainer
              : VeridiaColors.onSurfaceVariant,
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: VeridiaColors.surfaceContainerHighest,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: VeridiaColors.onSurface,
      ),
      actionTextColor: VeridiaColors.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VeridiaRadii.md),
        side: const BorderSide(color: VeridiaColors.outlineVariant),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: VeridiaColors.primary,
      linearTrackColor: VeridiaColors.surfaceContainerHighest,
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
        side: const BorderSide(color: VeridiaColors.outlineVariant),
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
