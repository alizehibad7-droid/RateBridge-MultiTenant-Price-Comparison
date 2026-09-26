import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_orders_view.dart';
import 'package:ratebridge/widgets/supplier/supplier_async_states.dart';

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

  testWidgets('shows a skeleton while orders are loading', (tester) async {
    when(() => supplier.isLoading).thenReturn(true);
    when(() => supplier.orders).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierOrdersView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(SupplierListSkeleton), findsWidgets);
    verify(() => supplier.loadOrders('co-1', null)).called(1);
  });

  testWidgets('shows empty copy when there are no pending orders',
      (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierOrdersView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No pending orders'), findsOneWidget);
  });

  testWidgets('renders a pending order and ACCEPT calls acceptOrder',
      (tester) async {
    final order = sampleOrder();
    when(() => supplier.orders).thenReturn([order]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierOrdersView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('ACCEPT'), findsOneWidget);

    await tester.tap(find.text('ACCEPT'));
    await tester.pump();
    await tester.tap(find.text('CONFIRM'));
    await tester.pump();

    verify(() => supplier.acceptOrder(order.orderId, order.companyId))
        .called(1);
  });
}
