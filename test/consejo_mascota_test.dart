import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/services/consejo_mascota.dart';
import 'package:veridia_app/services/economia.dart';

/// Lo que la mascota le dice al explorador desde el mapa.
///
/// La prueba que más importa es la del silencio: una mascota que habla
/// siempre es ruido encima del mapa, y el consejo dejaría de leerse.
void main() {
  DatosConsejo datos({
    required MascotaId mascota,
    int hora = 12,
    String? humedal,
    double? km,
    int especiesHoy = 0,
  }) => DatosConsejo(
    mascota: mascota,
    momento: DateTime(2026, 8, 26, hora),
    humedalCercano: humedal,
    kmAMiFotoMasCercana: km,
    especiesMiasHoy: especiesHoy,
  );

  group('rana', () {
    test('nombra el humedal en el que estás', () {
      final consejo = consejoDeMascota(
        datos(mascota: MascotaId.rana, humedal: 'Humedal Gualí'),
      );
      expect(consejo, contains('Humedal Gualí'));
      expect(consejo, contains('$bonoFijoMascota'));
    });

    test('se calla si no hay agua cerca', () {
      expect(consejoDeMascota(datos(mascota: MascotaId.rana)), isNull);
    });
  });

  group('currucutú', () {
    test('avisa cuando ya es de noche', () {
      expect(
        consejoDeMascota(datos(mascota: MascotaId.currucutu, hora: 20)),
        contains('noche'),
      );
      expect(
        consejoDeMascota(datos(mascota: MascotaId.currucutu, hora: 3)),
        contains('noche'),
      );
    });

    test('avisa que falta poco a partir de las 4 p.m.', () {
      final consejo = consejoDeMascota(
        datos(mascota: MascotaId.currucutu, hora: 16),
      );
      expect(consejo, isNotNull);
      expect(consejo, contains('6 p.m.'));
    });

    test('a media mañana no tiene nada que decir', () {
      expect(
        consejoDeMascota(datos(mascota: MascotaId.currucutu, hora: 10)),
        isNull,
      );
    });
  });

  group('colibrí', () {
    test('no habla antes de la primera foto del día', () {
      expect(
        consejoDeMascota(datos(mascota: MascotaId.colibri, especiesHoy: 0)),
        isNull,
      );
    });

    test('cuenta cuántas especies distintas llevas', () {
      final consejo = consejoDeMascota(
        datos(mascota: MascotaId.colibri, especiesHoy: 4),
      );
      expect(consejo, contains('4'));
    });

    test('anuncia lo que pagaría la siguiente especie nueva', () {
      // Con 3 distintas hoy, la cuarta pagaría +2.
      expect(
        consejoDeMascota(datos(mascota: MascotaId.colibri, especiesHoy: 3)),
        contains('+2'),
      );
    });
  });

  group('tucaneta', () {
    test('sin fotos previas, la primera ya cuenta', () {
      expect(
        consejoDeMascota(datos(mascota: MascotaId.tucaneta)),
        contains('territorio nuevo'),
      );
    });

    test('confirma el bono cuando ya estás lejos', () {
      final consejo = consejoDeMascota(
        datos(mascota: MascotaId.tucaneta, km: 12.4),
      );
      expect(consejo, contains('12.4 km'));
      expect(consejo, contains('territorio nuevo'));
    });

    test('dice cuánto falta cuando estás cerca de tus propias fotos', () {
      final consejo = consejoDeMascota(
        datos(mascota: MascotaId.tucaneta, km: 0.4),
      );
      expect(consejo, contains('400 m'));
      expect(consejo, contains('$kmTerritorioNuevo km'));
    });
  });

  group('mariquita', () {
    test('siempre trae el consejo de campo, que es su razón de ser', () {
      final consejo = consejoDeMascota(datos(mascota: MascotaId.mariquita));
      expect(consejo, contains('envés'));
    });
  });

  group('previaDeMascota', () {
    ContextoFoto contexto({
      int hora = 12,
      bool enHumedal = false,
      String? tipo,
      int especiesHoy = 1,
      double? km,
    }) => ContextoFoto(
      momento: DateTime(2026, 8, 27, hora),
      enHumedal: enHumedal,
      tipoEspecie: tipo,
      especiesDistintasHoy: especiesHoy,
      kmDesdeMisFotos: km,
    );

    test('anuncia el bono ANTES de disparar, con la cifra exacta', () {
      final previa = previaDeMascota(MascotaId.rana, contexto(enHumedal: true));
      expect(previa.suma, isTrue);
      expect(previa.veridiums, bonoFijoMascota);
      expect(previa.mensaje, contains('+$bonoFijoMascota'));
    });

    test('prometer y pagar son el mismo cálculo', () {
      // Si la vista previa tuviera su propia cuenta, anunciaría un bono y
      // pagaría otro. Se comprueba contra bonoDeMascota en varios escenarios.
      final casos = [
        (MascotaId.rana, contexto(enHumedal: true)),
        (MascotaId.rana, contexto()),
        (MascotaId.currucutu, contexto(hora: 21)),
        (MascotaId.currucutu, contexto(hora: 9)),
        (MascotaId.colibri, contexto(especiesHoy: 4)),
        (MascotaId.colibri, contexto(especiesHoy: 1)),
        (MascotaId.tucaneta, contexto(km: 9)),
        (MascotaId.tucaneta, contexto(km: 0.2)),
        (MascotaId.mariquita, contexto(tipo: 'planta')),
        (MascotaId.mariquita, contexto(tipo: 'ave')),
      ];
      for (final (mascota, ctx) in casos) {
        expect(
          previaDeMascota(mascota, ctx).veridiums,
          bonoDeMascota(mascota, ctx).veridiums,
          reason: 'la previa de $mascota no coincide con el pago',
        );
      }
    });

    test('cuando no aplica, dice QUÉ faltaría', () {
      // Un "+0" mudo no enseña nada; el valor de la mecánica está en que la
      // explicación te mueva antes de disparar.
      expect(
        previaDeMascota(MascotaId.rana, contexto()).mensaje,
        contains('humedal'),
      );
      expect(
        previaDeMascota(MascotaId.currucutu, contexto(hora: 10)).mensaje,
        contains('6 p.m.'),
      );
      expect(
        previaDeMascota(MascotaId.tucaneta, contexto(km: 0.5)).mensaje,
        contains('$kmTerritorioNuevo km'),
      );
    });

    test('el colibrí cuenta cuántas especies distintas faltan', () {
      expect(
        previaDeMascota(MascotaId.colibri, contexto(especiesHoy: 2)).mensaje,
        contains('una especie distinta más'),
      );
      expect(
        previaDeMascota(MascotaId.colibri, contexto(especiesHoy: 1)).mensaje,
        contains('2 especies distintas'),
      );
    });

    test('la mariquita no promete nada antes de saber qué es', () {
      final antes = previaDeMascota(MascotaId.mariquita, contexto());
      expect(antes.suma, isFalse);
      expect(antes.mensaje, contains('Si resulta ser'));

      final despues = previaDeMascota(
        MascotaId.mariquita,
        contexto(tipo: 'ave'),
      );
      expect(despues.mensaje, contains('no es un cultivo'));
    });

    test('ninguna mascota se queda sin previa', () {
      for (final mascota in MascotaId.values) {
        final previa = previaDeMascota(mascota, contexto());
        expect(previa.mensaje, isNotEmpty);
      }
    });
  });

  test('ninguna mascota se queda sin caso en el switch', () {
    for (final mascota in MascotaId.values) {
      // No debe lanzar por ninguna: si se añade una mascota nueva sin su
      // rama, esto se cae aquí y no en el mapa de alguien.
      consejoDeMascota(
        datos(
          mascota: mascota,
          hora: 20,
          humedal: 'Laguna',
          km: 9,
          especiesHoy: 4,
        ),
      );
    }
  });
}
