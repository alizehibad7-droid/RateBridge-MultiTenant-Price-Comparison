import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/material_listing.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_compare_viewmodel.dart';

import '../../mocks/mocks.dart';

MaterialListing _listing({
  String id = 'mat-1',
  String supplierId = 'sup-1',
  String supplierName = 'Cement House',
  double price = 1000,
  double rating = 4.0,
  String? city = 'Lahore',
}) {
  return MaterialListing(
    id: id,
    materialName: 'OPC Cement',
    supplierName: supplierName,
    supplierId: supplierId,
    pricePerUnit: price,
    unit: 'bag',
    category: 'Cement',
    city: city,
    supplierRating: rating,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(_listing());
  });

  late MockMaterialRepository materialRepo;
  late MockFirestoreService firestore;
  late MockFirebaseAuth auth;
  late MockFirebaseUser firebaseUser;
  late FieldCompareViewModel viewModel;

  setUp(() {
    materialRepo = MockMaterialRepository();
    firestore = MockFirestoreService();
    auth = MockFirebaseAuth();
    firebaseUser = MockFirebaseUser();
    when(() => auth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.uid).thenReturn('user-1');
    when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
        .thenAnswer((_) async => [_listing(), _listing(id: 'mat-2', price: 1100)]);
    when(
      () => firestore.generateAiText(
        uid: any(named: 'uid'),
        prompt: any(named: 'prompt'),
      ),
    ).thenAnswer((_) async => '{"summary":"Pick Cement House.","lines":{"mat-1":"Best value pick"}}');

    viewModel = FieldCompareViewModel(materialRepo, firestore, auth: auth);
  });

  tearDown(() {
    viewModel.dispose();
  });

  Future<void> settleAi() async {
    for (var i = 0; i < 40; i++) {
      if (!viewModel.isAiLoading) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('FieldCompareViewModel.loadComparison', () {
    test('flags anomalies, marks best value, and loads AI JSON', () async {
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenAnswer(
        (_) async => [
          _listing(id: 'cheap', price: 1000),
          _listing(id: 'mid', supplierId: 'sup-2', price: 1050, city: 'Karachi'),
          _listing(id: 'high', supplierId: 'sup-3', price: 2000, city: 'Islamabad'),
        ],
      );
      when(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      ).thenAnswer(
        (_) async =>
            '{"summary":"Pick Cement House.","lines":{"cheap":"Best value pick","high":"Too expensive"}}',
      );

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadComparison('co-1', '  OPC Cement  ');
      await settleAi();

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.materialName, 'OPC Cement');
      expect(viewModel.bestPrice, 1000);
      expect(viewModel.bestValueSupplier?.id, 'cheap');
      final high = viewModel.rawResults.firstWhere((r) => r.id == 'high');
      final mid = viewModel.rawResults.firstWhere((r) => r.id == 'mid');
      expect(viewModel.badgeFor(high), CompareBadgeType.anomaly);
      expect(viewModel.badgeFor(viewModel.bestValueSupplier!),
          CompareBadgeType.bestValue);
      expect(viewModel.badgeFor(mid), CompareBadgeType.none);
      expect(viewModel.aiSummary, 'Pick Cement House.');
      expect(viewModel.insightLineFor(viewModel.bestValueSupplier!), 'Best value pick');
      expect(viewModel.insightLineFor(high), 'Too expensive');
      expect(viewModel.showAiCard, isTrue);
      expect(viewModel.isAiLoading, isFalse);
      expect(viewModel.availableCities, ['Islamabad', 'Karachi', 'Lahore']);
      verify(
        () => materialRepo.getCompareListingsForMaterial('co-1', 'OPC Cement'),
      ).called(1);
    });

    test('empty name skips the repo and AI', () async {
      await viewModel.loadComparison('co-1', '   ');
      await settleAi();

      expect(viewModel.results, isEmpty);
      expect(viewModel.showAiCard, isFalse);
      verifyNever(() => materialRepo.getCompareListingsForMaterial(any(), any()));
      verifyNever(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      );
    });

    test('single listing skips AI and uses fallback insight lines', () async {
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenAnswer((_) async => [_listing(price: 1000)]);

      await viewModel.loadComparison('co-1', 'Cement');
      await settleAi();

      expect(viewModel.results, hasLength(1));
      expect(viewModel.bestValueSupplier?.id, 'mat-1');
      expect(
        viewModel.insightLineFor(viewModel.results.single),
        'Best value: lowest price among non-outlier listings.',
      );
      expect(viewModel.aiSummary, isNull);
      verifyNever(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      );
    });

    test('signed-out users skip AI after listings load', () async {
      when(() => auth.currentUser).thenReturn(null);

      await viewModel.loadComparison('co-1', 'Cement');
      await settleAi();

      expect(viewModel.results, hasLength(2));
      expect(viewModel.isAiLoading, isFalse);
      expect(viewModel.aiSummary, isNull);
      verifyNever(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      );
    });

    test('without AI, anomaly listings use the fallback insight line', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenAnswer(
        (_) async => [
          _listing(id: 'cheap', price: 1000),
          _listing(id: 'high', supplierId: 'sup-3', price: 2000),
        ],
      );

      await viewModel.loadComparison('co-1', 'Cement');

      final high = viewModel.rawResults.firstWhere((r) => r.id == 'high');
      expect(viewModel.badgeFor(high), CompareBadgeType.anomaly);
      expect(
        viewModel.insightLineFor(high),
        'Priced 15%+ above the average — confirm quality and terms.',
      );
    });

    test('markdown-fenced JSON is parsed', () async {
      when(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      ).thenAnswer(
        (_) async =>
            '```json\n{"summary":"Fence summary.","lines":{"mat-1":"Go cheap"}}\n```',
      );

      await viewModel.loadComparison('co-1', 'Cement');
      await settleAi();

      expect(viewModel.aiSummary, 'Fence summary.');
      expect(viewModel.insightLineFor(viewModel.bestValueSupplier!), 'Go cheap');
    });

    test('plain-text AI response becomes the summary', () async {
      when(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      ).thenAnswer((_) async => 'Go with the cheaper mill.');

      await viewModel.loadComparison('co-1', 'Cement');
      await settleAi();

      expect(viewModel.aiSummary, 'Go with the cheaper mill.');
    });

    test('AI failure clears summary without failing the comparison', () async {
      when(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      ).thenThrow(AppException('assistant unavailable'));

      await viewModel.loadComparison('co-1', 'Cement');
      await settleAi();

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.results, hasLength(2));
      expect(viewModel.aiSummary, isNull);
      expect(viewModel.isAiLoading, isFalse);
    });

    test('repository failure sets errorMessage', () async {
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenThrow(AppException('compare down'));

      await viewModel.loadComparison('co-1', 'Cement');

      expect(viewModel.errorMessage, 'compare down');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.results, isEmpty);
    });

    test('loadCompareRates is an alias of loadComparison', () async {
      await viewModel.loadCompareRates('co-1', 'Cement');
      verify(
        () => materialRepo.getCompareListingsForMaterial('co-1', 'Cement'),
      ).called(1);
    });
  });

  group('FieldCompareViewModel sort and city filter', () {
    test('setSortBy rating reorders displayResults', () async {
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenAnswer(
        (_) async => [
          _listing(id: 'a', price: 900, rating: 3.0),
          _listing(id: 'b', supplierId: 'sup-2', price: 1200, rating: 5.0),
        ],
      );
      await viewModel.loadComparison('co-1', 'Cement');

      expect(viewModel.results.first.id, 'a');
      viewModel.setSortBy(CompareSortOption.rating);
      expect(viewModel.sortBy, CompareSortOption.rating);
      expect(viewModel.results.first.id, 'b');

      viewModel.setSortBy(CompareSortOption.rating);
      expect(viewModel.results.first.id, 'b');
    });

    test('city filter and clearCityFilter', () async {
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenAnswer(
        (_) async => [
          _listing(id: 'lhr', city: 'Lahore'),
          _listing(id: 'khi', supplierId: 'sup-2', price: 1100, city: 'Karachi'),
        ],
      );
      await viewModel.loadComparison('co-1', 'Cement');

      viewModel.setCityFilter('Karachi');
      expect(viewModel.hasCityFilter, isTrue);
      expect(viewModel.results.single.id, 'khi');

      viewModel.clearCityFilter();
      expect(viewModel.hasCityFilter, isFalse);
      expect(viewModel.results, hasLength(2));
    });
  });

  group('FieldCompareViewModel.clearError', () {
    test('clears errorMessage', () async {
      when(() => materialRepo.getCompareListingsForMaterial(any(), any()))
          .thenThrow(AppException('boom'));
      await viewModel.loadComparison('co-1', 'Cement');

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
