import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/mascota.dart';
import '../models/user.dart';
import '../theme/veridia_theme.dart';
import 'economia.dart';
import 'repositorio_u.dart';

/// Por qué falló (o no) una compra en el Refugio.
enum ResultadoCompra {
  exito,
  sinSaldo,
  nivelInsuficiente,
  yaLoTienes,
  sinSesion,

  /// Firestore rechazó la escritura. En la práctica esto significa una sola
  /// cosa: las reglas del Refugio (`users/{uid}/inventario`) todavía no están
  /// desplegadas. Tiene su propio caso para poder decirlo, en vez de esconder
  /// un problema de configuración detrás de un "algo salió mal".
  sinPermisos,

  error,
}

/// El Refugio: qué mascotas y accesorios tiene cada explorador y cuál lleva
/// puesto.
///
/// Lo COMPRADO vive en `users/{uid}/inventario/{itemId}`, con el id del
/// catálogo como id del documento. Eso hace la compra idempotente por
/// construcción: comprar dos veces la misma mascota escribe el mismo
/// documento en vez de cobrar dos veces.
///
/// Lo EQUIPADO vive en el documento del usuario (`mascotaActiva`,
/// `accesorios`), porque hay uno solo de cada cosa y hace falta leerlo en el
/// mismo sitio donde ya se lee el perfil, sin una consulta extra.
class MascotaRepository {
  MascotaRepository._() {
    FirebaseAuth.instance.authStateChanges().listen(_subscribe);
  }

  static final MascotaRepository instance = MascotaRepository._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _inventarioDe(String uid) =>
      _firestore.collection('users').doc(uid).collection('inventario');

  /// Ids del catálogo que el explorador ya posee (mascotas y accesorios).
  final ValueNotifier<Set<String>> inventario = ValueNotifier<Set<String>>({});

  /// false si Firestore rechazó la lectura del inventario (reglas sin
  /// desplegar). Distinto de "el inventario está vacío", que es lo que se
  /// veía antes y hacía parecer que la app había perdido las compras.
  final ValueNotifier<bool> inventarioLegible = ValueNotifier<bool>(true);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe(User? user) {
    _sub?.cancel();
    _sub = null;

    if (user == null) {
      inventario.value = {};
      inventarioLegible.value = true;
      return;
    }

    _sub = _inventarioDe(user.uid).snapshots().listen(
      (snapshot) {
        inventarioLegible.value = true;
        inventario.value = snapshot.docs.map((doc) => doc.id).toSet();
        unawaited(_asegurarMascotaInicial(user.uid));
      },
      onError: (e) {
        inventarioLegible.value = false;
        debugPrint('MascotaRepository stream error: $e');
      },
    );
  }

  /// Nadie se queda sin compañero.
  ///
  /// La mascota inicial no se regala en el registro sino aquí, al leer el
  /// inventario: así también la reciben las cuentas creadas antes de que
  /// existiera el Refugio, sin necesidad de migrar nada a mano.
  Future<void> _asegurarMascotaInicial(String uid) async {
    final inicial = mascotaInicial;
    if (inventario.value.contains(inicial.id.name)) return;
    try {
      await _inventarioDe(uid).doc(inicial.id.name).set({
        'tipo': 'mascota',
        'costo': 0,
        'adquiridoEn': aIsoUtc(DateTime.now()),
      });
      final perfil = UserRepository.instance.currentUser.value;
      if (perfil != null && perfil.mascotaActiva == null) {
        await equiparMascota(inicial.id);
      }
    } on FirebaseException catch (e) {
      // Casi siempre es permission-denied porque las reglas del Refugio no
      // están desplegadas. No se reintenta en bucle: el explorador todavía
      // puede adoptarla a mano desde el Refugio, y ahí sí se le explica.
      debugPrint('No se pudo entregar la mascota inicial: ${e.code} $e');
    } catch (e) {
      debugPrint('No se pudo entregar la mascota inicial: $e');
    }
  }

  bool tiene(String itemId) => inventario.value.contains(itemId);

  bool tieneMascota(MascotaId id) => tiene(id.name);

  /// Mascotas que el explorador puede equipar ahora mismo.
  List<Mascota> misMascotas() =>
      catalogoMascotas.where((m) => tieneMascota(m.id)).toList();

  /// La mascota equipada, ya resuelta contra el catálogo.
  ///
  /// Si el perfil apunta a una mascota que no está en el inventario (un
  /// documento a medio migrar, un id viejo) cae a la inicial en vez de
  /// devolver null: el mapa nunca debería quedarse sin compañero.
  Mascota? mascotaActiva(UserProfile? perfil) {
    if (perfil == null) return null;
    final elegida = mascotaPorId(mascotaDesde(perfil.mascotaActiva));
    if (elegida != null && tieneMascota(elegida.id)) return elegida;
    return tieneMascota(mascotaInicial.id) ? mascotaInicial : null;
  }

  /// Accesorios puestos, por ranura. Ignora los que ya no estén en el
  /// inventario para que quitar algo nunca deje un sprite fantasma.
  Map<RanuraAccesorio, Accesorio> equipados(UserProfile? perfil) {
    if (perfil == null) return const {};
    final puestos = <RanuraAccesorio, Accesorio>{};
    for (final entrada in perfil.accesorios.entries) {
      final ranura = ranuraDesde(entrada.key);
      final accesorio = accesorioPorId(entrada.value);
      if (ranura == null || accesorio == null) continue;
      if (accesorio.ranura != ranura || !tiene(accesorio.id)) continue;
      puestos[ranura] = accesorio;
    }
    return puestos;
  }

  // -------------------------------------------------------------------------
  // Comprar
  // -------------------------------------------------------------------------

  Future<ResultadoCompra> comprarMascota(Mascota mascota) => _comprar(
    itemId: mascota.id.name,
    tipo: 'mascota',
    costo: mascota.costo,
    nivelRequerido: mascota.nivelRequerido,
    nombre: mascota.nombre,
  );

  Future<ResultadoCompra> comprarAccesorio(Accesorio accesorio) => _comprar(
    itemId: accesorio.id,
    tipo: 'accesorio',
    costo: accesorio.costo,
    nivelRequerido: accesorio.nivelRequerido,
    nombre: accesorio.nombre,
  );

  /// Cobra un artículo del Refugio y lo mete al inventario en la MISMA
  /// transacción, junto con su apunte en el libro de movimientos.
  ///
  /// El nivel se comprueba contra el acumulado que hay en el servidor, no
  /// contra el perfil en memoria: si solo mirara la copia local, bastaría con
  /// tener la app abierta desde antes de gastar para saltarse el requisito.
  Future<ResultadoCompra> _comprar({
    required String itemId,
    required String tipo,
    required int costo,
    required int nivelRequerido,
    required String nombre,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return ResultadoCompra.sinSesion;
    if (tiene(itemId)) return ResultadoCompra.yaLoTienes;

    final userRef = _firestore.collection('users').doc(uid);
    final itemRef = _inventarioDe(uid).doc(itemId);

    int? saldoFinal;
    int? totalFinal;
    try {
      final resultado = await _firestore
          .runTransaction<ResultadoCompra>((tx) async {
            final itemSnap = await tx.get(itemRef);
            if (itemSnap.exists) return ResultadoCompra.yaLoTienes;

            final userSnap = await tx.get(userRef);
            final datos = userSnap.data();
            final saldo = (datos?['tokens'] as num?)?.toInt() ?? 0;
            final total = leerTokensTotales(datos, saldo);

            if (nivelDesde(total) < nivelRequerido) {
              return ResultadoCompra.nivelInsuficiente;
            }
            if (saldo < costo) return ResultadoCompra.sinSaldo;

            saldoFinal = saldo - costo;
            totalFinal = total;

            // Solo baja el saldo: el acumulado no se toca al gastar. Lo
            // gratuito no toca el documento del usuario en absoluto.
            if (costo > 0) {
              tx.update(userRef, {'tokens': saldoFinal});
            }
            tx.set(itemRef, {
              'tipo': tipo,
              'costo': costo,
              'adquiridoEn': aIsoUtc(DateTime.now()),
            });
            if (costo > 0) {
              tx.set(
                userRef
                    .collection('movimientos')
                    .doc(
                      claveMovimiento(motivo: 'refugio', referencia: itemId),
                    ),
                {
                  'delta': -costo,
                  'motivo': 'refugio',
                  'referencia': itemId,
                  'detalle': nombre,
                  'fecha': aIsoUtc(DateTime.now()),
                },
              );
            }
            return ResultadoCompra.exito;
          })
          .timeout(const Duration(seconds: 20));

      if (resultado == ResultadoCompra.exito &&
          saldoFinal != null &&
          totalFinal != null) {
        UserRepository.instance.syncTokensFromServer(
          uid,
          saldoFinal!,
          totalFinal!,
        );
      }
      return resultado;
    } on FirebaseException catch (e) {
      debugPrint('MascotaRepository._comprar Firebase error: ${e.code} $e');
      return e.code == 'permission-denied'
          ? ResultadoCompra.sinPermisos
          : ResultadoCompra.error;
    } catch (e) {
      debugPrint('MascotaRepository._comprar error: $e');
      return ResultadoCompra.error;
    }
  }

  // -------------------------------------------------------------------------
  // Equipar
  // -------------------------------------------------------------------------

  /// Cambiar de mascota es gratis e ilimitado: lo que se compró una vez es
  /// tuyo para siempre y elegir compañero no debería costar nada.
  Future<bool> equiparMascota(MascotaId id) async {
    if (!tieneMascota(id)) return false;
    return _guardarEnPerfil({'mascotaActiva': id.name}, (perfil) {
      return perfil.copyWith(mascotaActiva: id.name);
    });
  }

  Future<bool> equiparAccesorio(Accesorio accesorio) async {
    if (!tiene(accesorio.id)) return false;
    final ranura = accesorio.ranura.name;
    return _guardarEnPerfil({'accesorios.$ranura': accesorio.id}, (perfil) {
      return perfil.copyWith(
        accesorios: {...perfil.accesorios, ranura: accesorio.id},
      );
    });
  }

  Future<bool> quitarAccesorio(RanuraAccesorio ranura) async {
    final clave = ranura.name;
    return _guardarEnPerfil({'accesorios.$clave': FieldValue.delete()}, (
      perfil,
    ) {
      final restantes = {...perfil.accesorios}..remove(clave);
      return UserProfile(
        userId: perfil.userId,
        email: perfil.email,
        displayName: perfil.displayName,
        photoURL: perfil.photoURL,
        tokens: perfil.tokens,
        tokensTotales: perfil.tokensTotales,
        role: perfil.role,
        createdDate: perfil.createdDate,
        isBanned: perfil.isBanned,
        mascotaActiva: perfil.mascotaActiva,
        accesorios: restantes,
        banExpires: perfil.banExpires,
        banReason: perfil.banReason,
      );
    });
  }

  /// Escribe en el perfil y refleja el cambio en memoria en el acto.
  ///
  /// Sin la copia local, equipar algo tardaba lo que tardara Firestore en
  /// devolver el eco y el sprite se quedaba con lo anterior puesto medio
  /// segundo. Si la escritura falla, el perfil real manda en la próxima
  /// lectura.
  Future<bool> _guardarEnPerfil(
    Map<String, dynamic> campos,
    UserProfile Function(UserProfile) aplicar,
  ) async {
    final perfil = UserRepository.instance.currentUser.value;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (perfil == null || uid == null) return false;

    UserRepository.instance.currentUser.value = aplicar(perfil);
    try {
      await _firestore.collection('users').doc(uid).update(campos);
      return true;
    } catch (e) {
      debugPrint('MascotaRepository._guardarEnPerfil error: $e');
      UserRepository.instance.currentUser.value = perfil;
      return false;
    }
  }
}
