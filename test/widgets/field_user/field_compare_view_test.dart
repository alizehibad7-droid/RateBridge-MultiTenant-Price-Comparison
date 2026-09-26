import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/viewmodels/field_user/field_compare_viewmodel.dart';
import 'package:ratebridge/views/field_user/compare/field_compare_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldCompareViewModel compare;

  setUp(() {
    session = MockFieldSessionViewModel();
    compare = MockFieldCompareViewModel();
    stubFieldSessionViewModel(session);
    stubFieldCompareViewModel(compare);
  });

  testWidgets('shows shimmer while comparison listings are loading',
      (tester) async {
    final hang = Completer<void>();
    when(() => compare.isLoading).thenReturn(true);
    when(() => compare.loadComparison(any(), any()))
        .thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldCompareView(materialName: 'Lucky Cement'),
      session: session,
      compare: compare,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    verify(() => compare.loadComparison('co-1', 'Lucky Cement')).called(1);
  });

  testWidgets('shows an error and Retry reloads comparison', (tester) async {
    when(() => compare.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldCompareView(materialName: 'Lucky Cement'),
      session: session,
      compare: compare,
    );
    await tester.pump();

    expect(find.text('Could not load comparison'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => compare.loadComparison('co-1', 'Lucky Cement'))
        .called(greaterThan(1));
  });

  testWidgets('shows empty copy when no suppliers offer the material',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldCompareView(materialName: 'Lucky Cement'),
      session: session,
      compare: compare,
    );
    await tester.pump();

    expect(find.text('No suppliers available'), findsOneWidget);
  });

  testWidgets('renders listings and Rating sort calls setSortBy',
      (tester) async {
    final listing = sampleListing();
    when(() => compare.rawResults).thenReturn([listing]);
    when(() => compare.results).thenReturn([listing]);
    when(() => compare.availableCities).thenReturn(const ['Karachi']);
    when(() => compare.bestValueSupplier).thenReturn(listing);

    await pumpFieldScreen(
      tester,
      child: const FieldCompareView(materialName: 'Lucky Cement'),
      session: session,
      compare: compare,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsWidgets);
    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Order Now'), findsOneWidget);

    await tester.tap(find.text('Rating ↑'));
    await tester.pump();

    verify(() => compare.setSortBy(CompareSortOption.rating)).called(1);
  });
}
