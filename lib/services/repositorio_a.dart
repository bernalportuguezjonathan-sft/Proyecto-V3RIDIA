import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/asignacion.dart';

/// Bitácora de desafíos creados/asignados. Solo los administradores pueden
/// leerla y escribirla (ver firestore.rules).
class AssignmentRepository {
  AssignmentRepository._() {
    FirebaseAuth.instance.authStateChanges().listen(_subscribe);
  }

  static final AssignmentRepository instance = AssignmentRepository._();

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('assignments');

  final ValueNotifier<List<AssignmentRecord>> records =
      ValueNotifier<List<AssignmentRecord>>([]);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe(User? user) {
    _sub?.cancel();
    _sub = null;

    if (user == null) {
      records.value = [];
      return;
    }

    _sub = _collection.snapshots().listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => AssignmentRecord.fromMap(doc.id, doc.data()))
            .toList();
        list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        records.value = list;
      },
      onError: (e) => debugPrint('AssignmentRepository stream error: $e'),
    );
  }

  Future<void> addRecord(AssignmentRecord record) async {
    await _collection.doc(record.id).set(record.toMap());
  }
}
