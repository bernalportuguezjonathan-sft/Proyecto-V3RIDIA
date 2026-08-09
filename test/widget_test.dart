import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/widgets/animated_visibility.dart';

/// El campo de "código de administrador" y el botón de Google aparecen y
/// desaparecen con este widget según el rol elegido en Login/Registro.
void main() {
  Widget envolver({required bool visible}) => MaterialApp(
    home: Scaffold(
      body: AnimatedVisibility(
        visible: visible,
        child: const Text('Código de administrador'),
      ),
    ),
  );

  testWidgets('muestra el contenido cuando visible es true', (tester) async {
    await tester.pumpWidget(envolver(visible: true));
    await tester.pumpAndSettle();

    expect(find.text('Código de administrador'), findsOneWidget);
  });

  testWidgets('oculta el contenido cuando visible es false', (tester) async {
    await tester.pumpWidget(envolver(visible: false));
    await tester.pumpAndSettle();

    expect(find.text('Código de administrador'), findsNothing);
  });

  testWidgets('anima al cambiar de oculto a visible', (tester) async {
    await tester.pumpWidget(envolver(visible: false));
    await tester.pumpAndSettle();
    expect(find.text('Código de administrador'), findsNothing);

    await tester.pumpWidget(envolver(visible: true));
    await tester.pumpAndSettle();
    expect(find.text('Código de administrador'), findsOneWidget);
  });
}
