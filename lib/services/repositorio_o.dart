import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/bird_zone.dart';
import '../models/observation.dart';
import '../utils/texto_busqueda.dart';
import 'economia.dart';
import 'especie_ia_service.dart';
import 'repositorio_d.dart' hide AvanceDesafio;
import 'repositorio_m.dart';
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
    this.veridiumsPorLaFoto = 0,
    this.bonoMascota,
  });

  final String observacionId;
  final List<AvanceDesafio> avances;

  /// Veridiums que pagó la foto en sí (base + mejora de la mascota), aparte
  /// de lo que hayan pagado los desafíos.
  final int veridiumsPorLaFoto;

  /// Qué aportó la mascota, para poder contarlo en pantalla. null si no
  /// aplicó ninguna mejora.
  final BonoMascota? bonoMascota;
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
    // Red de seguridad: si el stream de desafios todavia no emitio, esta
    // lista estaria vacia y la foto no sumaria a ningun desafio en silencio.
    await repo.asegurarCargado();
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

    // La foto se paga aparte de los desafíos, y una sola vez.
    //
    // Antes, una foto que no coincidiera con ningún desafío activo no daba
    // NADA: se podía salir a caminar toda la tarde, registrar diez especies
    // y volver con cero Veridiums. Ahora toda foto verificada paga —salvo
    // que ya la haya pagado un desafío, para no cobrarla dos veces— y encima
    // se le suma la mejora de la mascota que se lleve puesta.
    final contexto = await contextoDeFoto(
      userId: observation.userId,
      momento: observation.dateTime,
      latitude: latitude,
      longitude: longitude,
      tipoEspecie: identificacion.type,
      especieActual: observation.commonName,
      excluirObservacionId: observationId,
    );
    final mascota = MascotaRepository.instance.mascotaActiva(perfil);
    final bono = bonoDeMascota(mascota?.id, contexto);
    final base = avances.isEmpty ? 1 : 0;
    final total = base + bono.veridiums;

    var pagado = 0;
    if (total > 0) {
      final seOtorgo = await UserRepository.instance.otorgar(
        cantidad: total,
        motivo: 'foto',
        referencia: observationId,
        detalle: bono.motivo,
      );
      if (seOtorgo) pagado = total;
    }

    return ResultadoGuardarObservacion(
      observacionId: observationId,
      avances: avances,
      veridiumsPorLaFoto: pagado,
      bonoMascota: bono.aplica && pagado > 0 ? bono : null,
    );
  }

  /// Reúne lo que las mejoras de mascota necesitan saber de una foto.
  ///
  /// Sirve para las dos cosas: calcular el pago real de una observación ya
  /// guardada, y adelantarle al explorador qué va a pasar con la foto que
  /// todavía tiene encuadrada. Es EL MISMO cálculo a propósito — si la vista
  /// previa usara su propia cuenta, prometería un bono y pagaría otro.
  ///
  /// Todo sale de datos que ya existen: las zonas del mapa (el JSON de
  /// siempre) y los avistamientos propios.
  ///
  /// `especieActual` es el nombre común que la IA ya identificó. Cuando
  /// todavía no se sabe (vista previa antes de disparar) se cuenta como si
  /// fuera a ser una especie nueva, que es el caso que le interesa al
  /// explorador: "si esto es algo que no he registrado hoy, ¿cuánto paga?".
  Future<ContextoFoto> contextoDeFoto({
    required String? userId,
    required DateTime momento,
    double? latitude,
    double? longitude,
    String? tipoEspecie,
    String? especieActual,
    String? excluirObservacionId,
  }) async {
    try {
      final mias = await _misObservaciones(userId);
      final previas = mias
          .where((o) => o.id != excluirObservacionId)
          .toList(growable: false);

      return ContextoFoto(
        momento: momento,
        tipoEspecie: tipoEspecie,
        enHumedal: await _enHumedal(latitude, longitude),
        especiesDistintasHoy: _especiesDistintasHoy(
          previas,
          momento,
          especieActual,
        ),
        kmDesdeMisFotos: _kmALaMasCercana(previas, latitude, longitude),
      );
    } catch (e) {
      // Que la mascota no pueda calcular su bono no puede costarle al
      // explorador la observación que acaba de tomar.
      debugPrint('No se pudo calcular el contexto de la foto: $e');
      return ContextoFoto(momento: momento, tipoEspecie: tipoEspecie);
    }
  }

  Future<List<Observation>> _misObservaciones(String? userId) async {
    if (userId == null) return const [];
    final snapshot = await _collection
        .where('userId', isEqualTo: userId)
        .get()
        .timeout(const Duration(seconds: 10));
    return snapshot.docs
        .map((doc) => Observation.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Especies DISTINTAS que el explorador lleva hoy, contando la de ahora.
  ///
  /// Compara los nombres normalizados: "Colibrí Chillón" y "colibri chillon"
  /// son la misma especie y no pueden contar dos veces, o la mejora del
  /// colibrí se pagaría fotografiando el mismo pájaro con distinta grafía.
  int _especiesDistintasHoy(
    List<Observation> previas,
    DateTime momento,
    String? especieActual,
  ) {
    final nombres = <String>{};
    for (final anterior in previas) {
      if (!_mismoDia(anterior.dateTime, momento)) continue;
      nombres.add(normalizarTexto(anterior.commonName));
    }
    if (especieActual != null) {
      nombres.add(normalizarTexto(especieActual));
      return nombres.length;
    }
    // Sin identificar todavía: se asume que será una especie nueva.
    return nombres.length + 1;
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Distancia a la más cercana de sus fotos anteriores, en kilómetros.
  /// null si no hay coordenadas o si es su primera foto ubicada.
  double? _kmALaMasCercana(
    List<Observation> previas,
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null || longitude == null) return null;
    const distancia = Distance();
    final aqui = LatLng(latitude, longitude);

    double? minimo;
    for (final anterior in previas) {
      if (!anterior.hasCoordinates) continue;
      final km = distancia.as(
        LengthUnit.Kilometer,
        aqui,
        LatLng(anterior.latitude!, anterior.longitude!),
      );
      if (minimo == null || km < minimo) minimo = km;
    }
    return minimo;
  }

  /// true si el punto cae cerca de una zona de agua del mapa.
  ///
  /// "Cerca" es 1,5 km: las zonas del JSON están marcadas por un punto
  /// central, no por su contorno real, así que exigir que la foto caiga
  /// exactamente encima dejaría fuera media orilla del humedal.
  Future<bool> _enHumedal(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) return false;
    final zonas = await loadBirdZones();
    if (zonas.isEmpty) return false;

    const distancia = Distance();
    const radioKm = 1.5;
    final aqui = LatLng(latitude, longitude);

    for (final zona in zonas) {
      final texto = normalizarTexto(
        '${zona.name} ${zona.habitat} ${zona.description}',
      );
      if (!esZonaDeAguaNormalizada(texto)) continue;
      final km = distancia.as(
        LengthUnit.Kilometer,
        aqui,
        LatLng(zona.latitude, zona.longitude),
      );
      if (km <= radioKm) return true;
    }
    return false;
  }

  Future<void> updateObservation(Observation observation) async {
    await _collection.doc(observation.id).update(observation.toMap());
  }

  Future<void> deleteObservation(String id) async {
    await _collection.doc(id).delete();
  }
}
