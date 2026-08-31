import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// De dónde sale la foto de perfil de alguien, resuelto en UN solo sitio.
///
/// Existe porque el carnet y el perfil la resolvían cada uno por su cuenta y
/// no miraban las mismas fuentes. Una foto de perfil puede llegar por tres
/// caminos distintos y ninguna pantalla los tenía todos:
///
///   1. Los bytes que la persona subió desde "Modificar perfil", guardados en
///      SharedPreferences (la única vía que el carnet sí miraba).
///   2. El `photoURL` del perfil de Firestore.
///   3. El `photoURL` de FirebaseAuth — el avatar de Google de quien entró
///      con Google, que NUNCA pasa por los otros dos.
///
/// El carnet solo miraba (1) y (2). Con una cuenta de Google cuyo documento de
/// Firestore no guardó `photoURL`, la foto vive solo en (3): la persona veía
/// su cara en el perfil y un muñeco gris en el carnet, que es exactamente lo
/// que pasaba. Tener las tres fuentes aquí hace que ninguna pantalla pueda
/// volver a saber menos que otra.
abstract final class FotoPerfil {
  static String claveCache(String uid) => 'profile_image_$uid';

  /// Los bytes que la persona subió y guardó. `null` si nunca subió ninguna.
  ///
  /// El uid sale de FirebaseAuth y no de `UserRepository.currentUser`, que se
  /// llena de forma asíncrona: leerlo en un `initState` devolvía null y la
  /// búsqueda se rendía antes de empezar.
  static Future<Uint8List?> bytesGuardados() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final codificada = prefs.getString(claveCache(uid));
      if (codificada == null || codificada.isEmpty) return null;
      return base64Decode(codificada);
    } catch (e) {
      debugPrint('FotoPerfil: no se pudo leer la foto guardada: $e');
      return null;
    }
  }

  /// La URL de respaldo cuando no hay bytes guardados: primero la del perfil
  /// de Firestore y, si ahí no hay, la de FirebaseAuth.
  ///
  /// Devuelve `null` —y no una cadena vacía— cuando no hay ninguna, para que
  /// quien la use pueda preguntar solo por null.
  static String? urlDeRespaldo(String? deFirestore) {
    final candidatas = [
      deFirestore,
      FirebaseAuth.instance.currentUser?.photoURL,
    ];
    for (final url in candidatas) {
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }
}
