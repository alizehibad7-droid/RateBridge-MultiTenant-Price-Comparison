import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_dashboard_view.dart';
import 'package:shimmer/shimmer.dart';

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

  testWidgets('shows a spinner when the signed-in user is not ready',
      (tester) async {
    final auth = MockAuthViewModel();
    stubAuthViewModel(auth, user: supplierUser());
    when(() => auth.user).thenReturn(null);

    await pumpSupplierScreen(
      tester,
      child: const SupplierDashboardView(),
      supplier: supplier,
      auth: auth,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows shimmer while companies are still loading', (tester) async {
    when(() => supplier.companiesLoaded).thenReturn(false);

    await pumpSupplierScreen(
      tester,
      child: const SupplierDashboardView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    verify(() => supplier.loadDashboard()).called(1);
  });

  testWidgets('shows empty copy when no company is linked', (tester) async {
    when(() => supplier.companiesLoaded).thenReturn(true);
    when(() => supplier.companiesLoadFailed).thenReturn(false);
    when(() => supplier.companies).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierDashboardView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('No company linked yet'), findsOneWidget);
    expect(find.text("Skyline's Store"), findsOneWidget);
  });

  testWidgets('shows a retry banner when companies fail to load',
      (tester) async {
    when(() => supplier.companiesLoaded).thenReturn(true);
    when(() => supplier.companiesLoadFailed).thenReturn(true);
    when(() => supplier.error).thenReturn('offline');

    await pumpSupplierScreen(
      tester,
      child: const SupplierDashboardView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Some data failed to load.'), findsOneWidget);
    expect(find.text('Retry'), findsWidgets);

    await tester.tap(find.text('Retry').first);
    await tester.pump();

    verify(() => supplier.retryInitialLoad()).called(1);
  });

  testWidgets('renders recent orders from the ViewModel', (tester) async {
    when(() => supplier.companies).thenReturn([sampleCompany()]);
    when(() => supplier.orders).thenReturn([sampleOrder()]);
    when(() => supplier.recentOrders).thenReturn([sampleOrder()]);
    when(() => supplier.pendingOrdersCount).thenReturn(1);

    await pumpSupplierScreen(
      tester,
      child: const SupplierDashboardView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text("Skyline's Store"), findsOneWidget);
    expect(find.text('Lucky Cement'), findsWidgets);
  });
}
