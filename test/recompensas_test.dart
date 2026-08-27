import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/analitica.dart';
import 'package:veridia_app/models/observation.dart';
import 'package:veridia_app/models/recompensa.dart';

/// Catálogo de recompensas (para qué sirven los Veridiums) y los cálculos de
/// la analítica del administrador.
void main() {
  group('catálogo de recompensas', () {
    test('todos los ids son únicos', () {
      final ids = catalogoRecompensas.map((r) => r.id).toSet();
      expect(ids.length, catalogoRecompensas.length);
    });

    test('está ordenado de más barata a más cara', () {
      final costos = catalogoRecompensas.map((r) => r.costo).toList();
      final ordenados = [...costos]..sort();
      expect(costos, ordenados);
    });

    test('ninguna recompensa es gratis', () {
      expect(catalogoRecompensas.every((r) => r.costo > 0), isTrue);
    });

    test('las que cambian el perfil llevan el valor que aplican', () {
      final digitales = catalogoRecompensas.where((r) => r.tipo.cambiaElPerfil);
      expect(digitales.every((r) => (r.valor ?? '').isNotEmpty), isTrue);
    });

    test('solo las experiencias se pueden canjear más de una vez', () {
      expect(TipoRecompensa.fisica.repetible, isTrue);
      expect(TipoRecompensa.insignia.repetible, isFalse);
      expect(TipoRecompensa.marco.repetible, isFalse);
      expect(TipoRecompensa.titulo.repetible, isFalse);
    });

    test('las experiencias no cambian nada visible del perfil', () {
      expect(TipoRecompensa.fisica.cambiaElPerfil, isFalse);
      expect(TipoRecompensa.insignia.cambiaElPerfil, isTrue);
    });

    test('recompensaPorId encuentra y devuelve null si no existe', () {
      expect(recompensaPorId('insignia_explorador')?.costo, 10);
      expect(recompensaPorId('no_existe'), isNull);
    });
  });

  group('Canje', () {
    test('sobrevive la ida y vuelta a Firestore', () {
      final original = Canje(
        id: 'c1',
        userId: 'u1',
        userDisplayName: 'Samuel',
        recompensaId: 'kit_campo',
        nombre: 'Kit de campo Veridia',
        costo: 300,
        fecha: DateTime(2026, 8, 24, 10, 30),
        estado: EstadoCanje.activo,
      );

      final copia = Canje.fromMap('c1', original.toMap());

      expect(copia.userDisplayName, 'Samuel');
      expect(copia.recompensaId, 'kit_campo');
      expect(copia.costo, 300);
      expect(copia.estado, EstadoCanje.activo);
      expect(copia.fecha, original.fecha);
      expect(copia.recompensa?.nombre, 'Kit de campo Veridia');
    });

    test('un estado desconocido no rompe la lectura', () {
      expect(estadoCanjeDesde(null), EstadoCanje.activo);
      expect(estadoCanjeDesde('cualquier_cosa'), EstadoCanje.activo);
      expect(estadoCanjeDesde('entregado'), EstadoCanje.entregado);
    });
  });

  group('analítica', () {
    Observation obs(String especie, DateTime fecha) => Observation(
      id: fecha.microsecondsSinceEpoch.toString(),
      commonName: especie,
      scientificName: '',
      location: '',
      notes: '',
      dateTime: fecha,
    );

    test('ranking ordena por cantidad y corta en el top', () {
      final resultado = ranking([
        'Garza',
        'Garza',
        'Garza',
        'Tingua',
        'Tingua',
        'Colibrí',
      ], top: 2);

      expect(resultado.map((e) => e.key), ['Garza', 'Tingua']);
      expect(resultado.first.value, 3);
    });

    test('ranking ignora vacíos', () {
      expect(ranking(['', '   ', 'Garza']).length, 1);
    });

    test('enRango deja fuera lo anterior a la ventana', () {
      final hoy = DateTime.now();
      final lista = [
        obs('Garza', hoy),
        obs('Tingua', hoy.subtract(const Duration(days: 10))),
        obs('Vieja', hoy.subtract(const Duration(days: 60))),
      ];

      expect(enRango(lista, 7).length, 1);
      expect(enRango(lista, 30).length, 2);
      expect(enRango(lista, 90).length, 3);
    });

    test(
      'especieIdentificada descarta los marcadores de "sin identificar"',
      () {
        final hoy = DateTime.now();
        expect(especieIdentificada(obs('Garza real', hoy)), isTrue);
        expect(especieIdentificada(obs('Especie observada', hoy)), isFalse);
        expect(especieIdentificada(obs('sin confirmar', hoy)), isFalse);
      },
    );

    test('rankingPorId cuenta por id y muestra el nombre', () {
      // Dos exploradores distintos con el mismo nombre no deben fusionarse.
      final resultado = rankingPorId([
        'u1',
        'u1',
        'u2',
      ], etiqueta: (id) => id == 'u1' ? 'Samuel' : 'Samuel');

      expect(resultado.length, 2);
      expect(resultado.first.value, 2);
      expect(resultado.every((e) => e.key == 'Samuel'), isTrue);
    });

    test('rankingPorId marca los ids sin dueño', () {
      final resultado = rankingPorId([
        'borrado',
      ], etiqueta: (id) => id == 'borrado' ? 'Cuenta eliminada' : id);
      expect(resultado.single.key, 'Cuenta eliminada');
    });

    test('agruparSerie suma días consecutivos sin perder el total', () {
      final serie = List<int>.filled(30, 1);
      final agrupada = agruparSerie(serie, 10);

      expect(agrupada.length, 10);
      expect(agrupada.reduce((a, b) => a + b), 30);
    });

    test('agruparSerie no toca una serie que ya cabe', () {
      final serie = [1, 2, 3];
      expect(agruparSerie(serie, 10), serie);
    });

    test('actividadPorDia cuenta solo la ventana pedida', () {
      final hoy = DateTime.now();
      final serie = actividadPorDia([
        obs('Garza', hoy),
        obs('Garza', hoy),
        obs('Tingua', hoy.subtract(const Duration(days: 2))),
        obs('Vieja', hoy.subtract(const Duration(days: 30))),
      ]);

      expect(serie.length, 7);
      expect(serie.last, 2); // hoy
      expect(serie[4], 1); // hace 2 días
      expect(serie.reduce((a, b) => a + b), 3); // la de hace 30 días no cuenta
    });
  });
}
