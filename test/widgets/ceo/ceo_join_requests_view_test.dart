import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_join_requests_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
  });

  testWidgets('shows a spinner when the company is not loaded', (tester) async {
    when(() => ceo.company).thenReturn(null);

    await pumpCeoScreen(
      tester,
      child: const CeoJoinRequestsView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a spinner while partnership requests are not ready',
      (tester) async {
    when(() => ceo.partnershipRequestsReady).thenReturn(false);

    await pumpCeoScreen(
      tester,
      child: const CeoJoinRequestsView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('shows empty copy when there are no incoming requests',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoJoinRequestsView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('No incoming requests'), findsOneWidget);
  });

  testWidgets('renders a request and APPROVE confirms acceptPartnershipRequest',
      (tester) async {
    final request = samplePartnershipRequest();
    when(() => ceo.pendingReceivedPartnershipRequests).thenReturn([request]);
    when(() => ceo.receivedPartnershipRequests).thenReturn([request]);

    await pumpCeoScreen(
      tester,
      child: const CeoJoinRequestsView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);
    expect(find.text('APPROVE'), findsOneWidget);

    await tapVisible(tester, find.text('APPROVE'));
    await tester.pump();
    await tapVisible(tester, find.text('CONFIRM'));
    await tester.pump();

    verify(() => ceo.acceptPartnershipRequest('req-1')).called(1);
  });
}
