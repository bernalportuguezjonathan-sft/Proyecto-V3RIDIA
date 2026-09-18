import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/theme/veridia_theme.dart';
import 'package:veridia_app/widgets/veridia_responsive.dart';

/// Las decisiones de diseño adaptable, probadas en sus bordes.
///
/// El desbordamiento del panel del mapa apareció justo en una frontera de
/// ancho, y esas fronteras no se ven mirando la app en un solo teléfono.
void main() {
  group('VeridiaAncho.deAncho', () {
    test('un teléfono corriente es compacto', () {
      expect(VeridiaAncho.deAncho(360), VeridiaAncho.compacto);
      expect(VeridiaAncho.deAncho(412), VeridiaAncho.compacto);
    });

    test('una tablet en vertical es medio', () {
      expect(VeridiaAncho.deAncho(768), VeridiaAncho.medio);
    });

    test('un navegador de escritorio es amplio', () {
      expect(VeridiaAncho.deAncho(1440), VeridiaAncho.amplio);
    });

    test('las fronteras exactas caen del lado ancho', () {
      // 600 ya es tablet y 1024 ya es escritorio: si el umbral fuera
      // exclusivo, una pantalla de exactamente 600 se quedaría con el diseño
      // de teléfono y el salto se vería un píxel más tarde.
      expect(VeridiaAncho.deAncho(599.9), VeridiaAncho.compacto);
      expect(
        VeridiaAncho.deAncho(VeridiaBreakpoints.tablet),
        VeridiaAncho.medio,
      );
      expect(VeridiaAncho.deAncho(1023.9), VeridiaAncho.medio);
      expect(
        VeridiaAncho.deAncho(VeridiaBreakpoints.escritorio),
        VeridiaAncho.amplio,
      );
    });

    test('el margen crece con el espacio disponible', () {
      expect(VeridiaAncho.compacto.margen, lessThan(VeridiaAncho.medio.margen));
      expect(VeridiaAncho.medio.margen, lessThan(VeridiaAncho.amplio.margen));
    });

    test('tieneEspacio separa el teléfono de lo demás', () {
      expect(VeridiaAncho.compacto.tieneEspacio, isFalse);
      expect(VeridiaAncho.medio.tieneEspacio, isTrue);
      expect(VeridiaAncho.amplio.tieneEspacio, isTrue);
    });
  });

  group('VeridiaRejilla.columnasPara', () {
    int columnas(double disponible, {double comodo = 260, int maximo = 4}) =>
        VeridiaRejilla.columnasPara(
          disponible: disponible,
          anchoComodo: comodo,
          espacio: 16,
          maximoColumnas: maximo,
        );

    test('en un teléfono estrecho cabe una sola columna', () {
      expect(columnas(328), 1);
    });

    test('dos columnas en cuanto hay sitio para dos', () {
      // 260 + 16 + 260 = 536.
      expect(columnas(536), 2);
      expect(columnas(535), 1);
    });

    test('nunca pasa del tope', () {
      expect(columnas(4000), 4);
      expect(columnas(4000, maximo: 2), 2);
    });

    test('nunca devuelve cero columnas', () {
      // Cero sería una división por cero al repartir el ancho entre columnas.
      expect(columnas(0), 1);
      expect(columnas(-50), 1);
      expect(columnas(double.infinity), 1);
      expect(columnas(500, maximo: 0), 1);
    });

    test('las fichas del Refugio pasan a dos columnas en escritorio', () {
      // El caso real: cinco fichas de 420 px cómodos, tope de dos, dentro del
      // ancho máximo de contenido menos su margen.
      const anchoReal = VeridiaBreakpoints.anchoMaximoContenido - 64;
      expect(columnas(anchoReal, comodo: 420, maximo: 2), 2);
      // Y siguen en una sola columna en un teléfono.
      expect(columnas(328, comodo: 420, maximo: 2), 1);
    });
  });

  group('VeridiaRejilla en pantalla', () {
    testWidgets('no desborda cuando el ancho no alcanza', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: VeridiaRejilla(
                anchoComodo: 420,
                hijos: List.generate(
                  5,
                  (i) => SizedBox(height: 40, child: Text('$i')),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('una rejilla vacía no dibuja nada', () {
      expect(const VeridiaRejilla(hijos: []).hijos, isEmpty);
    });
  });
}
