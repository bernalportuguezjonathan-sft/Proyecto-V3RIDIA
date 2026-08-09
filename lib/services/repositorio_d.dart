import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/desafio.dart';
import 'repositorio_u.dart';

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

  final ValueNotifier<List<Challenge>> challenges =
      ValueNotifier<List<Challenge>>([]);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe(User? user) {
    _sub?.cancel();
    _sub = null;

    if (user == null) {
      challenges.value = [];
      return;
    }

    _sub = _collection.snapshots().listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => Challenge.fromMap(doc.id, doc.data()))
            .toList();
        list.sort((a, b) => b.createdDate.compareTo(a.createdDate));
        challenges.value = list;
      },
      onError: (e) => debugPrint('ChallengeRepository stream error: $e'),
    );
  }

  /// Desafíos que le corresponden a un usuario: los globales más los que un
  /// administrador le asignó personalmente.
  List<Challenge> challengesForUser(String? userId) {
    return challenges.value
        .where((c) => c.isGlobal || c.assignedToUserId == userId)
        .toList();
  }

  Future<void> addChallenge(Challenge challenge) async {
    await _collection.doc(challenge.id).set(challenge.toMap());
  }

  Future<void> updateChallenge(Challenge challenge) async {
    await _collection.doc(challenge.id).set(challenge.toMap());
  }

  Future<void> deleteChallenge(String id) async {
    await _collection.doc(id).delete();
  }

  /// Sube el progreso de un desafío y entrega Veridiums.
  ///
  /// Cada avance da 1 Veridium; al completarlo se entrega el premio total
  /// (`tokensReward`) una sola vez, marcando `tokensAwarded` para no repetirlo.
  Future<void> updateProgress(String id, int newProgress) async {
    final matches = challenges.value.where((c) => c.id == id);
    if (matches.isEmpty) return;
    final challenge = matches.first;

    final normalizedProgress = newProgress.clamp(0, challenge.targetGoal);
    final isCompleted = normalizedProgress >= challenge.targetGoal;
    final progressDelta = normalizedProgress - challenge.currentProgress;
    if (progressDelta <= 0) return;

    final entregarPremio = isCompleted && !challenge.tokensAwarded;

    await _collection.doc(id).update({
      'currentProgress': normalizedProgress,
      'isCompleted': isCompleted,
      'tokensAwarded': challenge.tokensAwarded || entregarPremio,
    });

    await UserRepository.instance.addTokens(
      entregarPremio ? challenge.tokensReward : progressDelta,
    );
  }
}
