import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/marketplace/field_marketplace_view.dart';
import 'package:shimmer/shimmer.dart';

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

  testWidgets('shows shimmer while the marketplace catalog is loading',
      (tester) async {
    final hang = Completer<void>();
    when(() => catalog.isCatalogLoading).thenReturn(true);
    when(() => catalog.loadMarketplace(any())).thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldMarketplaceView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('Marketplace'), findsOneWidget);
    verify(() => catalog.filterByCategory(null)).called(greaterThan(0));
    verify(() => catalog.loadMarketplace('co-1')).called(1);
  });

  testWidgets('shows empty copy when no materials are listed', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldMarketplaceView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.text('No materials available'), findsOneWidget);
  });

  testWidgets('shows an error and Retry reloads the marketplace',
      (tester) async {
    when(() => catalog.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldMarketplaceView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.text('Could not load marketplace'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => catalog.loadMarketplace('co-1')).called(greaterThan(1));
  });

  testWidgets('renders catalog materials from the ViewModel', (tester) async {
    final material = sampleMaterial();
    when(() => catalog.hasCachedMaterials).thenReturn(true);
    when(() => catalog.categories).thenReturn([sampleCategory()]);
    when(() => catalog.browseCategories).thenReturn([sampleCategory()]);
    when(() => catalog.catalogMaterials).thenReturn([material]);
    when(() => catalog.materials).thenReturn([material]);

    await pumpFieldScreen(
      tester,
      child: const FieldMarketplaceView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    verify(() => catalog.prefetchSupplierRatings()).called(1);
  });
}
