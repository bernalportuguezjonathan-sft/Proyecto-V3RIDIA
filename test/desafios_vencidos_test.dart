import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/desafio.dart';

/// Qué desafíos siguen abiertos.
///
/// El filtro se prueba aquí y no contra el repositorio porque ese es un
/// singleton que necesita Firebase; lo que decide todo es `Challenge.vencido`
/// y la regla de qué se muestra, y las dos son aritmética de fechas.
Challenge _reto({
  required String id,
  required DateTime vence,
  String? asignadoA,
}) => Challenge(
  id: id,
  title: id,
  description: '',
  targetSpecies: 'colibrí',
  targetGoal: 5,
  dueDate: vence,
  createdDate: DateTime(2026, 1, 1),
  assignedToUserId: asignadoA,
);

void main() {
  final ahora = DateTime.now();

  group('Challenge.vencido', () {
    test('uno de la semana que viene sigue abierto', () {
      expect(
        _reto(id: 'a', vence: ahora.add(const Duration(days: 7))).vencido,
        isFalse,
      );
    });

    test('uno de la semana pasada está vencido', () {
      expect(
        _reto(id: 'b', vence: ahora.subtract(const Duration(days: 7))).vencido,
        isTrue,
      );
    });

    test('el de la captura del usuario, que seguía saliendo activo', () {
      // Vencía el 07/09/2026 y se mostraba como si nada.
      expect(_reto(id: 'planta', vence: DateTime(2026, 9, 7)).vencido, isTrue);
    });

    test('uno que vence dentro de un minuto todavía cuenta', () {
      // La frontera importa: si se redondeara al día, un reto se cerraría
      // horas antes de tiempo y las fotos de esa tarde no sumarían.
      expect(
        _reto(id: 'c', vence: ahora.add(const Duration(minutes: 1))).vencido,
        isFalse,
      );
    });
  });

  group('lo que ve el explorador', () {
    // Mismo criterio que `ChallengeRepository.challengesVigentesPara`.
    List<Challenge> vigentes(List<Challenge> todos, String? uid) => todos
        .where((c) => c.isGlobal || c.assignedToUserId == uid)
        .where((c) => !c.vencido)
        .toList();

    final abierto = _reto(
      id: 'abierto',
      vence: ahora.add(const Duration(days: 3)),
    );
    final cerrado = _reto(
      id: 'cerrado',
      vence: ahora.subtract(const Duration(days: 3)),
    );
    final deOtro = _reto(
      id: 'de_otro',
      vence: ahora.add(const Duration(days: 3)),
      asignadoA: 'uid_beto',
    );
    final mioAbierto = _reto(
      id: 'mio',
      vence: ahora.add(const Duration(days: 3)),
      asignadoA: 'uid_ana',
    );

    test('los vencidos no se muestran', () {
      final r = vigentes([abierto, cerrado], 'uid_ana');
      expect(r.map((c) => c.id), ['abierto']);
    });

    test('sigue sin ver los de otro explorador', () {
      // El filtro nuevo no puede haber abierto la puerta a los ajenos.
      final r = vigentes([abierto, deOtro, mioAbierto], 'uid_ana');
      expect(r.map((c) => c.id).toSet(), {'abierto', 'mio'});
    });

    test('si todos vencieron, la lista queda vacía', () {
      expect(vigentes([cerrado], 'uid_ana'), isEmpty);
    });

    test('sin sesión solo se ven los globales abiertos', () {
      final r = vigentes([abierto, cerrado, mioAbierto], null);
      expect(r.map((c) => c.id), ['abierto']);
    });
  });

  group('lo que ve el administrador', () {
    test('los vencidos bajan al final pero NO desaparecen', () {
      // Es la pantalla desde la que se borran: ocultarlos los dejaría en la
      // base de datos sin forma de llegar a ellos.
      final cerradoViejo = _reto(
        id: 'cerrado',
        vence: ahora.subtract(const Duration(days: 30)),
      );
      final abierto1 = _reto(
        id: 'a1',
        vence: ahora.add(const Duration(days: 2)),
      );
      final abierto2 = _reto(
        id: 'a2',
        vence: ahora.add(const Duration(days: 9)),
      );

      final ordenados = [cerradoViejo, abierto1, abierto2]
        ..sort((a, b) {
          if (a.vencido != b.vencido) return a.vencido ? 1 : -1;
          return b.createdDate.compareTo(a.createdDate);
        });

      expect(ordenados.length, 3, reason: 'no se pierde ninguno');
      expect(ordenados.last.id, 'cerrado');
      expect(ordenados.first.vencido, isFalse);
    });
  });
}
