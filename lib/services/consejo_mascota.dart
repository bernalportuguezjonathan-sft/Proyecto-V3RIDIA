import 'economia.dart';

/// Lo que la mascota alcanza a saber del sitio donde está parado el explorador.
///
/// Todo sale de lo que el mapa ya tiene cargado: las zonas del JSON, los
/// avistamientos propios y el reloj. La mascota no consulta nada por su
/// cuenta.
class DatosConsejo {
  const DatosConsejo({
    required this.mascota,
    required this.momento,
    this.humedalCercano,
    this.kmAMiFotoMasCercana,
    this.especiesMiasHoy = 0,
  });

  final MascotaId mascota;
  final DateTime momento;

  /// Nombre de la zona de agua más cercana, si está al alcance. null si no
  /// hay ninguna cerca o si todavía no se sabe dónde está el explorador.
  final String? humedalCercano;

  /// Distancia a la más cercana de sus propias fotos. null si nunca ha
  /// registrado ninguna con ubicación.
  final double? kmAMiFotoMasCercana;

  /// Especies distintas que ya lleva registradas hoy.
  final int especiesMiasHoy;
}

/// Qué le dice la mascota al explorador, o null si no tiene nada útil que
/// decir ahora mismo.
///
/// Devolver null es la mitad del diseño. Una mascota que habla siempre es
/// ruido encima de un mapa que costó mucho dejar limpio: solo abre la boca
/// cuando el sitio, la hora o el recorrido de hoy cambian de verdad lo que
/// vale la próxima foto.
String? consejoDeMascota(DatosConsejo datos) {
  switch (datos.mascota) {
    case MascotaId.rana:
      final humedal = datos.humedalCercano;
      if (humedal == null) return null;
      return 'Estás en $humedal. Cada foto que tomes aquí te suma '
          '+${bonoDeRareza(datos.mascota)} Veridiums.';

    case MascotaId.currucutu:
      final hora = datos.momento.hour;
      if (hora >= 18 || hora < 6) {
        return 'Es de noche y casi nadie registra a esta hora: '
            '+${bonoDeRareza(datos.mascota)} por cada foto verificada.';
      }
      if (hora >= 16) {
        return 'Desde las 6 p.m. cada foto tuya vale '
            '+${bonoDeRareza(datos.mascota)}. Falta poco.';
      }
      return null;

    case MascotaId.colibri:
      final hoy = datos.especiesMiasHoy;
      if (hoy == 0) return null;
      if (hoy < 2) {
        return 'Llevas 1 especie hoy. Desde la tercera DISTINTA empiezas a '
            'sumar extra.';
      }
      final escalon = (hoy + 1 - 2).clamp(1, 3);
      final proxima =
          escalon *
          (rarezaDeMascota[datos.mascota] ?? Rareza.comun).multiplicador;
      return 'Llevas $hoy especies distintas hoy: la siguiente que sea nueva '
          'te suma +$proxima.';

    case MascotaId.tucaneta:
      final km = datos.kmAMiFotoMasCercana;
      if (km == null) {
        return 'Todavía no tienes fotos con ubicación: la primera ya cuenta '
            'como territorio nuevo, +${bonoDeRareza(datos.mascota)}.';
      }
      if (km >= kmTerritorioNuevo) {
        return 'Estás a ${_km(km)} de tu foto más cercana: territorio nuevo, '
            '+${bonoDeRareza(datos.mascota)}.';
      }
      return 'Estás a ${_km(km)} de una foto tuya. Alejándote hasta '
          '$kmTerritorioNuevo km cuenta como territorio nuevo.';

    case MascotaId.mariquita:
      return 'Si es un cultivo, fotografía el envés de la hoja: ahí empieza '
          'la plaga. Plantas y hongos suman +${bonoDeRareza(datos.mascota)}.';
  }
}

String _km(double valor) => valor < 1
    ? '${(valor * 1000).round()} m'
    : '${valor.toStringAsFixed(1)} km';

// ---------------------------------------------------------------------------
// Vista previa: qué va a pasar con la foto que se está a punto de tomar
// ---------------------------------------------------------------------------

/// Lo que la mascota adelanta sobre la foto que el explorador tiene encuadrada.
class PreviaMascota {
  const PreviaMascota({required this.veridiums, required this.mensaje});

  /// Veridiums que sumaría la mejora si la foto se guardara ahora.
  final int veridiums;

  final String mensaje;

  bool get suma => veridiums > 0;
}

/// Qué dice la mascota ANTES de disparar.
///
/// Es la diferencia entre una mejora que decora y una que cambia lo que haces:
/// enterarte de que estás sobre un humedal cuando ya guardaste la foto no
/// sirve de nada, pero saberlo con la cámara en la mano sí. Por eso cuando NO
/// aplica también dice por qué y qué faltaría — un "+0" sin explicación no
/// enseña nada.
PreviaMascota previaDeMascota(MascotaId mascota, ContextoFoto contexto) {
  final bono = bonoDeMascota(mascota, contexto);
  // Lo que pagaría SI se cumpliera la condición: es la cifra que hay que
  // enseñar cuando todavía no aplica, para que se vea qué se está perdiendo.
  final potencial = bonoDeRareza(mascota);

  switch (mascota) {
    case MascotaId.rana:
      return bono.aplica
          ? PreviaMascota(
              veridiums: bono.veridiums,
              mensaje:
                  'Estás sobre un humedal: esta foto suma '
                  '+${bono.veridiums}.',
            )
          : const PreviaMascota(
              veridiums: 0,
              mensaje:
                  'No hay ningún humedal cerca, así que esta foto no '
                  'lleva su bono.',
            );

    case MascotaId.currucutu:
      return bono.aplica
          ? PreviaMascota(
              veridiums: bono.veridiums,
              mensaje: 'Es de noche: esta foto suma +${bono.veridiums}.',
            )
          : const PreviaMascota(
              veridiums: 0,
              mensaje:
                  'Todavía es de día. Desde las 6 p.m. cada foto suma '
                  '+$bonoFijoMascota.',
            );

    case MascotaId.colibri:
      if (bono.aplica) {
        return PreviaMascota(
          veridiums: bono.veridiums,
          mensaje:
              'Sería tu especie ${contexto.especiesDistintasHoy} distinta '
              'de hoy: suma +${bono.veridiums}.',
        );
      }
      final faltan = 3 - contexto.especiesDistintasHoy;
      return PreviaMascota(
        veridiums: 0,
        mensaje: faltan == 1
            ? 'Con una especie distinta más hoy, empieza a sumar.'
            : 'Te faltan $faltan especies distintas hoy para que empiece a '
                  'sumar.',
      );

    case MascotaId.tucaneta:
      if (bono.aplica) {
        return PreviaMascota(
          veridiums: bono.veridiums,
          mensaje: 'Territorio nuevo: esta foto suma +${bono.veridiums}.',
        );
      }
      final km = contexto.kmDesdeMisFotos;
      return PreviaMascota(
        veridiums: 0,
        mensaje: km == null
            ? 'Sin ubicación no puede saber si es territorio nuevo.'
            : 'Estás a ${_km(km)} de una foto tuya. Desde '
                  '$kmTerritorioNuevo km cuenta como territorio nuevo.',
      );

    case MascotaId.mariquita:
      if (bono.aplica) {
        return PreviaMascota(
          veridiums: bono.veridiums,
          mensaje:
              'Es un cultivo: esta foto suma +${bono.veridiums}. Revisa '
              'el envés de la hoja.',
        );
      }
      return PreviaMascota(
        veridiums: 0,
        mensaje: contexto.tipoEspecie == null
            ? 'Si resulta ser una planta o un hongo, sumará +$potencial.'
            : 'Esto no es un cultivo. Suma +$potencial en plantas y hongos.',
      );
  }
}
