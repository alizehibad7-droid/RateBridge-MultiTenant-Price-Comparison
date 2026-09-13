import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/partnerships/supplier_partnerships_hub_view.dart';
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

  testWidgets('shows a skeleton while partnership data is loading',
      (tester) async {
    when(() => supplier.partnershipHubDataLoaded).thenReturn(false);
    when(() => supplier.activePartnerCompanies).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierPartnershipsHubView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(SupplierListSkeleton), findsOneWidget);
    verify(() => supplier.loadPartnershipHubData()).called(1);
  });

  testWidgets('shows empty copy when there are no partners', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierPartnershipsHubView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No Active Partnerships Yet'), findsOneWidget);
  });

  testWidgets('renders partners and Accept on Requests calls the ViewModel',
      (tester) async {
    final request = samplePartnershipRequest(initiatedBy: 'ceo');
    when(() => supplier.activePartnerCompanies).thenReturn([sampleCompany()]);
    when(() => supplier.pendingCeoInvitations).thenReturn([request]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierPartnershipsHubView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Acme Builders'), findsWidgets);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();

    verify(() => supplier.acceptPartnershipRequest(request.requestId))
        .called(1);
  });
}
