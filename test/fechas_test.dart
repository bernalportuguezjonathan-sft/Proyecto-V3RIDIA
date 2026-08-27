import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/observation.dart';
import 'package:veridia_app/theme/veridia_theme.dart';

/// Formato y almacenamiento de fechas.
///
/// Se guardan en UTC porque Firestore ordena estos campos como texto: con la
/// hora local y sin zona horaria, dos dispositivos en husos distintos daban un
/// orden cronológico falso.
void main() {
  group('formatoFecha', () {
    test('rellena con ceros a la izquierda', () {
      expect(formatoFecha(DateTime(2026, 8, 5)), '05/08/2026');
      expect(formatoFecha(DateTime(2026, 12, 25)), '25/12/2026');
    });

    test('convierte a hora local antes de pintar', () {
      // Medianoche UTC del 25 es el 24 por la tarde en Colombia (UTC-5).
      final enUtc = DateTime.utc(2026, 8, 25, 2);
      expect(formatoFecha(enUtc), formatoFecha(enUtc.toLocal()));
    });
  });

  group('formatoFechaHora', () {
    test('incluye hora y minuto con dos dígitos', () {
      expect(formatoFechaHora(DateTime(2026, 8, 5, 9, 7)), '05/08/2026 09:07');
    });
  });

  group('aIsoUtc / deIso', () {
    test('guarda siempre en UTC', () {
      final texto = aIsoUtc(DateTime(2026, 8, 25, 14, 30));
      expect(texto.endsWith('Z'), isTrue);
    });

    test('el viaje de ida y vuelta conserva el instante', () {
      final original = DateTime(2026, 8, 25, 14, 30, 15);
      final recuperada = deIso(aIsoUtc(original));

      expect(recuperada, isNotNull);
      expect(recuperada!.isAtSameMomentAs(original), isTrue);
    });

    test('deIso devuelve hora local, no UTC', () {
      final recuperada = deIso(aIsoUtc(DateTime(2026, 8, 25, 14, 30)));
      expect(recuperada!.isUtc, isFalse);
    });

    test('sigue leyendo las fechas locales que ya estaban guardadas', () {
      // Documentos escritos antes de este cambio: sin la Z final.
      final antigua = deIso('2026-08-25T14:30:00.000');
      expect(antigua, DateTime(2026, 8, 25, 14, 30));
    });

    test('un texto inválido o vacío da null', () {
      expect(deIso(null), isNull);
      expect(deIso(''), isNull);
      expect(deIso('ayer'), isNull);
    });
  });

  group('Observation con fechas UTC', () {
    test('el instante sobrevive a Firestore', () {
      final original = Observation(
        id: 'o1',
        commonName: 'Garza real',
        scientificName: 'Ardea alba',
        location: 'Humedal',
        notes: '',
        dateTime: DateTime(2026, 8, 25, 16, 45),
      );

      final copia = Observation.fromMap('o1', original.toMap());
      expect(copia.dateTime.isAtSameMomentAs(original.dateTime), isTrue);
    });
  });
}
