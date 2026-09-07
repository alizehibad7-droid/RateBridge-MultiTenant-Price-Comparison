import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/trends/field_price_trends_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldTrendsViewModel trends;

  setUp(() {
    session = MockFieldSessionViewModel();
    trends = MockFieldTrendsViewModel();
    stubFieldSessionViewModel(session);
    stubFieldTrendsViewModel(trends);
  });

  testWidgets('shows shimmer while price history is loading', (tester) async {
    final hang = Completer<void>();
    when(() => trends.isLoading).thenReturn(true);
    when(() => trends.loadTrends(any(), any(), any()))
        .thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldPriceTrendsView(
        materialId: 'mat-1',
        supplierUid: 'sup-1',
      ),
      session: session,
      trends: trends,
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    verify(() => trends.loadTrends('co-1', 'mat-1', 'sup-1')).called(1);
  });

  testWidgets('shows an error and Retry reloads trends', (tester) async {
    when(() => trends.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldPriceTrendsView(
        materialId: 'mat-1',
        supplierUid: 'sup-1',
      ),
      session: session,
      trends: trends,
    );
    await tester.pump();

    expect(find.text('Could not load price trends'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => trends.loadTrends('co-1', 'mat-1', 'sup-1'))
        .called(greaterThan(1));
  });

  testWidgets('shows empty copy when there is no price history',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldPriceTrendsView(
        materialId: 'mat-1',
        supplierUid: 'sup-1',
      ),
      session: session,
      trends: trends,
    );
    await tester.pump();

    expect(find.text('No Price Data Yet'), findsOneWidget);
  });

  testWidgets('renders price history from the ViewModel', (tester) async {
    final history = [
      samplePriceHistory(
        id: 'hist-1',
        price: 1200,
        timestamp: DateTime.utc(2026, 3, 1),
      ),
      samplePriceHistory(
        id: 'hist-2',
        price: 1250,
        timestamp: DateTime.utc(2026, 8, 1),
      ),
    ];
    when(() => trends.history).thenReturn(history);
    when(() => trends.chartPoints).thenReturn(history);
    when(() => trends.materialName).thenReturn('Lucky Cement');
    when(() => trends.supplierName).thenReturn('Skyline Materials');
    when(() => trends.currentPrice).thenReturn(1250);
    when(() => trends.lowestPrice).thenReturn(1200);
    when(() => trends.highestPrice).thenReturn(1250);
    when(() => trends.distinctMonthCount).thenReturn(2);
    when(() => trends.hasEnoughChartData).thenReturn(true);

    await pumpFieldScreen(
      tester,
      child: const FieldPriceTrendsView(
        materialId: 'mat-1',
        supplierUid: 'sup-1',
      ),
      session: session,
      trends: trends,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Skyline Materials'), findsWidgets);
    expect(find.text('Price History'), findsOneWidget);
    expect(find.text('Current Price'), findsOneWidget);
  });
}
