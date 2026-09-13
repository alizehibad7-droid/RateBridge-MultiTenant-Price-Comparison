import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/views/field_user/orders/field_order_detail_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';
import 'package:shimmer/shimmer.dart';

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

  testWidgets('shows a skeleton while the order is loading', (tester) async {
    final hang = Completer<OrderModel?>();
    when(() => orders.fetchOrderFromServer(any()))
        .thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldOrderDetailView(orderId: 'order-001'),
      orders: orders,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('Order detail'), findsOneWidget);
  });

  testWidgets('shows an error and Retry fetches the order again',
      (tester) async {
    when(() => orders.fetchOrderFromServer(any())).thenAnswer((_) async => null);

    await pumpFieldScreen(
      tester,
      child: const FieldOrderDetailView(orderId: 'order-001'),
      orders: orders,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load order'), findsOneWidget);
    expect(find.text('Order not found'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => orders.fetchOrderFromServer('order-001'))
        .called(greaterThan(1));
  });

  testWidgets('renders order details from the ViewModel', (tester) async {
    final order = sampleOrder();
    when(() => orders.fetchOrderFromServer(any())).thenAnswer((_) async => order);
    when(() => orders.fetchSupplier(any()))
        .thenAnswer((_) async => sampleSupplier());

    await pumpFieldScreen(
      tester,
      child: FieldOrderDetailView(order: order),
      orders: orders,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Skyline Materials'), findsWidgets);
    verify(() => orders.fetchOrderFromServer('order-001')).called(1);
  });

  testWidgets('Confirm Delivery calls confirmDelivery on the ViewModel',
      (tester) async {
    final order = sampleOrder(status: 'delivered');
    when(() => orders.fetchOrderFromServer(any())).thenAnswer((_) async => order);
    when(() => orders.fetchSupplier(any()))
        .thenAnswer((_) async => sampleSupplier());

    await pumpFieldScreen(
      tester,
      child: FieldOrderDetailView(order: order),
      orders: orders,
    );
    await tester.pump();

    await tester.tap(find.text('Confirm Delivery'));
    await tester.pump();
    await tester.tap(find.text('Yes, Confirm'));
    await tester.pump();

    verify(
      () => orders.confirmDelivery(orderId: 'order-001', companyId: 'co-1'),
    ).called(1);
  });
}
