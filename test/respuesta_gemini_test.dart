import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/especie_ia_service.dart';

/// Gemini no siempre devuelve texto. Cuando se niega, hay que tratarlo como
/// una respuesta más y no como un fallo técnico: reventar al leer `parts`
/// dejaba al explorador con "no se pudo interpretar la respuesta de la IA",
/// que no explica nada y le invita a reintentar en bucle.
void main() {
  group('motivoDeBloqueoGemini', () {
    test('una respuesta normal no está bloqueada', () {
      final r = motivoDeBloqueoGemini({
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': '{"identificado": true}'},
              ],
            },
          },
        ],
      });
      expect(r, isNull);
    });

    test('detecta el bloqueo de la petición entera', () {
      // Es la forma típica ante una foto de una persona.
      final r = motivoDeBloqueoGemini({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });
      expect(r, 'SAFETY');
    });

    test('detecta la respuesta sin candidatos', () {
      expect(motivoDeBloqueoGemini({}), 'SIN_CANDIDATOS');
      expect(motivoDeBloqueoGemini({'candidates': []}), 'SIN_CANDIDATOS');
    });

    test('detecta el candidato sin partes y devuelve su finishReason', () {
      final r = motivoDeBloqueoGemini({
        'candidates': [
          {'finishReason': 'SAFETY', 'content': {}},
        ],
      });
      expect(r, 'SAFETY');
    });

    test('detecta la respuesta cortada por longitud', () {
      // MAX_TOKENS deja el JSON a medias: antes reventaba al parsearlo.
      final r = motivoDeBloqueoGemini({
        'candidates': [
          {'finishReason': 'MAX_TOKENS', 'content': {}},
        ],
      });
      expect(r, 'MAX_TOKENS');
    });

    test('no se cae con formas inesperadas', () {
      expect(motivoDeBloqueoGemini({'candidates': 'texto'}), isNotNull);
      expect(
        motivoDeBloqueoGemini({
          'candidates': [42],
        }),
        isNotNull,
      );
      expect(
        motivoDeBloqueoGemini({
          'candidates': [
            {'content': 'no es un mapa'},
          ],
        }),
        isNotNull,
      );
    });
  });
}
