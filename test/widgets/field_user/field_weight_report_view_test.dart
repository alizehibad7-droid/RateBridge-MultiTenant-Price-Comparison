import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/views/field_user/orders/field_weight_report_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldOrdersViewModel orders;

  setUp(() {
    orders = MockFieldOrdersViewModel();
    stubFieldOrdersViewModel(orders);
  });

  testWidgets('shows a spinner while the order is loading', (tester) async {
    final hang = Completer<OrderModel?>();
    when(() => orders.fetchOrder(any())).thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldWeightReportView(orderId: 'order-001'),
      orders: orders,
      pumpPostFrame: false,
    );
    await tester.pump();

    expect(find.byType(FieldLoadingState), findsOneWidget);
    expect(find.text('Loading order…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error and Retry fetches the order again',
      (tester) async {
    when(() => orders.fetchOrder(any())).thenAnswer((_) async => null);

    await pumpFieldScreen(
      tester,
      child: const FieldWeightReportView(orderId: 'order-001'),
      orders: orders,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load order'), findsOneWidget);
    expect(find.text('Order not found'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => orders.fetchOrder('order-001')).called(greaterThan(1));
  });

  testWidgets('renders expected weight and submits a report', (tester) async {
    final order = sampleOrder();

    await pumpFieldScreen(
      tester,
      child: FieldWeightReportView(order: order),
      orders: orders,
    );

    expect(find.text('Lucky Cement'), findsOneWidget);
    expect(find.text('Expected weight'), findsOneWidget);
    expect(find.text('Enter actual weight'), findsOneWidget);

    await tester.enterText(textFieldByHint('Enter actual weight'), '48');
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    verify(
      () => orders.submitWeightReport(
        orderId: 'order-001',
        companyId: 'co-1',
        actualWeight: 48,
        remarks: any(named: 'remarks'),
      ),
    ).called(1);
  });
}
