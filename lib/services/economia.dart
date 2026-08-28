/// Economía de Veridia: niveles, mejoras de mascota y libro de movimientos.
///
/// Módulo PURO a propósito: no importa Firebase ni Flutter, así que se puede
/// probar con `flutter test` sin arrancar nada y —más importante— se puede
/// portar tal cual a `functions/logica.js` el día que el proyecto pase a
/// Blaze. Toda regla que decida CUÁNTOS Veridiums se pagan vive aquí y en
/// ningún otro sitio; los repositorios solo la aplican.
library;

// ---------------------------------------------------------------------------
// Nivel
// ---------------------------------------------------------------------------

/// Veridiums GANADOS EN TOTAL que hacen falta para cada nivel.
///
/// El nivel se calcula sobre el acumulado histórico (`tokensTotales`), nunca
/// sobre el saldo: si dependiera del saldo, gastar en la tienda te bajaría de
/// nivel y el explorador aprendería a no gastar nunca. El acumulado solo
/// sube, así que mide aporte real y no ahorro.
const List<int> umbralesNivel = [0, 15, 40, 80, 140, 220, 320, 450];

/// Nivel máximo alcanzable (longitud de [umbralesNivel]).
int get nivelMaximo => umbralesNivel.length;

/// Nivel de un explorador según todo lo que ha ganado en su historia.
int nivelDesde(int totalGanado) {
  var nivel = 1;
  for (var i = 1; i < umbralesNivel.length; i++) {
    if (totalGanado >= umbralesNivel[i]) nivel = i + 1;
  }
  return nivel;
}

/// Veridiums acumulados que exige el SIGUIENTE nivel, o null si ya está al
/// máximo.
int? umbralSiguienteNivel(int totalGanado) {
  final nivel = nivelDesde(totalGanado);
  if (nivel >= nivelMaximo) return null;
  return umbralesNivel[nivel];
}

/// Avance dentro del nivel actual, de 0.0 a 1.0. Devuelve 1.0 en el máximo.
double progresoHaciaSiguienteNivel(int totalGanado) {
  final siguiente = umbralSiguienteNivel(totalGanado);
  if (siguiente == null) return 1.0;
  final base = umbralesNivel[nivelDesde(totalGanado) - 1];
  final tramo = siguiente - base;
  if (tramo <= 0) return 1.0;
  return ((totalGanado - base) / tramo).clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Mascotas
// ---------------------------------------------------------------------------

/// Las cinco mascotas de exploración.
///
/// Vive aquí, en el módulo puro, y no en `models/mascota.dart`, porque la
/// mejora de cada una es una regla de economía: el modelo solo le pone
/// nombre, colores y sprite encima.
enum MascotaId { rana, currucutu, colibri, tucaneta, mariquita }

MascotaId? mascotaDesde(String? clave) {
  for (final id in MascotaId.values) {
    if (id.name == clave) return id;
  }
  return null;
}

/// A partir de cuántas especies distintas en el mismo día empieza a pagar la
/// mejora del colibrí.
const int _colibriDesdeEspecie = 3;

/// Tope de la mejora del colibrí, para que un día muy bueno no dispare la
/// economía.
const int _colibriMaximo = 3;

/// Kilómetros que tiene que haber entre la foto nueva y la más cercana de
/// las tuyas anteriores para que cuente como territorio nuevo.
const int kmTerritorioNuevo = 3;

/// Bono fijo de las mejoras que son de sí/no.
const int bonoFijoMascota = 2;

/// Palabras que delatan un cuerpo de agua en el nombre, el hábitat o la
/// descripción de una zona del mapa.
///
/// Se comparan contra el JSON de zonas, donde el humedal aparece como
/// "Humedal Gualí", "Laguna de La Herrera" o dentro de la descripción. No hay
/// un campo booleano que diga "esto es agua", y añadirlo obligaría a tocar el
/// JSON cada vez que se suma una zona.
const List<String> _palabrasDeAgua = [
  'humedal',
  'laguna',
  'pantano',
  'cienaga',
  'embalse',
  'represa',
  'quebrada',
  'rio ',
  'lago',
  'acuatic',
];

/// true si el texto de una zona la delata como cuerpo de agua.
///
/// Recibe el texto ya normalizado (minúsculas y sin tildes); quien la llama
/// usa `normalizarTexto` de utils/texto_busqueda.dart.
bool esZonaDeAguaNormalizada(String textoNormalizado) {
  for (final palabra in _palabrasDeAgua) {
    if (textoNormalizado.contains(palabra)) return true;
  }
  return false;
}

/// Todo lo que una mejora necesita saber de una foto para decidir si aplica.
///
/// Son datos que la app YA tiene en el momento de guardar: la hora del
/// dispositivo, si la foto cayó dentro de un humedal del mapa, qué tipo de
/// ser vivo dijo la IA, cuántas especies distintas lleva hoy el explorador y
/// a qué distancia está de sus fotos anteriores. Ninguna mejora inventa datos
/// nuevos ni obliga a consultar nada extra.
class ContextoFoto {
  const ContextoFoto({
    required this.momento,
    this.enHumedal = false,
    this.tipoEspecie,
    this.especiesDistintasHoy = 1,
    this.kmDesdeMisFotos,
  });

  final DateTime momento;

  /// La foto cayó dentro (o al borde) de una zona de humedal del mapa.
  final bool enHumedal;

  /// `tipo` que devolvió la IA: 'ave', 'planta', 'hongo', 'insecto'...
  final String? tipoEspecie;

  /// Especies DISTINTAS que el explorador ha fotografiado hoy, contando esta.
  final int especiesDistintasHoy;

  /// Distancia a la más cercana de sus fotos anteriores. null = es su primera
  /// foto con coordenadas, así que cuenta como territorio nuevo.
  final double? kmDesdeMisFotos;

  /// Franja nocturna: de 6 p.m. a 6 a.m. Es cuando la fauna que menos se
  /// registra está activa.
  bool get esDeNoche => momento.hour >= 18 || momento.hour < 6;

  /// Lo que se fotografía en un diagnóstico de cultivo: la planta, o el hongo
  /// que la está atacando.
  bool get esCultivo => tipoEspecie == 'planta' || tipoEspecie == 'hongo';

  bool get esTerritorioNuevo =>
      kmDesdeMisFotos == null || kmDesdeMisFotos! >= kmTerritorioNuevo;
}

/// Lo que aportó la mascota a una foto concreta.
class BonoMascota {
  const BonoMascota({required this.veridiums, required this.motivo});

  const BonoMascota.ninguno() : veridiums = 0, motivo = null;

  final int veridiums;

  /// Texto corto para enseñárselo al explorador ("Ojo nocturno: +2"). null
  /// cuando la mejora no aplicó.
  final String? motivo;

  bool get aplica => veridiums > 0;
}

/// Rareza de una mascota: lo que separa a la que viene con la cuenta de la
/// que cuesta 160 Veridiums.
///
/// El multiplicador es lo que hace que valga la pena ahorrar. Sin él, todas
/// las mascotas pagaban lo mismo (+2) y la única diferencia era CUÁNDO
/// pagaban; la tucaneta costaba cuatro veces más que el colibrí y rendía
/// igual, así que no había ninguna razón para comprarla salvo el sprite.
///
/// Sigue multiplicando solo cuando la condición de la mascota se cumple, que
/// es lo que mantiene la mecánica dirigida: una legendaria no es "más
/// Veridiums en todo", es "mucho más Veridiums cuando haces lo difícil".
enum Rareza { comun, rara, epica, legendaria }

extension RarezaX on Rareza {
  /// Por cuánto se multiplica el bono base de la mejora.
  int get multiplicador => switch (this) {
    Rareza.comun => 1,
    Rareza.rara => 2,
    Rareza.epica => 3,
    Rareza.legendaria => 4,
  };

  String get etiqueta => switch (this) {
    Rareza.comun => 'Común',
    Rareza.rara => 'Rara',
    Rareza.epica => 'Épica',
    Rareza.legendaria => 'Legendaria',
  };
}

/// Rareza de cada mascota.
///
/// Vive aquí y no en `models/mascota.dart` porque decide cuántos Veridiums se
/// pagan, y toda regla de pago tiene que estar en el módulo puro para poder
/// probarse sin Flutter y espejarse en `functions/logica.js`.
const Map<MascotaId, Rareza> rarezaDeMascota = {
  MascotaId.rana: Rareza.comun,
  MascotaId.colibri: Rareza.comun,
  MascotaId.currucutu: Rareza.rara,
  MascotaId.mariquita: Rareza.epica,
  MascotaId.tucaneta: Rareza.legendaria,
};

/// Veridiums que paga una mejora de esta rareza cuando se cumple su condición.
int bonoDeRareza(MascotaId mascota) =>
    bonoFijoMascota * (rarezaDeMascota[mascota] ?? Rareza.comun).multiplicador;

/// Veridiums extra que la mascota activa añade a una foto verificada.
///
/// Solo hay UNA mascota activa a la vez, y por eso ninguna mejora se apila
/// con otra: cada una es una forma distinta de jugar (agua, noche, variedad,
/// distancia, cultivos), no un escalón de poder. Todas empujan hacia un
/// muestreo que a Veridia le sirve de verdad.
///
/// Lo que SÍ escala con el precio es cuánto paga cada una: ver [Rareza].
BonoMascota bonoDeMascota(MascotaId? mascota, ContextoFoto contexto) {
  if (mascota == null) return const BonoMascota.ninguno();

  final rareza = rarezaDeMascota[mascota] ?? Rareza.comun;
  final bono = bonoDeRareza(mascota);

  switch (mascota) {
    case MascotaId.rana:
      if (!contexto.enHumedal) return const BonoMascota.ninguno();
      return BonoMascota(
        veridiums: bono,
        motivo: 'Bioindicadora: foto en humedal',
      );

    case MascotaId.currucutu:
      if (!contexto.esDeNoche) return const BonoMascota.ninguno();
      return BonoMascota(
        veridiums: bono,
        motivo: 'Ojo nocturno: registro entre 6 p.m. y 6 a.m.',
      );

    case MascotaId.colibri:
      // La única variable: crece con las especies distintas del día en vez de
      // ser un sí/no, así que el multiplicador se aplica sobre ese escalón.
      final extra = contexto.especiesDistintasHoy - (_colibriDesdeEspecie - 1);
      if (extra <= 0) return const BonoMascota.ninguno();
      return BonoMascota(
        veridiums: extra.clamp(1, _colibriMaximo) * rareza.multiplicador,
        motivo:
            'Polinizador: ${contexto.especiesDistintasHoy} especies distintas '
            'hoy',
      );

    case MascotaId.tucaneta:
      if (!contexto.esTerritorioNuevo) return const BonoMascota.ninguno();
      return BonoMascota(
        veridiums: bono,
        motivo: 'Dispersora: territorio nuevo para ti',
      );

    case MascotaId.mariquita:
      if (!contexto.esCultivo) return const BonoMascota.ninguno();
      return BonoMascota(
        veridiums: bono,
        motivo: 'Control biológico: diagnóstico de cultivo',
      );
  }
}

// ---------------------------------------------------------------------------
// Libro de movimientos
// ---------------------------------------------------------------------------

/// Clave de idempotencia de un movimiento de Veridiums.
///
/// Es el ID del documento en `users/{uid}/movimientos`, así que un pago que
/// se intenta dos veces choca contra un documento que ya existe en vez de
/// pagarse dos veces. Por eso NO puede llevar la hora: tiene que ser el mismo
/// identificador para el mismo hecho, se reintente cuando se reintente.
String claveMovimiento({required String motivo, required String referencia}) =>
    '${motivo}_$referencia';

/// Un apunte del libro: cuántos Veridiums se movieron, por qué y sobre qué.
class MovimientoVeridiums {
  const MovimientoVeridiums({
    required this.id,
    required this.delta,
    required this.motivo,
    required this.referencia,
    required this.fecha,
    this.detalle,
  });

  final String id;

  /// Positivo si se ganaron, negativo si se gastaron.
  final int delta;

  /// 'foto', 'bono_desafio', 'mascota', 'compra'...
  final String motivo;

  /// Sobre qué recayó: id de la observación, del desafío, del artículo.
  final String referencia;

  final DateTime fecha;

  /// Texto legible para el historial ("Ojo nocturno: +2").
  final String? detalle;

  bool get esIngreso => delta > 0;
}
