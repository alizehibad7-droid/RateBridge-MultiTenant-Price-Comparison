import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/admin/admin_payment_queue_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
  });

  testWidgets('shows a spinner while the payment queue is loading',
      (tester) async {
    when(() => admin.isLoading).thenReturn(true);

    await pumpAdminScreen(
      tester,
      child: const AdminPaymentQueueView(),
      admin: admin,
      wrapInScaffold: true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => admin.loadPaymentQueue()).called(1);
  });

  testWidgets('shows empty copy when there are no pending payments',
      (tester) async {
    await pumpAdminScreen(
      tester,
      child: const AdminPaymentQueueView(),
      admin: admin,
      wrapInScaffold: true,
    );
    await tester.pump();

    expect(find.text('No pending verifications'), findsOneWidget);
  });

  testWidgets('renders a pending subscription payment', (tester) async {
    final payment = samplePayment();
    when(() => admin.pendingPayments).thenReturn([payment]);

    await pumpAdminScreen(
      tester,
      child: const AdminPaymentQueueView(),
      admin: admin,
      wrapInScaffold: true,
    );
    await tester.pump();
    tester.takeException();

    expect(find.text('Ali CEO'), findsOneWidget);
    expect(find.text('CONFIRM PAYMENT'), findsOneWidget);
  });

  testWidgets('CONFIRM PAYMENT calls confirmPayment on the ViewModel',
      (tester) async {
    final payment = samplePayment();
    when(() => admin.pendingPayments).thenReturn([payment]);

    await pumpAdminScreen(
      tester,
      child: const AdminPaymentQueueView(),
      admin: admin,
      wrapInScaffold: true,
    );
    await tester.pump();
    tester.takeException();

    await tapVisible(tester, find.text('CONFIRM PAYMENT'));
    await tester.pump();
    await tapVisible(tester, find.text('CONFIRM'));
    await tester.pump();

    verify(() => admin.confirmPayment(payment)).called(1);
  });
}
