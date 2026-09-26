import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_profile_view.dart';

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

  testWidgets('shows a spinner while the profile is loading', (tester) async {
    when(() => supplier.isLoading).thenReturn(true);
    when(() => supplier.profile).thenReturn(null);

    await pumpSupplierScreen(
      tester,
      child: const SupplierProfileView(),
      supplier: supplier,
      pumpPostFrame: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders business name from the profile', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierProfileView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsWidgets);
    expect(find.text('Business Information'), findsOneWidget);
  });

  testWidgets('Save Changes calls updateProfile', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierProfileView(),
      supplier: supplier,
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pump();

    expect(find.text('Save Changes'), findsOneWidget);
    await tapVisible(tester, find.text('Save Changes'));
    await tester.pump();

    verify(() => supplier.updateProfile(any())).called(1);
  });

  testWidgets('Sign Out calls AuthViewModel.signOut', (tester) async {
    final auth = MockAuthViewModel();
    stubAuthViewModel(auth);

    await pumpSupplierScreen(
      tester,
      child: const SupplierProfileView(),
      supplier: supplier,
      auth: auth,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Sign Out'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
