import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/observation.dart';
import 'especie_ia_service.dart';
import 'repositorio_d.dart' hide AvanceDesafio;
import 'repositorio_u.dart';

/// Cuánto avanzó UN desafío al guardar una observación identificada por IA.
class AvanceDesafio {
  const AvanceDesafio({
    required this.challengeId,
    required this.title,
    required this.progreso,
    required this.meta,
    required this.completado,
    required this.veridiumsGanados,
    required this.bono,
  });

  final String challengeId;
  final String title;
  final int progreso;
  final int meta;
  final bool completado;

  /// Total de Veridiums que sumó esta foto a ESTE desafío (1 por la foto +
  /// bono si lo cerró). Una sola foto puede traer varios [AvanceDesafio] si
  /// coincide con más de un desafío activo a la vez.
  final int veridiumsGanados;

  /// Parte del total que corresponde al bono de cierre. 0 si no cerró.
  final int bono;
}

class ResultadoGuardarObservacion {
  const ResultadoGuardarObservacion({
    required this.observacionId,
    required this.avances,
  });

  final String observacionId;
  final List<AvanceDesafio> avances;
}

class GuardarObservacionException implements Exception {
  GuardarObservacionException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

  /// Id único para una observación nueva.
  ///
  /// Lo genera Firestore en vez de usar `millisecondsSinceEpoch`: dos
  /// exploradores que guardaran en el mismo milisegundo se sobrescribían la
  /// observación del otro. Es puramente local (no escribe nada); sirve para
  /// nombrar la foto en Supabase Storage antes de guardar el documento.
  String nuevoId() => _collection.doc().id;

  /// Guardado MANUAL, sin identificación de IA de por medio (el explorador
  /// eligió la especie de una guía). No otorga Veridiums ni toca ningún
  /// desafío — por eso puede seguir escribiendo directo desde el cliente.
  Future<void> addObservation(Observation observation) async {
    await _collection.doc(observation.id).set(observation.toMap());
  }

  /// Guarda una observación identificada por la IA y avanza los desafíos
  /// propios que coincidan.
  ///
  /// NOTA (2026-08-26): esto corre en el CLIENTE de forma temporal, mientras
  /// el proyecto no tenga el plan Blaze de Firebase activo (las Cloud
  /// Functions lo exigen para desplegarse). La versión servidor —
  /// `guardarObservacion` en `functions/index.js` — ya existe, probada, y
  /// hace exactamente esto mismo pero validando la identificación con el
  /// Admin SDK en vez de confiar en lo que mande el cliente. Cuando se
  /// active Blaze hay que volver a llamar a esa Cloud Function desde aquí
  /// (ver [[project-veridia-backend]] en la memoria del proyecto).
  Future<ResultadoGuardarObservacion> guardarConIA({
    required SpeciesIdentification identificacion,
    required String observationId,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? location,
  }) async {
    final perfil = UserRepository.instance.currentUser.value;
    if (perfil == null) {
      throw GuardarObservacionException(
        'Debes iniciar sesión para guardar observaciones.',
      );
    }

    final observation = Observation(
      id: observationId,
      commonName: identificacion.commonName ?? 'Especie observada',
      scientificName: identificacion.scientificName ?? 'Sin confirmar',
      location: location ?? 'Sin ubicación',
      notes: identificacion.description ?? 'Identificado con IA',
      dateTime: DateTime.now(),
      imagePath: imageUrl,
      latitude: latitude,
      longitude: longitude,
      type: identificacion.type,
      userId: perfil.userId,
      userDisplayName: perfil.displayName,
    );

    try {
      await _collection
          .doc(observationId)
          .set(observation.toMap())
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw GuardarObservacionException(
        'No se pudo guardar la observación: $e',
      );
    }

    // Avanza TODOS mis desafíos activos cuya especie coincida con lo que la
    // IA identificó, uno por uno: la misma foto puede sumar a más de un
    // desafío a la vez si varios piden la misma especie.
    final repo = ChallengeRepository.instance;
    final coincidencias = repo.challengesForUser(perfil.userId).where((c) {
      if (repo.progreso(c.id).completado) return false;
      return especieCoincide(c.targetSpecies, identificacion);
    }).toList();

    final avances = <AvanceDesafio>[];
    for (final challenge in coincidencias) {
      final avance = await repo.registrarFoto(challenge);
      if (avance == null) continue;
      avances.add(
        AvanceDesafio(
          challengeId: challenge.id,
          title: challenge.title,
          progreso: avance.progreso,
          meta: avance.meta,
          completado: avance.completado,
          veridiumsGanados: avance.veridiumsGanados,
          bono: avance.bono,
        ),
      );
    }

    return ResultadoGuardarObservacion(
      observacionId: observationId,
      avances: avances,
    );
  }

  Future<void> updateObservation(Observation observation) async {
    await _collection.doc(observation.id).update(observation.toMap());
  }

  Future<void> deleteObservation(String id) async {
    await _collection.doc(id).delete();
  }
}
