import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/viewmodels/order_viewmodel.dart';

import '../mocks/mocks.dart';

OrderModel _order({
  String orderId = 'order-1',
  double quantity = 10,
  double unitPrice = 150,
}) {
  final createdAt = DateTime.utc(2026, 3, 1);
  return OrderModel(
    orderId: orderId,
    companyId: 'company-1',
    fieldUserUid: 'field-1',
    supplierId: 'supplier-1',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    supplierName: 'Steel Co',
    fieldUserName: 'Ali Raza',
    quantity: quantity,
    unit: 'bag',
    unitPrice: unitPrice,
    totalAmount: quantity * unitPrice,
    commissionAmount: 30,
    supplierEarning: 1470,
    deliveryAddress: 'Site 12, Lahore',
    status: 'pending',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

RatingModel _rating() {
  return RatingModel(
    id: 'rating-1',
    orderId: 'order-1',
    supplierUid: 'supplier-1',
    userId: 'field-1',
    userName: 'Ali Raza',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    rating: 4.5,
    comment: 'On time',
    createdAt: DateTime.utc(2026, 3, 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final order = _order();
  final rating = _rating();

  setUpAll(() {
    registerFallbackValue(order);
    registerFallbackValue(rating);
    registerFallbackValue('');
  });

  late MockOrderRepository orderRepo;
  late MockTransactionRepository transactionRepo;
  late MockCloudFunctionService cloudFunctions;
  late OrderViewModel viewModel;

  setUp(() {
    orderRepo = MockOrderRepository();
    transactionRepo = MockTransactionRepository();
    cloudFunctions = MockCloudFunctionService();
    viewModel = OrderViewModel(orderRepo, transactionRepo, cloudFunctions);

    when(() => orderRepo.submitOrder(any())).thenAnswer((_) async {});
    when(() => orderRepo.submitRating(any(), any(), any())).thenAnswer((_) async {});
    when(() => orderRepo.updateSupplierAvgRating(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('OrderViewModel', () {
    test('updateQuantity sets calculatedTotal to qty * unitPrice', () {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      expect(viewModel.calculatedTotal, 0);

      viewModel.updateQuantity(8, 125.5);

      expect(viewModel.calculatedTotal, 8 * 125.5);
      expect(notifies, 1);

      viewModel.updateQuantity(0, 99);
      expect(viewModel.calculatedTotal, 0);
      expect(notifies, 2);
    });

    test(
      'placeOrder success: loading toggles, isOrderPlaced becomes true, error stays null',
      () async {
        var notifies = 0;
        var loadingOnFirstNotify = false;
        viewModel.addListener(() {
          notifies++;
          if (notifies == 1) {
            loadingOnFirstNotify = viewModel.isLoading;
            expect(viewModel.isOrderPlaced, isFalse);
            expect(viewModel.error, isNull);
          }
        });

        await viewModel.placeOrder(order);

        expect(loadingOnFirstNotify, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.isOrderPlaced, isTrue);
        expect(viewModel.error, isNull);
        expect(notifies, 2);

        verify(() => orderRepo.submitOrder(order)).called(1);
      },
    );

    test(
      'placeOrder failure: error is set, isOrderPlaced stays false, loading returns false',
      () async {
        when(() => orderRepo.submitOrder(any())).thenThrow(
          Exception('warehouse unavailable'),
        );

        var notifies = 0;
        var loadingOnFirstNotify = false;
        viewModel.addListener(() {
          notifies++;
          if (notifies == 1) {
            loadingOnFirstNotify = viewModel.isLoading;
            expect(viewModel.isOrderPlaced, isFalse);
            expect(viewModel.error, isNull);
          }
        });

        await viewModel.placeOrder(order);

        expect(loadingOnFirstNotify, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.isOrderPlaced, isFalse);
        expect(viewModel.error, 'Exception: warehouse unavailable');
        expect(notifies, 2);

        verify(() => orderRepo.submitOrder(order)).called(1);
      },
    );

    test('submitOrder is called exactly once with the given OrderModel', () async {
      await viewModel.placeOrder(order);

      verify(() => orderRepo.submitOrder(order)).called(1);
      verifyNoMoreInteractions(orderRepo);
    });

    test('hasExistingRating is null until rating logic assigns it', () {
      expect(viewModel.hasExistingRating, isNull);
    });

    test(
      'submitRating success: loading toggles, isRatingSubmitted becomes true',
      () async {
        expect(viewModel.hasExistingRating, isNull);

        var notifies = 0;
        var loadingOnFirstNotify = false;
        var submittedOnFirstNotify = true;
        viewModel.addListener(() {
          notifies++;
          if (notifies == 1) {
            loadingOnFirstNotify = viewModel.isLoading;
            submittedOnFirstNotify = viewModel.isRatingSubmitted;
            expect(viewModel.error, isNull);
          }
        });

        await viewModel.submitRating('order-1', 'company-1', rating);

        expect(loadingOnFirstNotify, isTrue);
        expect(submittedOnFirstNotify, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.isRatingSubmitted, isTrue);
        expect(viewModel.error, isNull);
        expect(viewModel.hasExistingRating, isNull);
        expect(notifies, 2);

        verify(() => orderRepo.submitRating('order-1', 'company-1', rating))
            .called(1);
        verify(() => orderRepo.updateSupplierAvgRating(rating.supplierUid))
            .called(1);
      },
    );

    test(
      'submitRating failure: error is set, isRatingSubmitted stays false',
      () async {
        when(() => orderRepo.submitRating(any(), any(), any())).thenThrow(
          Exception('rating write failed'),
        );

        var notifies = 0;
        viewModel.addListener(() => notifies++);

        await viewModel.submitRating('order-1', 'company-1', rating);

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.isRatingSubmitted, isFalse);
        expect(viewModel.error, 'Exception: rating write failed');
        expect(viewModel.hasExistingRating, isNull);
        expect(notifies, 2);

        verify(() => orderRepo.submitRating('order-1', 'company-1', rating))
            .called(1);
        verifyNever(() => orderRepo.updateSupplierAvgRating(any()));
      },
    );
  });
}
