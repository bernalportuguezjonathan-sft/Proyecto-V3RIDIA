import 'package:flutter/foundation.dart';
import '../models/asignacion.dart';

class AssignmentRepository {
  AssignmentRepository._();

  static final AssignmentRepository instance = AssignmentRepository._();

  final ValueNotifier<List<AssignmentRecord>> records =
      ValueNotifier<List<AssignmentRecord>>([]);

  void addRecord(AssignmentRecord record) {
    records.value = [record, ...records.value];
  }

  void clearAll() {
    records.value = [];
  }
}
