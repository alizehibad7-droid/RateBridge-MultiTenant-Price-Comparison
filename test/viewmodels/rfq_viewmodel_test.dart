import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/rfq_bid_model.dart';
import 'package:ratebridge/models/rfq_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/rfq_viewmodel.dart';

import '../mocks/mocks.dart';

RfqModel _rfq({
  String id = 'rfq-1',
  String status = 'open',
}) {
  return RfqModel(
    id: id,
    companyId: 'co-1',
    companyName: 'Acme Builders',
    category: 'Cement',
    materialDescription: 'OPC 53, 500 bags',
    quantity: 500,
    unit: 'bag',
    city: 'Lahore',
    requiredByDate: DateTime.utc(2026, 5, 1),
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

RfqBidModel _bid({
  String id = 'bid-1',
  String supplierId = 'sup-1',
  double bidPrice = 1180,
}) {
  return RfqBidModel(
    id: id,
    rfqId: 'rfq-1',
    supplierId: supplierId,
    supplierName: 'Cement House',
    bidPrice: bidPrice,
    estimatedDeliveryTime: '3 days',
    note: 'Ready stock',
    createdAt: DateTime.utc(2026, 4, 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rfq = _rfq();
  final bid = _bid();
  final requiredBy = DateTime.utc(2026, 5, 15);

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(requiredBy);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(rfq);
    registerFallbackValue(bid);
  });

  late MockFirestoreService firestore;
  late MockCloudFunctionService cloudFunctions;
  late MockNotificationService notifications;
  late RfqViewModel viewModel;

  SupplierModel matchingSupplier() {
    return SupplierModel(
      id: 'sup-match',
      name: 'Cement House',
      email: 'c@example.com',
      materialType: 'Cement',
      contact: '0300',
      status: 'active',
      rating: 4,
      activeContracts: 1,
      contractValue: 1,
      leadTimeDays: 2,
      city: 'Lahore',
      declaredCategories: const ['Cement'],
      deliveryCoverageAreas: const ['Lahore'],
    );
  }

  SupplierModel otherCitySupplier() {
    return matchingSupplier().copyWith(
      id: 'sup-other-city',
      city: 'Karachi',
      deliveryCoverageAreas: const ['Karachi'],
    );
  }

  setUp(() {
    firestore = MockFirestoreService();
    cloudFunctions = MockCloudFunctionService();
    notifications = MockNotificationService();
    viewModel = RfqViewModel(firestore, cloudFunctions, notifications);

    when(
      () => firestore.createRfqJob(
        uid: any(named: 'uid'),
        companyId: any(named: 'companyId'),
        companyName: any(named: 'companyName'),
        category: any(named: 'category'),
        materialDescription: any(named: 'materialDescription'),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        city: any(named: 'city'),
        requiredByDate: any(named: 'requiredByDate'),
      ),
    ).thenAnswer((_) async => 'job-1');
    when(
      () => firestore.createRfqAwardJob(
        uid: any(named: 'uid'),
        rfqId: any(named: 'rfqId'),
        bidId: any(named: 'bidId'),
      ),
    ).thenAnswer((_) async {});
    when(() => cloudFunctions.callFunction(any(), any()))
        .thenAnswer((_) async => null);
    when(() => firestore.streamCompanyRfqs(any())).thenAnswer(
      (_) => Stream.value([rfq]),
    );
    when(() => firestore.streamRfq(any())).thenAnswer(
      (_) => Stream.value(rfq),
    );
    when(() => firestore.streamRfqBids(any())).thenAnswer(
      (_) => Stream.value([bid]),
    );
    when(() => firestore.streamSuppliers()).thenAnswer(
      (_) => Stream.value([matchingSupplier(), otherCitySupplier()]),
    );
    when(() => firestore.getRfqBids(any())).thenAnswer(
      (_) async => [
        bid,
        _bid(id: 'bid-2', supplierId: 'sup-2'),
      ],
    );
    when(
      () => notifications.notifyNewRfqAvailable(
        supplierId: any(named: 'supplierId'),
        rfqId: any(named: 'rfqId'),
        category: any(named: 'category'),
        companyName: any(named: 'companyName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyRfqClosed(
        supplierId: any(named: 'supplierId'),
        rfqId: any(named: 'rfqId'),
        category: any(named: 'category'),
        companyName: any(named: 'companyName'),
        awarded: any(named: 'awarded'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('RfqViewModel.createRfq', () {
    test('success toggles loading and publishes the job with expected args',
        () async {
      var notifies = 0;
      var loadingOnFirst = false;
      String? errorOnFirst;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) {
          loadingOnFirst = viewModel.isLoading;
          errorOnFirst = viewModel.error;
        }
      });

      await viewModel.createRfq(
        uid: 'ceo-1',
        companyId: 'co-1',
        companyName: 'Acme Builders',
        category: 'Cement',
        materialDescription: 'OPC 53, 500 bags',
        quantity: 500,
        unit: 'bag',
        city: 'Lahore',
        requiredByDate: requiredBy,
      );

      expect(loadingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);

      verify(
        () => firestore.createRfqJob(
          uid: 'ceo-1',
          companyId: 'co-1',
          companyName: 'Acme Builders',
          category: 'Cement',
          materialDescription: 'OPC 53, 500 bags',
          quantity: 500,
          unit: 'bag',
          city: 'Lahore',
          requiredByDate: requiredBy,
        ),
      ).called(1);
      verifyNever(() => cloudFunctions.callFunction(any(), any()));
      verify(
        () => notifications.notifyNewRfqAvailable(
          supplierId: 'sup-match',
          rfqId: 'job-1',
          category: 'Cement',
          companyName: 'Acme Builders',
        ),
      ).called(1);
      verify(
        () => notifications.notifyNewRfqAvailable(
          supplierId: 'sup-other-city',
          rfqId: 'job-1',
          category: 'Cement',
          companyName: 'Acme Builders',
        ),
      ).called(1);
    });

    test('AppException sets error to the public message', () async {
      when(
        () => firestore.createRfqJob(
          uid: any(named: 'uid'),
          companyId: any(named: 'companyId'),
          companyName: any(named: 'companyName'),
          category: any(named: 'category'),
          materialDescription: any(named: 'materialDescription'),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          city: any(named: 'city'),
          requiredByDate: any(named: 'requiredByDate'),
        ),
      ).thenThrow(AppException('Publishing timed out.', 'deadline-exceeded'));

      await viewModel.createRfq(
        uid: 'ceo-1',
        companyId: 'co-1',
        companyName: 'Acme Builders',
        category: 'Cement',
        materialDescription: 'OPC 53',
        quantity: 10,
        unit: 'bag',
        city: 'Lahore',
        requiredByDate: requiredBy,
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'Publishing timed out.');
    });

    test('generic failure stores e.toString()', () async {
      when(
        () => firestore.createRfqJob(
          uid: any(named: 'uid'),
          companyId: any(named: 'companyId'),
          companyName: any(named: 'companyName'),
          category: any(named: 'category'),
          materialDescription: any(named: 'materialDescription'),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          city: any(named: 'city'),
          requiredByDate: any(named: 'requiredByDate'),
        ),
      ).thenThrow(Exception('network down'));

      await viewModel.createRfq(
        uid: 'ceo-1',
        companyId: 'co-1',
        companyName: 'Acme Builders',
        category: 'Cement',
        materialDescription: 'OPC 53',
        quantity: 10,
        unit: 'bag',
        city: 'Lahore',
        requiredByDate: requiredBy,
      );

      expect(viewModel.error, 'Exception: network down');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('RfqViewModel streams', () {
    test('watchCompanyRfqs forwards the company RFQ stream', () async {
      final emitted = await viewModel.watchCompanyRfqs('co-1').first;
      expect(emitted, [rfq]);
      verify(() => firestore.streamCompanyRfqs('co-1')).called(1);
    });

    test('watchRfq forwards a single RFQ stream', () async {
      expect(await viewModel.watchRfq('rfq-1').first, same(rfq));
      verify(() => firestore.streamRfq('rfq-1')).called(1);
    });

    test('watchRfqBids forwards bids for the RFQ', () async {
      final emitted = await viewModel.watchRfqBids('rfq-1').first;
      expect(emitted, [bid]);
      verify(() => firestore.streamRfqBids('rfq-1')).called(1);
    });
  });

  group('RfqViewModel.awardRfq (bid acceptance)', () {
    test('success writes an award job with rfq, bid, and CEO ids', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.awardRfq(rfq: rfq, bid: bid, ceoUid: 'ceo-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);

      verify(
        () => firestore.createRfqAwardJob(
          uid: 'ceo-1',
          rfqId: 'rfq-1',
          bidId: 'bid-1',
        ),
      ).called(1);
      verify(
        () => notifications.notifyRfqClosed(
          supplierId: 'sup-1',
          rfqId: 'rfq-1',
          category: 'Cement',
          companyName: 'Acme Builders',
          awarded: true,
        ),
      ).called(1);
      verify(
        () => notifications.notifyRfqClosed(
          supplierId: 'sup-2',
          rfqId: 'rfq-1',
          category: 'Cement',
          companyName: 'Acme Builders',
          awarded: false,
        ),
      ).called(1);
    });

    test('AppException sets error to the public message', () async {
      when(
        () => firestore.createRfqAwardJob(
          uid: any(named: 'uid'),
          rfqId: any(named: 'rfqId'),
          bidId: any(named: 'bidId'),
        ),
      ).thenThrow(
        AppException('This quote request is already awarded.'),
      );

      await viewModel.awardRfq(rfq: rfq, bid: bid, ceoUid: 'ceo-1');

      expect(viewModel.error, 'This quote request is already awarded.');
      expect(viewModel.isLoading, isFalse);
    });

    test('generic failure stores e.toString()', () async {
      when(
        () => firestore.createRfqAwardJob(
          uid: any(named: 'uid'),
          rfqId: any(named: 'rfqId'),
          bidId: any(named: 'bidId'),
        ),
      ).thenThrow(
        Exception('functions 403'),
      );

      await viewModel.awardRfq(rfq: rfq, bid: bid, ceoUid: 'ceo-1');

      expect(viewModel.error, 'Exception: functions 403');
      expect(viewModel.isLoading, isFalse);
    });
  });

  test('clearError clears a previous failure and notifies', () async {
    when(
      () => firestore.createRfqAwardJob(
        uid: any(named: 'uid'),
        rfqId: any(named: 'rfqId'),
        bidId: any(named: 'bidId'),
      ),
    ).thenThrow(
      AppException('award failed'),
    );
    await viewModel.awardRfq(rfq: rfq, bid: bid, ceoUid: 'ceo-1');
    expect(viewModel.error, isNotNull);

    var notifies = 0;
    viewModel.addListener(() => notifies++);
    viewModel.clearError();

    expect(viewModel.error, isNull);
    expect(notifies, 1);
  });
}
