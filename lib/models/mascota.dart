import 'package:flutter/material.dart';

import '../services/economia.dart';
import '../theme/veridia_theme.dart';
import '../widgets/pixel_sprite.dart';
import 'mascota_sprites.dart';

/// Compañeros de exploración: cinco especies reales de Cundinamarca.
///
/// El catálogo vive en el CÓDIGO y no en Firestore, igual que el de
/// recompensas: precios, niveles y mejoras son balance del juego, no
/// contenido que un administrador deba poder cambiar en caliente sin que
/// nadie revise qué le hace eso a la economía.
///
/// La mejora de cada mascota sale de un rasgo biológico verdadero del animal
/// y empuja hacia un muestreo que a Veridia le sirve: agua, noche, variedad,
/// cobertura y cultivos. Por eso solo puede haber UNA activa a la vez —
/// elegir mascota es elegir cómo explorar, no acumular poder.
class Mascota {
  const Mascota({
    required this.id,
    required this.nombre,
    required this.nombreCientifico,
    required this.mejora,
    required this.descripcionMejora,
    required this.dato,
    required this.costo,
    required this.nivelRequerido,
    required this.color,
    required this.sprite,
    required this.parpadeo,
    this.anclaCabeza = Offset.zero,
  });

  final String nombre;
  final MascotaId id;

  final String nombreCientifico;

  /// Nombre corto de la mejora ("Ojo nocturno").
  final String mejora;

  /// Qué hace la mejora, en una frase que el explorador pueda accionar.
  final String descripcionMejora;

  /// Dato biológico real. La mascota también enseña: es la excusa para que
  /// alguien aprenda por qué las ranas son bioindicadoras sin leer una ficha.
  final String dato;

  /// Veridiums que cuesta. 0 = viene con la cuenta.
  final int costo;

  /// Nivel que hay que tener para poder comprarla. Sin esto, ahorrar sin
  /// gastar sería la única barrera y una mascota cara diría "no gasté", no
  /// "llevo tiempo".
  final int nivelRequerido;

  /// Qué tan rara es, y por tanto por cuánto multiplica su mejora.
  /// Se deriva del catálogo de economía para que precio, nivel y pago no
  /// puedan desalinearse desde dos sitios distintos.
  Rareza get rareza => rarezaDeMascota[id] ?? Rareza.comun;

  /// Veridiums que paga su mejora cuando se cumple la condición.
  int get bono => bonoDeRareza(id);

  final Color color;

  final PixelArt sprite;

  /// Capa de ojos cerrados que se pinta durante el parpadeo.
  final PixelArt parpadeo;

  /// Cuánto hay que mover un accesorio de cabeza (en celdas de la rejilla)
  /// para que le caiga bien a ESTA mascota: el colibrí tiene la cabeza a la
  /// izquierda, la mariquita más arriba. Así un sombrero sirve para las cinco.
  final Offset anclaCabeza;

  bool get esInicial => costo == 0;
}

// Cifras de pago por rareza, en forma const para poder escribirlas dentro
// del catálogo. `test/mascotas_test.dart` comprueba que coincidan con
// `bonoDeRareza`, así que no pueden quedarse desfasadas en silencio.
const int _bonoComun = bonoFijoMascota * 1;
const int _bonoRaro = bonoFijoMascota * 2;
const int _bonoEpico = bonoFijoMascota * 3;
const int _bonoLegendario = bonoFijoMascota * 4;

const List<Mascota> catalogoMascotas = [
  Mascota(
    id: MascotaId.rana,
    nombre: 'Rana sabanera',
    nombreCientifico: 'Dendropsophus molitor',
    mejora: 'Bioindicadora',
    descripcionMejora:
        '+$_bonoComun Veridiums por cada foto tomada dentro de un humedal, '
        'y te marca los humedales cercanos en el mapa.',
    dato:
        'Vive en los humedales del altiplano cundiboyacense. Su piel absorbe '
        'agua y aire, así que enferma antes que ningún otro animal cuando el '
        'humedal se contamina: por eso los biólogos la usan como alarma '
        'temprana.',
    costo: 0,
    nivelRequerido: 1,
    color: VeridiaColors.primary,
    sprite: spriteRana,
    parpadeo: parpadeoRana,
  ),
  Mascota(
    id: MascotaId.colibri,
    nombre: 'Colibrí chillón',
    nombreCientifico: 'Colibri coruscans',
    mejora: 'Polinizador',
    descripcionMejora:
        'Desde la tercera especie DISTINTA que registres en un mismo día, '
        'cada especie nueva suma Veridiums (hasta +$_bonoComun por escalón, '
        'máximo +${_bonoComun * 3}).',
    dato:
        'Es el colibrí más común de la Sabana de Bogotá. Visita cientos de '
        'flores al día porque su metabolismo lo obliga: de noche baja su '
        'temperatura y entra en letargo para no gastar energía.',
    costo: 40,
    nivelRequerido: 2,
    color: Color(0xFF3FA9C4),
    sprite: spriteColibri,
    parpadeo: parpadeoColibri,
  ),
  Mascota(
    id: MascotaId.currucutu,
    nombre: 'Currucutú',
    nombreCientifico: 'Megascops choliba',
    mejora: 'Ojo nocturno',
    descripcionMejora:
        '+$_bonoRaro Veridiums por cada foto registrada entre las 6 p.m. y '
        'las 6 a.m.',
    dato:
        'Búho pequeño de penachos, activo solo de noche. La fauna nocturna es '
        'la menos documentada de Cundinamarca: casi nadie sale a esa hora, '
        'así que cada registro tuyo vale el doble para el monitoreo.',
    costo: 70,
    nivelRequerido: 3,
    color: Color(0xFFA98763),
    sprite: spriteCurrucutu,
    parpadeo: parpadeoCurrucutu,
    // Los penachos ocupan la fila 2, así que el sombrero sube una fila para
    // apoyarse entre ellos en vez de atravesarlos.
    anclaCabeza: Offset(0, -1),
  ),
  Mascota(
    id: MascotaId.mariquita,
    nombre: 'Mariquita',
    nombreCientifico: 'Cycloneda sanguinea',
    mejora: 'Control biológico',
    descripcionMejora:
        '+$_bonoEpico Veridiums en diagnósticos de cultivo (plantas y '
        'hongos), y te recuerda revisar el envés de las hojas.',
    dato:
        'Una sola mariquita se come decenas de áfidos al día. Es control de '
        'plagas sin un gramo de químico, y por eso los cultivos que la '
        'conservan necesitan menos fumigación.',
    costo: 110,
    nivelRequerido: 4,
    color: Color(0xFFE85A3A),
    sprite: spriteMariquita,
    parpadeo: parpadeoMariquita,
    anclaCabeza: Offset(0, -1),
  ),
  Mascota(
    id: MascotaId.tucaneta,
    nombre: 'Tucaneta esmeralda',
    nombreCientifico: 'Aulacorhynchus prasinus',
    mejora: 'Dispersora',
    descripcionMejora:
        '+$_bonoLegendario Veridiums cuando la foto está a más de '
        '$kmTerritorioNuevo km de todas tus fotos anteriores.',
    dato:
        'Come fruta y suelta las semillas lejos del árbol madre: buena parte '
        'del bosque andino existe porque ella lo sembró volando. Es la '
        'mascota de quien se aleja del mismo parque de siempre.',
    costo: 160,
    nivelRequerido: 5,
    color: Color(0xFF57B04A),
    sprite: spriteTucaneta,
    parpadeo: parpadeoTucaneta,
    anclaCabeza: Offset(-2, 0),
  ),
];

Mascota? mascotaPorId(MascotaId? id) {
  if (id == null) return null;
  for (final mascota in catalogoMascotas) {
    if (mascota.id == id) return mascota;
  }
  return null;
}

/// La que trae la cuenta desde el registro: nadie empieza sin compañero.
Mascota get mascotaInicial =>
    catalogoMascotas.firstWhere((mascota) => mascota.esInicial);

// ---------------------------------------------------------------------------
// Accesorios
// ---------------------------------------------------------------------------

/// Dónde se pone un accesorio. Una ranura, un accesorio equipado.
enum RanuraAccesorio { cabeza, objeto, aura }

extension RanuraAccesorioX on RanuraAccesorio {
  String get etiqueta => switch (this) {
    RanuraAccesorio.cabeza => 'Cabeza',
    RanuraAccesorio.objeto => 'Objeto',
    RanuraAccesorio.aura => 'Aura',
  };

  IconData get icono => switch (this) {
    RanuraAccesorio.cabeza => Icons.emoji_objects_outlined,
    RanuraAccesorio.objeto => Icons.backpack_outlined,
    RanuraAccesorio.aura => Icons.auto_awesome_outlined,
  };
}

RanuraAccesorio? ranuraDesde(String? clave) {
  for (final ranura in RanuraAccesorio.values) {
    if (ranura.name == clave) return ranura;
  }
  return null;
}

/// Un accesorio para la mascota.
///
/// Son 100% COSMÉTICOS a propósito. Si además dieran Veridiums se apilarían
/// con la mejora de la mascota, habría que rebalancear el juego entero cada
/// vez que se añade uno, y ganaría quien más grindeara. Así el accesorio es
/// puro estatus, que es exactamente para lo que se compra.
///
/// Son UNIVERSALES: sirven en las cinco mascotas, así que cambiar de
/// compañero nunca te hace perder lo que compraste.
class Accesorio {
  const Accesorio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.ranura,
    required this.costo,
    required this.nivelRequerido,
    required this.sprite,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final RanuraAccesorio ranura;
  final int costo;
  final int nivelRequerido;
  final PixelArt sprite;
}

const List<Accesorio> catalogoAccesorios = [
  // Cabeza
  Accesorio(
    id: 'gorra_campo',
    nombre: 'Gorra de campo',
    descripcion: 'La que se pone quien madruga a caminar.',
    ranura: RanuraAccesorio.cabeza,
    costo: 20,
    nivelRequerido: 1,
    sprite: spriteGorraCampo,
  ),
  Accesorio(
    id: 'sombrero_botanico',
    nombre: 'Sombrero de botánico',
    descripcion: 'Ala ancha de paja, contra el sol de la Sabana.',
    ranura: RanuraAccesorio.cabeza,
    costo: 25,
    nivelRequerido: 2,
    sprite: spriteSombreroBotanico,
  ),
  Accesorio(
    id: 'casco_espeleologo',
    nombre: 'Casco de espeleólogo',
    descripcion: 'Con lámpara: para cuevas y salidas de noche.',
    ranura: RanuraAccesorio.cabeza,
    costo: 40,
    nivelRequerido: 3,
    sprite: spriteCascoEspeleologo,
  ),
  Accesorio(
    id: 'corona_musgo',
    nombre: 'Corona de musgo',
    descripcion: 'Musgo de páramo con flores diminutas.',
    ranura: RanuraAccesorio.cabeza,
    costo: 45,
    nivelRequerido: 3,
    sprite: spriteCoronaMusgo,
  ),

  // Objeto
  Accesorio(
    id: 'libreta',
    nombre: 'Libreta de campo',
    descripcion: 'Donde se anota lo que la cámara no alcanza.',
    ranura: RanuraAccesorio.objeto,
    costo: 25,
    nivelRequerido: 1,
    sprite: spriteLibreta,
  ),
  Accesorio(
    id: 'lupa',
    nombre: 'Lupa',
    descripcion: 'Para el detalle que decide la especie.',
    ranura: RanuraAccesorio.objeto,
    costo: 30,
    nivelRequerido: 2,
    sprite: spriteLupa,
  ),
  Accesorio(
    id: 'cantimplora',
    nombre: 'Cantimplora',
    descripcion: 'Salir sin agua es la forma más tonta de volver temprano.',
    ranura: RanuraAccesorio.objeto,
    costo: 35,
    nivelRequerido: 2,
    sprite: spriteCantimplora,
  ),
  Accesorio(
    id: 'binoculares',
    nombre: 'Binoculares',
    descripcion: 'Ver el ave sin espantarla es media identificación.',
    ranura: RanuraAccesorio.objeto,
    costo: 55,
    nivelRequerido: 4,
    sprite: spriteBinoculares,
  ),

  // Aura
  Accesorio(
    id: 'aura_polen',
    nombre: 'Polen brillante',
    descripcion: 'Motas verdes flotando alrededor.',
    ranura: RanuraAccesorio.aura,
    costo: 50,
    nivelRequerido: 3,
    sprite: spriteAuraPolen,
  ),
  Accesorio(
    id: 'aura_luciernagas',
    nombre: 'Luciérnagas',
    descripcion: 'Puntos de luz que te siguen al anochecer.',
    ranura: RanuraAccesorio.aura,
    costo: 60,
    nivelRequerido: 4,
    sprite: spriteAuraLuciernagas,
  ),
  Accesorio(
    id: 'aura_niebla',
    nombre: 'Niebla de páramo',
    descripcion: 'La bruma que sube del Sumapaz a las cinco de la tarde.',
    ranura: RanuraAccesorio.aura,
    costo: 70,
    nivelRequerido: 5,
    sprite: spriteAuraNiebla,
  ),
];

Accesorio? accesorioPorId(String? id) {
  if (id == null) return null;
  for (final accesorio in catalogoAccesorios) {
    if (accesorio.id == id) return accesorio;
  }
  return null;
}

List<Accesorio> accesoriosDeRanura(RanuraAccesorio ranura) =>
    catalogoAccesorios.where((a) => a.ranura == ranura).toList();
