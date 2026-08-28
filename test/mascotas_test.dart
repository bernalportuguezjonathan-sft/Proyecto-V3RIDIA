import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/mascota.dart';
import 'package:veridia_app/services/economia.dart';
import 'package:veridia_app/widgets/mascota_vista.dart';
import 'package:veridia_app/widgets/pixel_sprite.dart';

/// Catálogo del Refugio y arte en píxeles.
///
/// Los sprites son cadenas de texto escritas a mano: una fila de 15 o 17
/// caracteres se ve como un dibujo torcido y no como un error, así que aquí
/// se comprueba la rejilla entera. Es la clase de fallo que solo se nota
/// mirando la pantalla, y en pantalla ya es tarde.
void main() {
  /// Toda rejilla tiene que ser cuadrada, del tamaño esperado, y no usar
  /// ningún carácter que la paleta no sepa pintar.
  void verificarRejilla(PixelArt arte, String nombre, int lado) {
    expect(arte.filas.length, lado, reason: '$nombre: no tiene $lado filas');
    for (var i = 0; i < arte.filas.length; i++) {
      final fila = arte.filas[i];
      expect(
        fila.length,
        lado,
        reason: '$nombre: la fila $i mide ${fila.length}, no $lado',
      );
      for (final caracter in fila.split('')) {
        if (caracter == '.') continue;
        expect(
          arte.paleta.containsKey(caracter),
          isTrue,
          reason:
              '$nombre: la fila $i usa "$caracter", que no está en la paleta',
        );
      }
    }
  }

  group('catálogo de mascotas', () {
    test('están las cinco, una por cada id', () {
      expect(catalogoMascotas.length, MascotaId.values.length);
      expect(
        catalogoMascotas.map((m) => m.id).toSet(),
        MascotaId.values.toSet(),
      );
    });

    test('hay exactamente una mascota inicial y es gratis', () {
      final iniciales = catalogoMascotas.where((m) => m.esInicial).toList();
      expect(iniciales.length, 1);
      expect(iniciales.single.costo, 0);
      expect(iniciales.single.nivelRequerido, 1);
      expect(mascotaInicial.id, iniciales.single.id);
    });

    test('lo más caro exige más nivel: precio y nivel van de la mano', () {
      // Si una mascota cara se abriera en nivel bajo, ahorrar sin gastar
      // sería la única barrera y el nivel dejaría de significar recorrido.
      final compradas = catalogoMascotas.where((m) => !m.esInicial).toList()
        ..sort((a, b) => a.costo.compareTo(b.costo));
      for (var i = 1; i < compradas.length; i++) {
        expect(
          compradas[i].nivelRequerido,
          greaterThanOrEqualTo(compradas[i - 1].nivelRequerido),
          reason: '${compradas[i].nombre} cuesta más pero pide menos nivel',
        );
      }
    });

    test('ningún nivel mínimo queda fuera de la escala', () {
      for (final mascota in catalogoMascotas) {
        expect(mascota.nivelRequerido, inInclusiveRange(1, nivelMaximo));
      }
    });

    test('cada una explica su mejora y trae su dato biológico', () {
      for (final mascota in catalogoMascotas) {
        expect(mascota.mejora, isNotEmpty);
        expect(mascota.descripcionMejora, isNotEmpty);
        expect(mascota.dato, isNotEmpty);
        expect(mascota.nombreCientifico, contains(' '));
      }
    });

    test('cada mascota tiene rareza y su bono sale de ahí', () {
      for (final mascota in catalogoMascotas) {
        expect(mascota.rareza, rarezaDeMascota[mascota.id]);
        expect(mascota.bono, bonoDeRareza(mascota.id));
      }
    });

    test('la descripción anuncia la cifra que de verdad se paga', () {
      // Las cifras del catálogo son constantes escritas a mano (tienen que
      // serlo para caber en un `const`), así que aquí se comprueba que no se
      // hayan quedado desfasadas del cálculo real. Es el fallo más fácil de
      // cometer y el más difícil de ver: la app prometería un número y
      // pagaría otro.
      for (final mascota in catalogoMascotas) {
        if (mascota.id == MascotaId.colibri) continue; // su bono es variable
        expect(
          mascota.descripcionMejora,
          contains('+${mascota.bono} '),
          reason: '${mascota.nombre} anuncia una cifra que no es su bono',
        );
      }
    });

    test('lo más caro es lo más raro: precio y rareza van de la mano', () {
      final porPrecio = [...catalogoMascotas]
        ..sort((a, b) => a.costo.compareTo(b.costo));
      for (var i = 1; i < porPrecio.length; i++) {
        expect(
          porPrecio[i].rareza.multiplicador,
          greaterThanOrEqualTo(porPrecio[i - 1].rareza.multiplicador),
          reason: '${porPrecio[i].nombre} cuesta más pero rinde menos',
        );
      }
    });

    test('mascotaPorId encuentra e ignora lo que no existe', () {
      expect(mascotaPorId(MascotaId.mariquita)?.nombre, 'Mariquita');
      expect(mascotaPorId(null), isNull);
    });
  });

  group('sprites de las mascotas', () {
    test('todas dibujan una rejilla de 16x16 válida', () {
      for (final mascota in catalogoMascotas) {
        verificarRejilla(mascota.sprite, mascota.nombre, 16);
        verificarRejilla(mascota.parpadeo, '${mascota.nombre} (parpadeo)', 16);
      }
    });

    test('las tres primeras filas quedan libres para el sombrero', () {
      // Es la convención que permite que UN accesorio de cabeza sirva para
      // las cinco: si una mascota invadiera esas filas, el sombrero le
      // taparía la cabeza en vez de posarse encima.
      for (final mascota in catalogoMascotas) {
        // El accesorio de cabeza se dibuja en sus filas 0 a 2 y luego se
        // desplaza según el ancla de ESTA mascota; hay que mirar dónde acaba
        // cayendo, no dónde estaba dibujado.
        for (var filaAccesorio = 0; filaAccesorio < 3; filaAccesorio++) {
          final fila = filaAccesorio + mascota.anclaCabeza.dy.round();
          if (fila < 0 || fila >= 16) continue;
          expect(
            mascota.sprite.filas[fila].replaceAll('.', ''),
            isEmpty,
            reason:
                '${mascota.nombre}: el sombrero caería sobre la fila $fila, '
                'que ya tiene dibujo',
          );
        }
      }
    });

    test('el parpadeo tapa píxeles donde la mascota tiene ojos', () {
      for (final mascota in catalogoMascotas) {
        final pintados = mascota.parpadeo.filas
            .join()
            .replaceAll('.', '')
            .length;
        expect(
          pintados,
          greaterThan(0),
          reason: '${mascota.nombre}: el parpadeo está vacío',
        );
      }
    });

    test('la paleta es corta: es lo que lo mantiene como pixel art', () {
      for (final mascota in catalogoMascotas) {
        expect(
          mascota.sprite.paleta.length,
          lessThanOrEqualTo(6),
          reason: '${mascota.nombre} usa demasiados colores',
        );
      }
    });
  });

  group('catálogo de accesorios', () {
    test('no hay ids repetidos entre accesorios ni con las mascotas', () {
      // El id es el id del documento en el inventario: si se repitiera, un
      // accesorio y una mascota se pisarían la compra.
      final ids = catalogoAccesorios.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final mascota in MascotaId.values) {
        expect(ids, isNot(contains(mascota.name)));
      }
    });

    test('las tres ranuras tienen algo que ponerse', () {
      for (final ranura in RanuraAccesorio.values) {
        expect(
          accesoriosDeRanura(ranura),
          isNotEmpty,
          reason: 'la ranura ${ranura.etiqueta} está vacía',
        );
      }
    });

    test('todos cuestan algo: no hay cosméticos regalados', () {
      for (final accesorio in catalogoAccesorios) {
        expect(accesorio.costo, greaterThan(0));
        expect(accesorio.nivelRequerido, inInclusiveRange(1, nivelMaximo));
      }
    });

    test('cabeza y aura son de 16x16; los objetos, de 8x8', () {
      for (final accesorio in catalogoAccesorios) {
        final lado = accesorio.ranura == RanuraAccesorio.objeto ? 8 : 16;
        verificarRejilla(accesorio.sprite, accesorio.nombre, lado);
      }
    });

    test('los de cabeza solo pintan en las tres primeras filas', () {
      for (final accesorio in accesoriosDeRanura(RanuraAccesorio.cabeza)) {
        for (var fila = 3; fila < 16; fila++) {
          expect(
            accesorio.sprite.filas[fila].replaceAll('.', ''),
            isEmpty,
            reason: '${accesorio.nombre}: pinta en la fila $fila',
          );
        }
      }
    });

    test('accesorioPorId encuentra e ignora lo que no existe', () {
      expect(accesorioPorId('lupa')?.ranura, RanuraAccesorio.objeto);
      expect(accesorioPorId('sombrero_invisible'), isNull);
      expect(accesorioPorId(null), isNull);
    });
  });

  group('render de la mascota', () {
    // Las rejillas de texto se validan arriba; esto comprueba el otro lado:
    // que el pintor las dibuje sin reventar, con accesorios encima y con el
    // controlador de la animación bien creado y bien destruido.
    Widget envolver(Widget hijo) => MaterialApp(
      home: Scaffold(body: Center(child: hijo)),
    );

    testWidgets('dibuja cada mascota al tamaño del Refugio', (tester) async {
      for (final mascota in catalogoMascotas) {
        await tester.pumpWidget(
          envolver(MascotaVista(mascota: mascota, tamano: 96)),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('dibuja las tres ranuras encima sin romperse', (tester) async {
      final equipado = {
        RanuraAccesorio.cabeza: accesorioPorId('sombrero_botanico')!,
        RanuraAccesorio.objeto: accesorioPorId('lupa')!,
        RanuraAccesorio.aura: accesorioPorId('aura_luciernagas')!,
      };
      for (final mascota in catalogoMascotas) {
        await tester.pumpWidget(
          envolver(
            MascotaVista(mascota: mascota, equipado: equipado, tamano: 96),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('la animación se detiene al salir de pantalla', (tester) async {
      // Un AnimationController vivo tras el dispose deja el árbol animando
      // para siempre y hace fallar cualquier test posterior con pumpAndSettle.
      await tester.pumpWidget(
        envolver(MascotaVista(mascota: catalogoMascotas.first, tamano: 64)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(envolver(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('quieta no arranca el controlador', (tester) async {
      await tester.pumpWidget(
        envolver(
          MascotaVista(
            mascota: catalogoMascotas.first,
            tamano: 64,
            animar: false,
          ),
        ),
      );
      // Sin animación en curso, pumpAndSettle tiene que terminar.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PixelArt.desplazado', () {
    const arte = PixelArt(
      paleta: {'x': Color(0xFFFFFFFF)},
      filas: ['xx..', '....', '....', '....'],
    );

    test('mover cero no cambia nada', () {
      expect(identical(arte.desplazado(), arte), isTrue);
    });

    test('conserva el tamaño de la rejilla', () {
      final movido = arte.desplazado(dx: 2, dy: 1);
      expect(movido.filas.length, 4);
      for (final fila in movido.filas) {
        expect(fila.length, 4);
      }
    });

    test('mueve los píxeles a donde toca', () {
      expect(arte.desplazado(dx: 1).filas.first, '.xx.');
      expect(arte.desplazado(dy: 1).filas[1], 'xx..');
      expect(arte.desplazado(dy: 1).filas.first, '....');
    });

    test('lo que se sale de la rejilla se recorta, no da la vuelta', () {
      // Si diera la vuelta, un sombrero desplazado a la izquierda reaparecería
      // por el borde derecho de la mascota.
      expect(arte.desplazado(dx: -1).filas.first, 'x...');
      expect(arte.desplazado(dx: -5).filas.first, '....');
      expect(arte.desplazado(dy: -1).filas.last, '....');
    });

    test('mantiene la paleta', () {
      expect(arte.desplazado(dx: 1).paleta, arte.paleta);
    });
  });
}
