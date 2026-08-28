/// Arte en píxeles de las mascotas y sus accesorios.
///
/// Convenciones de la rejilla, respetadas por TODOS los sprites:
/// - 16x16 para mascotas, accesorios de cabeza y auras; 8x8 para objetos.
/// - `.` es transparente.
/// - Las filas 0 a 2 de cada mascota se dejan libres: ahí es donde aterrizan
///   los sombreros. Cada mascota declara además cuánto hay que mover el
///   accesorio para que le caiga bien (ver `anclaCabeza` en mascota.dart).
/// - Máximo cinco colores por sprite. La paleta corta es lo que hace que
///   esto se lea como pixel art y no como un dibujo pequeño.
library;

import 'package:flutter/material.dart';

import '../widgets/pixel_sprite.dart';

// ---------------------------------------------------------------------------
// Rana sabanera
// ---------------------------------------------------------------------------

const _paletaRana = {
  'o': Color(0xFF25501C),
  'b': Color(0xFF6FBF57),
  'l': Color(0xFFB6E4A2),
  'w': Color(0xFFEFF7E8),
  'k': Color(0xFF09160A),
};

const spriteRana = PixelArt(
  paleta: _paletaRana,
  filas: [
    '................',
    '................',
    '................',
    '....oo....oo....',
    '...owwo..owwo...',
    '...owko..okwo...',
    '..oobbo..obboo..',
    '.obbbbbbbbbbbbo.',
    'obbbbbbbbbbbbbbo',
    'obblbbbbbbbbllbo',
    'obbbbbbbbbbbbbbo',
    'obbbbboooobbbbbo',
    '.obbbbbbbbbbbbo.',
    '..obbbbbbbbbbo..',
    '.ooo........ooo.',
    'obbbo......obbbo',
  ],
);

const parpadeoRana = PixelArt(
  paleta: _paletaRana,
  filas: [
    '................',
    '................',
    '................',
    '................',
    '....oo....oo....',
    '....oo....oo....',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
);

// ---------------------------------------------------------------------------
// Currucutú
// ---------------------------------------------------------------------------

const _paletaCurrucutu = {
  'o': Color(0xFF4A3A28),
  'b': Color(0xFFA98763),
  'l': Color(0xFFDCC7A6),
  'w': Color(0xFFF2E9D8),
  'k': Color(0xFF09160A),
  'a': Color(0xFFFFD166),
};

const spriteCurrucutu = PixelArt(
  paleta: _paletaCurrucutu,
  filas: [
    '................',
    '................',
    '..oo........oo..',
    '.obbo......obbo.',
    '.obbboooooobbbo.',
    '..obbbbbbbbbbo..',
    '..obbbbbbbbbbo..',
    '..obwwbbbbwwbo..',
    '..obwkbbbbkwbo..',
    '..obbbbaabbbbo..',
    '..obblbbbblbbo..',
    '..obbllllllbbo..',
    '...obbbbbbbbo...',
    '....obbbbbbo....',
    '.....oaaaao.....',
    '......aaaa......',
  ],
);

const parpadeoCurrucutu = PixelArt(
  paleta: _paletaCurrucutu,
  filas: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '....oo....oo....',
    '....oo....oo....',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
);

// ---------------------------------------------------------------------------
// Colibrí chillón
// ---------------------------------------------------------------------------

const _paletaColibri = {
  'o': Color(0xFF14414F),
  'b': Color(0xFF3FA9C4),
  'l': Color(0xFF9FD75B),
  'w': Color(0xFFF2E9D8),
  'k': Color(0xFF09160A),
  'a': Color(0xFF3A2E22),
};

const spriteColibri = PixelArt(
  paleta: _paletaColibri,
  filas: [
    '................',
    '................',
    '................',
    '......oooo......',
    '.....obbbbo.....',
    '....obwkbbbaaaaa',
    '....obbbbbbo....',
    '...obbbbbbbo....',
    '.llobbbbbbbo....',
    'lllobbbbbbo.....',
    '.llobbbbbbo.....',
    '..obbbbbbo......',
    '...obbbbo.......',
    '...obbbo........',
    '..oobbo.........',
    '..oo............',
  ],
);

const parpadeoColibri = PixelArt(
  paleta: _paletaColibri,
  filas: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '......oo........',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
);

// ---------------------------------------------------------------------------
// Tucaneta andino
// ---------------------------------------------------------------------------

const _paletaTucaneta = {
  'o': Color(0xFF17401A),
  'b': Color(0xFF57B04A),
  'l': Color(0xFF9FD75B),
  'w': Color(0xFFF2E9D8),
  'k': Color(0xFF09160A),
  'a': Color(0xFFFFD166),
};

const spriteTucaneta = PixelArt(
  paleta: _paletaTucaneta,
  filas: [
    '................',
    '................',
    '................',
    '.....oooo.......',
    '....obbbbo......',
    '...obbbbbbo.....',
    '...obwkbbboooooo',
    '...obbbbbaaaaaao',
    '..obbbbbbaaaaao.',
    '..obbbbbbboooo..',
    '.obbbbbbbbo.....',
    '.obbbbbbbbo.....',
    '.obbbbbbbbo.....',
    '.obbbbbbbo......',
    '..obbbbbo.......',
    '...obbbo........',
  ],
);

const parpadeoTucaneta = PixelArt(
  paleta: _paletaTucaneta,
  filas: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.....oo.........',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
);

// ---------------------------------------------------------------------------
// Mariquita
// ---------------------------------------------------------------------------

const _paletaMariquita = {
  'o': Color(0xFF7A2415),
  'b': Color(0xFFE85A3A),
  'k': Color(0xFF1A1410),
  'w': Color(0xFFF2E9D8),
  'l': Color(0xFFFF8C60),
};

const spriteMariquita = PixelArt(
  paleta: _paletaMariquita,
  filas: [
    '................',
    '................',
    '......kkkk......',
    '....kkkkkkkk....',
    '...kkwwkkwwkk...',
    '..okkkkkkkkkko..',
    '.obbbbbkkbbbbbo.',
    'obbkbbbkkbbbkbbo',
    'obbkkbbkkbbkkbbo',
    'obbbbbbkkbbbbbbo',
    'obbbbbbkkbbbbbbo',
    'obkkbbbkkbbbkkbo',
    '.obkkbbkkbbkkbo.',
    '..obbbbkkbbbbo..',
    '...oobbbbbboo...',
    '....oo....oo....',
  ],
);

const parpadeoMariquita = PixelArt(
  paleta: _paletaMariquita,
  filas: [
    '................',
    '................',
    '................',
    '................',
    '.....kk..kk.....',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
);

// ---------------------------------------------------------------------------
// Accesorios de cabeza (16x16, filas 0 a 2, centrados en la columna 8)
// ---------------------------------------------------------------------------

const _filasVacias = [
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
];

const spriteSombreroBotanico = PixelArt(
  paleta: {'h': Color(0xFFE0CE9E), 'c': Color(0xFFA8925C)},
  filas: [
    '......hhhh......',
    '.....hhhhhh.....',
    '..cccccccccccc..',
    ..._filasVacias,
  ],
);

const spriteGorraCampo = PixelArt(
  paleta: {'g': Color(0xFF6A9E2A), 'v': Color(0xFF3F6B14)},
  filas: [
    '......gggg......',
    '....gggggggg....',
    '....ggggggggvvvv',
    ..._filasVacias,
  ],
);

const spriteCoronaMusgo = PixelArt(
  paleta: {'m': Color(0xFF4C7C00), 'f': Color(0xFF9FD75B)},
  filas: [
    '....f.f.f.f.f...',
    '...mmmmmmmmmm...',
    '................',
    ..._filasVacias,
  ],
);

const spriteCascoEspeleologo = PixelArt(
  paleta: {'h': Color(0xFFBCCABC), 'l': Color(0xFFFFD166)},
  filas: [
    '......hhhh......',
    '....hhhhhhhh....',
    '..llhhhhhhhhhh..',
    ..._filasVacias,
  ],
);

// ---------------------------------------------------------------------------
// Auras (16x16, se pintan DETRÁS de la mascota)
// ---------------------------------------------------------------------------

const spriteAuraLuciernagas = PixelArt(
  paleta: {'a': Color(0xFFFFD166)},
  filas: [
    '..a.........a...',
    '................',
    '.......a........',
    'a.............a.',
    '................',
    '................',
    '.a............a.',
    '................',
    '................',
    'a..............a',
    '................',
    '....a......a....',
    '................',
    '.a............a.',
    '................',
    '.....a....a.....',
  ],
);

const spriteAuraPolen = PixelArt(
  paleta: {'p': Color(0xFF9FD75B)},
  filas: [
    '................',
    '.....p....p.....',
    '..p...........p.',
    '................',
    '.p.....p.....p..',
    '................',
    'p.............p.',
    '.....p...p......',
    '................',
    '.p...........p..',
    '................',
    'p......p.......p',
    '................',
    '..p.......p.....',
    '................',
    '.....p...p......',
  ],
);

const spriteAuraNiebla = PixelArt(
  paleta: {'n': Color(0xFFBCCABC)},
  filas: [
    '................',
    '...nnnn....nnn..',
    '................',
    'nn.......nnnn...',
    '................',
    '................',
    '..nn..........nn',
    '................',
    '................',
    'nnn...........nn',
    '................',
    '................',
    '.nn.........nnn.',
    '................',
    '...nnnn...nnnn..',
    '................',
  ],
);

// ---------------------------------------------------------------------------
// Objetos (8x8, se pintan al lado de la mascota, no encima)
// ---------------------------------------------------------------------------

const spriteLupa = PixelArt(
  paleta: {
    'm': Color(0xFFBCCABC),
    'g': Color(0xFF7FD4E8),
    'l': Color(0xFFEFFBFF),
    'h': Color(0xFF7A5A38),
  },
  filas: [
    '..mmmm..',
    '.mggggm.',
    'mggllggm',
    'mgglgggm',
    'mggggggm',
    '.mggggm.',
    '..mmmhh.',
    '.....hh.',
  ],
);

const spriteLibreta = PixelArt(
  paleta: {
    't': Color(0xFF8A5A3C),
    'p': Color(0xFFF2E9D8),
    'l': Color(0xFF8C9387),
  },
  filas: [
    '.tttttt.',
    '.tppppt.',
    '.tplllt.',
    '.tppppt.',
    '.tplllt.',
    '.tppppt.',
    '.tpllpt.',
    '.tttttt.',
  ],
);

const spriteBinoculares = PixelArt(
  paleta: {
    'b': Color(0xFF2B382A),
    'g': Color(0xFF7FD4E8),
    'o': Color(0xFF141B13),
  },
  filas: [
    '.bb..bb.',
    'bggbbggb',
    'bggbbggb',
    'bggbbggb',
    '.bb..bb.',
    '.bb..bb.',
    '.oo..oo.',
    '........',
  ],
);

const spriteCantimplora = PixelArt(
  paleta: {
    'c': Color(0xFF8C9387),
    'w': Color(0xFF4C7C00),
    'o': Color(0xFF2D5A27),
  },
  filas: [
    '..cccc..',
    '..c..c..',
    '.wwwwww.',
    'wwwwwwww',
    'wwwwwwww',
    'wwwwwwww',
    '.wwwwww.',
    '..oooo..',
  ],
);
