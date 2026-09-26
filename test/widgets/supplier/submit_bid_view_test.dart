import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/rfq/submit_bid_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

Future<FakeFirebaseFirestore> _seedRfq({String status = 'open'}) async {
  final fake = FakeFirebaseFirestore();
  await fake.collection('rfqs').doc('rfq-1').set({
    'companyId': 'co-1',
    'companyName': 'Acme Builders',
    'category': 'Cement',
    'materialDescription': 'OPC 53, 500 bags',
    'quantity': 500,
    'unit': 'bag',
    'city': 'Lahore',
    'requiredByDate': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
    'status': status,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
  });
  return fake;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
  });

  testWidgets('shows a spinner while the RFQ is loading', (tester) async {
    final fake = FakeFirebaseFirestore();

    await pumpSupplierScreen(
      tester,
      child: SubmitBidView(rfqId: 'rfq-1', debugFirestore: fake),
      supplier: supplier,
      pumpPostFrame: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty copy when the RFQ is missing', (tester) async {
    final fake = FakeFirebaseFirestore();

    await pumpSupplierScreen(
      tester,
      child: SubmitBidView(rfqId: 'missing', debugFirestore: fake),
      supplier: supplier,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Request not found'), findsOneWidget);
  });

  testWidgets('renders RFQ details and SUBMIT BID calls submitRfqBid',
      (tester) async {
    final fake = await _seedRfq();

    await pumpSupplierScreen(
      tester,
      child: SubmitBidView(rfqId: 'rfq-1', debugFirestore: fake),
      supplier: supplier,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('CEMENT'), findsOneWidget);
    expect(find.text('OPC 53, 500 bags'), findsOneWidget);

    await tester.enterText(textFieldByHint('e.g. 1200'), '1180');
    await tester.enterText(textFieldByHint('e.g. 24-48 hours'), '3 days');
    await tester.pump();

    await tapVisible(tester, find.text('SUBMIT BID'));
    await tester.pump();

    verify(
      () => supplier.submitRfqBid(
        rfqId: 'rfq-1',
        bidPrice: 1180,
        deliveryTime: '3 days',
        note: any(named: 'note'),
      ),
    ).called(1);
  });
}
