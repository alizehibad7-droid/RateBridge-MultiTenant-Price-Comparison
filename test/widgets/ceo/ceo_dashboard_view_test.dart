import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/views/ceo/ceo_dashboard_view.dart';

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

  testWidgets('shows a spinner while company data is loading', (tester) async {
    when(() => ceo.isLoading).thenReturn(true);
    when(() => ceo.company).thenReturn(null);

    await pumpCeoScreen(
      tester,
      child: const CeoDashboardView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => ceo.loadDashboard()).called(1);
  });

  testWidgets('renders empty recent orders when none are present',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoDashboardView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Acme Builders'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('RB-ACME01'), findsOneWidget);
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('Quick Actions'), findsOneWidget);
  });

  testWidgets('renders live stats and recent orders', (tester) async {
    when(() => ceo.watchDashboardStats(any())).thenAnswer(
      (_) => Stream<Map<String, dynamic>>.value({
        'pendingOrderApprovals': 3,
        'pendingJoinCount': 2,
        'fieldUserCount': 8,
        'activeSupplierCount': 5,
        'plan': 'Basic',
      }),
    );
    when(() => ceo.watchCompanyOrders(any(), any())).thenAnswer(
      (_) => Stream<List<OrderModel>>.value([sampleOrder()]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoDashboardView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('8'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Pending Requests'), findsOneWidget);
    expect(find.text('Lucky Cement'), findsOneWidget);
  });

  testWidgets(
      'recent order cards keep long names and prices on separate lines',
      (tester) async {
    const longName =
        'A-grade red clay bricks, standard size, suitable for residential construction';
    when(() => ceo.watchCompanyOrders(any(), any())).thenAnswer(
      (_) => Stream<List<OrderModel>>.value([
        sampleOrder(
          materialName: longName,
          status: 'pending_approval',
          totalAmount: 12000000,
        ),
      ]),
    );

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpCeoScreen(
      tester,
      child: const CeoDashboardView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
    expect(find.text('Awaiting Review'), findsOneWidget);
    expect(find.text('Rs. 1.20 Crore'), findsOneWidget);

    final nameText = tester.widget<Text>(find.text(longName));
    expect(nameText.maxLines, 2);
    expect(nameText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('Regenerate calls regenerateInviteCode', (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoDashboardView(),
      ceo: ceo,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Regenerate'));
    await tester.pump();

    verify(() => ceo.regenerateInviteCode()).called(1);
  });
}
