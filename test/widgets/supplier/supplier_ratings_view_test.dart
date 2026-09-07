import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_ratings_view.dart';
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

  testWidgets('shows a skeleton while ratings are loading', (tester) async {
    when(() => supplier.isLoading).thenReturn(true);
    when(() => supplier.ratings).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierRatingsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(SupplierListSkeleton), findsOneWidget);
    verify(() => supplier.loadRatings('sup-1', 'co-1')).called(1);
  });

  testWidgets('shows empty copy when there are no ratings', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierRatingsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No ratings yet'), findsWidgets);
  });

  testWidgets('renders rating comments from the ViewModel', (tester) async {
    when(() => supplier.ratings).thenReturn([sampleRating()]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierRatingsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Bags arrived in good condition.'), findsOneWidget);
    expect(find.text('Hassan Field'), findsOneWidget);
  });
}
