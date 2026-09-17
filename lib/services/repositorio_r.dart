import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/recompensa.dart';
import '../models/user.dart';
import '../theme/veridia_theme.dart';
import 'economia.dart';
import 'repositorio_u.dart';

/// Resultado de intentar canjear una recompensa.
enum ResultadoCanje { exito, sinSaldo, yaLaTienes, sinSesion, error }

/// Resultado de ponerse o quitarse un marco o un título.
enum ResultadoEquipar {
  exito,

  /// Firestore rechazó la escritura.
  ///
  /// En la práctica solo significa una cosa: las reglas desplegadas todavía
  /// no permiten `marcoEquipado`/`tituloEquipado`. Merece un caso propio
  /// porque el consejo correcto es "hay que desplegar las reglas", y decirle
  /// a alguien "intenta de nuevo" cuando reintentar no puede funcionar es
  /// mandarlo a golpear un botón muerto.
  sinPermiso,

  /// No es equipable o no la tiene comprada.
  noAplica,

  /// Falló por otra cosa (red, sesión caída): reintentar sí tiene sentido.
  error,
}

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
    // Lo que solo se puede canjear una vez lleva id determinista, así que un
    // segundo intento choca contra el documento que ya existe en vez de
    // cobrar dos veces. Lo repetible (una salida de campo, otro kit) sí pide
    // un id nuevo, y lo genera Firestore: `millisecondsSinceEpoch` hacía que
    // dos canjes en el mismo milisegundo se pisaran.
    final canjeRef = recompensa.tipo.repetible
        ? _canjes.doc()
        : _canjes.doc('${uid}_${recompensa.id}');

    int? saldoFinal;
    try {
      final resultado = await FirebaseFirestore.instance
          .runTransaction<ResultadoCanje>((tx) async {
            // Con id determinista, que el documento ya exista ES la prueba de
            // que esta recompensa ya se canjeó. Comprobarlo aquí dentro y no
            // solo con `yaCanjeada` (que mira una copia local que puede estar
            // vieja) evita cobrar dos veces desde dos dispositivos a la vez.
            if (!recompensa.tipo.repetible) {
              final anterior = await tx.get(canjeRef);
              if (anterior.exists) return ResultadoCanje.yaLaTienes;
            }

            final snapshot = await tx.get(userRef);
            final saldo = (snapshot.data()?['tokens'] as num?)?.toInt() ?? 0;
            if (saldo < recompensa.costo) return ResultadoCanje.sinSaldo;

            final nuevoSaldo = saldo - recompensa.costo;
            // Solo baja el SALDO. `tokensTotales` no se toca nunca al gastar:
            // es el acumulado histórico del que salen el nivel y el ranking.
            tx.update(userRef, {'tokens': nuevoSaldo});
            tx.set(
              userRef
                  .collection('movimientos')
                  .doc(
                    claveMovimiento(motivo: 'canje', referencia: canjeRef.id),
                  ),
              {
                'delta': -recompensa.costo,
                'motivo': 'canje',
                'referencia': recompensa.id,
                'detalle': recompensa.nombre,
                'fecha': aIsoUtc(DateTime.now()),
              },
            );
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
        UserRepository.instance.syncTokensFromServer(
          uid,
          saldoFinal!,
          perfil.tokensTotales,
        );
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

  /// Lo que el explorador tiene comprado de un tipo concreto.
  List<Recompensa> desbloqueadasDeTipo(TipoRecompensa tipo) =>
      desbloqueadas().where((r) => r.tipo == tipo).toList();

  /// La recompensa de [tipo] que lleva puesta ahora mismo.
  ///
  /// Respeta lo que haya ELEGIDO (ver [equipadoEntre]); si nunca eligió, cae
  /// en la más cara, que es lo que la app hacía antes de que se pudiera
  /// elegir.
  Recompensa? equipadaDeTipo(TipoRecompensa tipo) {
    final perfil = UserRepository.instance.currentUser.value;
    final elegido = switch (tipo) {
      TipoRecompensa.marco => perfil?.marcoEquipado,
      TipoRecompensa.titulo => perfil?.tituloEquipado,
      _ => null,
    };
    return equipadoEntre<Recompensa>(
      elegido,
      desbloqueadasDeTipo(tipo),
      idDe: (r) => r.id,
      costoDe: (r) => r.costo,
    );
  }

  /// Título que se muestra junto al nombre.
  String? tituloActivo() => equipadaDeTipo(TipoRecompensa.titulo)?.valor;

  /// Marco puesto en la foto de perfil (null si no lleva ninguno).
  Recompensa? marcoActivo() => equipadaDeTipo(TipoRecompensa.marco);

  /// true si esa recompensa concreta es la que lleva puesta.
  bool estaEquipada(Recompensa recompensa) =>
      equipadaDeTipo(recompensa.tipo)?.id == recompensa.id;

  /// Pone o quita un marco o un título.
  ///
  /// Pasar la que ya lleva puesta la QUITA: es el mismo gesto para las dos
  /// cosas, como el de una prenda que se toca para ponérsela y se vuelve a
  /// tocar para quitársela. Con un botón aparte de "quitar" habría dos
  /// controles por tarjeta para algo que solo tiene dos estados.
  ///
  /// Devuelve false si la recompensa no es equipable o no la tiene comprada.
  Future<ResultadoEquipar> alternarEquipada(Recompensa recompensa) async {
    if (recompensa.tipo != TipoRecompensa.marco &&
        recompensa.tipo != TipoRecompensa.titulo) {
      return ResultadoEquipar.noAplica;
    }
    if (!yaCanjeada(recompensa.id)) return ResultadoEquipar.noAplica;

    final quitar = estaEquipada(recompensa);
    final valor = quitar ? UserProfile.ningunoEquipado : recompensa.id;
    final campo = recompensa.tipo == TipoRecompensa.marco
        ? 'marcoEquipado'
        : 'tituloEquipado';

    final perfil = UserRepository.instance.currentUser.value;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (perfil == null || uid == null) return ResultadoEquipar.error;

    // Se refleja en memoria antes de escribir, igual que al equipar una
    // mascota: si no, el aro de la foto tarda en cambiar lo que tarde
    // Firestore en devolver el eco. Si la escritura falla se deshace.
    UserRepository.instance.currentUser.value =
        recompensa.tipo == TipoRecompensa.marco
        ? perfil.copyWith(marcoEquipado: valor)
        : perfil.copyWith(tituloEquipado: valor);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        campo: valor,
      });
      return ResultadoEquipar.exito;
    } on FirebaseException catch (e) {
      debugPrint('RewardRepository.alternarEquipada error: $e');
      UserRepository.instance.currentUser.value = perfil;
      return e.code == 'permission-denied'
          ? ResultadoEquipar.sinPermiso
          : ResultadoEquipar.error;
    } catch (e) {
      debugPrint('RewardRepository.alternarEquipada error: $e');
      UserRepository.instance.currentUser.value = perfil;
      return ResultadoEquipar.error;
    }
  }
}
