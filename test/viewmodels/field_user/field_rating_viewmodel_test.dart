import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_rating_viewmodel.dart';

import '../../mocks/mocks.dart';

RatingModel _rating({String userId = 'field-1'}) {
  return RatingModel(
    id: 'rating-1',
    orderId: 'order-1',
    supplierUid: 'sup-1',
    userId: userId,
    userName: 'Ali Raza',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    rating: 4.5,
    comment: 'On time',
    createdAt: DateTime.utc(2026, 4, 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rating = _rating();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(rating);
  });

  late MockOrderRepository orderRepo;
  late MockNotificationService notifications;
  late FieldRatingViewModel viewModel;

  setUp(() {
    orderRepo = MockOrderRepository();
    notifications = MockNotificationService();
    when(() => orderRepo.hasRatingForOrderByUser(any(), any()))
        .thenAnswer((_) async => false);
    when(() => orderRepo.submitRating(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => orderRepo.updateSupplierAvgRating(any()))
        .thenAnswer((_) async {});
    when(
      () => notifications.notifySupplierNewRating(
        supplierId: any(named: 'supplierId'),
        rating: any(named: 'rating'),
        fieldUserName: any(named: 'fieldUserName'),
        materialName: any(named: 'materialName'),
        orderId: any(named: 'orderId'),
        comment: any(named: 'comment'),
      ),
    ).thenAnswer((_) async {});
    viewModel = FieldRatingViewModel(orderRepo, notifications);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('FieldRatingViewModel.hasUserRatedOrder', () {
    test('success toggles checking and returns the repo value', () async {
      when(() => orderRepo.hasRatingForOrderByUser('order-1', 'field-1'))
          .thenAnswer((_) async => true);

      var notifies = 0;
      var checkingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) checkingOnFirst = viewModel.isCheckingExisting;
      });

      expect(await viewModel.hasUserRatedOrder('order-1', 'field-1'), isTrue);
      expect(checkingOnFirst, isTrue);
      expect(viewModel.isCheckingExisting, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(notifies, 2);
    });

    test('failure sets error and returns false', () async {
      when(() => orderRepo.hasRatingForOrderByUser(any(), any()))
          .thenThrow(AppException('lookup failed'));

      expect(await viewModel.hasUserRatedOrder('order-1', 'field-1'), isFalse);
      expect(viewModel.isCheckingExisting, isFalse);
      expect(viewModel.errorMessage, 'lookup failed');
    });
  });

  group('FieldRatingViewModel.submitRating', () {
    test('success submits then updates supplier average', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      expect(
        await viewModel.submitRating(
          orderId: 'order-1',
          companyId: 'co-1',
          rating: rating,
        ),
        FieldRatingSubmitResult.success,
      );
      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      verify(() => orderRepo.submitRating('order-1', 'co-1', rating)).called(1);
      verify(() => orderRepo.updateSupplierAvgRating('sup-1')).called(1);
      verify(
        () => notifications.notifySupplierNewRating(
          supplierId: 'sup-1',
          rating: 4.5,
          fieldUserName: 'Ali Raza',
          materialName: 'OPC Cement',
          orderId: 'order-1',
          comment: 'On time',
        ),
      ).called(1);
    });

    test('alreadyRated skips submit', () async {
      when(() => orderRepo.hasRatingForOrderByUser(any(), any()))
          .thenAnswer((_) async => true);

      expect(
        await viewModel.submitRating(
          orderId: 'order-1',
          companyId: 'co-1',
          rating: rating,
        ),
        FieldRatingSubmitResult.alreadyRated,
      );
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => orderRepo.submitRating(any(), any(), any()));
      verifyNever(
        () => notifications.notifySupplierNewRating(
          supplierId: any(named: 'supplierId'),
          rating: any(named: 'rating'),
          fieldUserName: any(named: 'fieldUserName'),
          materialName: any(named: 'materialName'),
          orderId: any(named: 'orderId'),
          comment: any(named: 'comment'),
        ),
      );
    });

    test('avg-rating failure still counts as success', () async {
      when(() => orderRepo.updateSupplierAvgRating(any()))
          .thenThrow(Exception('avg failed'));

      expect(
        await viewModel.submitRating(
          orderId: 'order-1',
          companyId: 'co-1',
          rating: rating,
        ),
        FieldRatingSubmitResult.success,
      );
      expect(viewModel.errorMessage, isNull);
    });

    test('submit failure returns failure and sets error', () async {
      when(() => orderRepo.submitRating(any(), any(), any()))
          .thenThrow(AppException('write denied'));

      expect(
        await viewModel.submitRating(
          orderId: 'order-1',
          companyId: 'co-1',
          rating: rating,
        ),
        FieldRatingSubmitResult.failure,
      );
      expect(viewModel.errorMessage, 'write denied');
      expect(viewModel.isLoading, isFalse);
      verifyNever(
        () => notifications.notifySupplierNewRating(
          supplierId: any(named: 'supplierId'),
          rating: any(named: 'rating'),
          fieldUserName: any(named: 'fieldUserName'),
          materialName: any(named: 'materialName'),
          orderId: any(named: 'orderId'),
          comment: any(named: 'comment'),
        ),
      );
    });
  });

  group('FieldRatingViewModel.clearError', () {
    test('clears errorMessage', () async {
      when(() => orderRepo.hasRatingForOrderByUser(any(), any()))
          .thenThrow(AppException('boom'));
      await viewModel.hasUserRatedOrder('order-1', 'field-1');

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
