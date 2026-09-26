import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_supplier_profile_viewmodel.dart';

import '../../mocks/mocks.dart';

SupplierModel _supplier({String status = 'Active'}) {
  return SupplierModel(
    id: 'sup-1',
    name: 'Cement House',
    email: 'cement@co.test',
    materialType: 'Cement',
    contact: '0300',
    status: status,
    rating: 4.5,
    activeContracts: 2,
    contractValue: 10000,
    leadTimeDays: 3,
    city: 'Lahore',
  );
}

MaterialModel _material({String id = 'mat-1'}) {
  return MaterialModel(
    id: id,
    name: 'OPC Cement',
    category: 'Cement',
    pricePerUnit: 1200,
    unit: 'bag',
    specifications: '53',
    qualityGrade: 'OPC 53',
    supplierId: 'sup-1',
    supplierName: 'Cement House',
    isCertified: true,
    originCity: 'Lahore',
  );
}

RatingModel _rating({
  String id = 'r-1',
  double quality = 4,
  double timeliness = 5,
}) {
  return RatingModel(
    id: id,
    orderId: 'order-1',
    supplierUid: 'sup-1',
    userId: 'field-1',
    userName: 'Ali Raza',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    rating: 4.5,
    comment: 'Good',
    dimensions: {
      'Quality': quality,
      'Timeliness': timeliness,
    },
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(_material());
    registerFallbackValue(_rating());
  });

  late MockMaterialRepository materialRepo;
  late MockOrderRepository orderRepo;
  late StreamController<List<RatingModel>> ratingsStream;
  late FieldSupplierProfileViewModel viewModel;

  setUp(() {
    materialRepo = MockMaterialRepository();
    orderRepo = MockOrderRepository();
    ratingsStream = StreamController<List<RatingModel>>.broadcast();

    when(() => orderRepo.getSupplierById(any()))
        .thenAnswer((_) async => _supplier());
    when(() => materialRepo.getSupplierAverageRating(any()))
        .thenAnswer((_) async => 4.2);
    when(() => materialRepo.getCompanyMaterialsBySupplier(any(), any()))
        .thenAnswer((_) async => [_material(), _material(id: 'mat-2')]);
    when(() => orderRepo.watchSupplierRatings(any()))
        .thenAnswer((_) => ratingsStream.stream);

    viewModel = FieldSupplierProfileViewModel(materialRepo, orderRepo);
  });

  tearDown(() async {
    viewModel.dispose();
    if (!ratingsStream.isClosed) await ratingsStream.close();
  });

  group('FieldSupplierProfileViewModel.load', () {
    test('loads supplier, rating, materials, then streams reviews', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.load('co-1', 'sup-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.supplier?.name, 'Cement House');
      expect(viewModel.averageRating, 4.2);
      expect(viewModel.materials, hasLength(2));
      verify(() => orderRepo.getSupplierById('sup-1')).called(1);
      verify(() => materialRepo.getSupplierAverageRating('sup-1')).called(1);
      verify(
        () => materialRepo.getCompanyMaterialsBySupplier('co-1', 'sup-1'),
      ).called(1);

      ratingsStream.add([
        _rating(id: 'r-1', quality: 4, timeliness: 5),
        _rating(id: 'r-2', quality: 2, timeliness: 3),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.ratingCount, 2);
      expect(viewModel.recentRatings, hasLength(2));
      expect(viewModel.qualityAverage, 3);
      expect(viewModel.deliveryAverage, 4);
    });

    test('recentRatings caps at 5', () async {
      await viewModel.load('co-1', 'sup-1');
      ratingsStream.add(
        List.generate(7, (i) => _rating(id: 'r-$i')),
      );
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.ratingCount, 7);
      expect(viewModel.recentRatings, hasLength(5));
    });

    test('dimension averages ignore missing and zero scores', () async {
      await viewModel.load('co-1', 'sup-1');
      ratingsStream.add([
        RatingModel(
          id: 'r-1',
          orderId: 'o-1',
          supplierUid: 'sup-1',
          userId: 'field-1',
          userName: 'Ali',
          materialId: 'mat-1',
          materialName: 'Cement',
          rating: 4,
          comment: '',
          dimensions: const {'Quality': 0, 'Timeliness': 5},
          createdAt: DateTime.utc(2026, 4, 1),
        ),
        RatingModel(
          id: 'r-2',
          orderId: 'o-2',
          supplierUid: 'sup-1',
          userId: 'field-2',
          userName: 'Sara',
          materialId: 'mat-1',
          materialName: 'Cement',
          rating: 3,
          comment: '',
          createdAt: DateTime.utc(2026, 4, 2),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.qualityAverage, 0);
      expect(viewModel.deliveryAverage, 5);
    });

    test('supplier lookup failure sets error and clears loading', () async {
      when(() => orderRepo.getSupplierById(any()))
          .thenThrow(AppException('supplier missing'));

      await viewModel.load('co-1', 'sup-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'supplier missing');
      expect(viewModel.supplier, isNull);
      verifyNever(() => orderRepo.watchSupplierRatings(any()));
    });

    test('ratings stream error sets errorMessage', () async {
      await viewModel.load('co-1', 'sup-1');
      ratingsStream.addError(Exception('ratings down'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.errorMessage, contains('ratings down'));
      expect(viewModel.supplier, isNotNull);
    });
  });

  group('FieldSupplierProfileViewModel.clearError', () {
    test('clears errorMessage', () async {
      when(() => orderRepo.getSupplierById(any()))
          .thenThrow(AppException('boom'));
      await viewModel.load('co-1', 'sup-1');

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
