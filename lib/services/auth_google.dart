import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Entrada única al login con Google, para web y para móvil.
///
/// Devuelve `null` si la persona cerró la ventana de Google sin elegir cuenta
/// (no es un error: no hay que mostrarle ninguna alerta).
///
/// Lanza [TimeoutException] con el nombre del paso que se colgó, y
/// [FirebaseAuthException] con los códigos normales de Firebase Auth.
Future<UserCredential?> iniciarSesionConGoogle() async {
  if (kIsWeb) return _conPopupDeFirebase();
  return _conGoogleSignInNativo();
}

/// En web NO se usa el paquete google_sign_in.
///
/// Su botón (Google Identity Services) valida el "authorized JavaScript
/// origin" EXACTO, puerto incluido, y `flutter run -d chrome` levanta un
/// puerto distinto en cada arranque: había que forzar `--web-port 5000` a mano
/// o el login con Google simplemente no abría.
///
/// `signInWithPopup` no tiene ese problema porque el OAuth sale por
/// `https://<proyecto>.firebaseapp.com/__/auth/handler`: lo que Google autoriza
/// es ese dominio fijo, no el nuestro. Del lado de Firebase el permiso se
/// decide por DOMINIO (Authentication > Settings > Authorized domains), donde
/// `localhost` ya viene incluido de fábrica y el puerto no se mira. Resultado:
/// funciona en cualquier puerto, y también en v3ridia.web.app.
Future<UserCredential?> _conPopupDeFirebase() async {
  try {
    return await FirebaseAuth.instance.signInWithPopup(
      GoogleAuthProvider()..addScope('email'),
    );
  } on FirebaseAuthException catch (e) {
    // Cerrar la ventana de Google no es un fallo que haya que reportar.
    if (e.code == 'popup-closed-by-user' ||
        e.code == 'cancelled-popup-request' ||
        e.code == 'user-cancelled') {
      return null;
    }
    rethrow;
  }
}

/// En Android/iOS sí se usa el flujo nativo: abre el selector de cuentas del
/// sistema y canjea sus tokens por una credencial de Firebase.
///
/// Los timeouts existen porque este flujo puede quedarse colgado sin devolver
/// nada (Play Services sin responder, red a medias); el nombre del paso viaja
/// en la excepción para que la pantalla pueda decir dónde se trabó.
Future<UserCredential?> _conGoogleSignInNativo() async {
  final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
  if (googleUser == null) return null;

  final googleAuth = await googleUser.authentication.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw TimeoutException('authentication'),
  );

  if (googleAuth.idToken == null && googleAuth.accessToken == null) {
    throw FirebaseAuthException(
      code: 'missing-google-credentials',
      message: 'No se pudieron obtener las credenciales de Google.',
    );
  }

  return FirebaseAuth.instance
      .signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      )
      .timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('signInWithCredential'),
      );
}

/// Olvida la cuenta de Google elegida en este dispositivo.
///
/// En web no hay nada que limpiar: `signInWithPopup` no deja sesión nativa
/// aparte de la de Firebase, que el llamador cierra por su cuenta.
Future<void> cerrarSesionGoogle() async {
  if (kIsWeb) return;
  final googleSignIn = GoogleSignIn();
  if (await googleSignIn.isSignedIn()) {
    await googleSignIn.signOut();
  }
}
