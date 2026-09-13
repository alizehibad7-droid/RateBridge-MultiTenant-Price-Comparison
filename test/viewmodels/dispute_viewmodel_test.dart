import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/dispute_viewmodel.dart';

import '../mocks/mocks.dart';

DisputeModel _dispute({
  String id = 'disp-1',
  String status = 'open',
}) {
  final now = DateTime.utc(2026, 4, 1);
  return DisputeModel(
    id: id,
    orderId: 'order-1',
    supplierId: 'sup-1',
    companyId: 'co-1',
    raisedByUid: 'field-1',
    raisedByRole: 'field_user',
    raisedByName: 'Ali Raza',
    type: DisputeType.damagedGoods,
    description: 'Bags arrived torn',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dispute = _dispute();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(dispute);
  });

  late MockFirestoreService firestore;
  late MockCloudFunctionService cloudFunctions;
  late MockNotificationService notifications;
  late DisputeViewModel viewModel;

  setUp(() {
    firestore = MockFirestoreService();
    cloudFunctions = MockCloudFunctionService();
    notifications = MockNotificationService();
    viewModel = DisputeViewModel(firestore, cloudFunctions, notifications);

    when(() => firestore.getAdminUserIds())
        .thenAnswer((_) async => ['admin-1', 'admin-2']);
    when(
      () => notifications.notifyDisputeRaised(
        adminUid: any(named: 'adminUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        raisedByRole: any(named: 'raisedByRole'),
      ),
    ).thenAnswer((_) async {});

    when(() => cloudFunctions.callFunction(any(), any()))
        .thenAnswer((_) async => null);
    when(
      () => firestore.createDisputeUpdateJob(
        uid: any(named: 'uid'),
        disputeId: any(named: 'disputeId'),
        status: any(named: 'status'),
        resolutionNotes: any(named: 'resolutionNotes'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyDisputeResolved(
        recipientUid: any(named: 'recipientUid'),
        recipientRole: any(named: 'recipientRole'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        status: any(named: 'status'),
        resolutionNotes: any(named: 'resolutionNotes'),
        disputeId: any(named: 'disputeId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => firestore.createDisputeJob(
        uid: any(named: 'uid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        type: any(named: 'type'),
        description: any(named: 'description'),
        photoUrl: any(named: 'photoUrl'),
      ),
    ).thenAnswer((_) async => 'disp-new');
    when(() => firestore.streamCompanyDisputes(any())).thenAnswer(
      (_) => Stream.value([dispute]),
    );
    when(() => firestore.streamAllDisputes(status: null)).thenAnswer(
      (_) => Stream.value([dispute]),
    );
    when(() => firestore.streamAllDisputes(status: 'resolved')).thenAnswer(
      (_) => Stream.value([_dispute(status: 'resolved')]),
    );
    when(() => firestore.streamRaisedByDisputes(any())).thenAnswer(
      (_) => Stream.value([dispute]),
    );
    when(() => firestore.streamDispute(any())).thenAnswer(
      (_) => Stream.value(dispute),
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('DisputeViewModel.raiseDispute', () {
    test('success toggles loading and calls raiseDispute with expected args',
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

      await viewModel.raiseDispute(
        uid: 'field-1',
        orderId: 'order-1',
        companyId: 'co-1',
        type: DisputeType.damagedGoods,
        description: 'Bags arrived torn',
        photoUrl: 'https://cdn.example/tear.jpg',
      );

      expect(loadingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);

      verify(
        () => firestore.createDisputeJob(
          uid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          type: 'damagedGoods',
          description: 'Bags arrived torn',
          photoUrl: 'https://cdn.example/tear.jpg',
        ),
      ).called(1);
      verifyNever(() => cloudFunctions.callFunction('raiseDispute', any()));
      verify(
        () => notifications.notifyDisputeRaised(
          adminUid: 'admin-1',
          orderId: 'order-1',
          companyId: 'co-1',
          raisedByRole: 'field_user',
        ),
      ).called(1);
      verify(
        () => notifications.notifyDisputeRaised(
          adminUid: 'admin-2',
          orderId: 'order-1',
          companyId: 'co-1',
          raisedByRole: 'field_user',
        ),
      ).called(1);
    });

    test('does not notify admins when raiseDispute fails', () async {
      when(
        () => firestore.createDisputeJob(
          uid: any(named: 'uid'),
          orderId: any(named: 'orderId'),
          companyId: any(named: 'companyId'),
          type: any(named: 'type'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenThrow(AppException('Order already has an open dispute.'));

      await expectLater(
        viewModel.raiseDispute(
          uid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          type: DisputeType.damagedGoods,
          description: 'Bags arrived torn',
        ),
        throwsA(isA<AppException>()),
      );

      verifyNever(
        () => notifications.notifyDisputeRaised(
          adminUid: any(named: 'adminUid'),
          orderId: any(named: 'orderId'),
          companyId: any(named: 'companyId'),
          raisedByRole: any(named: 'raisedByRole'),
        ),
      );
    });

    test('passes a null photoUrl through to the job', () async {
      await viewModel.raiseDispute(
        uid: 'field-1',
        orderId: 'order-1',
        companyId: 'co-1',
        type: DisputeType.nonDelivery,
        description: 'Never arrived',
      );

      verify(
        () => firestore.createDisputeJob(
          uid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          type: 'nonDelivery',
          description: 'Never arrived',
          photoUrl: null,
        ),
      ).called(1);
    });

    test('AppException sets error.message and is rethrown', () async {
      when(
        () => firestore.createDisputeJob(
          uid: any(named: 'uid'),
          orderId: any(named: 'orderId'),
          companyId: any(named: 'companyId'),
          type: any(named: 'type'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenThrow(AppException('Order already has an open dispute.'));

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await expectLater(
        viewModel.raiseDispute(
          uid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          type: DisputeType.other,
          description: 'Issue',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Order already has an open dispute.',
          ),
        ),
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'Order already has an open dispute.');
      expect(notifies, 2);
    });

    test('generic errors wrap toString in AppException and rethrow', () async {
      when(
        () => firestore.createDisputeJob(
          uid: any(named: 'uid'),
          orderId: any(named: 'orderId'),
          companyId: any(named: 'companyId'),
          type: any(named: 'type'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenThrow(Exception('functions 403'));

      await expectLater(
        viewModel.raiseDispute(
          uid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          type: DisputeType.paymentIssue,
          description: 'Overcharged',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Exception: functions 403',
          ),
        ),
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'Exception: functions 403');
    });
  });

  group('DisputeViewModel.resolveDispute', () {
    test('success writes a dispute update job and notifies the raiser', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.resolveDispute(
        'disp-1',
        'resolved',
        'Refund issued',
        adminUid: 'admin-1',
        raisedByUid: 'field-1',
        raisedByRole: 'field_user',
        orderId: 'order-1',
        companyId: 'co-1',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);

      verify(
        () => firestore.createDisputeUpdateJob(
          uid: 'admin-1',
          disputeId: 'disp-1',
          status: 'resolved',
          resolutionNotes: 'Refund issued',
        ),
      ).called(1);
      verify(
        () => notifications.notifyDisputeResolved(
          recipientUid: 'field-1',
          recipientRole: 'field_user',
          orderId: 'order-1',
          companyId: 'co-1',
          status: 'resolved',
          resolutionNotes: 'Refund issued',
          disputeId: 'disp-1',
        ),
      ).called(1);
      verifyNever(() => cloudFunctions.callFunction(any(), any()));
    });

    test('rejected status also notifies the raiser', () async {
      await viewModel.resolveDispute(
        'disp-1',
        'rejected',
        'Not enough evidence',
        adminUid: 'admin-1',
        raisedByUid: 'ceo-1',
        raisedByRole: 'ceo',
        orderId: 'order-1',
        companyId: 'co-1',
      );

      verify(
        () => firestore.createDisputeUpdateJob(
          uid: 'admin-1',
          disputeId: 'disp-1',
          status: 'rejected',
          resolutionNotes: 'Not enough evidence',
        ),
      ).called(1);
      verify(
        () => notifications.notifyDisputeResolved(
          recipientUid: 'ceo-1',
          recipientRole: 'ceo',
          orderId: 'order-1',
          companyId: 'co-1',
          status: 'rejected',
          resolutionNotes: 'Not enough evidence',
          disputeId: 'disp-1',
        ),
      ).called(1);
    });

    test('under_review does not notify the raiser', () async {
      await viewModel.resolveDispute(
        'disp-1',
        'under_review',
        'Looking into it',
        adminUid: 'admin-1',
        raisedByUid: 'field-1',
        raisedByRole: 'field_user',
        orderId: 'order-1',
        companyId: 'co-1',
      );

      verifyNever(
        () => notifications.notifyDisputeResolved(
          recipientUid: any(named: 'recipientUid'),
          recipientRole: any(named: 'recipientRole'),
          orderId: any(named: 'orderId'),
          companyId: any(named: 'companyId'),
          status: any(named: 'status'),
          resolutionNotes: any(named: 'resolutionNotes'),
        ),
      );
    });

    test('AppException sets error.message and is rethrown', () async {
      when(
        () => firestore.createDisputeUpdateJob(
          uid: any(named: 'uid'),
          disputeId: any(named: 'disputeId'),
          status: any(named: 'status'),
          resolutionNotes: any(named: 'resolutionNotes'),
        ),
      ).thenThrow(AppException('Only admins can resolve disputes.'));

      await expectLater(
        viewModel.resolveDispute(
          'disp-1',
          'resolved',
          'Closed',
          adminUid: 'admin-1',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Only admins can resolve disputes.',
          ),
        ),
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'Only admins can resolve disputes.');
    });

    test('generic errors wrap toString in AppException and rethrow', () async {
      when(
        () => firestore.createDisputeUpdateJob(
          uid: any(named: 'uid'),
          disputeId: any(named: 'disputeId'),
          status: any(named: 'status'),
          resolutionNotes: any(named: 'resolutionNotes'),
        ),
      ).thenThrow(Exception('timeout'));

      await expectLater(
        viewModel.resolveDispute(
          'disp-1',
          'under_review',
          'Looking into it',
          adminUid: 'admin-1',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Exception: timeout',
          ),
        ),
      );

      expect(viewModel.error, 'Exception: timeout');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('DisputeViewModel streams', () {
    test('watchCompanyDisputes forwards the company stream', () async {
      final emitted = await viewModel.watchCompanyDisputes('co-1').first;
      expect(emitted, [dispute]);
      verify(() => firestore.streamCompanyDisputes('co-1')).called(1);
    });

    test('watchAllDisputes forwards with a null status', () async {
      final emitted = await viewModel.watchAllDisputes().first;
      expect(emitted, [dispute]);
      verify(() => firestore.streamAllDisputes(status: null)).called(1);
    });

    test('watchAllDisputes forwards a status filter', () async {
      final emitted = await viewModel.watchAllDisputes(status: 'resolved').first;
      expect(emitted.single.status, 'resolved');
      verify(() => firestore.streamAllDisputes(status: 'resolved')).called(1);
    });

    test('watchMyDisputes forwards disputes raised by the user', () async {
      final emitted = await viewModel.watchMyDisputes('field-1').first;
      expect(emitted, [dispute]);
      verify(() => firestore.streamRaisedByDisputes('field-1')).called(1);
    });
  });
}
