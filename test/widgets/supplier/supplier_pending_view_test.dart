import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_pending_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;
  late MockAuthViewModel auth;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
    auth = MockAuthViewModel();
  });

  testWidgets('shows pending review copy for a pending supplier',
      (tester) async {
    stubAuthViewModel(auth, user: supplierUser(status: 'pending'));
    when(() => supplier.status).thenReturn('pending');
    when(() => supplier.profile).thenReturn(supplierUser(status: 'pending'));

    await pumpSupplierScreen(
      tester,
      child: const SupplierPendingView(),
      supplier: supplier,
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Account Under Review'), findsOneWidget);
    expect(find.text('Refresh Status'), findsOneWidget);
  });

  testWidgets('Refresh Status calls loadProfile', (tester) async {
    stubAuthViewModel(auth, user: supplierUser(status: 'pending'));
    when(() => supplier.status).thenReturn('pending');

    await pumpSupplierScreen(
      tester,
      child: const SupplierPendingView(),
      supplier: supplier,
      auth: auth,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Refresh Status'));
    await tester.pump();

    verify(() => supplier.loadProfile()).called(1);
  });

  testWidgets('shows rejection reason when registration was rejected',
      (tester) async {
    stubAuthViewModel(
      auth,
      user: supplierUser(
        status: 'rejected',
        rejectionReason: 'Documents were not readable.',
      ),
    );
    when(() => supplier.status).thenReturn('rejected');
    when(() => supplier.rejectionReason)
        .thenReturn('Documents were not readable.');

    await pumpSupplierScreen(
      tester,
      child: const SupplierPendingView(),
      supplier: supplier,
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Registration Rejected'), findsOneWidget);
    expect(find.text('Documents were not readable.'), findsOneWidget);
    expect(find.text('SUBMIT APPEAL'), findsOneWidget);
  });

  testWidgets('Sign Out calls AuthViewModel.signOut', (tester) async {
    stubAuthViewModel(auth, user: supplierUser(status: 'pending'));
    when(() => supplier.status).thenReturn('pending');

    await pumpSupplierScreen(
      tester,
      child: const SupplierPendingView(),
      supplier: supplier,
      auth: auth,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Sign Out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
