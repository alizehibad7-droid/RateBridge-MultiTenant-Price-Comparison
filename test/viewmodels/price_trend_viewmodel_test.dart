import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/price_history_model.dart';
import 'package:ratebridge/viewmodels/price_trend_viewmodel.dart';

import '../mocks/mocks.dart';

PriceHistoryModel _point({
  String id = 'hist-1',
  double price = 100,
  DateTime? timestamp,
}) {
  return PriceHistoryModel(
    histId: id,
    materialId: 'mat-1',
    supplierUid: 'supplier-1',
    companyId: 'company-1',
    price: price,
    timestamp: timestamp ?? DateTime.utc(2026, 4, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPriceHistoryRepository priceRepo;
  late StreamController<List<PriceHistoryModel>> historyStream;
  late PriceTrendViewModel viewModel;

  setUp(() {
    priceRepo = MockPriceHistoryRepository();
    historyStream = StreamController<List<PriceHistoryModel>>.broadcast();
    when(() => priceRepo.watchPriceHistory(any(), any(), null)).thenAnswer(
      (_) => historyStream.stream,
    );
    viewModel = PriceTrendViewModel(priceRepo);
  });

  tearDown(() async {
    viewModel.dispose();
    if (!historyStream.isClosed) {
      await historyStream.close();
    }
  });

  group('PriceTrendViewModel.setRange', () {
    test('updates selectedRange without loading history', () {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.setRange('6M');

      expect(viewModel.selectedRange, '6M');
      expect(notifies, 0);
      verifyNever(() => priceRepo.watchPriceHistory(any(), any(), null));
    });
  });

  group('PriceTrendViewModel.loadHistory', () {
    test('sets loading then stores emitted history', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadHistory('mat-1', 'company-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isTrue);
      verify(() => priceRepo.watchPriceHistory('mat-1', 'company-1', null))
          .called(1);

      final points = [_point(price: 110), _point(id: 'hist-2', price: 120)];
      historyStream.add(points);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.history, points);
      expect(notifies, 2);
    });

    test('later emissions replace history', () async {
      await viewModel.loadHistory('mat-1', 'company-1');
      historyStream.add([_point(price: 100)]);
      await Future<void>.delayed(Duration.zero);

      historyStream.add([_point(id: 'hist-9', price: 140)]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.history, hasLength(1));
      expect(viewModel.history.single.price, 140);
      expect(viewModel.isLoading, isFalse);
    });

    test('empty snapshot clears history and stops loading', () async {
      await viewModel.loadHistory('mat-1', 'company-1');
      historyStream.add(const []);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.history, isEmpty);
      expect(viewModel.isLoading, isFalse);
    });
  });

  test('getAiInsight is a no-op', () async {
    var notifies = 0;
    viewModel.addListener(() => notifies++);

    await viewModel.getAiInsight('OPC Cement', 'en');

    expect(viewModel.aiInsight, isNull);
    expect(viewModel.isAiLoading, isFalse);
    expect(notifies, 0);
    verifyNever(() => priceRepo.watchPriceHistory(any(), any(), null));
  });
}
