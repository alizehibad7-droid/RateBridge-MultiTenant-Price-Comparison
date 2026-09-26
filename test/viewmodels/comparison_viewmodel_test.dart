import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/viewmodels/comparison_viewmodel.dart';

import '../mocks/mocks.dart';

MaterialModel _material({
  String id = 'mat-1',
  String name = 'OPC Cement',
  double price = 100,
  String city = 'Lahore',
  String supplierName = 'Cement House',
}) {
  return MaterialModel(
    id: id,
    name: name,
    category: 'Cement',
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53 grade',
    qualityGrade: 'OPC 53',
    supplierId: 'supplier-$id',
    supplierName: supplierName,
    isCertified: true,
    originCity: city,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMaterialRepository materialRepo;
  late ComparisonViewModel viewModel;

  final listings = [
    _material(id: 'cheap', price: 90, city: 'Lahore'),
    _material(id: 'mid', price: 100, city: 'Karachi'),
    _material(id: 'pricey', price: 130, city: 'Lahore'),
  ];

  setUp(() {
    materialRepo = MockMaterialRepository();
    viewModel = ComparisonViewModel(materialRepo);
    when(() => materialRepo.getApprovedSuppliersForMaterial(any()))
        .thenAnswer((_) async => listings);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('ComparisonViewModel.loadSuppliers', () {
    test('success loads, sorts by price, and toggles loading', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadSuppliers('OPC Cement');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.sortByField, 'price');
      expect(viewModel.suppliers.map((m) => m.id), ['cheap', 'mid', 'pricey']);
      expect(notifies, 2);
      verify(() => materialRepo.getApprovedSuppliersForMaterial('OPC Cement'))
          .called(1);
    });

    test('failure leaves suppliers empty and loading false', () async {
      when(() => materialRepo.getApprovedSuppliersForMaterial(any())).thenThrow(
        Exception('compare query failed'),
      );

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.loadSuppliers('OPC Cement');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.suppliers, isEmpty);
      expect(notifies, 2);
    });

    test('failure after a successful load keeps the previous list', () async {
      await viewModel.loadSuppliers('OPC Cement');
      when(() => materialRepo.getApprovedSuppliersForMaterial(any())).thenThrow(
        Exception('timeout'),
      );

      await viewModel.loadSuppliers('OPC Cement');

      expect(viewModel.suppliers, isNotEmpty);
      expect(viewModel.suppliers.first.id, 'cheap');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('ComparisonViewModel sort and filter', () {
    test('sortBy location orders by origin city', () async {
      await viewModel.loadSuppliers('OPC Cement');

      var notifies = 0;
      viewModel.addListener(() => notifies++);
      viewModel.sortBy('location');

      expect(viewModel.sortByField, 'location');
      expect(
        viewModel.suppliers.map((m) => m.originCity),
        ['Karachi', 'Lahore', 'Lahore'],
      );
      expect(notifies, 1);
    });

    test('filterByCity keeps only matching cities', () async {
      await viewModel.loadSuppliers('OPC Cement');

      viewModel.filterByCity('Lahore');

      expect(viewModel.suppliers.map((m) => m.id), ['cheap', 'pricey']);
      viewModel.filterByCity(null);
      expect(viewModel.suppliers, hasLength(3));
    });
  });

  group('ComparisonViewModel.isAnomaly', () {
    test('returns false when there are no listings', () {
      expect(viewModel.isAnomaly(_material(price: 500)), isFalse);
    });

    test('flags prices more than 15 percent above the average', () async {
      await viewModel.loadSuppliers('OPC Cement');
      // avg = (90 + 100 + 130) / 3 = 106.66..., threshold ≈ 122.67
      expect(viewModel.isAnomaly(listings[0]), isFalse);
      expect(viewModel.isAnomaly(listings[1]), isFalse);
      expect(viewModel.isAnomaly(listings[2]), isTrue);
    });
  });

  test('getAiRecommendation is a no-op', () async {
    await viewModel.loadSuppliers('OPC Cement');
    clearInteractions(materialRepo);
    var notifies = 0;
    viewModel.addListener(() => notifies++);

    await viewModel.getAiRecommendation('best price', locale: 'ur');

    expect(viewModel.aiResult, isNull);
    expect(viewModel.aiError, isNull);
    expect(viewModel.isAiLoading, isFalse);
    expect(notifies, 0);
    verifyNever(() => materialRepo.getApprovedSuppliersForMaterial(any()));
  });
}
