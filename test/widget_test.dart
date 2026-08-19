import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/theme/ratebridge_theme.dart';
import 'package:ratebridge/views/auth/splash_view.dart';

void main() {
  testWidgets('App branding smoke test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RateBridgeTheme.light(),
        home: const SplashView(autoNavigate: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('RateBridge'), findsOneWidget);
    expect(find.text('Smart Material Procurement'), findsOneWidget);
    expect(find.byIcon(Icons.construction), findsOneWidget);
  });
}
