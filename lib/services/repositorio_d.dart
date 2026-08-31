import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/desafio.dart';
import '../models/user.dart';
import '../theme/veridia_theme.dart';
import 'economia.dart';
import 'repositorio_u.dart';

/// Resultado de sumar una foto a un desafío.
class AvanceDesafio {
  const AvanceDesafio({
    required this.progreso,
    required this.meta,
    required this.completado,
    required this.veridiumsGanados,
    required this.bono,
  });

  final int progreso;
  final int meta;
  final bool completado;

  /// Total de Veridiums que sumó esta foto (1 por la foto + bono si cerró).
  final int veridiumsGanados;

  /// Parte del total que corresponde al bono de cierre. 0 si no cerró.
  final int bono;
}

/// Desafíos de la app.
///
/// Separa dos cosas que antes iban juntas y por eso se veían iguales en todas
/// las cuentas:
/// - La DEFINICIÓN del desafío (`challenges`), que es común a todos.
/// - El PROGRESO de cada explorador (`users/{uid}/desafios/{challengeId}`),
///   que es privado y solo lo mueve su dueño.
///
/// NOTA (2026-08-26): [registrarFoto] otorga el progreso y los Veridiums
/// desde AQUÍ, en el cliente, de forma temporal — mientras el proyecto no
/// tenga el plan Blaze de Firebase activo (las Cloud Functions lo exigen
/// para desplegarse). Existe una versión servidor idéntica, ya escrita y
/// probada, en `functions/index.js` (`guardarObservacion`); cuando se active
/// Blaze hay que volver a llamarla desde ahí en vez de desde aquí (ver
/// [[project-veridia-backend]] en la memoria del proyecto).
class ChallengeRepository {
  ChallengeRepository._() {
    // Nos re-suscribimos con cada cambio de sesión: si escucháramos sin
    // usuario, Firestore cerraría el stream con permission-denied y la lista
    // quedaría vacía para siempre.
    FirebaseAuth.instance.authStateChanges().listen(_subscribe);

    // Y otra vez cuando se sepa el ROL, que llega despues.
    //
    // authStateChanges() dispara en cuanto hay sesion, pero el perfil -y con
    // el, si eres Administrador- se carga de forma asincrona un momento mas
    // tarde. Como [_subscribe] elige la consulta según el rol, un
    // administrador se suscribía con el filtro de explorador y su panel se
    // quedaba SIN los desafíos asignados a otras personas: creaba uno para un
    // estudiante y no volvía a verlo. Al enterarnos del rol rehacemos la
    // suscripción.
    UserRepository.instance.currentUser.addListener(_revisarRol);
  }

  /// Rol con el que se armo la suscripcion actual, para no rehacerla en cada
  /// notificacion del perfil (que cambia tambien al ganar Veridiums).
  String? _rolSuscrito;

  void _revisarRol() {
    final rol = UserRepository.instance.currentUser.value?.role;
    if (rol == _rolSuscrito) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subscribe(user);
  }

  static final ChallengeRepository instance = ChallengeRepository._();

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('challenges');

  CollectionReference<Map<String, dynamic>> _progresoDe(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('desafios');

  final ValueNotifier<List<Challenge>> challenges =
      ValueNotifier<List<Challenge>>([]);

  /// Progreso del explorador con la sesión abierta, por id de desafío.
  final ValueNotifier<Map<String, ProgresoDesafio>> misProgresos =
      ValueNotifier<Map<String, ProgresoDesafio>>({});

  /// Desafíos globales (o TODOS, si quien mira es administrador).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// Desafíos asignados personalmente a este explorador. Va aparte porque
  /// Firestore no sabe hacer un OR en una sola consulta (ver [_subscribe]).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subAsignados;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subProgreso;

  List<Challenge> _globales = const [];
  List<Challenge> _asignados = const [];

  void _subscribe(User? user) {
    _sub?.cancel();
    _subAsignados?.cancel();
    _subProgreso?.cancel();
    _sub = null;
    _subAsignados = null;
    _subProgreso = null;
    _globales = const [];
    _asignados = const [];

    if (user == null) {
      challenges.value = [];
      misProgresos.value = {};
      _rolSuscrito = null;
      return;
    }

    final rol = UserRepository.instance.currentUser.value?.role;
    _rolSuscrito = rol;
    final esAdmin = rol == 'Administrador';

    // DOS consultas para el explorador, no una.
    //
    // Antes esto era una sola: `where('assignedToUserId', whereIn: [null,
    // uid])`, para sacar de un golpe los globales y los suyos. Pero Firestore
    // NO admite null dentro de un `in`: rechaza la consulta entera, el error
    // cae en el `onError` de abajo —que solo lo imprime— y la lista se queda
    // vacía para siempre. El administrador no lo notaba porque su consulta no
    // lleva filtro, así que veía los desafíos que acababa de crear mientras
    // que a los exploradores no les llegaba ninguno.
    //
    // `isNull: true` e `isEqualTo` sí son comparaciones válidas, así que se
    // hacen por separado y se juntan aquí. Sigue sin traerse los desafíos
    // ajenos, que es lo que protegía el filtro original: el nombre y el
    // correo de otras personas no salen del servidor.
    if (esAdmin) {
      _sub = _collection.snapshots().listen((snapshot) {
        _globales = _leerDesafios(snapshot);
        _publicarDesafios();
      }, onError: (e) => debugPrint('ChallengeRepository stream error: $e'));
    } else {
      _sub = _collection
          .where('assignedToUserId', isNull: true)
          .snapshots()
          .listen((snapshot) {
            _globales = _leerDesafios(snapshot);
            _publicarDesafios();
          }, onError: (e) => debugPrint('ChallengeRepository globales: $e'));

      _subAsignados = _collection
          .where('assignedToUserId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
            _asignados = _leerDesafios(snapshot);
            _publicarDesafios();
          }, onError: (e) => debugPrint('ChallengeRepository asignados: $e'));
    }

    _subProgreso = _progresoDe(user.uid).snapshots().listen((snapshot) {
      misProgresos.value = {
        for (final doc in snapshot.docs)
          doc.id: ProgresoDesafio.fromMap(doc.id, doc.data()),
      };
    }, onError: (e) => debugPrint('ChallengeRepository progreso error: $e'));
  }

  List<Challenge> _leerDesafios(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map((doc) => Challenge.fromMap(doc.id, doc.data()))
          .toList();

  /// Junta las dos consultas en la lista que ve la app. Un desafío no puede
  /// estar en las dos (o su `assignedToUserId` es null o es un uid), así que
  /// no hay que quitar repetidos.
  void _publicarDesafios() {
    final todos = [..._globales, ..._asignados]
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    challenges.value = todos;
  }

  /// Desafíos que le corresponden a un usuario: los globales más los que un
  /// administrador le asignó personalmente.
  List<Challenge> challengesForUser(String? userId) {
    return challenges.value
        .where((c) => c.isGlobal || c.assignedToUserId == userId)
        .toList();
  }

  /// Progreso propio en un desafío. Nunca null: quien no ha empezado va en 0.
  ProgresoDesafio progreso(String challengeId) =>
      misProgresos.value[challengeId] ?? ProgresoDesafio.vacio(challengeId);

  /// Desafíos propios ya completados.
  int completadosPorMi(String? userId) {
    final mios = challengesForUser(userId).map((c) => c.id).toSet();
    return misProgresos.value.values
        .where((p) => p.completado && mios.contains(p.challengeId))
        .length;
  }

  /// Garantiza que la lista de desafíos esté cargada antes de consultarla.
  ///
  /// `guardarConIA` decide a qué desafíos suma una foto leyendo
  /// `challenges.value`, que llena un stream de Firestore. Si la foto se
  /// guarda ANTES de que ese stream emita por primera vez —abrir la app e ir
  /// derecho a la cámara, o hacerlo con mala conexión— la lista está vacía,
  /// no coincide ningún desafío y la foto no suma a nada. Sin ningún aviso:
  /// la observación se guarda bien, el desafío simplemente no avanza, y desde
  /// fuera parece que los desafíos "a veces no funcionan".
  ///
  /// Una lectura puntual cubre ese hueco. Si el stream llega mientras tanto,
  /// gana el stream y esto no pisa nada.
  Future<void> asegurarCargado() async {
    if (challenges.value.isNotEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Las mismas dos consultas que [_subscribe], por el mismo motivo: un
      // `whereIn` con null no es una consulta válida en Firestore.
      final esAdmin =
          UserRepository.instance.currentUser.value?.role == 'Administrador';
      const espera = Duration(seconds: 8);

      if (esAdmin) {
        final snap = await _collection.get().timeout(espera);
        _globales = _leerDesafios(snap);
        _asignados = const [];
      } else {
        final resultados = await Future.wait([
          _collection.where('assignedToUserId', isNull: true).get(),
          _collection.where('assignedToUserId', isEqualTo: user.uid).get(),
        ]).timeout(espera);
        _globales = _leerDesafios(resultados[0]);
        _asignados = _leerDesafios(resultados[1]);
      }

      if (challenges.value.isNotEmpty) return;
      _publicarDesafios();
    } catch (e) {
      debugPrint('ChallengeRepository: no se pudo asegurar la carga: $e');
    }
  }

  /// Id único para un desafío nuevo, generado por Firestore.
  String nuevoId() => _collection.doc().id;

  Future<void> addChallenge(Challenge challenge) async {
    await _collection.doc(challenge.id).set(challenge.toMap());
  }

  /// Actualiza la definición sin tocar el contador de completados.
  Future<void> updateChallenge(Challenge challenge) async {
    final datos = challenge.toMap()..remove('completadoPor');
    await _collection.doc(challenge.id).update(datos);
  }

  Future<void> deleteChallenge(String id) async {
    await _collection.doc(id).delete();
  }

  /// Suma una foto verificada al desafío y paga los Veridiums.
  ///
  /// Cada foto da 1 Veridium; cerrar el desafío añade el bono una sola vez.
  /// Todo va en UNA transacción (progreso propio + saldo + contador del
  /// desafío) para que dos fotos casi simultáneas no dupliquen el bono ni
  /// pierdan progreso.
  ///
  /// Devuelve null si no se pudo registrar o si el desafío ya estaba cerrado.
  Future<AvanceDesafio?> registrarFoto(Challenge challenge) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final progresoRef = _progresoDe(uid).doc(challenge.id);
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final challengeRef = _collection.doc(challenge.id);

    int? saldoFinal;
    int? totalFinal;
    try {
      final avance = await FirebaseFirestore.instance
          .runTransaction<AvanceDesafio?>((tx) async {
            final progresoSnap = await tx.get(progresoRef);
            final userSnap = await tx.get(userRef);

            final actual = progresoSnap.exists
                ? ProgresoDesafio.fromMap(challenge.id, progresoSnap.data()!)
                : ProgresoDesafio.vacio(challenge.id);

            if (actual.progreso >= challenge.targetGoal) return null;

            final nuevoProgreso = actual.progreso + 1;
            final completado = nuevoProgreso >= challenge.targetGoal;
            final pagarBono = completado && !actual.bonoPagado;
            final bono = pagarBono ? challenge.tokensReward : 0;
            final ganados = 1 + bono;

            tx.set(
              progresoRef,
              ProgresoDesafio(
                challengeId: challenge.id,
                progreso: nuevoProgreso,
                completado: completado,
                bonoPagado: actual.bonoPagado || pagarBono,
                actualizado: DateTime.now(),
              ).toMap(),
            );

            final datosUsuario = userSnap.data();
            final saldo = (datosUsuario?['tokens'] as num?)?.toInt() ?? 0;
            final total = leerTokensTotales(datosUsuario, saldo);
            saldoFinal = saldo + ganados;
            totalFinal = total + ganados;
            tx.update(userRef, {
              'tokens': saldoFinal,
              'tokensTotales': totalFinal,
            });

            // Apunte en el libro. El id es determinista —el desafío y el
            // peldaño de progreso que se acaba de pagar—, así que un
            // reintento reescribe el mismo documento en vez de crear un
            // segundo pago.
            tx.set(
              userRef
                  .collection('movimientos')
                  .doc(
                    claveMovimiento(
                      motivo: 'desafio',
                      referencia: '${challenge.id}_$nuevoProgreso',
                    ),
                  ),
              {
                'delta': ganados,
                'motivo': 'desafio',
                'referencia': challenge.id,
                'detalle': pagarBono
                    ? 'Desafío completado: ${challenge.title}'
                    : 'Foto para ${challenge.title}',
                'fecha': aIsoUtc(DateTime.now()),
              },
            );

            // Contador para el panel del administrador: es lo único que se
            // escribe en el desafío compartido.
            if (pagarBono) {
              tx.update(challengeRef, {
                'completadoPor': FieldValue.increment(1),
              });
            }

            return AvanceDesafio(
              progreso: nuevoProgreso,
              meta: challenge.targetGoal,
              completado: completado,
              veridiumsGanados: ganados,
              bono: bono,
            );
          })
          .timeout(const Duration(seconds: 20));

      if (avance != null && saldoFinal != null && totalFinal != null) {
        UserRepository.instance.syncTokensFromServer(
          uid,
          saldoFinal!,
          totalFinal!,
        );
      }
      return avance;
    } catch (e) {
      debugPrint('ChallengeRepository.registrarFoto error: $e');
      return null;
    }
  }
}
