import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/user.dart';

/// Un solo perfil por correo en el desplegable del administrador.
///
/// El caso real: dos documentos distintos con `julianbanjou@gmail.com`, uno
/// por cuenta de correo y otro por Google. Firebase Auth da uid distinto, así
/// que para Firestore son dos usuarios.
UserProfile _perfil(
  String uid,
  String correo, {
  String nombre = 'Alguien',
  int totales = 0,
  DateTime? creado,
  String rol = 'Explorador',
}) => UserProfile(
  userId: uid,
  email: correo,
  displayName: nombre,
  photoURL: null,
  tokens: 0,
  tokensTotales: totales,
  role: rol,
  createdDate: creado ?? DateTime(2026, 1, 1),
  isBanned: false,
);

void main() {
  group('unoPorCorreo', () {
    test('deja uno solo cuando el correo se repite', () {
      final r = unoPorCorreo([
        _perfil('uid_a', 'julianbanjou@gmail.com', nombre: 'Julian Banjou'),
        _perfil('uid_b', 'julianbanjou@gmail.com', nombre: 'Julian Banjou'),
      ]);
      expect(r.length, 1);
    });

    test('se queda con el que tiene el recorrido', () {
      // Lo que no puede pasar: enseñar la cuenta vacía y que el admin le
      // asigne el desafío ahí, donde la persona no entra nunca.
      final r = unoPorCorreo([
        _perfil('vacia', 'a@b.c', totales: 0),
        _perfil('usada', 'a@b.c', totales: 800),
      ]);
      expect(r.single.userId, 'usada');
    });

    test('el orden de entrada no cambia quién gana', () {
      final r = unoPorCorreo([
        _perfil('usada', 'a@b.c', totales: 800),
        _perfil('vacia', 'a@b.c', totales: 0),
      ]);
      expect(r.single.userId, 'usada');
    });

    test('a igual recorrido gana la cuenta más antigua', () {
      final r = unoPorCorreo([
        _perfil('nueva', 'a@b.c', creado: DateTime(2026, 9, 1)),
        _perfil('vieja', 'a@b.c', creado: DateTime(2026, 2, 1)),
      ]);
      expect(r.single.userId, 'vieja');
    });

    test('correos distintos NO se fusionan', () {
      final r = unoPorCorreo([
        _perfil('a', 'uno@b.c'),
        _perfil('b', 'dos@b.c'),
        _perfil('c', 'tres@b.c'),
      ]);
      expect(r.length, 3);
    });

    test('mayúsculas y espacios cuentan como el mismo correo', () {
      final r = unoPorCorreo([
        _perfil('a', 'Julian@Gmail.com'),
        _perfil('b', '  julian@gmail.com '),
      ]);
      expect(r.length, 1);
    });

    test('quien no tiene correo no se descarta', () {
      // Sin correo no hay forma de saber si es duplicado; esconderlo
      // ocultaría una cuenta real.
      final r = unoPorCorreo([
        _perfil('a', ''),
        _perfil('b', ''),
        _perfil('c', 'uno@b.c'),
      ]);
      expect(r.length, 3);
    });

    test('la lista sale ordenada por nombre', () {
      final r = unoPorCorreo([
        _perfil('c', 'c@b.c', nombre: 'Zoe'),
        _perfil('a', 'a@b.c', nombre: 'ana'),
        _perfil('b', 'b@b.c', nombre: 'Beto'),
      ]);
      expect(r.map((p) => p.displayName), ['ana', 'Beto', 'Zoe']);
    });

    test('una lista vacía no revienta', () {
      expect(unoPorCorreo([]), isEmpty);
    });
  });

  _pruebasDeAgrupado();
}

// --- Agrupado para la pantalla de moderación -------------------------------
// Ahí NO basta con esconder los duplicados: es la única pantalla desde la que
// se borran, así que tienen que seguir alcanzables.

void _pruebasDeAgrupado() {
  group('agruparPorCorreo', () {
    test('el caso de la captura: tres iguales y uno distinto', () {
      final grupos = agruparPorCorreo([
        _perfil('a', 'mahechadaniel54@gmail.com', nombre: 'Daniel Mahecha'),
        _perfil('b', 'mahechadaniel53@gmail.com', nombre: 'Daniel Mahecha'),
        _perfil('c', 'mahechadaniel54@gmail.com', nombre: 'Daniel Mahecha'),
        _perfil('d', 'mahechadaniel54@gmail.com', nombre: 'Daniel Mahecha'),
      ]);
      // Dos tarjetas: un correo con tres cuentas y otro con una.
      expect(grupos.length, 2);
      final conTres = grupos.firstWhere((g) => g.cuantas == 3);
      expect(conTres.duplicados.length, 2);
      expect(grupos.firstWhere((g) => g.cuantas == 1).hayDuplicados, isFalse);
    });

    test('no se pierde ninguna cuenta al agrupar', () {
      final entrada = [
        _perfil('a', 'x@b.c', totales: 100),
        _perfil('b', 'x@b.c', totales: 0),
        _perfil('c', 'y@b.c'),
      ];
      final grupos = agruparPorCorreo(entrada);
      final total = grupos.fold<int>(0, (n, g) => n + g.cuantas);
      expect(total, entrada.length, reason: 'todas siguen alcanzables');
    });

    test('la principal es la del recorrido y las otras son duplicados', () {
      final grupos = agruparPorCorreo([
        _perfil('vacia', 'x@b.c', totales: 0),
        _perfil('usada', 'x@b.c', totales: 500),
      ]);
      expect(grupos.single.principal.userId, 'usada');
      expect(grupos.single.duplicados.single.userId, 'vacia');
    });

    test('la principal nunca aparece entre sus propios duplicados', () {
      final grupos = agruparPorCorreo([
        _perfil('a', 'x@b.c', totales: 10),
        _perfil('b', 'x@b.c', totales: 10),
      ]);
      final g = grupos.single;
      expect(g.duplicados.any((d) => d.userId == g.principal.userId), isFalse);
    });

    test('unoPorCorreo devuelve exactamente las principales', () {
      final entrada = [
        _perfil('a', 'x@b.c', totales: 100),
        _perfil('b', 'x@b.c', totales: 0),
        _perfil('c', 'y@b.c'),
      ];
      expect(
        unoPorCorreo(entrada).map((p) => p.userId).toSet(),
        agruparPorCorreo(entrada).map((g) => g.principal.userId).toSet(),
      );
    });
  });
}
