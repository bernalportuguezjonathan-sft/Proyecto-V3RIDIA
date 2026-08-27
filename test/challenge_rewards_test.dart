import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/desafio.dart';

/// Economía de Veridiums: 1 por cada foto verificada por la IA, más un bono
/// del 10% de la meta al completar el desafío.
void main() {
  group('calcularBonoCompletar', () {
    test('da el 10% de la meta redondeado hacia arriba', () {
      expect(calcularBonoCompletar(10), 1);
      expect(calcularBonoCompletar(20), 2);
      expect(calcularBonoCompletar(100), 10);
    });

    test('redondea hacia arriba cuando no es múltiplo de 10', () {
      expect(calcularBonoCompletar(15), 2);
      expect(calcularBonoCompletar(11), 2);
    });

    test('nunca da menos de 1 Veridium', () {
      expect(calcularBonoCompletar(1), 1);
      expect(calcularBonoCompletar(5), 1);
      expect(calcularBonoCompletar(0), 1);
      expect(calcularBonoCompletar(-3), 1);
    });

    test('nunca da más de 10 Veridiums, por grande que sea la meta', () {
      expect(calcularBonoCompletar(500), 10);
      expect(calcularBonoCompletar(10000), 10);
    });
  });

  group('Challenge', () {
    Challenge crear({required int meta}) => Challenge(
      id: 'c1',
      title: 'Fotografía aves',
      description: 'Registra aves de la Sabana',
      targetSpecies: 'Ave',
      targetGoal: meta,
      dueDate: DateTime(2026, 9, 1),
      createdDate: DateTime(2026, 8, 1),
    );

    test('el bono siempre se deriva de la meta', () {
      expect(crear(meta: 10).tokensReward, 1);
      expect(crear(meta: 50).tokensReward, 5);
    });

    test('ignora un tokensReward inflado guardado en Firestore', () {
      // Los desafíos creados antes traían un bono fijo de 100 en el
      // documento: leerlo hacía que una meta de 5 fotos pagara 100.
      final map = crear(meta: 5).toMap()..['tokensReward'] = 100;
      expect(Challenge.fromMap('c1', map).tokensReward, 1);
    });

    test('un desafío sin usuario asignado es global', () {
      expect(crear(meta: 10).isGlobal, isTrue);
    });

    test('sobrevive el viaje de ida y vuelta a Firestore', () {
      final original = crear(meta: 30);
      final copia = Challenge.fromMap('c1', original.toMap());

      expect(copia.id, original.id);
      expect(copia.title, original.title);
      expect(copia.targetSpecies, original.targetSpecies);
      expect(copia.targetGoal, original.targetGoal);
      expect(copia.tokensReward, original.tokensReward);
      expect(copia.completadoPor, original.completadoPor);
      expect(copia.dueDate, original.dueDate);
    });

    test('un documento viejo sin tokensReward deriva el bono de la meta', () {
      final map = crear(meta: 40).toMap()..remove('tokensReward');
      expect(Challenge.fromMap('c1', map).tokensReward, 4);
    });

    test('el desafío ya no guarda progreso: eso es de cada explorador', () {
      expect(crear(meta: 10).toMap().containsKey('currentProgress'), isFalse);
      expect(crear(meta: 10).toMap().containsKey('isCompleted'), isFalse);
    });

    test('actualizar no arrastra el contador de completados', () {
      // El contador lo mueve solo la Cloud Function guardarObservacion.
      final conCompletados = crear(meta: 10).copyWith(completadoPor: 4);
      expect(conCompletados.completadoPor, 4);
      expect(conCompletados.copyWith(title: 'Otro').completadoPor, 4);
    });
  });

  group('ProgresoDesafio', () {
    test('quien no ha empezado va en cero y sin bono', () {
      const vacio = ProgresoDesafio.vacio('c1');
      expect(vacio.progreso, 0);
      expect(vacio.completado, isFalse);
      expect(vacio.bonoPagado, isFalse);
    });

    test('sobrevive el viaje de ida y vuelta a Firestore', () {
      final original = ProgresoDesafio(
        challengeId: 'c1',
        progreso: 3,
        completado: false,
        bonoPagado: false,
        actualizado: DateTime(2026, 8, 25, 9),
      );
      final copia = ProgresoDesafio.fromMap('c1', original.toMap());

      expect(copia.challengeId, 'c1');
      expect(copia.progreso, 3);
      expect(copia.completado, isFalse);
      expect(copia.bonoPagado, isFalse);
      expect(copia.actualizado, original.actualizado);
    });

    test('un documento incompleto no rompe la lectura', () {
      final progreso = ProgresoDesafio.fromMap('c1', const {});
      expect(progreso.progreso, 0);
      expect(progreso.completado, isFalse);
    });
  });

  group('Veridiums entregados al avanzar', () {
    /// Réplica de la fórmula de la Cloud Function guardarObservacion (ver
    /// functions/index.js): no se puede llamar a la función real en estos
    /// tests porque necesita Firebase.
    int veridiumsPorAvance({
      required int meta,
      required int progresoPrevio,
      required int progresoNuevo,
      required bool bonoYaEntregado,
    }) {
      final normalizado = progresoNuevo.clamp(0, meta);
      final delta = normalizado - progresoPrevio;
      if (delta <= 0) return 0;
      final completa = normalizado >= meta;
      final entregarBono = completa && !bonoYaEntregado;
      return delta + (entregarBono ? calcularBonoCompletar(meta) : 0);
    }

    test('una foto normal da exactamente 1 Veridium', () {
      expect(
        veridiumsPorAvance(
          meta: 5,
          progresoPrevio: 1,
          progresoNuevo: 2,
          bonoYaEntregado: false,
        ),
        1,
      );
    });

    test('la foto que completa da 1 por la foto MÁS el bono', () {
      // Meta 20 -> bono 2, así que la última foto entrega 1 + 2 = 3.
      expect(
        veridiumsPorAvance(
          meta: 20,
          progresoPrevio: 19,
          progresoNuevo: 20,
          bonoYaEntregado: false,
        ),
        3,
      );
    });

    test('el bono no se entrega dos veces', () {
      expect(
        veridiumsPorAvance(
          meta: 20,
          progresoPrevio: 19,
          progresoNuevo: 20,
          bonoYaEntregado: true,
        ),
        1,
      );
    });

    test('no avanzar no da Veridiums', () {
      expect(
        veridiumsPorAvance(
          meta: 5,
          progresoPrevio: 3,
          progresoNuevo: 3,
          bonoYaEntregado: false,
        ),
        0,
      );
    });
  });
}
