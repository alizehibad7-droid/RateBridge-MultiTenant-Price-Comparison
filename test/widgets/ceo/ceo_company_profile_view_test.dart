import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_company_profile_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;
  late MockAuthViewModel auth;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
  });

  testWidgets('shows a spinner when the company profile is missing',
      (tester) async {
    when(() => ceo.company).thenReturn(null);

    await pumpCeoScreen(
      tester,
      child: const CeoCompanyProfileView(),
      ceo: ceo,
      auth: auth,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders company details from CeoViewModel', (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoCompanyProfileView(),
      ceo: ceo,
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Acme Builders'), findsWidgets);
    expect(find.text('Ali CEO'), findsWidgets);
    expect(find.text('NTN-1'), findsOneWidget);
    expect(find.text('Logout Session'), findsOneWidget);
  });

  testWidgets('Logout Session confirms and calls AuthViewModel.signOut',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoCompanyProfileView(),
      ceo: ceo,
      auth: auth,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Logout Session'));
    await tester.pump();
    await tapVisible(tester, find.text('Log out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
