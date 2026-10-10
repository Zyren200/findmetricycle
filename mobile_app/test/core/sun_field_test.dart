import "package:findme_tricycle_mobile/core/components/sunrise.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("the password eye shows whether the password can be read",
      (tester) async {
    final controller = TextEditingController(text: "secret123");
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SunField(label: "Password", controller: controller, obscure: true),
      ),
    ));

    bool hidden() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;

    // Hidden: closed eye.
    expect(hidden(), isTrue);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    await tester.tap(find.byTooltip("Show password"));
    await tester.pump();

    // Shown: open eye.
    expect(hidden(), isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.byTooltip("Hide password"), findsOneWidget);
  });
}
