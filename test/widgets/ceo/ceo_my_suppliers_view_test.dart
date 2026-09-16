import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_my_suppliers_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
  });

  testWidgets('shows a spinner while marketplace suppliers are loading',
      (tester) async {
    when(() => ceo.isLoading).thenReturn(true);
    when(() => ceo.marketplaceSuppliers).thenReturn(const []);

    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty copy when there are no platform suppliers',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(
      find.text('No active suppliers on the platform yet'),
      findsOneWidget,
    );
  });

  testWidgets('renders available supplier and can open request sheet',
      (tester) async {
    when(() => ceo.marketplaceSuppliers).thenReturn([sampleSupplier()]);
    when(() => ceo.linkStatusFor('sup-1')).thenReturn('Not Invited');

    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('REQUEST PARTNERSHIP'), findsOneWidget);

    await tapVisible(tester, find.text('REQUEST PARTNERSHIP'));
    await tester.pumpAndSettle();

    expect(find.text('Invite Partner'), findsOneWidget);
    expect(find.text('SEND REQUEST'), findsOneWidget);
  });

  testWidgets('renders a partner and Remove calls removeSupplier',
      (tester) async {
    when(() => ceo.marketplaceSuppliers).thenReturn([sampleSupplier()]);
    when(() => ceo.linkStatusFor('sup-1')).thenReturn('Already Partners');

    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);

    await tapVisible(tester, find.text('Remove'));
    await tester.pump();
    await tapVisible(tester, find.text('REMOVE PERMANENTLY'));
    await tester.pump();

    verify(() => ceo.removeSupplier('sup-1')).called(1);
  });
}
