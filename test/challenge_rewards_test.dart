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
  });

  group('Challenge', () {
    Challenge crear({required int meta, int? premio}) => Challenge(
      id: 'c1',
      title: 'Fotografía aves',
      description: 'Registra aves de la Sabana',
      targetSpecies: 'Ave',
      targetGoal: meta,
      dueDate: DateTime(2026, 9, 1),
      createdDate: DateTime(2026, 8, 1),
      currentProgress: 0,
      isCompleted: false,
      tokensReward: premio,
    );

    test('calcula el bono a partir de la meta si no se indica', () {
      expect(crear(meta: 10).tokensReward, 1);
      expect(crear(meta: 50).tokensReward, 5);
    });

    test('respeta un premio explícito', () {
      expect(crear(meta: 10, premio: 42).tokensReward, 42);
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
      expect(copia.currentProgress, original.currentProgress);
      expect(copia.isCompleted, original.isCompleted);
      expect(copia.dueDate, original.dueDate);
    });

    test('un documento viejo sin tokensReward deriva el bono de la meta', () {
      final map = crear(meta: 40).toMap()..remove('tokensReward');
      expect(Challenge.fromMap('c1', map).tokensReward, 4);
    });
  });

  group('Veridiums entregados al avanzar', () {
    /// Réplica de la fórmula de ChallengeRepository.updateProgress: no se puede
    /// llamar al repositorio en tests porque necesita Firebase.
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
