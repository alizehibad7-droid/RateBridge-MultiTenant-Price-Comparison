import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/transaction_model.dart';
import 'package:ratebridge/views/admin/admin_commission_ledger_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;
  late MockTransactionRepository transactions;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
    transactions = MockTransactionRepository();
    when(() => transactions.watchCommissionLedger()).thenAnswer(
      (_) => Stream<CommissionLedgerSnapshot>.value(
        CommissionLedgerSnapshot.empty,
      ),
    );
  });

  testWidgets('shows a spinner while the ledger stream has no snapshot',
      (tester) async {
    final controller = StreamController<CommissionLedgerSnapshot>();
    when(() => transactions.watchCommissionLedger())
        .thenAnswer((_) => controller.stream);

    await pumpAdminScreen(
      tester,
      child: const AdminCommissionLedgerView(),
      admin: admin,
      transactions: transactions,
      wrapInScaffold: true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Active Ledger'), findsOneWidget);
    verify(() => admin.loadPaymentQueue()).called(1);
    await controller.close();
  });

  testWidgets('shows empty supplier balances when the ledger has no rows',
      (tester) async {
    await pumpAdminScreen(
      tester,
      child: const AdminCommissionLedgerView(),
      admin: admin,
      transactions: transactions,
      wrapInScaffold: true,
    );
    await tester.pump();

    expect(find.text('No outstanding commissions.'), findsOneWidget);
  });

  testWidgets('renders supplier balances from the ledger snapshot',
      (tester) async {
    when(() => transactions.watchCommissionLedger()).thenAnswer(
      (_) => Stream<CommissionLedgerSnapshot>.value(
        const CommissionLedgerSnapshot(
          outstandingThisMonth: 2500,
          collectedThisMonth: 1000,
          grandTotalCollected: 8000,
          suppliers: [
            SupplierUnsettledSummary(
              supplierUid: 'sup-1',
              supplierName: 'Skyline Materials',
              unsettledAmount: 2500,
              orderCount: 3,
              transactionIds: ['tx-1'],
            ),
          ],
        ),
      ),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminCommissionLedgerView(),
      admin: admin,
      transactions: transactions,
      wrapInScaffold: true,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);
  });

  testWidgets('SETTLE confirms and calls confirmPayment', (tester) async {
    final payment = samplePayment(
      type: 'commission',
      payerName: 'Skyline Materials',
    );
    when(() => admin.pendingPayments).thenReturn([payment]);

    await pumpAdminScreen(
      tester,
      child: const AdminCommissionLedgerView(),
      admin: admin,
      transactions: transactions,
      wrapInScaffold: true,
    );
    await tester.pump();
    tester.takeException();

    await tapVisible(tester, find.text('SETTLE'));
    await tester.pump();
    await tapVisible(tester, find.text('CONFIRM'));
    await tester.pump();

    verify(() => admin.confirmPayment(payment)).called(1);
  });
}
