import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/home/field_home_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';
import 'package:shimmer/shimmer.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

Widget homeScreen() => const Scaffold(body: FieldHomeView());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldCatalogViewModel catalog;
  late MockFieldOrdersViewModel orders;

  setUp(() {
    session = MockFieldSessionViewModel();
    catalog = MockFieldCatalogViewModel();
    orders = MockFieldOrdersViewModel();
    stubFieldSessionViewModel(session);
    stubFieldCatalogViewModel(catalog);
    stubFieldOrdersViewModel(orders);
  });

  testWidgets('shows a spinner when the signed-in user is not ready',
      (tester) async {
    when(() => session.user).thenReturn(null);

    await pumpFieldScreen(
      tester,
      child: homeScreen(),
      session: session,
      catalog: catalog,
      orders: orders,
    );

    expect(find.byType(FieldLoadingState), findsOneWidget);
    expect(find.text('Loading your dashboard…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows shimmer while home materials are still loading',
      (tester) async {
    final hang = Completer<void>();
    when(() => catalog.isCatalogLoading).thenReturn(true);
    when(() => catalog.loadHomeData(any())).thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: homeScreen(),
      session: session,
      catalog: catalog,
      orders: orders,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    verify(() => catalog.loadHomeData('co-1')).called(1);
  });

  testWidgets('shows empty copy when no materials are available',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: homeScreen(),
      session: session,
      catalog: catalog,
      orders: orders,
    );
    await tester.pump();

    expect(
      find.text('No materials available yet from your suppliers'),
      findsOneWidget,
    );
    expect(find.text('No categories available yet.'), findsOneWidget);
    expect(find.text('No active orders'), findsOneWidget);
  });

  testWidgets('Retry on the empty materials row reloads home data',
      (tester) async {
    when(() => catalog.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: homeScreen(),
      session: session,
      catalog: catalog,
      orders: orders,
    );
    await tester.pump();

    expect(find.text('Retry'), findsWidgets);

    await tester.tap(find.text('Retry').first);
    await tester.pump();

    verify(() => catalog.loadHomeData('co-1')).called(greaterThan(1));
  });

  testWidgets('renders recent materials and the search shortcut',
      (tester) async {
    when(() => catalog.recentMaterials).thenReturn([sampleMaterial()]);
    when(() => catalog.uniqueCategories).thenReturn(const ['Cement']);
    when(() => catalog.browseCategories).thenReturn([sampleCategory()]);
    when(() => catalog.materialCountForCategory(any())).thenReturn(1);

    await pumpFieldScreen(
      tester,
      child: homeScreen(),
      session: session,
      catalog: catalog,
      orders: orders,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Search cement, steel, bricks...'), findsOneWidget);
    expect(find.text('Request a Bulk Quote'), findsOneWidget);
    verify(() => catalog.loadHomeData('co-1')).called(1);
    verify(() => orders.watchOrders('field-1', 'co-1')).called(1);
  });
}
