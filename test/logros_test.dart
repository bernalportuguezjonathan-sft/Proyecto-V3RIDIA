import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/logro.dart';
import 'package:veridia_app/models/observation.dart';
import 'package:veridia_app/models/recompensa.dart';

/// Logros: lo que se gana haciendo, no comprando.
void main() {
  Observation foto(String especie, {int dia = 1}) => Observation(
    id: '$especie-$dia',
    commonName: especie,
    scientificName: 'Xxx yyy',
    location: 'Funza',
    notes: '',
    dateTime: DateTime(2026, 8, dia),
  );

  group('EstadisticasExplorador', () {
    test('cuenta registros, especies distintas y lo que se le pasa', () {
      final stats = EstadisticasExplorador.de(
        veridiumsGanados: 300,
        fotos: [foto('Garza'), foto('Garza', dia: 2), foto('Mirla')],
        desafios: 4,
      );
      expect(stats.registros, 3);
      expect(stats.especiesDistintas, 2);
      expect(stats.veridiumsGanados, 300);
      expect(stats.desafios, 4);
    });

    test('no cuenta como especie lo que la IA no identificó', () {
      // Si contaran, tres fotos borrosas valdrían un certificado.
      final stats = EstadisticasExplorador.de(
        veridiumsGanados: 0,
        fotos: [
          foto('Especie observada'),
          foto('Sin confirmar'),
          foto('Referencia visual'),
          foto('Colibrí Chillón'),
        ],
        desafios: 0,
      );
      expect(stats.registros, 4);
      expect(stats.especiesDistintas, 1);
    });

    test('la misma especie con otra grafía no cuenta dos veces', () {
      final stats = EstadisticasExplorador.de(
        veridiumsGanados: 0,
        fotos: [foto('Colibrí Chillón'), foto('  colibrí chillón  ')],
        desafios: 0,
      );
      expect(stats.especiesDistintas, 1);
    });
  });

  group('catálogo de logros', () {
    test('no hay ids repetidos', () {
      final ids = catalogoLogros.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('todos piden algo y explican qué', () {
      for (final logro in catalogoLogros) {
        expect(logro.meta, greaterThan(0), reason: logro.id);
        expect(logro.nombre, isNotEmpty);
        expect(logro.descripcion, isNotEmpty);
        expect(logro.requisito, contains('${logro.meta}'));
      }
    });

    test('el certificado de contribución YA NO se compra', () {
      // Era una recompensa de 120 Veridiums: cualquiera con saldo lo tenía
      // sin haber aportado una sola especie al monitoreo.
      expect(recompensaPorId('certificado_aporte'), isNull);
      expect(logroPorId('certificado_aporte'), isNotNull);
    });

    test('el certificado se gana con especies aportadas', () {
      final certificado = logroPorId('certificado_aporte')!;
      expect(certificado.metrica, MetricaLogro.especiesDistintas);

      const justoAntes = EstadisticasExplorador(especiesDistintas: 19);
      const justo = EstadisticasExplorador(especiesDistintas: 20);
      expect(certificado.conseguido(justoAntes), isFalse);
      expect(certificado.conseguido(justo), isTrue);
    });

    test('tener muchos Veridiums no regala el certificado', () {
      // Es justo el fallo del diseño anterior: saldo ≠ aporte.
      const rico = EstadisticasExplorador(
        veridiumsGanados: 100000,
        especiesDistintas: 2,
      );
      expect(logroPorId('certificado_aporte')!.conseguido(rico), isFalse);
    });
  });

  group('progreso y reparto', () {
    const nadie = EstadisticasExplorador();

    test('sin nada hecho no hay ningún logro', () {
      expect(logrosConseguidos(nadie), isEmpty);
      expect(logrosPendientes(nadie).length, catalogoLogros.length);
    });

    test('conseguidos y pendientes nunca se solapan ni pierden nada', () {
      const stats = EstadisticasExplorador(
        veridiumsGanados: 200,
        especiesDistintas: 12,
        registros: 30,
        desafios: 1,
      );
      final ganados = logrosConseguidos(stats);
      final faltan = logrosPendientes(stats);
      expect(ganados.length + faltan.length, catalogoLogros.length);
      expect(
        ganados
            .map((l) => l.id)
            .toSet()
            .intersection(faltan.map((l) => l.id).toSet()),
        isEmpty,
      );
    });

    test('lo pendiente sale ordenado por cercanía', () {
      // Una meta cercana empuja; cinco lejanas desaniman. La primera de la
      // lista es la que la interfaz enseña.
      const stats = EstadisticasExplorador(especiesDistintas: 19);
      final faltan = logrosPendientes(stats);
      expect(faltan.first.id, 'certificado_aporte');
    });

    test('el progreso va de 0 a 1 y no se pasa', () {
      final logro = logroPorId('ojo_entrenado')!;
      expect(logro.progreso(nadie), 0.0);
      expect(
        logro.progreso(const EstadisticasExplorador(especiesDistintas: 5)),
        closeTo(0.5, 0.001),
      );
      expect(
        logro.progreso(const EstadisticasExplorador(especiesDistintas: 999)),
        1.0,
      );
    });

    test('lo que falta nunca es negativo', () {
      final logro = logroPorId('ojo_entrenado')!;
      expect(
        logro.restante(const EstadisticasExplorador(especiesDistintas: 999)),
        0,
      );
      expect(logro.restante(nadie), logro.meta);
    });
  });

  group('unidades', () {
    test('el singular y el plural se escriben bien', () {
      expect(MetricaLogro.especiesDistintas.unidad(1), 'especie distinta');
      expect(MetricaLogro.especiesDistintas.unidad(3), 'especies distintas');
      expect(MetricaLogro.registros.unidad(1), 'registro');
      expect(MetricaLogro.desafios.unidad(2), 'desafíos completados');
    });
  });
}
