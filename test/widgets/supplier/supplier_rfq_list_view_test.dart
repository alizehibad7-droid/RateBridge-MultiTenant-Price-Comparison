import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/rfq_model.dart';
import 'package:ratebridge/views/supplier/rfq/supplier_rfq_list_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
  });

  testWidgets('shows a spinner while open RFQs are loading', (tester) async {
    final controller = StreamController<List<RfqModel>>();
    when(supplier.streamOpenRfqsForSupplier)
        .thenAnswer((_) => controller.stream);

    await pumpSupplierScreen(
      tester,
      child: const SupplierRfqListView(),
      supplier: supplier,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows empty copy when there are no open RFQs', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierRfqListView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No open requests matching you'), findsOneWidget);
  });

  testWidgets('renders RFQ tiles from the ViewModel stream', (tester) async {
    when(supplier.streamOpenRfqsForSupplier).thenAnswer(
      (_) => Stream<List<RfqModel>>.value([sampleRfq()]),
    );

    await pumpSupplierScreen(
      tester,
      child: const SupplierRfqListView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Cement'), findsOneWidget);
    expect(find.text('OPC 53, 500 bags'), findsOneWidget);
  });
}
