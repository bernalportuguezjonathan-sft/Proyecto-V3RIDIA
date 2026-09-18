import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/desafio.dart';

/// El campo "Meta" de los formularios de desafío.
///
/// Se prueba porque lo que había antes —solo comprobar que no estuviera
/// vacío— dejaba pasar dos cosas que rompían la app más adelante y no en el
/// formulario, que es donde se habrían visto.
void main() {
  group('validarMeta', () {
    test('acepta un número normal', () {
      expect(validarMeta('5'), isNull);
      expect(validarMeta(' 12 '), isNull);
    });

    test('rechaza texto que no es un número', () {
      // El caso que reventaba: `TextInputType.number` solo sugiere teclado,
      // no impide escribir letras ni pegar texto. En el panel del
      // administrador el `int.parse` de después no tenía try/catch alrededor.
      expect(validarMeta('cinco'), isNotNull);
      expect(validarMeta('5 fotos'), isNotNull);
      expect(validarMeta('3.5'), isNotNull);
    });

    test('rechaza cero y negativos', () {
      // Un desafío de meta 0 nacía ya terminado: `registrarFoto` corta en
      // cuanto el progreso alcanza la meta, así que ninguna foto lo movía.
      expect(validarMeta('0'), isNotNull);
      expect(validarMeta('-3'), isNotNull);
    });

    test('rechaza vacío', () {
      expect(validarMeta(null), isNotNull);
      expect(validarMeta('   '), isNotNull);
    });

    test('rechaza metas imposibles', () {
      // El bono está topado en 10 Veridiums, así que pedir 500 fotos no paga
      // más: solo crea algo que nadie va a terminar.
      expect(validarMeta('$metaMaxima'), isNull);
      expect(validarMeta('${metaMaxima + 1}'), isNotNull);
    });
  });

  group('leerMeta', () {
    test('lee lo que el validador dejó pasar', () {
      expect(leerMeta('7'), 7);
      expect(leerMeta(' 7 '), 7);
    });

    test('nunca devuelve una meta inservible', () {
      // Red por si algún día se guarda desde un sitio que no pasó por el
      // formulario: vale más una meta de 1 que un desafío muerto.
      expect(leerMeta('0'), 1);
      expect(leerMeta('abc'), 1);
      expect(leerMeta('99999'), metaMaxima);
    });
  });
}
