import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/observation.dart';

class ObservationRepository {
  ObservationRepository._();

  static final ObservationRepository instance = ObservationRepository._();

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('avistamientos');

  Stream<List<Observation>> streamForUser(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => Observation.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    });
  }

  Stream<List<Observation>> streamAll({int limit = 300}) {
    return _collection
        .orderBy('dateTime', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Observation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addObservation(Observation observation) async {
    await _collection.doc(observation.id).set(observation.toMap());
  }

  Future<void> updateObservation(Observation observation) async {
    await _collection.doc(observation.id).update(observation.toMap());
  }

  Future<void> deleteObservation(String id) async {
    await _collection.doc(id).delete();
  }
}
