import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/widgets/veridia_ui.dart';

/// La banda de brillo que cruza los botones al tocarlos.
///
/// Se prueba porque el mismo efecto se rompió DOS veces por la misma causa y
/// de las dos formas posibles: dentro de un `Positioned.fill` las
/// restricciones llegan ajustadas al botón, así que el ancho y el alto que
/// pide la banda se recortan a esa caja sin avisar.
///
/// - Recortado el ancho, la banda salía tan ancha como el botón entero y se
///   veía medio botón iluminado incluso sin tocarlo.
/// - Recortado el alto, la banda quedaba tan alta como el botón y al
///   inclinarla sus dos puntas se salían por arriba y por abajo: dentro solo
///   quedaba una franja corta y caída hacia abajo, así que la mitad de arriba
///   del botón no se iluminaba nunca.
///
/// Nada de esto lo ve el analizador ni tumba ninguna otra prueba: el botón
/// sigue funcionando, solo se ve mal. Por eso se fija aquí.
void main() {
  const anchoBoton = 320.0;
  const altoBoton = 52.0;

  /// La banda es el único `Container` con degradado dentro del botón.
  Finder banda() => find.byWidgetPredicate((w) {
    if (w is! Container) return false;
    final decoracion = w.decoration;
    return decoracion is BoxDecoration && decoracion.gradient != null;
  });

  Future<void> montar(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: anchoBoton,
              height: altoBoton,
              child: VeridiaBotonTactil(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Entrar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Deja el destello a media pasada, que es cuando la banda está encima del
  /// botón. Devuelve el gesto para poder soltarlo al terminar de medir.
  Future<TestGesture> destellar(WidgetTester tester) async {
    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(VeridiaBotonTactil)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return gesto;
  }

  testWidgets('sin tocarlo no hay ninguna banda dentro del botón', (
    tester,
  ) async {
    await montar(tester);

    // El brillo es la respuesta al dedo o al mouse. Sin gesto no se monta
    // nada, así que tampoco puede quedarse una franja clara parada dentro.
    expect(banda(), findsNothing);
  });

  testWidgets('la banda rebasa el alto del botón en vez de recortarse a él', (
    tester,
  ) async {
    await montar(tester);
    final gesto = await destellar(tester);

    final alto = tester.getSize(banda()).height;

    // Inclinada unos 20°, una banda tan alta como el botón deja de llegar a
    // sus bordes: necesita al menos `alto / cos(20°)` para volver a taparlo
    // de arriba abajo. Si alguien la vuelve a apretar contra las
    // restricciones del padre, esta comparación cae.
    expect(alto, greaterThan(altoBoton / math.cos(0.35)));

    await gesto.up();
    await tester.pumpAndSettle();
  });

  testWidgets('la banda es estrecha: un reflejo, no medio botón encendido', (
    tester,
  ) async {
    await montar(tester);
    final gesto = await destellar(tester);

    final ancho = tester.getSize(banda()).width;

    // Proporcional al botón, y lejísimos de su ancho completo —que es lo que
    // medía cuando las restricciones la estiraban—.
    expect(ancho, closeTo(anchoBoton * 0.28, 1));

    await gesto.up();
    await tester.pumpAndSettle();
  });

  testWidgets('al soltar, el destello termina y la banda desaparece', (
    tester,
  ) async {
    await montar(tester);
    final gesto = await destellar(tester);
    await gesto.up();
    await tester.pumpAndSettle();

    // Cruza una vez y se va. Un brillo que se queda es exactamente el fallo
    // que se veía en las capturas.
    expect(banda(), findsNothing);
  });

  testWidgets('el brillo llega al borde de arriba y al de abajo del botón', (
    tester,
  ) async {
    await montar(tester);
    final gesto = await destellar(tester);

    final bandaBox = tester.renderObject<RenderBox>(banda());
    final botonBox = tester.renderObject<RenderBox>(
      find.byType(VeridiaBotonTactil),
    );
    final aBoton = bandaBox.getTransformTo(botonBox);

    // Los dos extremos de la LÍNEA CENTRAL de la banda, medidos en las
    // coordenadas del botón.
    //
    // Se mide el centro y no las esquinas a propósito: el degradado va de
    // transparente a blanco y otra vez a transparente a lo ancho, así que los
    // dos cantos largos de la banda son invisibles y lo único que se ve de
    // verdad es este eje. `getRect` tampoco sirve aquí: con una rotación de
    // por medio devuelve el rectángulo entre dos esquinas transformadas, que
    // no es la caja que la banda ocupa realmente.
    final eje = [
      Offset(bandaBox.size.width / 2, 0),
      Offset(bandaBox.size.width / 2, bandaBox.size.height),
    ].map((p) => MatrixUtils.transformPoint(aBoton, p)).toList();

    final arriba = math.min(eje.first.dy, eje.last.dy);
    final abajo = math.max(eje.first.dy, eje.last.dy);

    // Esto es exactamente lo que se veía mal. Con la banda recortada al alto
    // del botón, al inclinarla su eje se quedaba corto por los dos lados y el
    // brillo arrancaba pasada la mitad: la franja de arriba no se encendía
    // nunca.
    expect(arriba, lessThanOrEqualTo(0));
    expect(abajo, greaterThanOrEqualTo(altoBoton));

    await gesto.up();
    await tester.pumpAndSettle();
  });
}
