import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_materials_view.dart';
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

  testWidgets('shows a skeleton while materials are loading', (tester) async {
    when(() => supplier.isLoading).thenReturn(true);
    when(() => supplier.materials).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierMaterialsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(SupplierMaterialListSkeleton), findsOneWidget);
    verify(() => supplier.loadMaterials('co-1')).called(1);
  });

  testWidgets('shows empty copy when there are no materials', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierMaterialsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No materials yet'), findsOneWidget);
    expect(find.text('Add Material'), findsOneWidget);
  });

  testWidgets('renders material names from the ViewModel', (tester) async {
    when(() => supplier.materials).thenReturn([sampleMaterial()]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierMaterialsView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsOneWidget);
  });
}
