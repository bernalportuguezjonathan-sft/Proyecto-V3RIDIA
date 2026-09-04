import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/logro.dart';

/// Recuerda el MÁXIMO histórico de las métricas con las que se ganan logros.
///
/// Los logros se calculan a partir de los datos vivos del explorador, que es
/// lo que evita llevar contadores paralelos que se desincronizan. El problema
/// es que dos de esas métricas —cuántos registros lleva y cuántas especies
/// distintas ha visto— BAJAN al borrar una foto del diario, y con ellas se
/// perdían logros ya conseguidos: bastaba borrar dos fotos para quedarse sin
/// "Primer avistamiento".
///
/// Un logro dice "hice esto", y eso no deja de ser cierto porque después
/// borres la foto. Así que estas marcas solo suben, nunca bajan, y los logros
/// se evalúan contra ellas.
///
/// Las otras dos métricas no necesitan marca: `veridiumsGanados` usa
/// `tokensTotales`, que por diseño solo sube, y los desafíos completados no
/// se deshacen al borrar una foto.
///
/// Vive en SharedPreferences y no en Firestore a propósito: guardarlo en el
/// perfil obligaría a abrir campos nuevos en las reglas de seguridad, y el
/// beneficio (que la marca viaje entre dispositivos) no compensa ese riesgo.
/// La consecuencia a tener presente es que la marca es de ESTE aparato.
class MarcaLogros extends ChangeNotifier {
  MarcaLogros._();

  static final MarcaLogros instance = MarcaLogros._();

  int _maxRegistros = 0;
  int _maxEspecies = 0;

  /// uid con el que se cargaron las marcas actuales. Si cambia la sesión hay
  /// que releer: las marcas de una persona no valen para otra.
  String? _uid;
  bool _cargando = false;

  String _clave(String uid, String metrica) => 'marca_logro_${metrica}_$uid';

  /// Lee las marcas guardadas de quien tenga la sesión abierta.
  ///
  /// Es idempotente y barata: si ya están cargadas para ese uid no hace nada.
  Future<void> cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _cargando) return;
    if (uid == _uid) return;

    _cargando = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _maxRegistros = prefs.getInt(_clave(uid, 'registros')) ?? 0;
      _maxEspecies = prefs.getInt(_clave(uid, 'especies')) ?? 0;
      _uid = uid;
      notifyListeners();
    } catch (e) {
      debugPrint('MarcaLogros: no se pudieron leer las marcas: $e');
    } finally {
      _cargando = false;
    }
  }

  /// El mayor entre lo que hay ahora y lo que hubo alguna vez.
  ///
  /// Si los valores vivos superan la marca, la sube y la guarda. Devuelve
  /// siempre el máximo, así que quien la use puede tratarla como el dato
  /// bueno sin preguntar nada más.
  ({int registros, int especies}) elevar({
    required int registros,
    required int especies,
  }) {
    final nuevoRegistros = registros > _maxRegistros
        ? registros
        : _maxRegistros;
    final nuevoEspecies = especies > _maxEspecies ? especies : _maxEspecies;

    if (nuevoRegistros != _maxRegistros || nuevoEspecies != _maxEspecies) {
      _maxRegistros = nuevoRegistros;
      _maxEspecies = nuevoEspecies;
      unawaited(_guardar());
    }
    return (registros: _maxRegistros, especies: _maxEspecies);
  }

  /// Aplica la marca a unas estadísticas recién calculadas: sube la marca si
  /// los valores vivos la superan, y devuelve las estadísticas con los
  /// mínimos históricos ya puestos.
  ///
  /// Es el único punto donde se juntan el estado guardado y el modelo puro.
  EstadisticasExplorador aplicar(EstadisticasExplorador vivas) {
    final marca = elevar(
      registros: vivas.registros,
      especies: vivas.especiesDistintas,
    );
    return vivas.conMinimos(
      registros: marca.registros,
      especies: marca.especies,
    );
  }

  Future<void> _guardar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_clave(uid, 'registros'), _maxRegistros);
      await prefs.setInt(_clave(uid, 'especies'), _maxEspecies);
    } catch (e) {
      debugPrint('MarcaLogros: no se pudieron guardar las marcas: $e');
    }
  }

  /// Al cerrar sesión: las marcas de quien salía no pueden teñir el perfil de
  /// quien entre después en el mismo aparato.
  void olvidar() {
    _uid = null;
    _maxRegistros = 0;
    _maxEspecies = 0;
  }
}
