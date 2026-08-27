import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/recompensa.dart';
import 'repositorio_u.dart';

/// Resultado de intentar canjear una recompensa.
enum ResultadoCanje { exito, sinSaldo, yaLaTienes, sinSesion, error }

/// Tienda de Veridiums: qué se puede canjear y qué ha canjeado cada quien.
///
/// Los canjes viven en la colección `canjes`. El descuento de Veridiums y el
/// registro del canje ocurren en UNA transacción de Firestore: si algo falla,
/// ni se cobra ni queda el canje a medias.
class RewardRepository {
  RewardRepository._() {
    FirebaseAuth.instance.authStateChanges().listen(_subscribe);
  }

  static final RewardRepository instance = RewardRepository._();

  CollectionReference<Map<String, dynamic>> get _canjes =>
      FirebaseFirestore.instance.collection('canjes');

  /// Canjes del explorador con la sesión abierta (vacío si no hay sesión).
  final ValueNotifier<List<Canje>> misCanjes = ValueNotifier<List<Canje>>([]);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe(User? user) {
    _sub?.cancel();
    _sub = null;

    if (user == null) {
      misCanjes.value = [];
      return;
    }

    _sub = _canjes.where('userId', isEqualTo: user.uid).snapshots().listen((
      snapshot,
    ) {
      final lista = snapshot.docs
          .map((doc) => Canje.fromMap(doc.id, doc.data()))
          .toList();
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      misCanjes.value = lista;
    }, onError: (e) => debugPrint('RewardRepository stream error: $e'));
  }

  /// Todos los canjes, para el panel del administrador.
  Stream<List<Canje>> streamTodos({int limite = 200}) {
    return _canjes
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Canje.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// true si el explorador ya compró esa recompensa y no tiene sentido
  /// repetirla (insignias, marcos y títulos).
  bool yaCanjeada(String recompensaId) {
    final recompensa = recompensaPorId(recompensaId);
    if (recompensa != null && recompensa.tipo.repetible) return false;
    return misCanjes.value.any((canje) => canje.recompensaId == recompensaId);
  }

  /// Cobra la recompensa y la entrega en el acto.
  ///
  /// No hay aprobación de por medio: el descuento de Veridiums y el registro
  /// del canje ocurren en la misma transacción y la recompensa queda activa.
  /// Si el saldo no alcanza no se toca nada.
  Future<ResultadoCanje> canjear(Recompensa recompensa) async {
    final perfil = UserRepository.instance.currentUser.value;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (perfil == null || uid == null) return ResultadoCanje.sinSesion;
    if (yaCanjeada(recompensa.id)) return ResultadoCanje.yaLaTienes;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final canjeRef = _canjes.doc(
      '${uid}_${recompensa.id}_${DateTime.now().millisecondsSinceEpoch}',
    );

    int? saldoFinal;
    try {
      final resultado = await FirebaseFirestore.instance
          .runTransaction<ResultadoCanje>((tx) async {
            final snapshot = await tx.get(userRef);
            final saldo = (snapshot.data()?['tokens'] as num?)?.toInt() ?? 0;
            if (saldo < recompensa.costo) return ResultadoCanje.sinSaldo;

            final nuevoSaldo = saldo - recompensa.costo;
            tx.update(userRef, {'tokens': nuevoSaldo});
            tx.set(
              canjeRef,
              Canje(
                id: canjeRef.id,
                userId: uid,
                userDisplayName: perfil.displayName,
                recompensaId: recompensa.id,
                nombre: recompensa.nombre,
                costo: recompensa.costo,
                fecha: DateTime.now(),
                estado: EstadoCanje.activo,
              ).toMap(),
            );
            saldoFinal = nuevoSaldo;
            return ResultadoCanje.exito;
          })
          .timeout(const Duration(seconds: 20));

      if (resultado == ResultadoCanje.exito && saldoFinal != null) {
        UserRepository.instance.syncTokensFromServer(uid, saldoFinal!);
      }
      return resultado;
    } catch (e) {
      debugPrint('RewardRepository.canjear error: $e');
      return ResultadoCanje.error;
    }
  }

  /// Recompensas de un explorador que cambian algo visible en su perfil, ya
  /// resueltas contra el catálogo: insignias, marco y título.
  List<Recompensa> desbloqueadas() {
    final ids = misCanjes.value.map((canje) => canje.recompensaId).toSet();
    return catalogoRecompensas
        .where((r) => ids.contains(r.id) && r.tipo.cambiaElPerfil)
        .toList();
  }

  /// Título comprado más caro (el que se muestra junto al nombre).
  String? tituloActivo() {
    final titulos = desbloqueadas()
        .where((r) => r.tipo == TipoRecompensa.titulo)
        .toList();
    if (titulos.isEmpty) return null;
    titulos.sort((a, b) => b.costo.compareTo(a.costo));
    return titulos.first.valor;
  }

  /// Marco comprado más caro (null si no tiene ninguno).
  Recompensa? marcoActivo() {
    final marcos = desbloqueadas()
        .where((r) => r.tipo == TipoRecompensa.marco)
        .toList();
    if (marcos.isEmpty) return null;
    marcos.sort((a, b) => b.costo.compareTo(a.costo));
    return marcos.first;
  }
}
