import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/recompensa.dart';
import 'package:veridia_app/models/user.dart';

/// Qué marco o título lleva puesto el explorador.
///
/// El caso que importa de verdad es el de una cuenta que YA existía: hasta
/// ahora el perfil pintaba siempre el más caro de los comprados, sin que
/// nadie eligiera. Si al añadir la elección esas cuentas se quedaran sin
/// marco, la actualización les borraría algo que pagaron.
Recompensa _marco(String id, int costo) => Recompensa(
  id: id,
  nombre: id,
  descripcion: '',
  costo: costo,
  tipo: TipoRecompensa.marco,
  icono: Icons.filter_frames_rounded,
  color: const Color(0xFF10B981),
  valor: id,
);

void main() {
  final esmeralda = _marco('marco_esmeralda', 40);
  final dorado = _marco('marco_dorado', 90);

  Recompensa? resolver(String? elegido, List<Recompensa> tiene) =>
      equipadoEntre<Recompensa>(
        elegido,
        tiene,
        idDe: (r) => r.id,
        costoDe: (r) => r.costo,
      );

  group('equipadoEntre', () {
    test('sin comprar nada no lleva nada', () {
      expect(resolver(null, []), isNull);
      expect(resolver('marco_dorado', []), isNull);
    });

    test('quien nunca eligió sigue viendo el más caro', () {
      // Es exactamente lo que hacía la app antes de que se pudiera elegir:
      // nadie pierde su marco al actualizar.
      expect(resolver(null, [esmeralda, dorado])?.id, 'marco_dorado');
    });

    test('el orden de la lista no cambia el resultado', () {
      expect(resolver(null, [dorado, esmeralda])?.id, 'marco_dorado');
    });

    test('lo elegido manda sobre lo más caro', () {
      // El caso que reportó el usuario: tiene los dos, quiere el esmeralda.
      expect(
        resolver('marco_esmeralda', [esmeralda, dorado])?.id,
        'marco_esmeralda',
      );
    });

    test('se puede no llevar ninguno', () {
      // Sin este valor no se podría DESEQUIPAR: un null se leería como
      // "todavía no he elegido" y el más caro volvería solo.
      expect(
        resolver(UserProfile.ningunoEquipado, [esmeralda, dorado]),
        isNull,
      );
    });

    test('elegir algo que no se tiene cae en el más caro', () {
      // Puede pasar si un id se queda apuntando a una recompensa retirada del
      // catálogo. Mejor enseñar algo que dejar el perfil pelado sin motivo.
      expect(resolver('marco_inventado', [esmeralda])?.id, 'marco_esmeralda');
    });

    test('con uno solo comprado, ese es el que va', () {
      expect(resolver(null, [esmeralda])?.id, 'marco_esmeralda');
      expect(resolver('marco_esmeralda', [esmeralda])?.id, 'marco_esmeralda');
    });
  });

  group('catálogo', () {
    test('los dos marcos siguen existiendo y son distintos', () {
      final marcos = catalogoRecompensas
          .where((r) => r.tipo == TipoRecompensa.marco)
          .toList();
      expect(marcos.length, 2);
      expect(marcos.map((m) => m.id).toSet(), {
        'marco_esmeralda',
        'marco_dorado',
      });
      // Colores distintos: el aro de la foto es la única forma de saber cuál
      // llevas puesto.
      expect(marcos[0].color, isNot(marcos[1].color));
    });

    test('un marco y un título no se pueden volver a comprar', () {
      expect(TipoRecompensa.marco.repetible, isFalse);
      expect(TipoRecompensa.titulo.repetible, isFalse);
      // Una experiencia sí.
      expect(TipoRecompensa.fisica.repetible, isTrue);
    });
  });

  group('UserProfile', () {
    test('copyWith conserva lo equipado', () {
      final perfil = UserProfile(
        userId: 'u1',
        email: 'a@b.c',
        displayName: 'Ana',
        photoURL: null,
        tokens: 10,
        role: 'Explorador',
        createdDate: DateTime(2026, 1, 1),
        isBanned: false,
        marcoEquipado: 'marco_esmeralda',
        tituloEquipado: UserProfile.ningunoEquipado,
      );

      final conSaldoNuevo = perfil.copyWith(tokens: 99);
      expect(conSaldoNuevo.marcoEquipado, 'marco_esmeralda');
      expect(conSaldoNuevo.tituloEquipado, UserProfile.ningunoEquipado);
    });

    test('un perfil nuevo no trae nada elegido', () {
      final perfil = UserProfile(
        userId: 'u1',
        email: 'a@b.c',
        displayName: 'Ana',
        photoURL: null,
        tokens: 0,
        role: 'Explorador',
        createdDate: DateTime(2026, 1, 1),
        isBanned: false,
      );
      expect(perfil.marcoEquipado, isNull);
      expect(perfil.tituloEquipado, isNull);
    });
  });
}
