import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/price_history_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_trends_viewmodel.dart';

import '../../mocks/mocks.dart';

CompanyModel _company({String plan = 'free'}) {
  return CompanyModel(
    id: 'co-1',
    name: 'Acme Builders',
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
    plan: plan,
  );
}

MaterialModel _material({String supplierId = 'sup-1'}) {
  return MaterialModel(
    id: 'mat-1',
    name: 'OPC Cement',
    category: 'Cement',
    pricePerUnit: 1200,
    unit: 'bag',
    specifications: '53',
    qualityGrade: 'OPC 53',
    supplierId: supplierId,
    supplierName: 'Cement House',
    isCertified: true,
    originCity: 'Lahore',
  );
}

PriceHistoryModel _point({
  String id = 'h-1',
  double price = 1000,
  DateTime? timestamp,
}) {
  return PriceHistoryModel(
    histId: id,
    materialId: 'mat-1',
    supplierUid: 'sup-1',
    companyId: 'co-1',
    price: price,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 15),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0);
    registerFallbackValue(_point());
    registerFallbackValue(_material());
  });

  late MockMaterialRepository materialRepo;
  late MockCompanyRepository companyRepo;
  late MockFirestoreService firestore;
  late MockFirebaseAuth auth;
  late MockFirebaseUser firebaseUser;
  late FieldTrendsViewModel viewModel;

  setUp(() {
    materialRepo = MockMaterialRepository();
    companyRepo = MockCompanyRepository();
    firestore = MockFirestoreService();
    auth = MockFirebaseAuth();
    firebaseUser = MockFirebaseUser();
    when(() => auth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.uid).thenReturn('user-1');
    when(() => companyRepo.getCompanyById(any()))
        .thenAnswer((_) async => _company());
    when(
      () => materialRepo.getPriceTrendForMaterial(
        any(),
        any(),
        months: any(named: 'months'),
      ),
    ).thenAnswer((_) async => [
          _point(price: 1000, timestamp: DateTime.utc(2026, 1, 1)),
          _point(id: 'h-2', price: 1100, timestamp: DateTime.utc(2026, 2, 1)),
          _point(id: 'h-3', price: 1200, timestamp: DateTime.utc(2026, 3, 1)),
        ]);
    when(() => materialRepo.isSupplierLinkedToCompany(any(), any()))
        .thenAnswer((_) async => true);
    when(() => materialRepo.getMaterialById(any()))
        .thenAnswer((_) async => _material());
    when(
      () => materialRepo.getSupplierMaterialPriceTrend(
        materialId: any(named: 'materialId'),
        supplierUid: any(named: 'supplierUid'),
        months: any(named: 'months'),
        companyId: any(named: 'companyId'),
      ),
    ).thenAnswer((_) async => [
          _point(price: 1000, timestamp: DateTime.utc(2026, 1, 1)),
          _point(id: 'h-2', price: 1100, timestamp: DateTime.utc(2026, 2, 1)),
          _point(id: 'h-3', price: 1200, timestamp: DateTime.utc(2026, 3, 1)),
        ]);
    when(
      () => firestore.generateAiText(
        uid: any(named: 'uid'),
        prompt: any(named: 'prompt'),
      ),
    ).thenAnswer((_) async => 'Prices are rising. Buy soon.');

    viewModel = FieldTrendsViewModel(
      materialRepo,
      companyRepo,
      firestore,
      auth: auth,
    );
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

  group('FieldTrendsViewModel.loadTrends aggregate', () {
    test('free plan uses 1 month and computes an up trend plus AI', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadTrends('co-1', 'OPC Cement', '_');
      await settleAi();

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.materialName, 'OPC Cement');
      expect(viewModel.supplierName, 'All suppliers');
      expect(viewModel.trendDirection, 'up');
      expect(viewModel.currentPrice, 1200);
      expect(viewModel.lowestPrice, 1000);
      expect(viewModel.highestPrice, 1200);
      expect(viewModel.periodChangePercent, closeTo(20, 0.01));
      expect(viewModel.hasEnoughChartData, isTrue);
      expect(viewModel.hasEnoughDataForAi, isTrue);
      expect(viewModel.aiInsight, 'Prices are rising. Buy soon.');
      expect(viewModel.showAiCard, isTrue);
      verify(
        () => materialRepo.getPriceTrendForMaterial(
          'co-1',
          'OPC Cement',
          months: 1,
        ),
      ).called(1);
    });

    test('premium plan requests 6 months of history', () async {
      when(() => companyRepo.getCompanyById(any()))
          .thenAnswer((_) async => _company(plan: 'premium'));

      await viewModel.loadTrends('co-1', 'OPC Cement', 'all');

      verify(
        () => materialRepo.getPriceTrendForMaterial(
          'co-1',
          'OPC Cement',
          months: 6,
        ),
      ).called(1);
    });

    test('empty supplierUid is treated as aggregate', () async {
      await viewModel.loadTrends('co-1', 'OPC Cement', '');
      verify(
        () => materialRepo.getPriceTrendForMaterial(
          'co-1',
          'OPC Cement',
          months: 1,
        ),
      ).called(1);
    });

    test('missing company defaults to the free-plan window', () async {
      when(() => companyRepo.getCompanyById(any())).thenAnswer((_) async => null);

      await viewModel.loadTrends('co-1', 'OPC Cement', '_');

      verify(
        () => materialRepo.getPriceTrendForMaterial(
          'co-1',
          'OPC Cement',
          months: 1,
        ),
      ).called(1);
    });

    test('loadPriceTrend is an alias of loadTrends', () async {
      await viewModel.loadPriceTrend('co-1', 'OPC Cement', '_');
      verify(
        () => materialRepo.getPriceTrendForMaterial(
          any(),
          any(),
          months: any(named: 'months'),
        ),
      ).called(1);
    });
  });

  group('FieldTrendsViewModel.loadTrends supplier-specific', () {
    test('success loads linked supplier history', () async {
      await viewModel.loadTrends('co-1', 'mat-1', 'sup-1');
      await settleAi();

      expect(viewModel.materialName, 'OPC Cement');
      expect(viewModel.supplierName, 'Cement House');
      verify(() => materialRepo.isSupplierLinkedToCompany('co-1', 'sup-1'))
          .called(1);
      verify(
        () => materialRepo.getSupplierMaterialPriceTrend(
          materialId: 'mat-1',
          supplierUid: 'sup-1',
          companyId: 'co-1',
          months: 1,
        ),
      ).called(1);
    });

    test('unlinked supplier sets error', () async {
      when(() => materialRepo.isSupplierLinkedToCompany(any(), any()))
          .thenAnswer((_) async => false);

      await viewModel.loadTrends('co-1', 'mat-1', 'sup-1');

      expect(
        viewModel.errorMessage,
        'Exception: This supplier is not partnered with your company.',
      );
      expect(viewModel.isLoading, isFalse);
      verifyNever(
        () => materialRepo.getSupplierMaterialPriceTrend(
          materialId: any(named: 'materialId'),
          supplierUid: any(named: 'supplierUid'),
          months: any(named: 'months'),
          companyId: any(named: 'companyId'),
        ),
      );
    });

    test('missing material sets error', () async {
      when(() => materialRepo.getMaterialById(any())).thenAnswer((_) async => null);

      await viewModel.loadTrends('co-1', 'mat-1', 'sup-1');

      expect(viewModel.errorMessage, 'Exception: Material not found');
    });

    test('material belonging to another supplier sets error', () async {
      when(() => materialRepo.getMaterialById(any()))
          .thenAnswer((_) async => _material(supplierId: 'other'));

      await viewModel.loadTrends('co-1', 'mat-1', 'sup-1');

      expect(
        viewModel.errorMessage,
        'Exception: This material does not belong to the selected supplier',
      );
    });
  });

  group('FieldTrendsViewModel trend and AI', () {
    test('down and stable directions', () async {
      when(
        () => materialRepo.getPriceTrendForMaterial(
          any(),
          any(),
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => [
            _point(price: 1200, timestamp: DateTime.utc(2026, 1, 1)),
            _point(id: 'h-2', price: 1000, timestamp: DateTime.utc(2026, 2, 1)),
          ]);
      await viewModel.loadTrends('co-1', 'Cement', '_');
      expect(viewModel.trendDirection, 'down');

      when(
        () => materialRepo.getPriceTrendForMaterial(
          any(),
          any(),
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => [
            _point(price: 1000, timestamp: DateTime.utc(2026, 1, 1)),
            _point(id: 'h-2', price: 1010, timestamp: DateTime.utc(2026, 2, 1)),
          ]);
      await viewModel.loadTrends('co-1', 'Cement', '_');
      expect(viewModel.trendDirection, 'stable');
      expect(viewModel.hasEnoughDataForAi, isFalse);
    });

    test('signed-out users skip AI', () async {
      when(() => auth.currentUser).thenReturn(null);

      await viewModel.loadTrends('co-1', 'Cement', '_');
      await settleAi();

      expect(viewModel.history, hasLength(3));
      expect(viewModel.aiInsight, isNull);
      expect(viewModel.isAiLoading, isFalse);
      verifyNever(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      );
    });

    test('AI failure leaves insight null', () async {
      when(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      ).thenThrow(AppException('unavailable'));

      await viewModel.loadTrends('co-1', 'Cement', '_');
      await settleAi();

      expect(viewModel.aiInsight, isNull);
      expect(viewModel.isAiLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('company lookup failure sets error', () async {
      when(() => companyRepo.getCompanyById(any()))
          .thenThrow(AppException('company missing'));

      await viewModel.loadTrends('co-1', 'Cement', '_');

      expect(viewModel.errorMessage, 'company missing');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('FieldTrendsViewModel.clearError', () {
    test('clears errorMessage', () async {
      when(() => companyRepo.getCompanyById(any()))
          .thenThrow(AppException('boom'));
      await viewModel.loadTrends('co-1', 'Cement', '_');

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
