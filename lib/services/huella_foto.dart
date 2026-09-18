import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../theme/veridia_theme.dart';

/// Huella de una foto: una exacta y otra tolerante a reencodings.
///
/// `sha256` cambia con el más mínimo byte distinto, así que por sí solo no
/// detecta la misma foto reexportada o recomprimida por WhatsApp. `ahash`
/// (average hash) reduce la imagen a 8x8 en grises y guarda un bit por píxel
/// según esté por encima o por debajo del brillo medio: dos versiones de la
/// misma foto dan hashes casi idénticos.
///
/// NOTA (2026-08-26): esta verificación corre en el CLIENTE de forma
/// temporal, mientras el proyecto no tenga el plan Blaze activo en Firebase
/// (las Cloud Functions lo exigen para desplegarse). La versión servidor de
/// esta misma lógica ya existe y está probada en `functions/logica.js` /
/// `functions/index.js`; cuando se active Blaze y se despliegue, hay que
/// volver a apuntar `EspecieIAService`/`ObservationRepository.guardarConIA`
/// a las Cloud Functions y este archivo puede borrarse otra vez (ver
/// [[project-veridia-backend]] en la memoria del proyecto).
class HuellaFoto {
  const HuellaFoto({required this.sha256, required this.ahash});

  final String sha256;
  final String ahash;

  Map<String, dynamic> toMap() => {'sha256': sha256, 'ahash': ahash};
}

/// Foto ya usada antes por el mismo explorador.
class FotoDuplicada {
  const FotoDuplicada({
    required this.fecha,
    required this.origen,
    required this.exacta,
  });

  final DateTime fecha;

  /// Texto corto de dónde se usó ('un desafío', 'una observación').
  final String origen;

  /// true si es el mismo archivo byte a byte; false si es una versión
  /// reencodada/recortada de una foto ya usada.
  final bool exacta;

  String get mensaje {
    final f = formatoFecha(fecha);
    return exacta
        ? 'Ya usaste esta misma foto en $origen el $f. Toma una foto nueva.'
        : 'Esta foto es prácticamente idéntica a una que ya usaste en $origen '
              'el $f. Toma una foto nueva.';
  }
}

/// Bits distintos entre dos ahash en hexadecimal. 0 = idénticas.
///
/// Se compara nibble a nibble (4 bits) en vez de convertir el hex entero a
/// int: 64 bits no caben en el int de JavaScript, y la app también corre en
/// web.
int distanciaHamming(String hexA, String hexB) {
  if (hexA.length != hexB.length) return 64;
  var distancia = 0;
  for (var i = 0; i < hexA.length; i++) {
    final a = int.tryParse(hexA[i], radix: 16);
    final b = int.tryParse(hexB[i], radix: 16);
    if (a == null || b == null) return 64;
    var xor = a ^ b;
    while (xor != 0) {
      distancia += xor & 1;
      xor >>= 1;
    }
  }
  return distancia;
}

/// Convierte 64 píxeles RGBA (una miniatura de 8x8) en un average hash hex.
String ahashDesdeRgba(Uint8List rgba) {
  const total = 64;
  if (rgba.length < total * 4) return '';

  final grises = List<int>.filled(total, 0);
  var suma = 0;
  for (var i = 0; i < total; i++) {
    final o = i * 4;
    // Luminancia perceptual (Rec. 601): el verde pesa más que el azul.
    final gris =
        (rgba[o] * 299 + rgba[o + 1] * 587 + rgba[o + 2] * 114) ~/ 1000;
    grises[i] = gris;
    suma += gris;
  }

  final promedio = suma / total;
  final buffer = StringBuffer();
  for (var nibble = 0; nibble < total ~/ 4; nibble++) {
    var valor = 0;
    for (var bit = 0; bit < 4; bit++) {
      valor <<= 1;
      if (grises[nibble * 4 + bit] > promedio) valor |= 1;
    }
    buffer.write(valor.toRadixString(16));
  }
  return buffer.toString();
}

/// sha256 en hexadecimal. Es una función de nivel superior para poder
/// pasarla a `compute()`.
String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

/// Calcula las dos huellas de una imagen codificada (JPEG/PNG/...).
Future<HuellaFoto> calcularHuella(Uint8List bytes) async {
  // El sha256 de una foto de varios MB tarda lo suficiente como para saltarse
  // varios fotogramas; va a otro isolate para que la pantalla no se congele
  // justo cuando el explorador está esperando el resultado.
  final exacta = await compute(sha256Hex, bytes);

  String perceptual = '';
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 8,
      targetHeight: 8,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();
    if (data != null) perceptual = ahashDesdeRgba(data.buffer.asUint8List());
  } catch (e) {
    // Si el formato no se puede decodificar nos quedamos solo con el sha256.
    debugPrint('No se pudo calcular el ahash de la foto: $e');
  }

  return HuellaFoto(sha256: exacta, ahash: perceptual);
}

/// Registro de fotos ya usadas, para que la misma imagen no pueda sumar
/// progreso ni Veridiums dos veces.
///
/// Vive en `users/{uid}/fotos/{sha256}`: cada explorador solo ve y escribe
/// las suyas, y las reglas de Firestore prohíben borrarlas o modificarlas.
class HuellaFotoService {
  HuellaFotoService._();

  static final HuellaFotoService instance = HuellaFotoService._();

  /// Bits de diferencia que aún consideramos "la misma foto". Con 64 bits
  /// totales, 5 tolera recompresión y recortes leves sin marcar como
  /// repetidas dos fotos distintas del mismo pájaro.
  static const umbralParecido = 5;

  /// Cuántas huellas recientes se comparan. Suficiente para el uso real de
  /// un explorador y acota el costo de lecturas de Firestore.
  static const _maxHuellasRevisadas = 200;

  CollectionReference<Map<String, dynamic>> _coleccion(String userId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fotos');

  /// Devuelve la coincidencia si la foto ya se usó; null si es nueva.
  ///
  /// No registra nada: se llama ANTES de gastar una petición de IA.
  Future<FotoDuplicada?> buscarDuplicado({
    required String userId,
    required HuellaFoto huella,
  }) async {
    try {
      // La foto EXACTA se pregunta por su id, que es el propio sha256.
      //
      // Es una sola lectura en vez de recorrer la lista, nunca se queda
      // desactualizada, y de paso alcanza más lejos: antes solo se comparaba
      // contra las [_maxHuellasRevisadas] más recientes, así que quien
      // superara ese número podía reenviar una foto vieja y colaba.
      final exacta = await _coleccion(
        userId,
      ).doc(huella.sha256).get().timeout(const Duration(seconds: 12));
      if (exacta.exists) {
        final data = exacta.data() ?? const <String, dynamic>{};
        return FotoDuplicada(
          fecha: deIso(data['fecha'] as String?) ?? DateTime.now(),
          origen: data['origen'] as String? ?? 'una captura anterior',
          exacta: true,
        );
      }

      // Las PARECIDAS sí hay que recorrerlas: un ahash no se puede buscar por
      // igualdad, hay que comparar bit a bit contra cada una.
      for (final registro in await _huellasDe(userId)) {
        if (huella.ahash.isEmpty || registro.ahash.isEmpty) continue;
        if (distanciaHamming(registro.ahash, huella.ahash) <= umbralParecido) {
          return FotoDuplicada(
            fecha: registro.fecha,
            origen: registro.origen,
            exacta: false,
          );
        }
      }
    } catch (e) {
      // Sin conexión no bloqueamos al explorador: preferimos dejar pasar la
      // foto antes que impedirle avanzar por un fallo de red.
      debugPrint('No se pudo revisar el historial de fotos: $e');
    }
    return null;
  }

  /// Las huellas del explorador, descargadas como mucho una vez cada
  /// [_frescura].
  ///
  /// Antes esta lista se bajaba ENTERA en cada análisis. Como Firebase cobra
  /// por documento leído, el precio de analizar una foto crecía con el número
  /// de fotos ya tomadas —hasta 200 lecturas por intento— y el plan gratuito
  /// da 50.000 al día para toda la app.
  ///
  /// Quedarse con una copia en memoria es seguro porque esta colección solo
  /// CRECE: las reglas de Firestore prohíben borrar y modificar huellas, así
  /// que lo único que puede faltar en la copia es algo añadido después, y de
  /// eso se encarga [registrar]. Lo único que se escapa es una foto subida
  /// desde OTRO dispositivo en los últimos minutos, y aun ese caso lo atrapa
  /// la comprobación exacta de arriba, que siempre pregunta al servidor.
  Future<List<_HuellaGuardada>> _huellasDe(String userId) async {
    final cache = _cache;
    final desde = _cacheEn;
    if (cache != null &&
        _cacheDe == userId &&
        desde != null &&
        DateTime.now().difference(desde) < _frescura) {
      return cache;
    }

    final snapshot = await _coleccion(userId)
        .orderBy('fecha', descending: true)
        .limit(_maxHuellasRevisadas)
        .get()
        .timeout(const Duration(seconds: 12));

    final lista = [
      for (final doc in snapshot.docs)
        _HuellaGuardada(
          ahash: doc.data()['ahash'] as String? ?? '',
          fecha: deIso(doc.data()['fecha'] as String?) ?? DateTime.now(),
          origen: doc.data()['origen'] as String? ?? 'una captura anterior',
        ),
    ];

    _cache = lista;
    _cacheDe = userId;
    _cacheEn = DateTime.now();
    return lista;
  }

  List<_HuellaGuardada>? _cache;
  String? _cacheDe;
  DateTime? _cacheEn;

  static const _frescura = Duration(minutes: 10);

  /// Marca la foto como usada. Se llama solo cuando la captura ya contó.
  Future<void> registrar({
    required String userId,
    required HuellaFoto huella,
    required String origen,
    String? referenciaId,
  }) async {
    try {
      final ahora = DateTime.now();
      await _coleccion(userId).doc(huella.sha256).set({
        ...huella.toMap(),
        'origen': origen,
        'referenciaId': referenciaId,
        'fecha': aIsoUtc(ahora),
      });

      // Al día en memoria sin volver a preguntar: si no, dos fotos parecidas
      // seguidas —el caso más obvio de repetir— pasarían las dos.
      final cache = _cache;
      if (cache != null && _cacheDe == userId) {
        _cache = [
          _HuellaGuardada(ahash: huella.ahash, fecha: ahora, origen: origen),
          ...cache,
        ];
      }
    } catch (e) {
      debugPrint('No se pudo registrar la huella de la foto: $e');
    }
  }
}

/// Una huella ya guardada, con lo justo para comparar y para poder decir
/// dónde y cuándo se usó.
class _HuellaGuardada {
  const _HuellaGuardada({
    required this.ahash,
    required this.fecha,
    required this.origen,
  });

  final String ahash;
  final DateTime fecha;
  final String origen;
}
