import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/desafio.dart';
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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subProgreso;

  void _subscribe(User? user) {
    _sub?.cancel();
    _subProgreso?.cancel();
    _sub = null;
    _subProgreso = null;

    if (user == null) {
      challenges.value = [];
      misProgresos.value = {};
      return;
    }

    // El administrador necesita ver todos los desafíos; un explorador solo
    // los suyos. Traérselos todos a cada dispositivo no solo gastaba lecturas
    // de más: le enseñaba el nombre y el correo de las personas a las que se
    // asignaron los desafíos ajenos.
    _sub = _consultaPara(user.uid).snapshots().listen((snapshot) {
      final list = snapshot.docs
          .map((doc) => Challenge.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      challenges.value = list;
    }, onError: (e) => debugPrint('ChallengeRepository stream error: $e'));

    _subProgreso = _progresoDe(user.uid).snapshots().listen((snapshot) {
      misProgresos.value = {
        for (final doc in snapshot.docs)
          doc.id: ProgresoDesafio.fromMap(doc.id, doc.data()),
      };
    }, onError: (e) => debugPrint('ChallengeRepository progreso error: $e'));
  }

  /// Consulta de desafíos según el rol.
  ///
  /// Firestore no sabe hacer un OR entre "global" y "asignado a mí" en una
  /// sola consulta, así que se usa `whereIn` sobre `assignedToUserId`: null
  /// (global) o el propio uid. Un administrador se salta el filtro porque su
  /// panel tiene que verlos todos.
  Query<Map<String, dynamic>> _consultaPara(String uid) {
    final esAdmin =
        UserRepository.instance.currentUser.value?.role == 'Administrador';
    if (esAdmin) return _collection;
    return _collection.where('assignedToUserId', whereIn: [null, uid]);
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

            final saldo = (userSnap.data()?['tokens'] as num?)?.toInt() ?? 0;
            saldoFinal = saldo + ganados;
            tx.update(userRef, {'tokens': saldoFinal});

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

      if (avance != null && saldoFinal != null) {
        UserRepository.instance.syncTokensFromServer(uid, saldoFinal!);
      }
      return avance;
    } catch (e) {
      debugPrint('ChallengeRepository.registrarFoto error: $e');
      return null;
    }
  }
}
