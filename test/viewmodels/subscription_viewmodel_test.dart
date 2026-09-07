import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/subscription_model.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/viewmodels/subscription_viewmodel.dart';

import '../mocks/mocks.dart';

class MockXFile extends Mock implements XFile {}

SubscriptionModel _sub({
  String companyId = 'co-1',
  String plan = 'free',
  String status = 'active',
  DateTime? startedAt,
  DateTime? expiresAt,
  bool adminGranted = false,
  String? adminNote,
  List<SubscriptionHistoryEntry> history = const [],
}) {
  return SubscriptionModel(
    companyId: companyId,
    plan: plan,
    status: status,
    startedAt: startedAt ?? DateTime.utc(2026, 4, 1),
    expiresAt: expiresAt,
    adminGranted: adminGranted,
    adminNote: adminNote,
    history: history,
  );
}

void _expectFreePlanLimits(SubscriptionModel sub) {
  expect(sub.planDef.maxFieldUsers, 3);
  expect(sub.planDef.maxSuppliers, 3);
  expect(sub.planDef.maxActiveOrders, 5);
  expect(sub.planDef.aiUnlocked, isFalse);
  expect(sub.canCreateRfq, isFalse);
  expect(sub.aiInsightsEnabled, isFalse);
  expect(sub.hasAccess(PlanId.free), isTrue);
  expect(sub.hasAccess(PlanId.basic), isFalse);
  expect(sub.hasAccess(PlanId.premium), isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fallbackSub = _sub();
  final fallbackHistory = SubscriptionHistoryEntry(
    plan: 'free',
    action: 'purchased',
    date: DateTime.utc(2026, 4, 1),
  );

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(fallbackSub);
    registerFallbackValue(fallbackHistory);
    registerFallbackValue(DateTime.utc(2026, 4, 1));
  });

  late MockFirestoreService firestore;
  late MockCloudFunctionService cloudFunctions;
  late MockStorageService storage;
  late FakeFirebaseFirestore fake;
  late MockXFile screenshotFile;
  late MockNotificationService notifications;
  late SubscriptionViewModel viewModel;

  List<int> uploadedBytes = [];
  String uploadedFolder = '';
  String uploadedFilename = '';
  String? uploadResult = 'https://cdn.example/proof.jpg';
  bool uploadThrows = false;

  SubscriptionModel? storedSub;

  SubscriptionViewModel createViewModel() {
    return SubscriptionViewModel(
      firestore,
      cloudFunctions,
      storage,
      fake,
      ({
        required List<int> bytes,
        required String folder,
        String filename = 'upload.jpg',
      }) async {
        uploadedBytes = bytes;
        uploadedFolder = folder;
        uploadedFilename = filename;
        if (uploadThrows) throw Exception('cdn down');
        return uploadResult;
      },
      notifications,
    );
  }

  Future<void> seedPendingProof({
    String companyId = 'co-1',
    String status = 'pending',
    String type = 'subscription',
  }) {
    return fake.collection('payment_proofs').add({
      'payerId': 'ceo-1',
      'companyId': companyId,
      'payerName': 'Ali CEO',
      'payerRole': 'CEO',
      'amount': 1000.0,
      'method': 'bank_transfer',
      'screenshotUrl': 'https://cdn.example/proof.jpg',
      'status': status,
      'type': type,
      'planId': 'basic',
      'planName': 'Basic',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
    });
  }

  setUp(() {
    firestore = MockFirestoreService();
    cloudFunctions = MockCloudFunctionService();
    storage = MockStorageService();
    fake = FakeFirebaseFirestore();
    screenshotFile = MockXFile();
    notifications = MockNotificationService();
    uploadedBytes = [];
    uploadedFolder = '';
    uploadedFilename = '';
    uploadResult = 'https://cdn.example/proof.jpg';
    uploadThrows = false;
    storedSub = null;

    when(() => screenshotFile.readAsBytes()).thenAnswer(
      (_) async => Uint8List.fromList([1, 2, 3]),
    );
    when(() => firestore.getSubscription(any())).thenAnswer(
      (_) async => storedSub,
    );
    when(() => firestore.saveSubscription(any())).thenAnswer((inv) async {
      storedSub = inv.positionalArguments.first as SubscriptionModel;
    });
    when(() => firestore.updateSubscriptionHistory(any(), any()))
        .thenAnswer((_) async {});
    when(() => firestore.streamSubscription(any())).thenAnswer(
      (_) => Stream.value(storedSub),
    );
    when(() => firestore.getCompany(any())).thenAnswer(
      (_) async => CompanyModel(
        id: 'co-1',
        name: 'Acme Builders',
        registrationNumber: 'REG-1',
        address: 'Lahore',
        status: 'active',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    when(() => firestore.getAdminUserIds())
        .thenAnswer((_) async => ['admin-1']);
    when(
      () => notifications.notifySubscriptionPaymentSubmitted(
        adminUserId: any(named: 'adminUserId'),
        companyName: any(named: 'companyName'),
        companyId: any(named: 'companyId'),
      ),
    ).thenAnswer((_) async {});

    viewModel = createViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('SubscriptionViewModel.loadSubscription', () {
    test('empty companyId returns without loading or notifying', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.loadSubscription('');

      expect(notifies, 0);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.currentSubscription, isNull);
      verifyNever(() => firestore.getSubscription(any()));
    });

    test('success loads subscription, pending proof, and toggles loading',
        () async {
      storedSub = _sub(plan: 'basic', status: 'active');
      await seedPendingProof();

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

      await viewModel.loadSubscription('co-1');

      expect(loadingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);
      expect(viewModel.currentSubscription?.plan, 'basic');
      expect(viewModel.hasPendingPayment, isTrue);
      expect(viewModel.isWaitingVerification, isTrue);
      expect(viewModel.pendingPayment?.companyId, 'co-1');
      expect(viewModel.pendingPayment?.status, 'pending');
      verify(() => firestore.getSubscription('co-1')).called(1);
    });

    test('null subscription falls back to an active Free plan', () async {
      storedSub = null;

      await viewModel.loadSubscription('co-1');

      final sub = viewModel.currentSubscription!;
      expect(sub.companyId, 'co-1');
      expect(sub.plan, 'free');
      expect(sub.status, 'active');
      _expectFreePlanLimits(sub);
      expect(viewModel.hasPendingPayment, isFalse);
      expect(viewModel.isWaitingVerification, isFalse);
    });

    test('ignores payment proofs that are not pending subscription rows',
        () async {
      storedSub = _sub();
      await seedPendingProof(status: 'approved');
      await seedPendingProof(companyId: 'co-other');
      await seedPendingProof(type: 'commission');

      await viewModel.loadSubscription('co-1');

      expect(viewModel.hasPendingPayment, isFalse);
      expect(viewModel.pendingPayment, isNull);
    });

    test('failure sets error and clears loading', () async {
      when(() => firestore.getSubscription(any()))
          .thenThrow(Exception('unavailable'));

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadSubscription('co-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(viewModel.error, contains('Failed to load subscription:'));
      expect(viewModel.error, contains('unavailable'));
      expect(viewModel.currentSubscription, isNull);
    });
  });

  group('SubscriptionViewModel.watchSubscription', () {
    test('empty companyId emits null without hitting Firestore', () async {
      final emitted = await viewModel.watchSubscription('').first;

      expect(emitted, isNull);
      expect(viewModel.currentSubscription, isNull);
      verifyNever(() => firestore.streamSubscription(any()));
    });

    test('null stream value maps to a default Free plan and assigns state',
        () async {
      when(() => firestore.streamSubscription('co-1'))
          .thenAnswer((_) => Stream.value(null));

      final emitted = await viewModel.watchSubscription('co-1').first;

      expect(emitted?.companyId, 'co-1');
      expect(emitted?.plan, 'free');
      expect(emitted?.status, 'active');
      expect(viewModel.currentSubscription, same(emitted));
      _expectFreePlanLimits(emitted!);
    });

    test('existing subscription is assigned as currentSubscription', () async {
      final premium = _sub(plan: 'premium', status: 'active');
      when(() => firestore.streamSubscription('co-1'))
          .thenAnswer((_) => Stream.value(premium));

      final emitted = await viewModel.watchSubscription('co-1').first;

      expect(emitted, same(premium));
      expect(viewModel.currentSubscription, same(premium));
      expect(emitted!.canCreateRfq, isTrue);
      expect(emitted.aiInsightsEnabled, isTrue);
    });

    test('stream errors propagate to the listener', () async {
      when(() => firestore.streamSubscription('co-1'))
          .thenAnswer((_) => Stream.error(Exception('offline')));

      await expectLater(
        viewModel.watchSubscription('co-1').first,
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SubscriptionViewModel.submitPaymentProof', () {
    test('empty companyId sets error, notifies once, and returns false',
        () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      final ok = await viewModel.submitPaymentProof(
        ceoId: 'ceo-1',
        companyId: '',
        ceoName: 'Ali CEO',
        plan: kPlans[1],
        method: 'bank_transfer',
        amount: 1000,
        screenshotFile: screenshotFile,
      );

      expect(ok, isFalse);
      expect(notifies, 1);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'Invalid Company ID. Please log in again.');
      expect(uploadedBytes, isEmpty);
      verifyNever(() => screenshotFile.readAsBytes());
    });

    test('empty screenshot bytes sets a wrapped error and returns false',
        () async {
      when(() => screenshotFile.readAsBytes()).thenAnswer(
        (_) async => Uint8List(0),
      );

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      final ok = await viewModel.submitPaymentProof(
        ceoId: 'ceo-1',
        companyId: 'co-1',
        ceoName: 'Ali CEO',
        plan: kPlans[1],
        method: 'bank_transfer',
        amount: 1000,
        screenshotFile: screenshotFile,
      );

      expect(ok, isFalse);
      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(
        viewModel.error,
        'Failed to submit payment proof: Exception: Selected file is empty.',
      );
      expect(viewModel.hasPendingPayment, isFalse);
    });

    test('null Cloudinary URL sets a wrapped error and returns false',
        () async {
      uploadResult = null;

      final ok = await viewModel.submitPaymentProof(
        ceoId: 'ceo-1',
        companyId: 'co-1',
        ceoName: 'Ali CEO',
        plan: kPlans[1],
        method: 'bank_transfer',
        amount: 1000,
        screenshotFile: screenshotFile,
      );

      expect(ok, isFalse);
      expect(
        viewModel.error,
        'Failed to submit payment proof: Exception: Failed to upload screenshot to Cloudinary.',
      );
      expect(viewModel.successMessage, isNull);
      final proofs = await fake.collection('payment_proofs').get();
      expect(proofs.docs, isEmpty);
    });

    test('upload failure sets error and returns false', () async {
      uploadThrows = true;

      final ok = await viewModel.submitPaymentProof(
        ceoId: 'ceo-1',
        companyId: 'co-1',
        ceoName: 'Ali CEO',
        plan: kPlans[1],
        method: 'bank_transfer',
        amount: 1000,
        screenshotFile: screenshotFile,
      );

      expect(ok, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, contains('Failed to submit payment proof:'));
      expect(viewModel.error, contains('cdn down'));
    });

    test('success uploads bytes, writes proof, and marks waiting verification',
        () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      final ok = await viewModel.submitPaymentProof(
        ceoId: 'ceo-1',
        companyId: 'co-1',
        ceoName: 'Ali CEO',
        plan: kPlans[1],
        method: 'bank_transfer',
        amount: 1000,
        screenshotFile: screenshotFile,
      );

      expect(ok, isTrue);
      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(viewModel.error, isNull);
      expect(
        viewModel.successMessage,
        'Payment proof submitted. Plan will be active after Admin verification.',
      );
      expect(uploadedBytes, [1, 2, 3]);
      expect(uploadedFolder, 'payment_proofs/co-1');
      expect(uploadedFilename, endsWith('.jpg'));
      expect(viewModel.hasPendingPayment, isTrue);
      expect(viewModel.isWaitingVerification, isTrue);
      expect(viewModel.pendingPayment?.screenshotUrl, uploadResult);
      expect(viewModel.pendingPayment?.planId, 'basic');

      final proofs = await fake.collection('payment_proofs').get();
      expect(proofs.docs, hasLength(1));
      final data = proofs.docs.first.data();
      expect(data['payerId'], 'ceo-1');
      expect(data['companyId'], 'co-1');
      expect(data['payerName'], 'Ali CEO');
      expect(data['payerRole'], 'CEO');
      expect(data['amount'], 1000.0);
      expect(data['method'], 'bank_transfer');
      verify(
        () => notifications.notifySubscriptionPaymentSubmitted(
          adminUserId: 'admin-1',
          companyName: 'Acme Builders',
          companyId: 'co-1',
        ),
      ).called(1);
      expect(data['status'], 'pending');
      expect(data['type'], 'subscription');
      expect(data['planId'], 'basic');
      expect(data['planName'], 'Basic');
      expect(data['screenshotUrl'], uploadResult);
    });
  });

  group('SubscriptionViewModel.activateSubscription', () {
    test('purchased Basic plan writes history, expiry, and company limits',
        () async {
      await viewModel.activateSubscription(
        companyId: 'co-1',
        plan: kPlans[1],
        adminGranted: false,
      );

      final saved = verify(() => firestore.saveSubscription(captureAny()))
          .captured
          .single as SubscriptionModel;
      expect(saved.companyId, 'co-1');
      expect(saved.plan, 'basic');
      expect(saved.status, 'active');
      expect(saved.adminGranted, isFalse);
      expect(saved.expiresAt, isNotNull);
      expect(saved.expiresAt!.isAfter(DateTime.now()), isTrue);
      expect(
        saved.expiresAt!.isBefore(DateTime.now().add(const Duration(days: 31))),
        isTrue,
      );

      final history = verify(
        () => firestore.updateSubscriptionHistory('co-1', captureAny()),
      ).captured.single as SubscriptionHistoryEntry;
      expect(history.plan, 'basic');
      expect(history.action, 'purchased');
      expect(history.amountPaid, kPlans[1].priceRs);
      expect(history.note, isNull);

      final company = await fake.collection('companies').doc('co-1').get();
      expect(company.data()?['plan'], 'basic');
      expect(company.data()?['aiEnabled'], isTrue);
      expect(company.data()?['status'], 'active');
      expect(company.data()?['planExpiry'], isA<Timestamp>());

      final current = viewModel.currentSubscription!;
      expect(current.plan, 'basic');
      expect(current.planDef.maxFieldUsers, 15);
      expect(current.planDef.maxSuppliers, 15);
      expect(current.planDef.maxActiveOrders, -1);
      expect(current.hasAccess(PlanId.basic), isTrue);
      expect(current.hasAccess(PlanId.premium), isFalse);
      expect(current.canCreateRfq, isFalse);
      expect(current.aiInsightsEnabled, isTrue);
    });

    test('uses explicit amountPaid and Premium feature access', () async {
      await viewModel.activateSubscription(
        companyId: 'co-1',
        plan: kPlans[2],
        adminGranted: false,
        amountPaid: 4500,
      );

      final history = verify(
        () => firestore.updateSubscriptionHistory('co-1', captureAny()),
      ).captured.single as SubscriptionHistoryEntry;
      expect(history.action, 'purchased');
      expect(history.amountPaid, 4500);

      final current = viewModel.currentSubscription!;
      expect(current.plan, 'premium');
      expect(current.planDef.maxFieldUsers, -1);
      expect(current.planDef.maxSuppliers, -1);
      expect(current.canCreateRfq, isTrue);
      expect(current.hasAccess(PlanId.premium), isTrue);
      expect(current.aiInsightsEnabled, isTrue);
    });

    test('Free plan activation writes a null expiry and locked AI', () async {
      await viewModel.activateSubscription(
        companyId: 'co-1',
        plan: kPlans.first,
        adminGranted: false,
      );

      final saved = verify(() => firestore.saveSubscription(captureAny()))
          .captured
          .single as SubscriptionModel;
      expect(saved.plan, 'free');
      expect(saved.expiresAt, isNull);

      final company = await fake.collection('companies').doc('co-1').get();
      expect(company.data()?['plan'], 'free');
      expect(company.data()?['planExpiry'], isNull);
      expect(company.data()?['aiEnabled'], isFalse);
      _expectFreePlanLimits(viewModel.currentSubscription!);
    });

    test('save failure propagates because activateSubscription has no catch',
        () async {
      when(() => firestore.saveSubscription(any()))
          .thenThrow(Exception('write denied'));

      await expectLater(
        viewModel.activateSubscription(
          companyId: 'co-1',
          plan: kPlans[1],
          adminGranted: false,
        ),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => firestore.updateSubscriptionHistory(any(), any()));
    });
  });

  group('SubscriptionViewModel.adminGrantPlan', () {
    test('success grants Premium, records admin history, and sets message',
        () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.adminGrantPlan(
        companyId: 'co-1',
        plan: kPlans[2],
        note: '  Partner perk  ',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.successMessage, 'Premium plan granted to company.');
      expect(notifies, 4);

      final saved = verify(() => firestore.saveSubscription(captureAny()))
          .captured
          .single as SubscriptionModel;
      expect(saved.plan, 'premium');
      expect(saved.status, 'admin_granted');
      expect(saved.adminGranted, isTrue);
      expect(saved.adminNote, 'Partner perk');

      final history = verify(
        () => firestore.updateSubscriptionHistory('co-1', captureAny()),
      ).captured.single as SubscriptionHistoryEntry;
      expect(history.action, 'admin_granted');
      expect(history.amountPaid, 0);
      expect(history.note, 'Partner perk');

      final company = await fake.collection('companies').doc('co-1').get();
      expect(company.data()?['plan'], 'premium');
      expect(company.data()?['aiEnabled'], isTrue);

      final current = viewModel.currentSubscription!;
      expect(current.canCreateRfq, isTrue);
      expect(current.planDef.maxFieldUsers, -1);
    });

    test('blank note is stored as null', () async {
      await viewModel.adminGrantPlan(
        companyId: 'co-1',
        plan: kPlans[1],
        note: '   ',
      );

      final saved = verify(() => firestore.saveSubscription(captureAny()))
          .captured
          .single as SubscriptionModel;
      expect(saved.adminNote, isNull);
    });

    test('failure sets error and clears loading', () async {
      when(() => firestore.saveSubscription(any()))
          .thenThrow(Exception('grant denied'));

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.adminGrantPlan(
        companyId: 'co-1',
        plan: kPlans[2],
        note: 'VIP',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(viewModel.error, contains('Failed to grant plan:'));
      expect(viewModel.error, contains('grant denied'));
      expect(viewModel.successMessage, isNull);
    });
  });

  group('SubscriptionViewModel.cancelSubscription', () {
    test('success reverts to Free limits and records cancelled history',
        () async {
      storedSub = _sub(plan: 'premium', status: 'active');
      await viewModel.loadSubscription('co-1');

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.cancelSubscription('co-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(
        viewModel.successMessage,
        'Subscription cancelled. You are now on the Free plan.',
      );
      expect(notifies, 4);

      final saved = verify(() => firestore.saveSubscription(captureAny()))
          .captured
          .last as SubscriptionModel;
      expect(saved.plan, 'free');
      expect(saved.status, 'active');
      expect(saved.expiresAt, isNull);

      final history = verify(
        () => firestore.updateSubscriptionHistory('co-1', captureAny()),
      ).captured.single as SubscriptionHistoryEntry;
      expect(history.plan, 'premium');
      expect(history.action, 'cancelled');
      expect(history.note, 'Subscription cancelled by user.');

      final company = await fake.collection('companies').doc('co-1').get();
      expect(company.data()?['plan'], 'free');
      expect(company.data()?['planExpiry'], isNull);
      expect(company.data()?['aiEnabled'], isFalse);

      _expectFreePlanLimits(viewModel.currentSubscription!);
    });

    test('uses unknown plan in history when nothing was loaded', () async {
      await viewModel.cancelSubscription('co-1');

      final history = verify(
        () => firestore.updateSubscriptionHistory('co-1', captureAny()),
      ).captured.single as SubscriptionHistoryEntry;
      expect(history.plan, 'unknown');
      expect(history.action, 'cancelled');
    });

    test('failure sets error and clears loading', () async {
      when(() => firestore.saveSubscription(any()))
          .thenThrow(Exception('cancel denied'));

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.cancelSubscription('co-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(viewModel.error, contains('Failed to cancel subscription:'));
      expect(viewModel.error, contains('cancel denied'));
      expect(viewModel.successMessage, isNull);
    });
  });

  group('SubscriptionViewModel.clearMessages', () {
    test('clears error and successMessage and notifies listeners', () async {
      viewModel.error = 'boom';
      viewModel.successMessage = 'ok';

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.clearMessages();

      expect(viewModel.error, isNull);
      expect(viewModel.successMessage, isNull);
      expect(notifies, 1);
    });
  });

  group('SubscriptionViewModel plan-limit checks', () {
    test('Basic plan unlocks AI but not RFQ', () async {
      storedSub = _sub(plan: 'basic', status: 'active');
      await viewModel.loadSubscription('co-1');

      final sub = viewModel.currentSubscription!;
      expect(sub.planDef.maxFieldUsers, 15);
      expect(sub.planDef.maxSuppliers, 15);
      expect(sub.planDef.maxActiveOrders, -1);
      expect(sub.planDef.priceHistoryDays, -1);
      expect(sub.hasAccess(PlanId.free), isTrue);
      expect(sub.hasAccess(PlanId.basic), isTrue);
      expect(sub.hasAccess(PlanId.premium), isFalse);
      expect(sub.canCreateRfq, isFalse);
      expect(sub.aiInsightsEnabled, isTrue);
    });

    test('Premium plan unlocks RFQ and unlimited seats', () async {
      storedSub = _sub(plan: 'premium', status: 'admin_granted');
      await viewModel.loadSubscription('co-1');

      final sub = viewModel.currentSubscription!;
      expect(sub.isActive, isTrue);
      expect(sub.planDef.maxFieldUsers, -1);
      expect(sub.planDef.maxSuppliers, -1);
      expect(sub.planDef.maxActiveOrders, -1);
      expect(sub.hasAccess(PlanId.premium), isTrue);
      expect(sub.canCreateRfq, isTrue);
      expect(sub.aiInsightsEnabled, isTrue);
    });

    test('expired Premium falls back to Free effective limits', () async {
      storedSub = _sub(
        plan: 'premium',
        status: 'active',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await viewModel.loadSubscription('co-1');

      final sub = viewModel.currentSubscription!;
      expect(sub.plan, 'premium');
      expect(sub.planDef.id, PlanId.premium);
      expect(sub.isActive, isFalse);
      expect(sub.effectivePlanDef.id, PlanId.free);
      expect(sub.canCreateRfq, isFalse);
      expect(sub.aiInsightsEnabled, isFalse);
      expect(sub.hasAccess(PlanId.premium), isFalse);
    });

    test('history getter reflects loaded subscription history', () async {
      storedSub = _sub(
        plan: 'basic',
        history: [
          SubscriptionHistoryEntry(
            plan: 'basic',
            action: 'purchased',
            date: DateTime.utc(2026, 4, 1),
            amountPaid: 1000,
          ),
        ],
      );

      await viewModel.loadSubscription('co-1');

      expect(viewModel.history, hasLength(1));
      expect(viewModel.history.first.action, 'purchased');
      expect(viewModel.history.first.amountPaid, 1000);
    });
  });
}
