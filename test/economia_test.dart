import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/user.dart';
import 'package:veridia_app/services/economia.dart';

/// Reglas de la economía: nivel por acumulado, mejoras de mascota y claves de
/// idempotencia. Todo esto es lógica pura, así que se prueba sin Firebase.
void main() {
  group('nivelDesde', () {
    test('empieza en 1 y sube al cruzar cada umbral', () {
      expect(nivelDesde(0), 1);
      expect(nivelDesde(14), 1);
      expect(nivelDesde(15), 2);
      expect(nivelDesde(39), 2);
      expect(nivelDesde(40), 3);
      expect(nivelDesde(450), nivelMaximo);
    });

    test('no pasa del nivel máximo por muchos Veridiums que se ganen', () {
      expect(nivelDesde(100000), nivelMaximo);
    });

    test('un acumulado negativo no rompe nada', () {
      expect(nivelDesde(-50), 1);
    });
  });

  group('progreso hacia el siguiente nivel', () {
    test('en el máximo no hay siguiente umbral', () {
      expect(umbralSiguienteNivel(450), isNull);
      expect(progresoHaciaSiguienteNivel(450), 1.0);
    });

    test('recién ascendido, el progreso vuelve a cero', () {
      // 15 es justo el umbral del nivel 2: arranca de nuevo hacia el 40.
      expect(umbralSiguienteNivel(15), 40);
      expect(progresoHaciaSiguienteNivel(15), 0.0);
    });

    test('a mitad de tramo devuelve la mitad', () {
      // Nivel 2 va de 15 a 40; 27.5 no es entero, así que se usa 27 -> 0.48.
      expect(progresoHaciaSiguienteNivel(27), closeTo(0.48, 0.01));
    });
  });

  group('bonoDeMascota', () {
    ContextoFoto contexto({
      int hora = 12,
      bool enHumedal = false,
      String? tipo,
      int especiesHoy = 1,
      double? km,
    }) => ContextoFoto(
      momento: DateTime(2026, 8, 26, hora),
      enHumedal: enHumedal,
      tipoEspecie: tipo,
      especiesDistintasHoy: especiesHoy,
      kmDesdeMisFotos: km,
    );

    test('sin mascota equipada no hay bono', () {
      expect(bonoDeMascota(null, contexto()).veridiums, 0);
    });

    test('la rana solo paga dentro de un humedal', () {
      expect(
        bonoDeMascota(MascotaId.rana, contexto(enHumedal: true)).veridiums,
        bonoFijoMascota,
      );
      expect(bonoDeMascota(MascotaId.rana, contexto()).veridiums, 0);
    });

    test('el currucutú paga de 6 p.m. a 6 a.m.', () {
      expect(
        bonoDeMascota(MascotaId.currucutu, contexto(hora: 18)).veridiums,
        bonoDeRareza(MascotaId.currucutu),
      );
      expect(
        bonoDeMascota(MascotaId.currucutu, contexto(hora: 5)).veridiums,
        bonoDeRareza(MascotaId.currucutu),
      );
      expect(
        bonoDeMascota(MascotaId.currucutu, contexto(hora: 12)).veridiums,
        0,
      );
      expect(
        bonoDeMascota(MascotaId.currucutu, contexto(hora: 17)).veridiums,
        0,
      );
    });

    test('el colibrí arranca en la tercera especie distinta del día', () {
      expect(
        bonoDeMascota(MascotaId.colibri, contexto(especiesHoy: 2)).veridiums,
        0,
      );
      expect(
        bonoDeMascota(MascotaId.colibri, contexto(especiesHoy: 3)).veridiums,
        1,
      );
      expect(
        bonoDeMascota(MascotaId.colibri, contexto(especiesHoy: 5)).veridiums,
        3,
      );
    });

    test('el colibrí tiene tope: un día muy bueno no dispara la economía', () {
      expect(
        bonoDeMascota(MascotaId.colibri, contexto(especiesHoy: 30)).veridiums,
        3,
      );
    });

    test('la tucaneta paga lejos de tus fotos anteriores', () {
      expect(
        bonoDeMascota(MascotaId.tucaneta, contexto(km: 8)).veridiums,
        bonoDeRareza(MascotaId.tucaneta),
      );
      expect(bonoDeMascota(MascotaId.tucaneta, contexto(km: 0.5)).veridiums, 0);
    });

    test('la primera foto con ubicación ya es territorio nuevo', () {
      // km null = todavía no hay ninguna foto propia contra la que comparar.
      expect(
        bonoDeMascota(MascotaId.tucaneta, contexto()).veridiums,
        bonoDeRareza(MascotaId.tucaneta),
      );
    });

    test('la mariquita paga en plantas y hongos, no en fauna', () {
      expect(
        bonoDeMascota(MascotaId.mariquita, contexto(tipo: 'planta')).veridiums,
        bonoDeRareza(MascotaId.mariquita),
      );
      expect(
        bonoDeMascota(MascotaId.mariquita, contexto(tipo: 'hongo')).veridiums,
        bonoDeRareza(MascotaId.mariquita),
      );
      expect(
        bonoDeMascota(MascotaId.mariquita, contexto(tipo: 'ave')).veridiums,
        0,
      );
    });

    test('ninguna mejora se sale de lo que su rareza permite', () {
      // Con TODAS las condiciones cumplidas a la vez, cada mascota sigue
      // pagando solo lo suyo: las mejoras no se apilan entre sí, solo escalan
      // con la rareza. El techo es el escalón máximo del colibrí (x3) por su
      // multiplicador, que es la única variable.
      for (final mascota in MascotaId.values) {
        final bono = bonoDeMascota(
          mascota,
          contexto(hora: 20, enHumedal: true, tipo: 'planta', especiesHoy: 50),
        );
        final techo = mascota == MascotaId.colibri
            ? 3 * rarezaDeMascota[mascota]!.multiplicador
            : bonoDeRareza(mascota);
        expect(bono.veridiums, lessThanOrEqualTo(techo));
      }
    });

    test('la rareza alta paga al menos el triple que la común', () {
      // Es la razón de existir del multiplicador: sin él, la tucaneta de 160
      // Veridiums rendía igual que la rana gratis.
      for (final entrada in rarezaDeMascota.entries) {
        if (entrada.value != Rareza.epica &&
            entrada.value != Rareza.legendaria) {
          continue;
        }
        expect(
          bonoDeRareza(entrada.key),
          greaterThanOrEqualTo(bonoFijoMascota * 3),
          reason: '${entrada.key} es ${entrada.value.etiqueta} y paga poco',
        );
      }
    });

    test('el multiplicador sube con la rareza y nunca baja', () {
      expect(Rareza.comun.multiplicador, 1);
      expect(
        Rareza.rara.multiplicador,
        greaterThan(Rareza.comun.multiplicador),
      );
      expect(
        Rareza.epica.multiplicador,
        greaterThan(Rareza.rara.multiplicador),
      );
      expect(
        Rareza.legendaria.multiplicador,
        greaterThan(Rareza.epica.multiplicador),
      );
    });

    test('cuando aplica siempre trae un motivo que enseñar', () {
      final bono = bonoDeMascota(MascotaId.rana, contexto(enHumedal: true));
      expect(bono.aplica, isTrue);
      expect(bono.motivo, isNotNull);
    });
  });

  group('mascotaDesde', () {
    test('lee la clave guardada en Firestore', () {
      expect(mascotaDesde('colibri'), MascotaId.colibri);
      expect(mascotaDesde('tucaneta'), MascotaId.tucaneta);
    });

    test('una clave desconocida o vacía no revienta', () {
      expect(mascotaDesde('dragon'), isNull);
      expect(mascotaDesde(null), isNull);
    });
  });

  group('claveMovimiento', () {
    test('el mismo hecho siempre da la misma clave', () {
      // Es lo que hace idempotente el pago: si llevara la hora, un reintento
      // crearía un apunte nuevo y se pagaría dos veces.
      expect(
        claveMovimiento(motivo: 'foto', referencia: 'obs1'),
        claveMovimiento(motivo: 'foto', referencia: 'obs1'),
      );
    });

    test('hechos distintos dan claves distintas', () {
      expect(
        claveMovimiento(motivo: 'foto', referencia: 'obs1'),
        isNot(claveMovimiento(motivo: 'foto', referencia: 'obs2')),
      );
      expect(
        claveMovimiento(motivo: 'foto', referencia: 'x'),
        isNot(claveMovimiento(motivo: 'canje', referencia: 'x')),
      );
    });
  });

  group('esZonaDeAguaNormalizada', () {
    test('reconoce los cuerpos de agua del JSON de zonas', () {
      expect(esZonaDeAguaNormalizada('humedal guali'), isTrue);
      expect(esZonaDeAguaNormalizada('laguna de la herrera'), isTrue);
      expect(esZonaDeAguaNormalizada('aves acuaticas y migratorias'), isTrue);
    });

    test('no confunde bosque seco ni potrero con agua', () {
      expect(esZonaDeAguaNormalizada('bosque andino'), isFalse);
      expect(esZonaDeAguaNormalizada('potrero abierto'), isFalse);
    });
  });

  group('leerTokensTotales', () {
    test('un perfil viejo sin acumulado arranca desde su saldo', () {
      // Nunca pudo gastar más de lo que ganó, así que el saldo es la mejor
      // cota inferior: mandarlo a 0 le borraría el recorrido.
      expect(leerTokensTotales(const {}, 120), 120);
      expect(leerTokensTotales(null, 40), 40);
    });

    test('un acumulado guardado por debajo del saldo se corrige', () {
      expect(leerTokensTotales(const {'tokensTotales': 10}, 90), 90);
    });

    test('un acumulado normal se respeta', () {
      expect(leerTokensTotales(const {'tokensTotales': 300}, 90), 300);
    });
  });

  group('UserProfile', () {
    UserProfile perfil({int tokens = 0, int totales = 0}) => UserProfile(
      userId: 'u1',
      email: 'a@b.co',
      displayName: 'Explorador',
      photoURL: null,
      tokens: tokens,
      tokensTotales: totales,
      role: 'Explorador',
      createdDate: DateTime(2026, 1, 1),
      isBanned: false,
    );

    test('el nivel sale del acumulado, no del saldo', () {
      // Gastó casi todo: su saldo es 2 pero su recorrido sigue siendo el
      // mismo, y con él su nivel.
      expect(perfil(tokens: 2, totales: 300).nivel, nivelDesde(300));
      expect(perfil(tokens: 300, totales: 300).nivel, nivelDesde(300));
    });

    test('gastar no baja el nivel', () {
      final antes = perfil(tokens: 200, totales: 200);
      final despues = antes.copyWith(tokens: 40);
      expect(despues.nivel, antes.nivel);
    });
  });
}
