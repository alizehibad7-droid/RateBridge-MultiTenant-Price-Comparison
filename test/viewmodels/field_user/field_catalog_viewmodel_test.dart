import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_catalog_viewmodel.dart';

import '../../mocks/mocks.dart';

CategoryModel _category({
  String id = 'cement',
  String name = 'Cement',
  String unit = 'bag',
}) {
  return CategoryModel(
    id: id,
    name: name,
    unit: unit,
    brands: const ['Lucky'],
    grades: const ['OPC 53'],
  );
}

MaterialModel _material({
  String id = 'mat-1',
  String name = 'OPC Cement',
  String category = 'Cement',
  double price = 1200,
  String supplierId = 'sup-1',
  String supplierName = 'Cement House',
  String? brand,
  DateTime? createdAt,
}) {
  return MaterialModel(
    id: id,
    name: name,
    category: category,
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53 grade',
    qualityGrade: 'OPC 53',
    supplierId: supplierId,
    supplierName: supplierName,
    isCertified: true,
    originCity: 'Lahore',
    brand: brand,
    createdAt: createdAt,
  );
}

Future<void> _flushCatalog() async {
  await Future<void>.delayed(Duration.zero);
  final binding = TestWidgetsFlutterBinding.instance;
  binding.handleBeginFrame(Duration.zero);
  binding.handleDrawFrame();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cement = _category();
  final steel = _category(id: 'steel', name: 'Steel', unit: 'ton');
  final cheapCement = _material(id: 'mat-1', price: 1100, brand: 'Lucky');
  final priceyCement = _material(
    id: 'mat-2',
    name: 'White Cement',
    price: 1800,
    supplierId: 'sup-2',
    supplierName: 'White Co',
    createdAt: DateTime.utc(2026, 5, 1),
  );
  final rebar = _material(
    id: 'mat-3',
    name: 'Grade 60 Bar',
    category: 'Steel',
    price: 1500,
    supplierId: 'sup-1',
    supplierName: 'Cement House',
    createdAt: DateTime.utc(2026, 4, 1),
  );

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(<String>[]);
    registerFallbackValue(cheapCement);
  });

  late MockMaterialRepository materialRepo;
  late StreamController<List<MaterialModel>> materialsStream;
  late FieldCatalogViewModel viewModel;

  setUp(() {
    materialRepo = MockMaterialRepository();
    materialsStream = StreamController<List<MaterialModel>>.broadcast();

    when(() => materialRepo.getCompanyMaterials(any()))
        .thenAnswer((_) => materialsStream.stream);
    when(() => materialRepo.getPopularMaterials(companyId: any(named: 'companyId')))
        .thenAnswer((_) async => [cheapCement]);
    when(() => materialRepo.getCategories())
        .thenAnswer((_) async => [cement, steel]);
    when(
      () => materialRepo.getRecentCompanyMaterials(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [priceyCement]);
    when(() => materialRepo.getMaterialsByIds(any()))
        .thenAnswer((_) async => [cheapCement, rebar]);
    when(() => materialRepo.getSupplierAverageRating(any()))
        .thenAnswer((_) async => 4.2);

    viewModel = FieldCatalogViewModel(materialRepo);
    viewModel.addListener(() {});
  });

  tearDown(() async {
    viewModel.dispose();
    if (!materialsStream.isClosed) await materialsStream.close();
  });

  Future<void> loadCatalog({
    List<MaterialModel>? materials,
  }) async {
    await viewModel.loadMarketplace('co-1');
    materialsStream.add(materials ?? [cheapCement, priceyCement, rebar]);
    await _flushCatalog();
  }

  group('CatalogSortOption.fromValue', () {
    test('maps known values and falls back to priceAsc', () {
      expect(CatalogSortOption.fromValue('price_desc'), CatalogSortOption.priceDesc);
      expect(CatalogSortOption.fromValue('rating'), CatalogSortOption.rating);
      expect(CatalogSortOption.fromValue('newest'), CatalogSortOption.newest);
      expect(CatalogSortOption.fromValue('nope'), CatalogSortOption.priceAsc);
    });
  });

  group('FieldCatalogViewModel.loadMarketplace', () {
    test('loads categories, watches materials, and sorts by price ascending',
        () async {
      var loadingOnFirst = false;
      var first = true;
      viewModel.addListener(() {
        if (first) {
          first = false;
          loadingOnFirst = viewModel.isLoading;
        }
      });

      await viewModel.loadMarketplace('co-1');
      expect(loadingOnFirst, isTrue);
      expect(viewModel.isCatalogLoading, isTrue);
      expect(viewModel.categories.map((c) => c.name), ['Cement', 'Steel']);

      materialsStream.add([priceyCement, cheapCement]);
      await _flushCatalog();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isCatalogLoading, isFalse);
      expect(viewModel.hasCachedMaterials, isTrue);
      expect(viewModel.catalogMaterials, hasLength(2));
      expect(viewModel.materials.map((m) => m.id), ['mat-1', 'mat-2']);
      expect(viewModel.errorMessage, isNull);
    });

    test('falls back to popular materials when the company stream is empty',
        () async {
      await viewModel.loadMarketplace('co-1');
      materialsStream.add(const []);
      await _flushCatalog();

      expect(viewModel.catalogMaterials.single.id, 'mat-1');
      verify(
        () => materialRepo.getPopularMaterials(companyId: 'co-1'),
      ).called(1);
    });

    test('stream error sets errorMessage and finishes loading', () async {
      await viewModel.loadMarketplace('co-1');
      materialsStream.addError(AppException('catalog offline'));
      await _flushCatalog();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'catalog offline');
    });

    test('getCategories failure sets error and skips the material watch',
        () async {
      when(() => materialRepo.getCategories())
          .thenThrow(AppException('categories down'));

      await viewModel.loadMarketplace('co-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'categories down');
      verifyNever(() => materialRepo.getCompanyMaterials(any()));
    });

    test('does not resubscribe when already watching the same company',
        () async {
      await loadCatalog();
      await viewModel.loadMarketplace('co-1');

      verify(() => materialRepo.getCompanyMaterials('co-1')).called(1);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.materials, isNotEmpty);
    });
  });

  group('FieldCatalogViewModel.loadHomeData', () {
    test('loads categories and recent materials then starts the watch',
        () async {
      await viewModel.loadHomeData('co-1');
      verify(
        () => materialRepo.getRecentCompanyMaterials('co-1', limit: 4),
      ).called(1);
      expect(viewModel.recentMaterials.single.id, 'mat-2');

      materialsStream.add([cheapCement]);
      await _flushCatalog();

      expect(viewModel.catalogMaterials.single.id, 'mat-1');
      expect(viewModel.isLoading, isFalse);
    });

    test('failure sets error and does not watch materials', () async {
      when(() => materialRepo.getCategories())
          .thenThrow(AppException('home failed'));

      await viewModel.loadHomeData('co-1');

      expect(viewModel.errorMessage, 'home failed');
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => materialRepo.getCompanyMaterials(any()));
    });
  });

  group('FieldCatalogViewModel.loadCategoriesBrowse', () {
    test('delegates to loadMarketplace', () async {
      await viewModel.loadCategoriesBrowse('co-1');
      materialsStream.add([cheapCement]);
      await _flushCatalog();

      verify(() => materialRepo.getCompanyMaterials('co-1')).called(1);
      expect(viewModel.catalogMaterials, isNotEmpty);
    });
  });

  group('FieldCatalogViewModel filters and sort', () {
    test('filterByCategory is case-insensitive', () async {
      await loadCatalog();

      viewModel.filterByCategory('steel');

      expect(viewModel.categoryFilter, 'steel');
      expect(viewModel.materials.map((m) => m.id), ['mat-3']);
      expect(viewModel.materialCountForCategory('Cement'), 2);
    });

    test('clearFilters restores the full sorted list', () async {
      await loadCatalog();
      viewModel.filterByCategory('Steel');
      viewModel.clearFilters();

      expect(viewModel.categoryFilter, isNull);
      expect(viewModel.materials, hasLength(3));
    });

    test('setSortOption priceDesc and newest', () async {
      await loadCatalog();

      await viewModel.setSortOption(CatalogSortOption.priceDesc);
      expect(viewModel.sortOption, CatalogSortOption.priceDesc);
      expect(viewModel.materials.first.id, 'mat-2');

      await viewModel.setSortOption(CatalogSortOption.newest);
      expect(viewModel.materials.first.id, 'mat-2');
    });

    test('rating sort loads missing supplier ratings', () async {
      when(() => materialRepo.getSupplierAverageRating('sup-1'))
          .thenAnswer((_) async => 3.0);
      when(() => materialRepo.getSupplierAverageRating('sup-2'))
          .thenAnswer((_) async => 5.0);

      await loadCatalog();
      await viewModel.setSortOption(CatalogSortOption.rating);

      expect(viewModel.materials.first.supplierId, 'sup-2');
      expect(viewModel.supplierRatingFor('sup-2'), 5.0);
      expect(viewModel.supplierRatingFor('missing'), 0.0);
    });
  });

  group('FieldCatalogViewModel search', () {
    test('matches name, brand, supplier, and category', () async {
      await loadCatalog();

      viewModel.searchLocalMaterials('lucky');
      expect(viewModel.searchResults.map((m) => m.id), ['mat-1']);

      viewModel.searchLocalMaterials('White Co');
      expect(viewModel.searchResults.map((m) => m.id), ['mat-2']);

      viewModel.searchLocalMaterials('steel');
      expect(viewModel.searchResults.map((m) => m.id), ['mat-3']);
    });

    test('blank query and clearSearchResults empty the list', () async {
      await loadCatalog();
      viewModel.searchLocalMaterials('cement');
      expect(viewModel.searchResults, isNotEmpty);

      viewModel.searchLocalMaterials('   ');
      expect(viewModel.searchResults, isEmpty);

      viewModel.searchLocalMaterials('cement');
      viewModel.clearSearchResults();
      expect(viewModel.searchResults, isEmpty);
    });
  });

  group('FieldCatalogViewModel recently viewed', () {
    test('empty ids clear the list', () async {
      await viewModel.loadRecentlyViewedMaterials('co-1', const []);

      expect(viewModel.recentlyViewedMaterials, isEmpty);
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => materialRepo.getMaterialsByIds(any()));
    });

    test('keeps only linked materials in the requested order', () async {
      await loadCatalog();
      when(() => materialRepo.getMaterialsByIds(any())).thenAnswer(
        (_) async => [rebar, cheapCement, _material(id: 'unlinked')],
      );

      await viewModel.loadRecentlyViewedMaterials(
        'co-1',
        const ['mat-3', 'missing', 'mat-1'],
      );

      expect(
        viewModel.recentlyViewedMaterials.map((m) => m.id),
        ['mat-3', 'mat-1'],
      );
    });

    test('fetches company materials first when the cache is empty', () async {
      final oneShot = StreamController<List<MaterialModel>>();
      when(() => materialRepo.getCompanyMaterials('co-1'))
          .thenAnswer((_) => oneShot.stream);
      when(() => materialRepo.getMaterialsByIds(any()))
          .thenAnswer((_) async => [cheapCement]);

      final pending =
          viewModel.loadRecentlyViewedMaterials('co-1', const ['mat-1']);
      oneShot.add([cheapCement]);
      await pending;
      await oneShot.close();

      expect(viewModel.recentlyViewedMaterials.single.id, 'mat-1');
    });

    test('failure sets errorMessage', () async {
      when(() => materialRepo.getCompanyMaterials(any()))
          .thenAnswer((_) => Stream.error(AppException('ids failed')));

      await viewModel.loadRecentlyViewedMaterials('co-1', const ['mat-1']);

      expect(viewModel.errorMessage, 'ids failed');
      expect(viewModel.isLoading, isFalse);
    });

    test('clearRecentlyViewedDisplay empties the list', () async {
      await loadCatalog();
      await viewModel.loadRecentlyViewedMaterials('co-1', const ['mat-1']);
      expect(viewModel.recentlyViewedMaterials, isNotEmpty);

      viewModel.clearRecentlyViewedDisplay();
      expect(viewModel.recentlyViewedMaterials, isEmpty);
    });
  });

  group('FieldCatalogViewModel category getters', () {
    test('materialCategoryNames are unique and sorted', () async {
      await loadCatalog();

      expect(viewModel.materialCategoryNames, ['Cement', 'Steel']);
      expect(viewModel.uniqueCategories, ['Cement', 'Steel']);
    });

    test('browseCategories merges Firestore categories with material names',
        () async {
      await loadCatalog(materials: [
        cheapCement,
        _material(id: 'mat-9', name: 'Sand', category: 'Sand', price: 40),
      ]);

      expect(
        viewModel.browseCategories.map((c) => c.name),
        ['Cement', 'Sand', 'Steel'],
      );
    });
  });

  group('FieldCatalogViewModel.prefetchSupplierRatings', () {
    test('caches ratings for catalog suppliers', () async {
      await loadCatalog();
      await viewModel.prefetchSupplierRatings();

      expect(viewModel.supplierRatingFor('sup-1'), 4.2);
      verify(() => materialRepo.getSupplierAverageRating('sup-1')).called(1);
    });
  });

  group('FieldCatalogViewModel.clearError', () {
    test('clears errorMessage', () async {
      await viewModel.loadMarketplace('co-1');
      materialsStream.addError(Exception('offline'));
      await _flushCatalog();

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
