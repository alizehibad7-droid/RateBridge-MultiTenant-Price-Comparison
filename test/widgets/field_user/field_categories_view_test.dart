import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/field_categories_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';
import 'package:ratebridge/views/field_user/widgets/field_material_grid_skeleton.dart';
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

  testWidgets('shows a skeleton while categories are loading', (tester) async {
    final hang = Completer<void>();
    when(() => catalog.isCatalogLoading).thenReturn(true);
    when(() => catalog.loadCategoriesBrowse(any()))
        .thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldCategoriesView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.byType(FieldMaterialGridSkeleton), findsOneWidget);
    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('All Categories'), findsOneWidget);
    verify(() => catalog.loadCategoriesBrowse('co-1')).called(1);
  });

  testWidgets('shows an error and Retry reloads categories', (tester) async {
    when(() => catalog.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldCategoriesView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load categories'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => catalog.loadCategoriesBrowse('co-1')).called(greaterThan(1));
  });

  testWidgets('shows empty copy when there are no categories', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldCategoriesView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.text('No categories available yet'), findsOneWidget);
  });

  testWidgets('renders browse categories from the ViewModel', (tester) async {
    when(() => catalog.browseCategories).thenReturn([sampleCategory()]);
    when(() => catalog.materialCountForCategory(any())).thenReturn(3);

    await pumpFieldScreen(
      tester,
      child: const FieldCategoriesView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(find.text('Cement'), findsOneWidget);
    expect(find.text('3 materials'), findsOneWidget);
    expect(find.text('Search cement, steel, bricks…'), findsOneWidget);
  });
}
