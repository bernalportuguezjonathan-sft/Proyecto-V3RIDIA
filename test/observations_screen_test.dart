import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/observations_screen.dart';

void main() {
  testWidgets('permite crear una observación desde la pantalla', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ObservationsScreen()));

    expect(find.text('No hay observaciones todavía'), findsOneWidget);

    await tester.tap(find.text('Agregar observación'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva observación'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('commonNameField')), 'Águila pescadora');
    await tester.enterText(find.byKey(const Key('scientificNameField')), 'Pandion haliaetus');
    await tester.enterText(find.byKey(const Key('locationField')), 'Lago de la reserva');
    await tester.enterText(find.byKey(const Key('notesField')), 'Vista desde el mirador');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Águila pescadora'), findsOneWidget);
    expect(find.text('Pandion haliaetus'), findsOneWidget);
  });
}
