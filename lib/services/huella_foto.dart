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
      final snapshot = await _coleccion(userId)
          .orderBy('fecha', descending: true)
          .limit(_maxHuellasRevisadas)
          .get()
          .timeout(const Duration(seconds: 12));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fecha = deIso(data['fecha'] as String?) ?? DateTime.now();
        final origen = data['origen'] as String? ?? 'una captura anterior';

        if (doc.id == huella.sha256) {
          return FotoDuplicada(fecha: fecha, origen: origen, exacta: true);
        }

        final ahash = data['ahash'] as String? ?? '';
        if (huella.ahash.isEmpty || ahash.isEmpty) continue;
        if (distanciaHamming(ahash, huella.ahash) <= umbralParecido) {
          return FotoDuplicada(fecha: fecha, origen: origen, exacta: false);
        }
      }
    } catch (e) {
      // Sin conexión no bloqueamos al explorador: preferimos dejar pasar la
      // foto antes que impedirle avanzar por un fallo de red.
      debugPrint('No se pudo revisar el historial de fotos: $e');
    }
    return null;
  }

  /// Marca la foto como usada. Se llama solo cuando la captura ya contó.
  Future<void> registrar({
    required String userId,
    required HuellaFoto huella,
    required String origen,
    String? referenciaId,
  }) async {
    try {
      await _coleccion(userId).doc(huella.sha256).set({
        ...huella.toMap(),
        'origen': origen,
        'referenciaId': referenciaId,
        'fecha': aIsoUtc(DateTime.now()),
      });
    } catch (e) {
      debugPrint('No se pudo registrar la huella de la foto: $e');
    }
  }
}
