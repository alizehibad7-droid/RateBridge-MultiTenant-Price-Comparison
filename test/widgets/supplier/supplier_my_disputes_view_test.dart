import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/views/supplier/supplier_my_disputes_view.dart';
import 'package:ratebridge/views/supplier/supplier_profile_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

DisputeModel _mine({
  String status = 'under_review',
  String? notes,
}) {
  return DisputeModel(
    id: 'd-sup',
    orderId: 'order-19818236',
    supplierId: 'sup-1',
    companyId: 'co-1',
    raisedByUid: 'sup-1',
    raisedByRole: 'supplier',
    type: DisputeType.paymentIssue,
    description: 'Commission deducted twice on the same delivery.',
    status: status,
    resolutionNotes: notes,
    createdAt: DateTime.utc(2026, 5, 2),
    updatedAt: DateTime.utc(2026, 5, 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;
  late MockDisputeViewModel dispute;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
    dispute = MockDisputeViewModel();
    when(() => dispute.isLoading).thenReturn(false);
    when(() => dispute.error).thenReturn(null);
    when(() => dispute.watchMyDisputes(any()))
        .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
  });

  testWidgets('profile lists a My Disputes shortcut', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierProfileView(),
      supplier: supplier,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('My Disputes'), findsOneWidget);
  });

  testWidgets('renders the supplier\'s own dispute card', (tester) async {
    when(() => dispute.watchMyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([_mine()]),
    );

    await pumpSupplierScreen(
      tester,
      child: const SupplierMyDisputesView(),
      supplier: supplier,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('Payment Issue'), findsOneWidget);
    expect(find.textContaining('Commission deducted twice'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    verify(() => dispute.watchMyDisputes('sup-1')).called(1);
  });
}
