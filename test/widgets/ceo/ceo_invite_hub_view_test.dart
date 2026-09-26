import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_invite_hub_view.dart';

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

  testWidgets('shows a spinner while the marketplace is loading',
      (tester) async {
    when(() => ceo.isLoading).thenReturn(true);

    await pumpCeoScreen(
      tester,
      child: const CeoInviteHubView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => ceo.loadMarketplace()).called(1);
  });

  testWidgets('shows error copy from CeoViewModel', (tester) async {
    when(() => ceo.errorMessage).thenReturn('Supplier limit reached.');

    await pumpCeoScreen(
      tester,
      child: const CeoInviteHubView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Supplier limit reached.'), findsOneWidget);
    expect(find.text('No matching suppliers found'), findsOneWidget);
  });

  testWidgets('renders a supplier and Send Formal Request calls the ViewModel',
      (tester) async {
    when(() => ceo.marketplaceSuppliers).thenReturn([sampleSupplier()]);

    await pumpCeoScreen(
      tester,
      child: const CeoInviteHubView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);

    await tapVisible(tester, find.text('Request Partnership'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Send Formal Request'));
    await tester.pump();

    verify(
      () => ceo.sendPartnershipRequest('sup-1', message: any(named: 'message')),
    ).called(1);
  });
}
