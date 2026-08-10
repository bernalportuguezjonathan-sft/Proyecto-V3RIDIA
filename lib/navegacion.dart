import 'package:flutter/material.dart';

import 'desafios.dart';
import 'historial.dart';
import 'home.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'perfil.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';

/// Secciones del explorador, en el mismo orden que [VeridiaBottomNav].
enum VeridiaSeccion { inicio, camara, mapa, diario, perfil }

/// Navegación unificada: evita repetir el switch de rutas en cada pantalla.
abstract final class VeridiaNav {
  /// Reemplaza la pantalla actual por la sección elegida.
  ///
  /// Usa `pushReplacement` en vez de `push` para que la pila no crezca sin
  /// límite al saltar entre secciones desde la barra inferior.
  static void ir(BuildContext context, VeridiaSeccion destino, int actual) {
    if (destino.index == actual) return;

    final Widget pantalla = switch (destino) {
      VeridiaSeccion.inicio => const HomeScreen(),
      VeridiaSeccion.camara => const IdentifySpeciesScreen(),
      VeridiaSeccion.mapa => const MapScreen(),
      VeridiaSeccion.diario => const HistoryScreen(),
      VeridiaSeccion.perfil => const ProfileScreen(),
    };

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: pantalla),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  /// Navega a una pantalla puntual apilándola sobre la actual.
  static Future<T?> abrir<T>(BuildContext context, Widget pantalla) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  static void irADesafios(BuildContext context) {
    abrir(context, const ChallengesScreen());
  }

  /// Pide confirmación y cierra sesión.
  ///
  /// El orden importa: primero se vacía la pila hasta la raíz y sólo después
  /// se llama a `signOut()`. La raíz es el `StreamBuilder` de
  /// `authStateChanges` en main.dart; si se cierra sesión primero, ese stream
  /// reconstruye la raíz mientras el Navigator todavía está haciendo pop de
  /// las rutas superiores y la app se congela.
  static Future<void> cerrarSesion(BuildContext context) async {
    final confirmado = await confirmarCerrarSesion(context);
    if (!confirmado || !context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    await UserRepository.instance.signOut();
  }

  /// Diálogo "¿Cerrar sesión?". Devuelve true si el usuario confirma.
  static Future<bool> confirmarCerrarSesion(BuildContext context) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          color: VeridiaColors.primary,
          size: 28,
        ),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a iniciar sesión para seguir explorando.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: VeridiaColors.errorContainer,
              foregroundColor: VeridiaColors.onErrorContainer,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }
}
