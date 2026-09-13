import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/viewmodels/material_viewmodel.dart';

import '../mocks/mocks.dart';

class MockXFile extends Mock implements XFile {}

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
  double price = 1200,
}) {
  return MaterialModel(
    id: id,
    name: 'OPC Cement',
    category: 'Cement',
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53 grade',
    qualityGrade: 'OPC 53',
    supplierId: 'supplier-1',
    supplierName: 'Cement House',
    isCertified: true,
    originCity: 'Lahore',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_material());
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(0.0);
    registerFallbackValue('');
  });

  late MockMaterialRepository materialRepo;
  late MockXFile imageFile;
  late MaterialViewModel viewModel;
  late List<int> uploadedBytes;
  late String uploadedFolder;
  late String uploadedFilename;
  String? uploadResult;

  MaterialViewModel createViewModel() {
    return MaterialViewModel(
      materialRepo,
      uploadImage: ({
        required List<int> bytes,
        required String folder,
        String filename = 'upload.jpg',
      }) async {
        uploadedBytes = bytes;
        uploadedFolder = folder;
        uploadedFilename = filename;
        return uploadResult;
      },
    );
  }

  Future<void> loadCementCategory() async {
    when(() => materialRepo.getCategories()).thenAnswer(
      (_) async => [_category()],
    );
    await viewModel.loadCategories();
    viewModel.onCategorySelected('cement');
  }

  setUp(() {
    materialRepo = MockMaterialRepository();
    imageFile = MockXFile();
    uploadedBytes = [];
    uploadedFolder = '';
    uploadedFilename = '';
    uploadResult = 'https://cdn.example/mat.jpg';

    when(() => imageFile.readAsBytes()).thenAnswer(
      (_) async => Uint8List.fromList([1, 2, 3]),
    );
    when(() => imageFile.name).thenReturn('photo.jpg');
    when(() => materialRepo.saveMaterialWithCompany(any(), any()))
        .thenAnswer((_) async {});
    when(
      () => materialRepo.recordInitialMaterialPrice(
        materialId: any(named: 'materialId'),
        price: any(named: 'price'),
        supplierUid: any(named: 'supplierUid'),
      ),
    ).thenAnswer((_) async {});
    when(() => materialRepo.getMaterialById(any())).thenAnswer(
      (_) async => _material(),
    );
    when(
      () => materialRepo.archiveMaterialPriceChange(
        materialId: any(named: 'materialId'),
        previousPrice: any(named: 'previousPrice'),
        newPrice: any(named: 'newPrice'),
        supplierUid: any(named: 'supplierUid'),
      ),
    ).thenAnswer((_) async {});
    when(() => materialRepo.updateMaterialFields(any(), any(), any()))
        .thenAnswer((_) async {});

    viewModel = createViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('MaterialViewModel form helpers', () {
    test('resetSuccess clears isSuccess and notifies once', () {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.resetSuccess();

      expect(viewModel.isSuccess, isFalse);
      expect(notifies, 1);
    });

    test('resetAddMaterialForm clears category, error, and success', () async {
      await loadCementCategory();
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.resetAddMaterialForm();

      expect(viewModel.selectedCategory, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.isSuccess, isFalse);
      expect(notifies, 1);
    });
  });

  group('MaterialViewModel.loadCategories', () {
    test('success loads categories and clears a stale selection', () async {
      when(() => materialRepo.getCategories()).thenAnswer(
        (_) async => [_category()],
      );
      await viewModel.loadCategories();
      viewModel.onCategorySelected('cement');
      expect(viewModel.selectedCategory?.id, 'cement');

      when(() => materialRepo.getCategories()).thenAnswer(
        (_) async => [_category(id: 'steel', name: 'Steel', unit: 'ton')],
      );

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) {
          loadingOnFirst = viewModel.isLoadingCategories;
        }
      });

      await viewModel.loadCategories();

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoadingCategories, isFalse);
      expect(viewModel.categories.single.id, 'steel');
      expect(viewModel.selectedCategory, isNull);
      expect(viewModel.error, isNull);
      expect(notifies, 2);
      verify(() => materialRepo.getCategories()).called(2);
    });

    test('failure sets error, clears categories, and stops loading', () async {
      when(() => materialRepo.getCategories()).thenThrow(
        Exception('categories down'),
      );

      await viewModel.loadCategories();

      expect(viewModel.isLoadingCategories, isFalse);
      expect(viewModel.categories, isEmpty);
      expect(viewModel.error, 'Exception: categories down');
    });
  });

  group('MaterialViewModel category selection', () {
    test('onCategorySelected sets the matching category', () async {
      await loadCementCategory();
      expect(viewModel.selectedCategory?.id, 'cement');
    });

    test('onCategorySelected clears selection when id is unknown', () async {
      await loadCementCategory();
      viewModel.onCategorySelected('unknown');
      expect(viewModel.selectedCategory, isNull);
    });

    test('selectCategoryByName matches by name and notifies', () async {
      when(() => materialRepo.getCategories()).thenAnswer(
        (_) async => [_category()],
      );
      await viewModel.loadCategories();

      var notifies = 0;
      viewModel.addListener(() => notifies++);
      viewModel.selectCategoryByName('Cement');

      expect(viewModel.selectedCategory?.id, 'cement');
      expect(notifies, 1);
    });

    test('selectCategoryByName does nothing when the name is missing', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);
      viewModel.selectCategoryByName('Steel');

      expect(viewModel.selectedCategory, isNull);
      expect(notifies, 0);
    });
  });

  group('MaterialViewModel.addMaterial', () {
    final params = <String, dynamic>{
      'name': 'OPC Cement',
      'price': '1250',
      'specifications': '53 grade',
      'grade': 'OPC 53',
      'supplierName': 'Cement House',
      'city': 'Lahore',
      'brand': 'Lucky',
      'minOrderQuantity': '10',
      'bulkDiscountAvailable': true,
      'bulkDiscountDetails': '5% over 100 bags',
    };

    test('fails when no category is selected', () async {
      await viewModel.addMaterial(params, imageFile, 'company-1', 'supplier-1');

      expect(viewModel.error, 'Please select a category first');
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => materialRepo.saveMaterialWithCompany(any(), any()));
    });

    test('fails when photo is missing', () async {
      await loadCementCategory();
      await viewModel.addMaterial(params, null, 'company-1', 'supplier-1');

      expect(viewModel.error, 'Material photo is required');
      verifyNever(() => materialRepo.saveMaterialWithCompany(any(), any()));
    });

    test('fails when companyId is empty', () async {
      await loadCementCategory();
      await viewModel.addMaterial(params, imageFile, '  ', 'supplier-1');

      expect(
        viewModel.error,
        'No company selected. Please select a company before adding materials.',
      );
      verifyNever(() => materialRepo.saveMaterialWithCompany(any(), any()));
    });

    test('fails when supplierUid is empty', () async {
      await loadCementCategory();
      await viewModel.addMaterial(params, imageFile, 'company-1', '');

      expect(
        viewModel.error,
        'Supplier account not found. Please sign in again.',
      );
      verifyNever(() => materialRepo.saveMaterialWithCompany(any(), any()));
    });

    test('fails when image upload returns null', () async {
      await loadCementCategory();
      uploadResult = null;

      await viewModel.addMaterial(params, imageFile, 'company-1', 'supplier-1');

      expect(viewModel.error, 'Image upload failed. Please try again.');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isSuccess, isFalse);
      verifyNever(() => materialRepo.saveMaterialWithCompany(any(), any()));
    });

    test('success saves the material and records the initial price', () async {
      await loadCementCategory();

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.addMaterial(params, imageFile, 'company-1', 'supplier-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isSuccess, isTrue);
      expect(viewModel.error, isNull);
      expect(uploadedFolder, 'ratebridge/materials');
      expect(uploadedFilename, 'photo.jpg');
      expect(uploadedBytes, [1, 2, 3]);
      expect(notifies, 2);

      final saved = verify(
        () => materialRepo.saveMaterialWithCompany(captureAny(), 'company-1'),
      ).captured.single as MaterialModel;
      expect(saved.name, 'OPC Cement');
      expect(saved.category, 'Cement');
      expect(saved.unit, 'bag');
      expect(saved.pricePerUnit, 1250);
      expect(saved.supplierId, 'supplier-1');
      expect(saved.profileImageUrl, 'https://cdn.example/mat.jpg');
      expect(saved.minOrderQuantity, 10);
      expect(saved.bulkDiscountDetails, '5% over 100 bags');

      verify(
        () => materialRepo.recordInitialMaterialPrice(
          materialId: saved.id,
          price: 1250,
          supplierUid: 'supplier-1',
        ),
      ).called(1);
    });

    test('failure from the repository sets error and isSuccess false', () async {
      await loadCementCategory();
      when(() => materialRepo.saveMaterialWithCompany(any(), any())).thenThrow(
        Exception('write failed'),
      );

      await viewModel.addMaterial(params, imageFile, 'company-1', 'supplier-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isSuccess, isFalse);
      expect(viewModel.error, 'Exception: write failed');
    });
  });

  group('MaterialViewModel.updateMaterial', () {
    final params = <String, dynamic>{
      'name': 'OPC Cement',
      'price': '1200',
      'brand': 'Lucky',
      'grade': 'OPC 53',
      'stockStatus': 'Available',
      'minOrderQuantity': '',
      'deliveryTime': '',
      'description': '',
    };

    test('success without a photo skips archive when the price is unchanged',
        () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.updateMaterial(
        'mat-1',
        params,
        null,
        'company-1',
        'supplier-1',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isSuccess, isTrue);
      expect(viewModel.error, isNull);
      expect(notifies, 2);

      verify(() => materialRepo.getMaterialById('mat-1')).called(1);
      verifyNever(
        () => materialRepo.archiveMaterialPriceChange(
          materialId: any(named: 'materialId'),
          previousPrice: any(named: 'previousPrice'),
          newPrice: any(named: 'newPrice'),
          supplierUid: any(named: 'supplierUid'),
        ),
      );

      final updates = verify(
        () => materialRepo.updateMaterialFields(
          'mat-1',
          'company-1',
          captureAny(),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(updates['pricePerUnit'], 1200.0);
      expect(updates['name'], 'OPC Cement');
      expect(updates['minOrderQuantity'], isA<FieldValue>());
      expect(updates['deliveryTime'], isA<FieldValue>());
      expect(updates.containsKey('profileImageUrl'), isFalse);
    });

    test('archives a price change before updating fields', () async {
      await viewModel.updateMaterial(
        'mat-1',
        {...params, 'price': '1500'},
        null,
        'company-1',
        'supplier-1',
      );

      verify(
        () => materialRepo.archiveMaterialPriceChange(
          materialId: 'mat-1',
          previousPrice: 1200,
          newPrice: 1500,
          supplierUid: 'supplier-1',
        ),
      ).called(1);
      verify(() => materialRepo.updateMaterialFields('mat-1', 'company-1', any()))
          .called(1);
      expect(viewModel.isSuccess, isTrue);
    });

    test('sets error when the material is missing', () async {
      when(() => materialRepo.getMaterialById('mat-1')).thenAnswer(
        (_) async => null,
      );

      await viewModel.updateMaterial(
        'mat-1',
        params,
        null,
        'company-1',
        'supplier-1',
      );

      expect(viewModel.error, 'Material not found');
      expect(viewModel.isSuccess, isFalse);
      expect(viewModel.isLoading, isFalse);
      verifyNever(
        () => materialRepo.updateMaterialFields(any(), any(), any()),
      );
    });

    test('sets error when image upload fails', () async {
      uploadResult = null;

      await viewModel.updateMaterial(
        'mat-1',
        params,
        imageFile,
        'company-1',
        'supplier-1',
      );

      expect(viewModel.error, 'Image upload failed. Please try again.');
      expect(viewModel.isSuccess, isFalse);
      verifyNever(
        () => materialRepo.updateMaterialFields(any(), any(), any()),
      );
    });

    test('includes uploaded image URL in the field updates', () async {
      await viewModel.updateMaterial(
        'mat-1',
        params,
        imageFile,
        'company-1',
        'supplier-1',
      );

      final updates = verify(
        () => materialRepo.updateMaterialFields(
          'mat-1',
          'company-1',
          captureAny(),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(updates['profileImageUrl'], 'https://cdn.example/mat.jpg');
      expect(viewModel.isSuccess, isTrue);
    });

    test('failure from getMaterialById sets error', () async {
      when(() => materialRepo.getMaterialById(any())).thenThrow(
        Exception('read failed'),
      );

      await viewModel.updateMaterial(
        'mat-1',
        params,
        null,
        'company-1',
        'supplier-1',
      );

      expect(viewModel.error, 'Exception: read failed');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isSuccess, isFalse);
    });
  });
}
