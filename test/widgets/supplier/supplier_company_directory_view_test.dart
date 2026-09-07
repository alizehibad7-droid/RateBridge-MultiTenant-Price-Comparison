import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_company_directory_view.dart';
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

  testWidgets('shows a skeleton while the directory is loading', (tester) async {
    when(() => supplier.isLoading).thenReturn(true);
    when(() => supplier.companyDirectory).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierCompanyDirectoryView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(SupplierListSkeleton), findsOneWidget);
    verify(() => supplier.loadCompanyDirectory()).called(1);
    verify(supplier.ensurePartnershipStatusWatch).called(1);
  });

  testWidgets('shows empty copy when no companies are listed', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierCompanyDirectoryView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No active companies found'), findsOneWidget);
  });

  testWidgets('search calls searchCompanies', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierCompanyDirectoryView(),
      supplier: supplier,
    );
    await tester.pump();

    await tester.enterText(
      textFieldByHint('Search by company name or city...'),
      'Acme',
    );
    await tester.pump();

    verify(() => supplier.searchCompanies('Acme')).called(1);
  });

  testWidgets('renders companies and Send Request calls the ViewModel',
      (tester) async {
    when(() => supplier.companyDirectory).thenReturn([sampleCompany()]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierCompanyDirectoryView(),
      supplier: supplier,
      surfaceSize: const Size(1200, 1400),
    );
    await tester.pump();

    expect(find.text('Acme Builders'), findsWidgets);

    await tester.tap(find.text('Send Request').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Request').last);
    await tester.pump();

    verify(
      () => supplier.sendPartnershipRequest(
        'co-1',
        message: any(named: 'message'),
      ),
    ).called(1);
  });
}
