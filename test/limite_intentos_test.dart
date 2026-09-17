import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/limite_intentos.dart';

/// El freno a las fotos que no son especies.
///
/// Toda la regla vive en funciones puras justamente para poder probarla sin
/// almacenamiento ni Firebase.
void main() {
  final ahora = DateTime(2026, 9, 16, 10, 0);

  group('racha de rechazos', () {
    test('no bloquea antes de agotar la racha', () {
      var estado = const EstadoIntentos();
      for (var i = 1; i < maxRechazosSeguidos; i++) {
        estado = trasRechazo(estado, ahora);
        expect(
          bloqueoActual(estado, ahora),
          isNull,
          reason: 'no debería bloquear en el rechazo $i',
        );
      }
      expect(estado.rechazosSeguidos, maxRechazosSeguidos - 1);
    });

    test('bloquea justo al llegar al tope', () {
      var estado = const EstadoIntentos();
      for (var i = 0; i < maxRechazosSeguidos; i++) {
        estado = trasRechazo(estado, ahora);
      }
      expect(bloqueoActual(estado, ahora), MotivoBloqueo.rachaDeRechazos);
      expect(esperaRestante(estado, ahora), esperaTrasRacha);
    });

    test('la espera se levanta sola al pasar el tiempo', () {
      var estado = const EstadoIntentos();
      for (var i = 0; i < maxRechazosSeguidos; i++) {
        estado = trasRechazo(estado, ahora);
      }
      final despues = ahora
          .add(esperaTrasRacha)
          .add(const Duration(seconds: 1));
      expect(bloqueoActual(estado, despues), isNull);
    });

    test('al volver de la espera se tiene la racha completa otra vez', () {
      // Si no, el explorador quedaría bloqueado foto sí, foto también.
      var estado = const EstadoIntentos();
      for (var i = 0; i < maxRechazosSeguidos; i++) {
        estado = trasRechazo(estado, ahora);
      }
      expect(estado.rechazosSeguidos, 0);
    });

    test('una foto válida borra la racha y la espera', () {
      var estado = const EstadoIntentos();
      for (var i = 0; i < maxRechazosSeguidos; i++) {
        estado = trasRechazo(estado, ahora);
      }
      expect(bloqueoActual(estado, ahora), isNotNull);

      estado = trasExito(estado);
      expect(estado.rechazosSeguidos, 0);
      expect(estado.bloqueadoHasta, isNull);
      expect(bloqueoActual(estado, ahora), isNull);
    });

    test('un acierto entre medias reinicia el conteo', () {
      // Quien explora de verdad falla fotos sueltas y no debería toparse
      // nunca con la espera.
      var estado = const EstadoIntentos();
      estado = trasRechazo(estado, ahora);
      estado = trasRechazo(estado, ahora);
      estado = trasExito(estado);
      estado = trasRechazo(estado, ahora);
      expect(estado.rechazosSeguidos, 1);
      expect(bloqueoActual(estado, ahora), isNull);
    });
  });

  group('cuota diaria', () {
    test('bloquea al agotar los análisis del día', () {
      var estado = EstadoIntentos(dia: diaDe(ahora));
      for (var i = 0; i < maxAnalisisDiarios; i++) {
        estado = trasAnalisis(estado, ahora);
      }
      expect(estado.analisisHoy, maxAnalisisDiarios);
      expect(bloqueoActual(estado, ahora), MotivoBloqueo.cuotaDiaria);
    });

    test('el contador se reinicia al cambiar de día', () {
      var estado = EstadoIntentos(dia: diaDe(ahora));
      for (var i = 0; i < maxAnalisisDiarios; i++) {
        estado = trasAnalisis(estado, ahora);
      }
      final manana = ahora.add(const Duration(days: 1));
      expect(bloqueoActual(estado, manana), isNull);
      expect(alDiaDe(estado, manana).analisisHoy, 0);
    });

    test('la espera por racha pesa más que la cuota', () {
      // Las dos a la vez: se le dice la que le deja volver antes.
      var estado = EstadoIntentos(dia: diaDe(ahora));
      for (var i = 0; i < maxAnalisisDiarios; i++) {
        estado = trasAnalisis(estado, ahora);
      }
      for (var i = 0; i < maxRechazosSeguidos; i++) {
        estado = trasRechazo(estado, ahora);
      }
      expect(bloqueoActual(estado, ahora), MotivoBloqueo.rachaDeRechazos);
    });
  });

  group('diaDe', () {
    test('formatea con ceros a la izquierda', () {
      expect(diaDe(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('dos momentos del mismo día dan la misma clave', () {
      expect(
        diaDe(DateTime(2026, 9, 16, 0, 1)),
        diaDe(DateTime(2026, 9, 16, 23, 59)),
      );
    });
  });

  group('mensajeDeBloqueo', () {
    test('dice cuántos minutos faltan', () {
      final m = mensajeDeBloqueo(
        MotivoBloqueo.rachaDeRechazos,
        const Duration(minutes: 3),
      );
      expect(m, contains('3 minutos'));
    });

    test('baja a segundos cuando falta menos de un minuto', () {
      final m = mensajeDeBloqueo(
        MotivoBloqueo.rachaDeRechazos,
        const Duration(seconds: 40),
      );
      expect(m, contains('40 segundos'));
    });

    test('el de cuota diaria nombra el tope', () {
      final m = mensajeDeBloqueo(MotivoBloqueo.cuotaDiaria, Duration.zero);
      expect(m, contains('$maxAnalisisDiarios'));
    });
  });
}
