import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/views/ceo/ceo_orders_view.dart';

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

  testWidgets('shows a spinner while company orders are loading',
      (tester) async {
    final controller = StreamController<List<OrderModel>>();
    when(() => ceo.watchCompanyOrders(any(), any()))
        .thenAnswer((_) => controller.stream);

    await pumpCeoScreen(
      tester,
      child: const CeoOrdersView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await controller.close();
  });

  testWidgets('shows error copy when the orders stream fails', (tester) async {
    when(() => ceo.watchCompanyOrders(any(), any())).thenAnswer(
      (_) => Stream<List<OrderModel>>.error('unavailable'),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoOrdersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.textContaining('Could not load orders'), findsWidgets);
  });

  testWidgets('shows empty copy when there are no orders', (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoOrdersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('No orders found'), findsWidgets);
  });

  testWidgets('renders a pending approval order and Approve calls approveOrder',
      (tester) async {
    final order = sampleOrder(status: 'pending_approval');
    when(() => ceo.watchCompanyOrders(any(), any())).thenAnswer(
      (_) => Stream<List<OrderModel>>.value([order]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoOrdersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Approve'), findsWidgets);

    await tapVisible(tester, find.text('Approve').first);
    await tester.pump();

    verify(() => ceo.approveOrder(order)).called(1);
  });
}
