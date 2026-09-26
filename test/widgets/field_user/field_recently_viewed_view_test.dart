import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/services/recently_viewed_service.dart';
import 'package:ratebridge/views/field_user/field_recently_viewed_view.dart';
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

  testWidgets('shows a skeleton while recently viewed materials load',
      (tester) async {
    final hang = Completer<void>();
    when(() => catalog.loadRecentlyViewedMaterials(any(), any()))
        .thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldRecentlyViewedView(),
      session: session,
      catalog: catalog,
      prefsValues: {
        RecentlyViewedService.storageKey: ['mat-1'],
      },
      pumpPostFrame: false,
    );
    await tester.pump();

    expect(find.byType(FieldMaterialGridSkeleton), findsOneWidget);
    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('Recently Viewed'), findsOneWidget);
  });

  testWidgets('shows empty copy when nothing has been viewed', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldRecentlyViewedView(),
      session: session,
      catalog: catalog,
    );
    await tester.pump();

    expect(
      find.text('Materials you browse will appear here'),
      findsOneWidget,
    );
  });

  testWidgets('renders recently viewed materials and Clear wipes history',
      (tester) async {
    when(() => catalog.recentlyViewedMaterials)
        .thenReturn([sampleMaterial()]);

    await pumpFieldScreen(
      tester,
      child: const FieldRecentlyViewedView(),
      session: session,
      catalog: catalog,
      prefsValues: {
        RecentlyViewedService.storageKey: ['mat-1'],
      },
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    verify(() => catalog.loadRecentlyViewedMaterials('co-1', ['mat-1']))
        .called(1);

    await tester.tap(find.text('Clear'));
    await tester.pump();

    verify(catalog.clearRecentlyViewedDisplay).called(1);
    expect(
      find.text('Materials you browse will appear here'),
      findsOneWidget,
    );
  });
}
