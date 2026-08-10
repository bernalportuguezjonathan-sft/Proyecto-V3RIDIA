import 'package:flutter/material.dart';
import '../theme/veridia_theme.dart';

/// Fondo de la app: negro verdoso con dos halos de verde neón muy difusos.
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
          colors: [Color(0xFF15311A), VeridiaColors.background],
          stops: [0.0, 0.75],
        ),
      ),
      child: child,
    );
  }
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? VeridiaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? VeridiaColors.outlineVariant),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: VeridiaColors.secondary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
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
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
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
                color: VeridiaColors.surfaceContainerHigh,
                border: Border.all(
                  color: VeridiaColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, size: 36, color: VeridiaColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: text.bodySmall),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Píldora de Veridiums para el AppBar. Fondo dorado translúcido y borde:
/// legible sobre el fondo negro/verde (antes el icono se perdía).
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
          Text(
            '$tokens',
            style: const TextStyle(
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

/// Barra inferior de las 5 secciones del explorador.
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
    return Container(
      decoration: const BoxDecoration(
        color: VeridiaColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: VeridiaColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          height: 66,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt_rounded),
              label: 'Cámara',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Diario',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
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
      obscureText: obscure,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(VeridiaRadii.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: VeridiaColors.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(color ?? VeridiaColors.secondary),
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
