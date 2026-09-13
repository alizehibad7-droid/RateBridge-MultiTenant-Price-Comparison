import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/marketplace/field_search_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldCatalogViewModel catalog;

  setUp(() {
    session = MockFieldSessionViewModel();
    catalog = MockFieldCatalogViewModel();
    stubFieldSessionViewModel(session);
    stubFieldCatalogViewModel(catalog);
  });

  testWidgets('shows a spinner while search catalog is loading',
      (tester) async {
    final hang = Completer<void>();
    when(() => catalog.loadMarketplace(any())).thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldSearchView(),
      session: session,
      catalog: catalog,
      pumpPostFrame: false,
    );
    await tester.pump();

    expect(find.byType(FieldLoadingState), findsOneWidget);
    expect(find.text('Loading search…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows idle empty copy when there are no categories',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldSearchView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.text('No categories available.'), findsOneWidget);
    expect(find.text('Search materials...'), findsOneWidget);
  });

  testWidgets('shows no-results copy when a query matches nothing',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldSearchView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    await tester.enterText(textFieldByHint('Search materials...'), 'xyz');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No results found'), findsOneWidget);
    verify(() => catalog.searchLocalMaterials('xyz')).called(1);
  });

  testWidgets('renders matching materials after a search', (tester) async {
    when(() => catalog.searchResults).thenReturn([sampleMaterial()]);
    when(() => catalog.browseCategories).thenReturn([sampleCategory()]);

    await pumpFieldScreen(
      tester,
      child: const FieldSearchView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    await tester.enterText(textFieldByHint('Search materials...'), 'Lucky');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Lucky Cement'), findsWidgets);
    verify(() => catalog.searchLocalMaterials('Lucky')).called(1);
  });
}
