import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'auth_google.dart';
import 'economia.dart';

import '../theme/veridia_theme.dart';

/// El rol de administrador, escrito UNA vez.
///
/// Estaba repetido como el literal 'Administrador' en una decena de sitios
/// (navegación, mapa, desafíos, moderación...). Con la cadena suelta, olvidar
/// la comprobación en un sitio nuevo no da ningún error: simplemente esa
/// pantalla trata al administrador como explorador, que es exactamente lo que
/// pasó con la barra inferior del mapa.
const String rolAdministrador = 'Administrador';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  late ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(
    null,
  );

  /// Si quien tiene la sesión abierta es administrador.
  ///
  /// Es solo para decidir QUÉ SE MUESTRA. Lo que de verdad protege los datos
  /// son las reglas de Firestore (`isAdmin()`), que se evalúan en el servidor
  /// y no dependen de lo que diga el cliente.
  bool get esAdmin => currentUser.value?.role == rolAdministrador;

  UserProfile _perfilDesdeDoc(String id, Map<String, dynamic> data) {
    final createdDate = data['createdDate'] is String
        ? DateTime.tryParse(data['createdDate'] as String)
        : DateTime.now();
    final banExpiresValue = data['banExpires'];
    final banExpires = banExpiresValue is String
        ? DateTime.tryParse(banExpiresValue)
        : banExpiresValue is Timestamp
        ? banExpiresValue.toDate()
        : null;
    final tokens = data['tokens'] as int? ?? 0;
    return UserProfile(
      userId: id,
      email: data['email'] as String? ?? '',
      displayName:
          data['displayName'] as String? ??
          (data['email'] as String? ?? '').split('@').first,
      photoURL: data['photoURL'] as String?,
      tokens: tokens,
      tokensTotales: leerTokensTotales(data, tokens),
      role: data['role'] as String? ?? 'Explorador',
      createdDate: createdDate ?? DateTime.now(),
      isBanned: data['isBanned'] as bool? ?? false,
      mascotaActiva: data['mascotaActiva'] as String?,
      accesorios: leerAccesorios(data),
      banExpires: banExpires,
      banReason: data['banReason'] as String?,
    );
  }

  Future<List<UserProfile>> fetchAllUsers({String? role}) async {
    try {
      final query = await _firestore.collection('users').get();
      final users = query.docs
          .map((doc) => _perfilDesdeDoc(doc.id, doc.data()))
          .where((user) => role == null || user.role == role)
          .toList();
      users.sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    } catch (e) {
      debugPrint('UserRepository.fetchAllUsers error: $e');
      return [];
    }
  }

  /// Usuarios en vivo. A diferencia de [fetchAllUsers] no se traga los
  /// errores: el widget recibe el fallo y puede mostrarlo en pantalla.
  ///
  /// `porVeridiums` ordena el ranking; si no, alfabético.
  ///
  /// El ranking usa el ACUMULADO (`tokensTotales`), no el saldo. Ordenar por
  /// saldo castigaba gastar: quien compraba una mascota de 110 Veridiums caía
  /// en la tabla y aprendía a no volver a la tienda.
  Stream<List<UserProfile>> streamAllUsers({
    String? role,
    bool porVeridiums = false,
  }) {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => _perfilDesdeDoc(doc.id, doc.data()))
          .where((user) => role == null || user.role == role)
          .toList();
      if (porVeridiums) {
        users.sort((a, b) {
          final porTokens = b.tokensTotales.compareTo(a.tokensTotales);
          return porTokens != 0
              ? porTokens
              : a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                );
        });
      } else {
        users.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
      }
      return users;
    });
  }

  Future<void> signOut() async {
    try {
      await cerrarSesionGoogle();
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }
    await FirebaseAuth.instance.signOut();
    currentUser.value = null;
  }

  Future<void> initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}

      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null) {
        Map<String, dynamic>? data;
        var lecturaOk = false;
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(refreshedUser.uid)
              .get();
          data = userDoc.data();
          lecturaOk = true;
        } catch (e) {
          debugPrint('Firestore user read error for ${refreshedUser.uid}: $e');
        }

        final cachedTokens = await _getCachedTokens(refreshedUser.uid);
        final cachedRole = await _getCachedRole(refreshedUser.uid);
        final cachedDisplayName = await _getCachedDisplayName(
          refreshedUser.uid,
        );

        // Autorreparación: el usuario ya existe en Firebase Auth (inició
        // sesión bien) pero nunca quedó su documento en Firestore — por
        // ejemplo, un fallo de red al registrarse. Sin ese documento el
        // Panel Admin (Moderación, Ranking) nunca lo ve, aunque la persona
        // siga usando la app con datos solo en caché local. Se crea aquí,
        // siempre como Explorador: un rol en caché nunca es prueba
        // suficiente para crear un Administrador (eso exige el código real,
        // ver firestore.rules → isAdminCodeValid).
        if (lecturaOk && data == null) {
          final nombreParaCrear = cachedDisplayName.isNotEmpty
              ? cachedDisplayName
              : (refreshedUser.displayName ??
                    refreshedUser.email?.split('@').first ??
                    'Usuario');
          try {
            await createUserProfile(
              userId: refreshedUser.uid,
              email: refreshedUser.email ?? '',
              displayName: nombreParaCrear,
              role: 'Explorador',
            );
            if (cachedTokens > 0) {
              await _firestore
                  .collection('users')
                  .doc(refreshedUser.uid)
                  .update({'tokens': cachedTokens});
            }
            data = {
              'email': refreshedUser.email ?? '',
              'displayName': nombreParaCrear,
              'role': 'Explorador',
              'tokens': cachedTokens,
              'isBanned': false,
            };
          } catch (e) {
            debugPrint(
              'No se pudo autorreparar el perfil de ${refreshedUser.uid}: $e',
            );
          }
        }

        // Cuentas de administrador creadas antes de que se dejara de guardar
        // el código: se limpia al entrar, sin bloquear el arranque.
        if (data != null && data['adminCode'] != null) {
          unawaited(_borrarCodigoAdmin(refreshedUser.uid));
        }

        final currentTokens = data != null
            ? (data['tokens'] as int? ?? cachedTokens)
            : cachedTokens;
        final currentRole = data != null
            ? (data['role'] as String? ?? cachedRole)
            : (cachedRole.isNotEmpty ? cachedRole : 'Explorador');
        final displayName = data != null && data['displayName'] != null
            ? data['displayName'] as String
            : (cachedDisplayName.isNotEmpty
                  ? cachedDisplayName
                  : (refreshedUser.displayName ??
                        refreshedUser.email?.split('@').first ??
                        'Usuario'));
        final currentCreatedDate = data != null && data['createdDate'] != null
            ? DateTime.tryParse(data['createdDate'] as String) ?? DateTime.now()
            : DateTime.now();
        var currentIsBanned = data != null
            ? (data['isBanned'] as bool? ?? false)
            : false;
        final banExpiresValue = data != null ? data['banExpires'] : null;
        final banExpires = banExpiresValue is String
            ? DateTime.tryParse(banExpiresValue)
            : banExpiresValue is Timestamp
            ? banExpiresValue.toDate()
            : null;
        var banReason = data != null ? data['banReason'] as String? : null;

        // Suspensión temporal ya cumplida: se levanta al entrar. Si Firestore
        // la rechaza no debe tumbar todo initializeUser() y dejar al usuario
        // sin perfil cargado: se queda suspendido y un admin puede levantarla.
        if (currentIsBanned &&
            banExpires != null &&
            banExpires.isBefore(DateTime.now()) &&
            await intentarLevantarSuspension(refreshedUser.uid)) {
          currentIsBanned = false;
          banReason = null;
        }

        final resolvedDisplayName = displayName.isNotEmpty
            ? displayName
            : refreshedUser.displayName ??
                  refreshedUser.email?.split('@').first ??
                  'Usuario';

        currentUser.value = UserProfile(
          userId: refreshedUser.uid,
          email: refreshedUser.email ?? '',
          displayName: resolvedDisplayName,
          photoURL: refreshedUser.photoURL,
          tokens: currentTokens,
          tokensTotales: leerTokensTotales(data, currentTokens),
          role: currentRole,
          createdDate: currentCreatedDate,
          isBanned: currentIsBanned,
          mascotaActiva: data?['mascotaActiva'] as String?,
          accesorios: leerAccesorios(data),
          banExpires: banExpires,
          banReason: banReason,
        );
      } else {
        currentUser.value = null;
      }
    } else {
      currentUser.value = null;
    }
  }

  /// Crea el perfil del usuario en Firestore.
  ///
  /// Si `role` es 'Administrador', `adminCode` viaja en el documento para que
  /// la regla de seguridad lo compare contra `config/secrets` (que ningún
  /// cliente puede leer). Si no coincide, Firestore rechaza la escritura con
  /// `permission-denied` y NO se guarda el perfil como admin.
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String displayName,
    required String role,
    String? adminCode,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'displayName': displayName,
      'role': role,
      'tokens': 0,
      'tokensTotales': 0,
      // Nadie empieza sin compañero: la rana viene con la cuenta y es lo que
      // hace que la mascota se entienda el primer día, no al llegar a un
      // nivel. Ver `mascotaInicial` en models/mascota.dart.
      'mascotaActiva': MascotaId.rana.name,
      'accesorios': <String, String>{},
      'createdDate': aIsoUtc(now),
      'photoURL': null,
      'isBanned': false,
      'banExpires': null,
      'banReason': null,
      // El código va SOLO en la escritura de creación: firestore.rules lo
      // compara contra config/secrets con `request.resource.data.adminCode`.
      // Se borra justo después para no dejarlo guardado (ver _borrarCodigoAdmin).
      if (role == 'Administrador') 'adminCode': adminCode,
    });
    if (role == 'Administrador') {
      await _borrarCodigoAdmin(userId);
    }
    await _cacheUserProfile(userId, 0, role, displayName);
  }

  /// Quita el `adminCode` del documento del usuario.
  ///
  /// Las reglas necesitan el campo en el momento de crear el perfil, pero
  /// dejarlo ahí significa guardar el secreto compartido de los
  /// administradores en texto plano tantas veces como administradores haya.
  /// Cualquiera con acceso a uno de esos documentos podría crear más
  /// administradores. Aquí se borra en cuanto ha cumplido su función.
  Future<void> _borrarCodigoAdmin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'adminCode': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('No se pudo borrar el adminCode de $userId: $e');
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required String displayName,
    String? photoURL,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'displayName': displayName,
        'photoURL': photoURL,
      });
    } catch (e) {
      debugPrint('Warning: failed to update profile in Firestore: $e');
    }
  }

  Future<void> banUser({
    required String userId,
    required bool isPermanent,
    required int days,
    required String reason,
  }) async {
    final banExpires = isPermanent
        ? null
        : DateTime.now().add(Duration(days: days));

    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banExpires': banExpires,
      'banReason': reason,
    });
  }

  Future<void> unbanUser({required String userId}) async {
    await _firestore.collection('users').doc(userId).update({
      'isBanned': false,
      'banExpires': null,
      'banReason': null,
    });
  }

  /// Levanta una suspensión temporal ya cumplida.
  ///
  /// Devuelve true solo si el servidor aceptó el cambio. Si lo rechaza, el
  /// usuario sigue suspendido de verdad y quien llama no debe dejarlo entrar:
  /// el estado de Firestore manda, no el que la app calculó en memoria.
  Future<bool> intentarLevantarSuspension(String userId) async {
    try {
      await unbanUser(userId: userId);
      return true;
    } catch (e) {
      debugPrint('No se pudo levantar la suspensión vencida: $e');
      return false;
    }
  }

  /// Borra el perfil de Firestore (solo administradores, ver firestore.rules).
  ///
  /// Es lo que hace falta cuando se elimina una cuenta desde la consola de
  /// Firebase Authentication: allí desaparece el login, pero el documento de
  /// `users` sobrevive y la app lo sigue listando.
  Future<void> eliminarPerfil(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  Future<UserProfile?> getUserProfileById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return null;
    return _perfilDesdeDoc(doc.id, data);
  }

  Future<void> addTokens(int amount) => _adjustTokens(amount);

  Future<void> removeTokens(int amount) => _adjustTokens(-amount);

  /// Suma/resta tokens de forma atómica sobre el valor que tenga el
  /// servidor en ese momento (no sobre el caché local), para que dos
  /// ajustes casi simultáneos (p. ej. dos desafíos completados seguidos)
  /// no se pisen entre sí.
  ///
  /// Un delta POSITIVO sube también el acumulado histórico; uno negativo solo
  /// baja el saldo. Esa asimetría es la regla central de la economía: gastar
  /// no puede quitarte nivel ni bajarte en el ranking.
  Future<void> _adjustTokens(int delta) async {
    final user = currentUser.value;
    if (user == null) return;

    try {
      final saldos = await _firestore.runTransaction<List<int>>((tx) async {
        final ref = _firestore.collection('users').doc(user.userId);
        final snapshot = await tx.get(ref);
        final datos = snapshot.data();
        final current = (datos?['tokens'] as int?) ?? user.tokens;
        final totalActual = leerTokensTotales(datos, current);
        final clamped = (current + delta).clamp(0, 1 << 31);
        final nuevoTotal = delta > 0 ? totalActual + delta : totalActual;
        tx.update(ref, {'tokens': clamped, 'tokensTotales': nuevoTotal});
        return [clamped, nuevoTotal];
      });
      _applyTokensLocally(user.userId, saldos[0], saldos[1]);
    } catch (e) {
      debugPrint('Warning: failed to persist tokens: $e');
    }
  }

  /// Paga Veridiums UNA sola vez por hecho.
  ///
  /// El apunte en `users/{uid}/movimientos` lleva como id la clave de
  /// idempotencia del hecho que se está pagando (ver [claveMovimiento]), y se
  /// escribe en la misma transacción que el saldo. Si el mismo pago se
  /// reintenta —porque se cayó la red, porque el usuario volvió atrás— la
  /// transacción encuentra el apunte ya escrito y no vuelve a pagar. Sin esto
  /// un reintento regala Veridiums, que es la forma más fácil de romper una
  /// economía.
  ///
  /// Devuelve true solo si el pago se hizo AHORA.
  Future<bool> otorgar({
    required int cantidad,
    required String motivo,
    required String referencia,
    String? detalle,
  }) async {
    final user = currentUser.value;
    if (user == null || cantidad <= 0) return false;

    final clave = claveMovimiento(motivo: motivo, referencia: referencia);
    final userRef = _firestore.collection('users').doc(user.userId);
    final movimientoRef = userRef.collection('movimientos').doc(clave);

    try {
      final saldos = await _firestore
          .runTransaction<List<int>?>((tx) async {
            final yaPagado = await tx.get(movimientoRef);
            if (yaPagado.exists) return null;

            final snapshot = await tx.get(userRef);
            final datos = snapshot.data();
            final saldo = (datos?['tokens'] as int?) ?? user.tokens;
            final total = leerTokensTotales(datos, saldo);

            tx.update(userRef, {
              'tokens': saldo + cantidad,
              'tokensTotales': total + cantidad,
            });
            tx.set(movimientoRef, {
              'delta': cantidad,
              'motivo': motivo,
              'referencia': referencia,
              'detalle': detalle,
              'fecha': aIsoUtc(DateTime.now()),
            });
            return [saldo + cantidad, total + cantidad];
          })
          .timeout(const Duration(seconds: 20));

      if (saldos == null) return false;
      _applyTokensLocally(user.userId, saldos[0], saldos[1]);
      return true;
    } catch (e) {
      debugPrint('UserRepository.otorgar error: $e');
      return false;
    }
  }

  void _applyTokensLocally(String userId, int tokens, int totales) {
    final user = currentUser.value;
    if (user != null && user.userId == userId) {
      currentUser.value = user.copyWith(tokens: tokens, tokensTotales: totales);
    }
    _cacheTokens(userId, tokens);
  }

  /// Usado por otros repositorios (p. ej. desafíos) que ya movieron los
  /// tokens del usuario dentro de su propia transacción de Firestore, para
  /// mantener sincronizado el estado en memoria/caché sin volver a escribir.
  void syncTokensFromServer(String userId, int tokens, int totales) =>
      _applyTokensLocally(userId, tokens, totales);

  int getTokens() {
    return currentUser.value?.tokens ?? 0;
  }

  Future<void> _cacheTokens(String uid, int tokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cached_tokens_$uid', tokens);
    } catch (e) {
      debugPrint('Warning: failed to cache tokens locally: $e');
    }
  }

  Future<int> _getCachedTokens(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('cached_tokens_$uid') ?? 0;
    } catch (e) {
      debugPrint('Warning: failed to read cached tokens locally: $e');
      return 0;
    }
  }

  Future<void> cacheUserProfile(
    String uid,
    int tokens,
    String role,
    String displayName,
  ) async {
    await _cacheUserProfile(uid, tokens, role, displayName);
  }

  Future<void> _cacheUserProfile(
    String uid,
    int tokens,
    String role,
    String displayName,
  ) async {
    await _cacheTokens(uid, tokens);
    await _cacheRole(uid, role);
    await _cacheDisplayName(uid, displayName);
  }

  Future<void> _cacheRole(String uid, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_role_$uid', role);
    } catch (e) {
      debugPrint('Warning: failed to cache role locally: $e');
    }
  }

  Future<String> _getCachedRole(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_role_$uid') ?? '';
    } catch (e) {
      debugPrint('Warning: failed to read cached role locally: $e');
      return '';
    }
  }

  Future<void> _cacheDisplayName(String uid, String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_displayName_$uid', displayName);
    } catch (e) {
      debugPrint('Warning: failed to cache displayName locally: $e');
    }
  }

  Future<String> _getCachedDisplayName(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_displayName_$uid') ?? '';
    } catch (e) {
      debugPrint('Warning: failed to read cached displayName locally: $e');
      return '';
    }
  }
}
