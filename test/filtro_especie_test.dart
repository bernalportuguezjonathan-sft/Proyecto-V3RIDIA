import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/especie_ia_service.dart';

/// El filtro que decide qué entra al mapa comunitario.
///
/// Los avistamientos los ve todo el mundo y no se pueden depurar después uno
/// por uno, así que cada caso de aquí es una foto que NO debe poder guardarse.
void main() {
  group('evaluarRespuestaIA — lo que sí sirve', () {
    test('una especie reconocida en vivo pasa', () {
      final e = evaluarRespuestaIA(
        identificado: true,
        esSerVivo: true,
        categoriaNoValida: 'ninguna',
        esPantalla: false,
      );
      expect(e.sirve, isTrue);
      expect(e.rechazo, MotivoRechazo.ninguno);
      expect(e.mensaje, isNull);
    });

    test('sin los campos nuevos se comporta como antes', () {
      // Respaldo: si el modelo responde con el formato viejo, `identificado`
      // sigue mandando y la app no se queda sin identificar nada.
      final e = evaluarRespuestaIA(identificado: true);
      expect(e.sirve, isTrue);
    });
  });

  group('evaluarRespuestaIA — personas y objetos', () {
    test('rechaza una persona aunque la IA la haya identificado', () {
      final e = evaluarRespuestaIA(
        identificado: true,
        esSerVivo: false,
        categoriaNoValida: 'persona',
        esPantalla: false,
      );
      expect(e.sirve, isFalse);
      expect(e.rechazo, MotivoRechazo.noEsSerVivo);
      expect(e.mensaje, contains('una persona'));
    });

    test('rechaza un objeto', () {
      final e = evaluarRespuestaIA(
        identificado: true,
        esSerVivo: false,
        categoriaNoValida: 'objeto',
      );
      expect(e.rechazo, MotivoRechazo.noEsSerVivo);
    });

    test('una categoría no válida manda aunque es_ser_vivo venga en true', () {
      // Respuesta incoherente del modelo: ante la duda, no entra.
      final e = evaluarRespuestaIA(
        identificado: true,
        esSerVivo: true,
        categoriaNoValida: 'vehiculo',
      );
      expect(e.sirve, isFalse);
      expect(e.rechazo, MotivoRechazo.noEsSerVivo);
    });

    test('una categoría desconocida también rechaza', () {
      final e = evaluarRespuestaIA(
        identificado: true,
        esSerVivo: false,
        categoriaNoValida: 'algo_que_no_esta_en_la_lista',
      );
      expect(e.sirve, isFalse);
      expect(e.mensaje, contains('no es una especie'));
    });
  });

  group('evaluarRespuestaIA — fotos de pantallas', () {
    test('rechaza una especie real fotografiada de una pantalla', () {
      // El caso de buscar el ave en el portátil y fotografiar el monitor.
      final e = evaluarRespuestaIA(
        identificado: true,
        esSerVivo: true,
        categoriaNoValida: 'ninguna',
        esPantalla: true,
      );
      expect(e.sirve, isFalse);
      expect(e.rechazo, MotivoRechazo.pantallaOImpresion);
      expect(e.mensaje, contains('en vivo'));
    });

    test('lo que no es ser vivo pesa más que la pantalla', () {
      // Foto de una pantalla que muestra un carro: lo útil es decirle que no
      // es una especie, no discutir sobre el monitor.
      final e = evaluarRespuestaIA(
        identificado: false,
        esSerVivo: false,
        categoriaNoValida: 'vehiculo',
        esPantalla: true,
      );
      expect(e.rechazo, MotivoRechazo.noEsSerVivo);
    });
  });

  group('evaluarRespuestaIA — no reconocida', () {
    test('conserva el motivo que dio la IA', () {
      final e = evaluarRespuestaIA(
        identificado: false,
        esSerVivo: true,
        categoriaNoValida: 'ninguna',
        motivoIA: 'La foto está demasiado borrosa.',
      );
      expect(e.rechazo, MotivoRechazo.noIdentificada);
      expect(e.mensaje, 'La foto está demasiado borrosa.');
    });

    test('pone un mensaje propio si la IA no dio motivo', () {
      final e = evaluarRespuestaIA(identificado: false, esSerVivo: true);
      expect(e.rechazo, MotivoRechazo.noIdentificada);
      expect(e.mensaje, isNotNull);
      expect(e.mensaje, contains('no reconoció'));
    });
  });

  group('SpeciesIdentification', () {
    test('identified es lo único que abre la puerta de guardar', () {
      const rechazada = SpeciesIdentification(
        identified: false,
        sha256: 'x',
        commonName: 'Ser humano',
        rechazo: MotivoRechazo.noEsSerVivo,
      );
      // Aunque traiga nombre común, no cuenta como especie identificada.
      expect(rechazada.identified, isFalse);
      expect(especieCoincide('Ser humano', rechazada), isTrue);
      // especieCoincide solo compara nombres; quien decide es `identified`,
      // y por eso desafios.dart exige las dos cosas.
    });
  });
}
