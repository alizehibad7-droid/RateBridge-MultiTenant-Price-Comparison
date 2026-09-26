import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_pending_view.dart';

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
  });

  testWidgets('shows pending review copy for a pending CEO', (tester) async {
    stubAuthViewModel(auth, user: ceoUser(status: 'pending'));

    await pumpCeoScreen(
      tester,
      child: const CeoPendingView(),
      ceo: ceo,
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Application Under Review'), findsOneWidget);
    expect(find.text('Waiting for admin review...'), findsOneWidget);
    expect(find.text('Ali CEO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => ceo.watchCeoStatus()).called(1);
  });

  testWidgets('shows rejection reason when registration was rejected',
      (tester) async {
    stubAuthViewModel(
      auth,
      user: ceoUser(
        status: 'rejected',
        rejectionReason: 'Documents were not readable.',
      ),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoPendingView(),
      ceo: ceo,
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Registration Rejected'), findsOneWidget);
    expect(find.text('Documents were not readable.'), findsOneWidget);
  });

  testWidgets('Sign Out calls AuthViewModel.signOut', (tester) async {
    stubAuthViewModel(auth, user: ceoUser(status: 'pending'));

    await pumpCeoScreen(
      tester,
      child: const CeoPendingView(),
      ceo: ceo,
      auth: auth,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Sign Out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
