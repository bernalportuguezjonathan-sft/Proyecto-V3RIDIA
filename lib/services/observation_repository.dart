import 'package:flutter/foundation.dart';
import '../models/observation.dart';

class ObservationRepository {
  ObservationRepository._();

  static final ObservationRepository instance = ObservationRepository._();

  final ValueNotifier<List<Observation>> observations = ValueNotifier<List<Observation>>([]);

  void addObservation(Observation observation) {
    observations.value = [observation, ...observations.value];
  }

  void updateObservation(Observation observation) {
    final index = observations.value.indexWhere((item) => item.id == observation.id);
    if (index >= 0) {
      final updated = List<Observation>.from(observations.value);
      updated[index] = observation;
      observations.value = updated;
    }
  }

  void deleteObservation(String id) {
    observations.value = observations.value.where((item) => item.id != id).toList();
  }
}
