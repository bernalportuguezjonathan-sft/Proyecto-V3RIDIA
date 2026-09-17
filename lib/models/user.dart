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
    this.marcoEquipado,
    this.tituloEquipado,
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

  /// Id de la recompensa de tipo marco que el explorador eligió llevar, o
  /// null si no ha elegido ninguno.
  ///
  /// Hasta que existió este campo NO HABÍA ELECCIÓN: el perfil pintaba
  /// siempre el marco más caro de los comprados, así que quien compraba el
  /// dorado después del esmeralda perdía el esmeralda para siempre sin
  /// haberlo pedido, y no había ningún sitio en la app donde cambiarlo.
  ///
  /// null significa "no he elegido", no "ninguno": ahí se sigue usando el más
  /// caro, que es lo que esas cuentas ya veían. Para quitárselo del todo se
  /// guarda [ningunoEquipado], que es una elección explícita y sí se respeta.
  final String? marcoEquipado;

  /// Igual que [marcoEquipado], para el título que acompaña al nombre.
  final String? tituloEquipado;

  final DateTime? banExpires;
  final String? banReason;

  /// Valor que distingue "elegí no llevar nada" de "todavía no he elegido".
  ///
  /// Sin él no se puede desequipar: un null se interpretaría como "sin
  /// elegir" y el marco más caro volvería a aparecer solo.
  static const ningunoEquipado = 'ninguno';

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
    String? marcoEquipado,
    String? tituloEquipado,
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
      marcoEquipado: marcoEquipado ?? this.marcoEquipado,
      tituloEquipado: tituloEquipado ?? this.tituloEquipado,
      banExpires: banExpires ?? this.banExpires,
      banReason: banReason ?? this.banReason,
    );
  }
}

/// Deja un solo perfil por correo, quedándose con el que tiene el recorrido.
///
/// En `users` conviven documentos distintos con el MISMO correo: pasa cuando
/// alguien se registró con correo y contraseña y después entró con Google
/// —Firebase Auth le da otro uid, así que es otro documento—, o cuando se
/// borró la cuenta de Auth y se volvió a crear. Al administrador le llegaban
/// dos "Julian Banjou" idénticos en el desplegable y no había forma de saber
/// a cuál asignarle un desafío.
///
/// **Se queda el de más `tokensTotales`**, que es el acumulado histórico y
/// nunca baja: es la mejor señal de cuál de los dos ha usado la persona de
/// verdad. A igualdad, gana el más antiguo, que es donde suele estar el
/// progreso. Empatan de verdad solo si los dos están vacíos, y entonces da
/// igual cuál se muestre.
///
/// NO borra nada: solo decide qué se enseña. Limpiar la base de datos es otra
/// decisión y la toma una persona, porque borrar el documento equivocado se
/// lleva por delante los Veridiums y las insignias de alguien.
///
/// Quien no tiene correo se deja pasar tal cual: sin correo no hay forma de
/// saber si es un duplicado, y descartarlo escondería una cuenta real.
List<UserProfile> unoPorCorreo(Iterable<UserProfile> perfiles) =>
    agruparPorCorreo(perfiles).map((g) => g.principal).toList();

/// Las cuentas que comparten un mismo correo, con una señalada como la buena.
///
/// Existe para la pantalla de moderación, donde esconder los duplicados sin
/// más sería un error: **es la única pantalla desde la que se pueden borrar**.
/// Ocultarlos dejaría la lista limpia y los documentos sobrantes atrapados en
/// la base de datos para siempre.
///
/// Así que ahí se enseña una sola tarjeta por correo —la [principal]— y los
/// [duplicados] quedan colgando de ella para poder revisarlos y borrarlos uno
/// a uno.
class GrupoDeCorreo {
  const GrupoDeCorreo({required this.principal, required this.duplicados});

  /// La que se queda: más `tokensTotales` y, a igualdad, la más antigua.
  final UserProfile principal;

  /// Las demás con el mismo correo. Vacío en el caso normal.
  final List<UserProfile> duplicados;

  bool get hayDuplicados => duplicados.isNotEmpty;

  /// Cuántas cuentas hay en total con este correo.
  int get cuantas => duplicados.length + 1;
}

/// Agrupa por correo normalizado y elige la principal de cada grupo.
List<GrupoDeCorreo> agruparPorCorreo(Iterable<UserProfile> perfiles) {
  final porCorreo = <String, List<UserProfile>>{};
  final sinCorreo = <UserProfile>[];

  for (final perfil in perfiles) {
    final clave = perfil.email.trim().toLowerCase();
    if (clave.isEmpty) {
      // Sin correo no hay forma de saber si es un duplicado, y descartarlo
      // escondería una cuenta real: cada uno va en su propio grupo.
      sinCorreo.add(perfil);
      continue;
    }
    porCorreo.putIfAbsent(clave, () => <UserProfile>[]).add(perfil);
  }

  final grupos = <GrupoDeCorreo>[];
  for (final lista in porCorreo.values) {
    var principal = lista.first;
    for (final candidato in lista.skip(1)) {
      if (_ganaComoPrincipal(candidato, principal)) principal = candidato;
    }
    grupos.add(
      GrupoDeCorreo(
        principal: principal,
        duplicados: lista.where((p) => p.userId != principal.userId).toList(),
      ),
    );
  }
  for (final suelto in sinCorreo) {
    grupos.add(GrupoDeCorreo(principal: suelto, duplicados: const []));
  }

  grupos.sort(
    (a, b) => a.principal.displayName.toLowerCase().compareTo(
      b.principal.displayName.toLowerCase(),
    ),
  );
  return grupos;
}

bool _ganaComoPrincipal(UserProfile candidato, UserProfile actual) {
  if (candidato.tokensTotales != actual.tokensTotales) {
    return candidato.tokensTotales > actual.tokensTotales;
  }
  return candidato.createdDate.isBefore(actual.createdDate);
}

/// Decide qué recompensa de un tipo lleva puesta el explorador.
///
/// Función aparte y pura porque concentra la única regla delicada de todo
/// esto: qué hacer cuando no hay elección guardada. Se prueba en
/// `test/equipar_recompensa_test.dart`.
///
/// - [elegido] null → nadie ha elegido nunca: se devuelve la más cara de
///   [disponibles], que es exactamente lo que esas cuentas ya veían antes de
///   que se pudiera elegir. Así nadie pierde su marco al actualizar.
/// - [elegido] igual a [UserProfile.ningunoEquipado] → eligió no llevar nada.
/// - [elegido] apuntando a algo que ya no tiene (o que dejó de existir en el
///   catálogo) → se cae al mismo criterio que si no hubiera elegido, en vez
///   de dejar el perfil sin nada sin explicación.
T? equipadoEntre<T>(
  String? elegido,
  List<T> disponibles, {
  required String Function(T) idDe,
  required int Function(T) costoDe,
}) {
  if (disponibles.isEmpty) return null;
  if (elegido == UserProfile.ningunoEquipado) return null;

  if (elegido != null) {
    for (final candidato in disponibles) {
      if (idDe(candidato) == elegido) return candidato;
    }
  }

  final ordenados = [...disponibles]
    ..sort((a, b) => costoDe(b).compareTo(costoDe(a)));
  return ordenados.first;
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
