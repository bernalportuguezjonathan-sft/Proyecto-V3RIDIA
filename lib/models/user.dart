import '../services/economia.dart';

class UserProfile {
  UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.photoURL,
    required this.tokens,
    required this.role,
    required this.createdDate,
    required this.isBanned,
    this.tokensTotales = 0,
    this.mascotaActiva,
    this.accesorios = const {},
    this.banExpires,
    this.banReason,
  });

  final String userId;
  final String email;
  final String displayName;
  final String? photoURL;

  /// Saldo gastable. Sube al ganar y BAJA al canjear.
  final int tokens;

  /// Todo lo que ha ganado en su historia. Nunca baja.
  ///
  /// Existe porque `tokens` no puede hacer las dos cosas a la vez: si el
  /// ranking y el nivel se calcularan sobre el saldo, comprar una mascota de
  /// 110 Veridiums te haría bajar 110 puestos en la tabla y el explorador
  /// aprendería rapidísimo a no gastar nunca. El acumulado mide aporte real.
  final int tokensTotales;

  final String role;
  final DateTime createdDate;
  final bool isBanned;

  /// Clave de la mascota equipada (ver [MascotaId]). Solo una a la vez.
  final String? mascotaActiva;

  /// Accesorio puesto en cada ranura: `{'cabeza': 'sombrero_botanico'}`.
  final Map<String, String> accesorios;

  final DateTime? banExpires;
  final String? banReason;

  /// Nivel del explorador, derivado SIEMPRE del acumulado. Nunca se guarda en
  /// Firestore: un campo guardado se desincroniza, una función no.
  int get nivel => nivelDesde(tokensTotales);

  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? photoURL,
    int? tokens,
    int? tokensTotales,
    String? role,
    DateTime? createdDate,
    bool? isBanned,
    String? mascotaActiva,
    Map<String, String>? accesorios,
    DateTime? banExpires,
    String? banReason,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      tokens: tokens ?? this.tokens,
      tokensTotales: tokensTotales ?? this.tokensTotales,
      role: role ?? this.role,
      createdDate: createdDate ?? this.createdDate,
      isBanned: isBanned ?? this.isBanned,
      mascotaActiva: mascotaActiva ?? this.mascotaActiva,
      accesorios: accesorios ?? this.accesorios,
      banExpires: banExpires ?? this.banExpires,
      banReason: banReason ?? this.banReason,
    );
  }
}

/// Lee `tokensTotales` de un documento de Firestore.
///
/// Los perfiles creados antes de que existiera el acumulado no lo traen. En
/// esos casos el saldo actual es la mejor cota inferior de lo que ganaron
/// (nunca pudieron gastar más de lo que ganaron), así que se arranca de ahí
/// en vez de mandarlos a nivel 1 y borrarles el recorrido.
int leerTokensTotales(Map<String, dynamic>? data, int saldo) {
  final guardado = (data?['tokensTotales'] as num?)?.toInt();
  if (guardado == null) return saldo;
  return guardado < saldo ? saldo : guardado;
}

/// Lee el mapa de accesorios equipados de un documento de Firestore.
Map<String, String> leerAccesorios(Map<String, dynamic>? data) {
  final crudo = data?['accesorios'];
  if (crudo is! Map) return const {};
  return {
    for (final entrada in crudo.entries)
      if (entrada.value is String) '${entrada.key}': entrada.value as String,
  };
}
