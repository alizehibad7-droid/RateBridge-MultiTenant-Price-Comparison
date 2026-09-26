import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/orders/field_order_status.dart';
import 'package:ratebridge/views/field_user/orders/field_orders_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';
import 'package:shimmer/shimmer.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldOrdersViewModel orders;

  setUp(() {
    session = MockFieldSessionViewModel();
    orders = MockFieldOrdersViewModel();
    stubFieldSessionViewModel(session);
    stubFieldOrdersViewModel(orders);
  });

  testWidgets('shows a skeleton while orders are loading', (tester) async {
    when(() => orders.isLoadingOrders).thenReturn(true);

    await pumpFieldScreen(
      tester,
      child: const FieldOrdersView(),
      session: session,
      orders: orders,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('My Orders'), findsOneWidget);
    verify(() => orders.watchOrders('field-1', 'co-1')).called(1);
  });

  testWidgets('shows an error and Retry starts watching orders again',
      (tester) async {
    when(() => orders.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldOrdersView(),
      session: session,
      orders: orders,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load orders'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => orders.watchOrders('field-1', 'co-1')).called(greaterThan(1));
  });

  testWidgets('shows empty copy when there are no pending orders',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldOrdersView(),
      session: session,
      orders: orders,
    );
    await tester.pump();

    expect(find.text('No pending orders'), findsOneWidget);
  });

  testWidgets('renders a pending order from the ViewModel', (tester) async {
    final order = sampleOrder();
    when(() => orders.orders).thenReturn([order]);
    when(() => orders.ordersForTab(FieldOrderTab.pending)).thenReturn([order]);

    await pumpFieldScreen(
      tester,
      child: const FieldOrdersView(),
      session: session,
      orders: orders,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('View Details'), findsOneWidget);
  });

  testWidgets('Confirm Delivery on a delivered order calls confirmDelivery',
      (tester) async {
    final order = sampleOrder(status: 'delivered');
    when(() => orders.orders).thenReturn([order]);

    await pumpFieldScreen(
      tester,
      child: const FieldOrdersView(),
      session: session,
      orders: orders,
    );
    await tester.pump();

    await tester.tap(find.text('Delivered'));
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    await tester.tap(find.text('Confirm Delivery'));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    verify(
      () => orders.confirmDelivery(orderId: 'order-001', companyId: 'co-1'),
    ).called(1);
  });
}
