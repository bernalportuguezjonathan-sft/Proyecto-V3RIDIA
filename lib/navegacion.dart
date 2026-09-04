import 'dart:async';
import 'package:flutter/material.dart';

import 'admin_home.dart';
import 'desafios.dart';
import 'historial.dart';
import 'home.dart';
import 'identify_species.dart';
import 'mapa.dart';
import 'perfil.dart';
import 'raiz.dart';
import 'services/marca_logros.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Secciones del explorador, en el mismo orden que [VeridiaBottomNav].
enum VeridiaSeccion { inicio, camara, mapa, diario, perfil }

/// Navegación unificada: evita repetir el switch de rutas en cada pantalla.
abstract final class VeridiaNav {
  /// Salta a una sección de la barra inferior.
  ///
  /// Usa `pushAndRemoveUntil` conservando la PRIMERA ruta, no
  /// `pushReplacement`. La diferencia es la causa del bug de cierre de sesión:
  /// [RaizVeridia] (el widget que escucha `authStateChanges` y decide entre
  /// bienvenida, home, panel admin o pantalla de baneado) vive en la primera
  /// ruta. Con `pushReplacement`, la primera vez que se tocaba la barra
  /// inferior desde Inicio esa ruta se REEMPLAZABA y la raíz quedaba fuera
  /// del árbol: al cerrar sesión ya no había nadie escuchando, la app se
  /// quedaba en la pantalla de turno sin sesión y con los listeners de
  /// Firestore muriendo con permission-denied.
  ///
  /// Conservando la primera ruta la pila nunca pasa de dos niveles y la raíz
  /// sobrevive a cualquier recorrido por la app.
  /// Las secciones de esta barra son del EXPLORADOR. Si quien navega es
  /// administrador se le devuelve a SU panel en vez de meterlo en la app del
  /// explorador.
  ///
  /// La barra ya no se le dibuja al administrador (ver [VeridiaBottomNav]),
  /// así que en condiciones normales esto no llega a dispararse. Está igual
  /// porque el daño de que se colara era grave: `pushAndRemoveUntil` conserva
  /// solo la primera ruta, así que un administrador que tocara una pestaña
  /// perdía el Panel de Administración de la pila y terminaba dentro de la
  /// sesión del explorador sin manera evidente de volver.
  static void ir(BuildContext context, VeridiaSeccion destino, int actual) {
    if (destino.index == actual) return;

    if (UserRepository.instance.esAdmin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (route) => route.isFirst,
      );
      return;
    }

    // Volver a INICIO se hace vaciando la pila, no apilando otro Inicio.
    //
    // La primera ruta es [RaizVeridia], que para un explorador YA dibuja
    // HomeScreen. Empujar aquí otro HomeScreen dejaba dos Inicios seguidos en
    // la pila: el de arriba salía con flecha de retroceso —porque tenía algo
    // debajo— y al pulsarla "volvías" de Inicio a Inicio, sin que pasara nada
    // visible. Vaciar hasta la raíz deja exactamente un Inicio y sin flecha,
    // que es lo que significa estar en el menú principal.
    if (destino == VeridiaSeccion.inicio) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    final Widget pantalla = switch (destino) {
      // Inalcanzable: `inicio` se resuelve arriba con popUntil. Se deja para
      // que el switch siga siendo exhaustivo sobre el enum.
      VeridiaSeccion.inicio => const HomeScreen(),
      VeridiaSeccion.camara => const IdentifySpeciesScreen(),
      VeridiaSeccion.mapa => const MapScreen(),
      VeridiaSeccion.diario => const HistoryScreen(),
      VeridiaSeccion.perfil => const ProfileScreen(),
    };

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: pantalla),
        transitionDuration: const Duration(milliseconds: 180),
      ),
      (route) => route.isFirst,
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
  /// Deja la pila con EXACTAMENTE una ruta —una [RaizVeridia] recién
  /// creada— y solo después llama a `signOut()`. Así:
  ///
  /// - No queda ninguna pantalla viva escuchando Firestore sin sesión, que
  ///   es lo que provocaba una lluvia de `permission-denied` y pantallas en
  ///   blanco al salir.
  /// - Funciona aunque la raíz original ya no estuviera en el árbol.
  /// - Es UNA sola operación del Navigator, no un `pop` seguido de un
  ///   rebuild: no hay carrera entre ambos (esa carrera congelaba la app si
  ///   se cerraba sesión antes de vaciar la pila).
  ///
  /// El orden —navegar y luego cerrar sesión— es a propósito: la raíz nueva
  /// muestra su pantalla de carga durante el instante que tarda `signOut()`,
  /// y en cuanto la sesión cae pinta la bienvenida.
  static Future<void> cerrarSesion(BuildContext context) async {
    final confirmado = await confirmarCerrarSesion(context);
    if (!confirmado || !context.mounted) return;

    unawaited(
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RaizVeridia()),
        (route) => false,
      ),
    );

    // Las marcas de logros son de ESTE aparato: si no se olvidan, quien
    // entre después en el mismo celular arrancaría con los máximos de la
    // persona anterior y vería logros que no ganó.
    MarcaLogros.instance.olvidar();
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
          VeridiaBotonTactil(
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: VeridiaColors.errorContainer,
                foregroundColor: VeridiaColors.onErrorContainer,
              ),
              child: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }
}
