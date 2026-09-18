import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/widgets/veridia_ui.dart';

/// El contador de Veridiums.
///
/// Lo que se prueba aquí no es que anime —eso se ve— sino las dos decisiones
/// que son fáciles de romper sin darse cuenta: que NO cuente desde cero al
/// abrir una pantalla, y que acabe siempre en el número exacto.
void main() {
  Future<void> montar(WidgetTester tester, int valor) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: VeridiaContador(valor: valor)),
        ),
      ),
    );
  }

  testWidgets('al aparecer muestra el saldo, no lo cuenta desde cero', (
    tester,
  ) async {
    await montar(tester, 240);

    // Sin bombear un solo cuadro: el número ya tiene que estar ahí. Si
    // animara desde 0, en este instante se leería "0" y el explorador vería
    // su saldo subir solo por haber abierto una pantalla.
    expect(find.text('240'), findsOneWidget);
  });

  testWidgets('al subir recorre el camino y llega al valor exacto', (
    tester,
  ) async {
    await montar(tester, 10);
    await montar(tester, 25);

    // A mitad de la animación el número va por el camino, no en el destino.
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.text('25'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('al gastar también llega al valor exacto', (tester) async {
    await montar(tester, 80);
    await montar(tester, 30);
    await tester.pumpAndSettle();

    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('un saldo que no cambia no monta ninguna animación', (
    tester,
  ) async {
    await montar(tester, 15);
    await montar(tester, 15);

    // Importa porque esta píldora vive en la AppBar de casi toda la app: un
    // widget de animación montado en cada pantalla se paga en todas.
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('llegar a cero se muestra como cero', (tester) async {
    await montar(tester, 5);
    await montar(tester, 0);
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
  });
}
