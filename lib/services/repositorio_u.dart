import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

const webGoogleClientId =
    '523510024166-g4se2aa356mnlmkotah178gss2efve3a.apps.googleusercontent.com';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  late ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(
    null,
  );

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
    return UserProfile(
      userId: id,
      email: data['email'] as String? ?? '',
      displayName:
          data['displayName'] as String? ??
          (data['email'] as String? ?? '').split('@').first,
      photoURL: data['photoURL'] as String?,
      tokens: data['tokens'] as int? ?? 0,
      role: data['role'] as String? ?? 'Explorador',
      createdDate: createdDate ?? DateTime.now(),
      isBanned: data['isBanned'] as bool? ?? false,
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
  /// `porVeridiums` ordena de mayor a menor saldo (ranking); si no, alfabético.
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
          final porTokens = b.tokens.compareTo(a.tokens);
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
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? webGoogleClientId : null,
      );
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
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

        if (currentIsBanned &&
            banExpires != null &&
            banExpires.isBefore(DateTime.now())) {
          await unbanUser(userId: refreshedUser.uid);
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
          role: currentRole,
          createdDate: currentCreatedDate,
          isBanned: currentIsBanned,
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
      'createdDate': now.toIso8601String(),
      'photoURL': null,
      'isBanned': false,
      'banExpires': null,
      'banReason': null,
      if (role == 'Administrador') 'adminCode': adminCode,
    });
    await _cacheUserProfile(userId, 0, role, displayName);
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

  Future<UserProfile?> getUserProfileById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return null;

    final createdDate = data['createdDate'] is String
        ? DateTime.tryParse(data['createdDate'] as String)
        : DateTime.now();

    return UserProfile(
      userId: doc.id,
      email: data['email'] as String? ?? '',
      displayName:
          data['displayName'] as String? ??
          (data['email'] as String? ?? '').split('@').first,
      photoURL: data['photoURL'] as String?,
      tokens: data['tokens'] as int? ?? 0,
      role: data['role'] as String? ?? 'Explorador',
      createdDate: createdDate ?? DateTime.now(),
      isBanned: data['isBanned'] as bool? ?? false,
      banExpires: data['banExpires'] != null
          ? (data['banExpires'] is String
                ? DateTime.tryParse(data['banExpires'] as String)
                : data['banExpires'] is Timestamp
                ? (data['banExpires'] as Timestamp).toDate()
                : null)
          : null,
      banReason: data['banReason'] as String?,
    );
  }

  Future<void> addTokens(int amount) =>
      _setTokens((currentUser.value?.tokens ?? 0) + amount);

  Future<void> removeTokens(int amount) =>
      _setTokens((currentUser.value?.tokens ?? 0) - amount);

  Future<void> _setTokens(int rawTotal) async {
    final user = currentUser.value;
    if (user == null) return;

    final newTokens = rawTotal < 0 ? 0 : rawTotal;
    currentUser.value = user.copyWith(tokens: newTokens);
    await _cacheTokens(user.userId, newTokens);

    // Persistimos en Firestore; si falla, el valor queda al menos en caché.
    try {
      await _firestore.collection('users').doc(user.userId).update({
        'tokens': newTokens,
      });
    } catch (e) {
      debugPrint('Warning: failed to persist tokens: $e');
    }
  }

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
