import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_earnings_view.dart';

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

  testWidgets('loads earnings for the current month on open', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierEarningsView(),
      supplier: supplier,
    );
    await tester.pump();

    verify(() => supplier.loadEarnings(any())).called(1);
    expect(find.text('Earnings & Commissions'), findsOneWidget);
  });

  testWidgets('shows empty copy when there are no commissions', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierEarningsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No commissions this month'), findsOneWidget);
  });

  testWidgets('renders transactions and Pay commission is visible',
      (tester) async {
    when(() => supplier.transactions).thenReturn([sampleTransaction()]);
    when(() => supplier.commissionOwed).thenReturn(1250);

    await pumpSupplierScreen(
      tester,
      child: const SupplierEarningsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Pay commission'), findsOneWidget);
    expect(find.text('Order #ER-001'), findsOneWidget);
    expect(find.text('Unsettled'), findsOneWidget);
  });
}
