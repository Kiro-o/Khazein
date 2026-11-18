import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khazeen_app/features/splash/views/splash_screen.dart';

void main() {
  testWidgets('shows the logo and slogan while the session loads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.bySemanticsLabel('خزين'), findsOneWidget);
    expect(find.text('كل نواقص محلك في مكان واحد'), findsOneWidget);

    // Let the minimum display time and the session check finish.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
