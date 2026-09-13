import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/payment_proof_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/viewmodels/admin_viewmodel.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';

import '../mocks/mocks.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

UserModel _user({
  String uid = 'ceo-1',
  String name = 'Ali CEO',
  String role = 'CEO',
  String companyId = 'co-1',
  String status = 'pending',
  bool approved = false,
  String? rejectionReason,
}) {
  return UserModel(
    uid: uid,
    email: '$uid@co.test',
    name: name,
    role: role,
    companyId: companyId,
    phone: '03001234567',
    city: 'Lahore',
    status: status,
    approved: approved,
    rejectionReason: rejectionReason,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

CompanyModel _company({
  String id = 'co-1',
  String name = 'Acme Builders',
  String status = 'pending',
  String? inviteCode,
  String plan = 'free',
  bool aiEnabled = false,
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: 'Lahore',
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    inviteCode: inviteCode,
    plan: plan,
    aiEnabled: aiEnabled,
    ceoUid: 'ceo-1',
  );
}

PaymentProofModel _proof({
  String id = 'pay-1',
  String type = 'subscription',
  String status = 'pending',
  String planId = 'basic',
  String companyId = 'co-1',
  String payerId = 'ceo-1',
  double amount = 1000,
  List<String>? relatedTransactions,
}) {
  return PaymentProofModel(
    id: id,
    payerId: payerId,
    companyId: companyId,
    payerName: 'Ali CEO',
    payerRole: type == 'commission' ? 'Supplier' : 'CEO',
    amount: amount,
    method: 'bank_transfer',
    screenshotUrl: 'https://cdn.example/proof.jpg',
    status: status,
    type: type,
    planId: planId,
    planName: 'Basic',
    createdAt: DateTime.utc(2026, 4, 1),
    relatedTransactions: relatedTransactions,
  );
}

Future<void> _waitUntil(
  bool Function() test, {
  String because = 'timed out',
}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(_user());
    registerFallbackValue(_proof());
  });

  late FakeFirebaseFirestore fake;
  late MockNotificationService notifications;
  late MockAuthViewModel auth;
  late AdminViewModel viewModel;

  Future<void> seedUser(UserModel user) {
    return fake.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> seedCompany(CompanyModel company) {
    return fake.collection('companies').doc(company.id).set(company.toMap());
  }

  Future<void> seedProof(PaymentProofModel proof) {
    return fake.collection('payment_proofs').doc(proof.id).set(proof.toMap());
  }

  Future<void> seedSupplierProfile(
    String uid, {
    String businessName = 'Cement House',
    String status = 'Pending',
    bool isVerified = false,
  }) {
    return fake.collection('suppliers').doc(uid).set({
      'businessName': businessName,
      'name': businessName,
      'status': status,
      'isVerified': isVerified,
    });
  }

  Future<Map<String, dynamic>?> userData(String uid) async {
    final doc = await fake.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> companyData(String id) async {
    final doc = await fake.collection('companies').doc(id).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> supplierData(String uid) async {
    final doc = await fake.collection('suppliers').doc(uid).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> auditLogs() async {
    final snap = await fake.collection('audit_logs').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> becomeAdmin({
    AdminViewModel? vm,
    String uid = 'admin-1',
    String name = 'Super Admin',
    String role = 'Admin',
  }) async {
    when(() => auth.user).thenReturn(
      _user(uid: uid, name: name, role: role, companyId: '', status: 'active'),
    );
    (vm ?? viewModel).updateAuth(auth);
    await _waitUntil(
      () => !(vm ?? viewModel).isLoading,
      because: 'admin dashboard loads did not finish',
    );
  }

  setUp(() async {
    fake = FakeFirebaseFirestore();
    notifications = MockNotificationService();
    auth = MockAuthViewModel();
    when(() => auth.user).thenReturn(null);
    when(
      () => notifications.notifySubscriptionDecision(
        ceoUid: any(named: 'ceoUid'),
        title: any(named: 'title'),
        message: any(named: 'message'),
        companyId: any(named: 'companyId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyPaymentStatus(
        userId: any(named: 'userId'),
        title: any(named: 'title'),
        message: any(named: 'message'),
        companyId: any(named: 'companyId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});

    viewModel = AdminViewModel(notifications, fake);
    await becomeAdmin();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('AdminViewModel.updateAuth', () {
    test('non-admin does not load dashboard data', () async {
      final vm = AdminViewModel(notifications, fake);
      addTearDown(vm.dispose);
      await seedCompany(_company(status: 'active'));

      when(() => auth.user).thenReturn(
        _user(uid: 'field-1', role: 'field_user', status: 'active'),
      );
      vm.updateAuth(auth);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.companiesList, isEmpty);
    });

    test('Administrator role loads dashboard data', () async {
      final vm = AdminViewModel(notifications, fake);
      addTearDown(vm.dispose);
      await seedCompany(_company(status: 'active'));

      await becomeAdmin(vm: vm, uid: 'admin-2', role: 'Administrator');

      expect(vm.companiesList, isNotEmpty);
      expect(vm.companiesList.single.id, 'co-1');
    });

    test('same admin uid does not reload', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.updateAuth(auth);

      expect(notifies, 0);
    });
  });

  group('AdminViewModel.loadDashboardData', () {
    test('success loads companies and transactions and toggles loading',
        () async {
      await seedCompany(_company(status: 'active'));
      await fake.collection('transactions').doc('tx-1').set({
        'type': 'order_payment',
        'companyName': 'Acme Builders',
        'supplierName': 'Cement House',
        'amount': 1500,
        'status': 'pending',
        'date': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
        'payerRole': 'CEO',
        'screenshotUrl': 'https://cdn.example/tx.jpg',
      });

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadDashboardData();

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(viewModel.companiesList.single.name, 'Acme Builders');
      expect(viewModel.transactions, hasLength(1));
      expect(viewModel.transactions.single.amount, 1500);
      expect(viewModel.transactions.single.supplierName, 'Cement House');
      expect(viewModel.transactions.single.status, 'pending');
    });
  });

  group('AdminViewModel.loadPaymentQueue', () {
    test('splits pending vs confirmed proofs from the snapshot stream',
        () async {
      await seedProof(_proof(id: 'pay-pending'));
      await seedProof(_proof(id: 'pay-confirmed', status: 'confirmed'));
      await seedProof(_proof(id: 'pay-rejected', status: 'rejected'));
      await seedProof(_proof(id: 'pay-settled', status: 'settled'));

      await viewModel.loadPaymentQueue();
      await _waitUntil(
        () => viewModel.pendingPayments.isNotEmpty,
        because: 'payment queue did not emit',
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.pendingPayments.map((p) => p.id), ['pay-pending']);
      expect(
        viewModel.confirmedPayments.map((p) => p.id),
        containsAll(['pay-confirmed', 'pay-settled']),
      );
      expect(
        viewModel.confirmedPayments.map((p) => p.id),
        isNot(contains('pay-rejected')),
      );
    });
  });

  group('AdminViewModel.confirmPayment', () {
    test('already confirmed payments return without writing', () async {
      final payment = _proof(status: 'confirmed');
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.confirmPayment(payment);

      expect(notifies, 0);
      expect(await fake.collection('payment_proofs').get(),
          predicate<QuerySnapshot>((s) => s.docs.isEmpty));
    });

    test('already settled payments return without writing', () async {
      await viewModel.confirmPayment(_proof(status: 'settled'));
      expect(await fake.collection('payment_proofs').get(),
          predicate<QuerySnapshot>((s) => s.docs.isEmpty));
    });

    test('subscription confirmation activates the plan and notifies the CEO',
        () async {
      await seedCompany(_company());
      await seedProof(_proof());
      await fake.collection('subscriptions').doc('co-1').set({'plan': 'free'});

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.confirmPayment(_proof());

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, greaterThanOrEqualTo(2));

      final proof = (await fake.collection('payment_proofs').doc('pay-1').get())
          .data()!;
      expect(proof['status'], 'confirmed');
      expect(proof['confirmedBy'], 'admin-1');

      final sub =
          (await fake.collection('subscriptions').doc('co-1').get()).data()!;
      expect(sub['plan'], 'basic');
      expect(sub['status'], 'active');
      expect(sub['adminGranted'], isFalse);
      expect(sub['history'], isA<List>());

      final company = await companyData('co-1');
      expect(company?['plan'], 'basic');
      expect(company?['aiEnabled'], isTrue);
      expect(company?['status'], 'active');
      expect(company?['planExpiry'], isA<Timestamp>());

      verify(
        () => notifications.notifySubscriptionDecision(
          ceoUid: 'ceo-1',
          companyId: 'co-1',
          title: 'Subscription Activated! ✅',
          message: 'Your Basic subscription has been activated successfully.',
          data: {'planId': 'basic', 'status': 'active'},
        ),
      ).called(1);

      final logs = await auditLogs();
      expect(logs.single['actionType'], 'confirm_payment');
      expect(logs.single['targetId'], 'pay-1');
    });

    test('unknown planId falls back to Free limits', () async {
      await seedCompany(_company());
      final payment = _proof(planId: 'gold');
      await seedProof(payment);
      await fake.collection('subscriptions').doc('co-1').set({'plan': 'free'});

      await viewModel.confirmPayment(payment);

      final company = await companyData('co-1');
      expect(company?['plan'], 'free');
      expect(company?['aiEnabled'], isFalse);
      expect(company?['planExpiry'], isNull);
    });

    test('subscription without planId only confirms the proof', () async {
      await seedCompany(_company());
      final payment = PaymentProofModel(
        id: 'pay-1',
        payerId: 'ceo-1',
        companyId: 'co-1',
        payerName: 'Ali CEO',
        payerRole: 'CEO',
        amount: 1000,
        method: 'bank_transfer',
        screenshotUrl: 'https://cdn.example/proof.jpg',
        status: 'pending',
        type: 'subscription',
        createdAt: DateTime.utc(2026, 4, 1),
      );
      await seedProof(payment);

      await viewModel.confirmPayment(payment);

      final proof = (await fake.collection('payment_proofs').doc('pay-1').get())
          .data()!;
      expect(proof['status'], 'confirmed');
      expect((await companyData('co-1'))?['plan'], 'free');
      expect((await fake.collection('subscriptions').doc('co-1').get()).exists,
          isFalse);
      verify(
        () => notifications.notifySubscriptionDecision(
          ceoUid: 'ceo-1',
          companyId: 'co-1',
          title: 'Subscription Activated! ✅',
          message: 'Your Free subscription has been activated successfully.',
          data: {'planId': 'free', 'status': 'active'},
        ),
      ).called(1);
    });

    test('commission confirmation settles related transactions', () async {
      final payment = _proof(
        type: 'commission',
        payerId: 'sup-1',
        relatedTransactions: ['tx-1', 'tx-2'],
        amount: 250,
      );
      await seedProof(payment);
      await fake.collection('transactions').doc('tx-1').set({
        'status': 'unsettled',
        'supplierUid': 'sup-1',
      });
      await fake.collection('transactions').doc('tx-2').set({
        'status': 'unsettled',
        'supplierUid': 'sup-1',
      });

      await viewModel.confirmPayment(payment);

      final proof = (await fake.collection('payment_proofs').doc('pay-1').get())
          .data()!;
      expect(proof['status'], 'settled');

      for (final id in ['tx-1', 'tx-2']) {
        final tx = (await fake.collection('transactions').doc(id).get()).data()!;
        expect(tx['status'], 'settled');
        expect(tx['settledBy'], 'admin-1');
        expect(tx['paymentProofId'], 'pay-1');
      }

      verify(
        () => notifications.notifyPaymentStatus(
          userId: 'sup-1',
          companyId: 'co-1',
          title: 'Commission Payment Confirmed ✅',
          message: 'Your commission payment of Rs 250.0 has been settled.',
          data: {'status': 'settled'},
        ),
      ).called(1);
    });

    test('batch failure is swallowed and loading is cleared', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.confirmPayment(_proof());

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      verifyNever(
        () => notifications.notifySubscriptionDecision(
          ceoUid: any(named: 'ceoUid'),
          title: any(named: 'title'),
          message: any(named: 'message'),
          companyId: any(named: 'companyId'),
          data: any(named: 'data'),
        ),
      );
    });

    test('notification failure after commit still leaves the plan active',
        () async {
      await seedCompany(_company());
      await seedProof(_proof());
      await fake.collection('subscriptions').doc('co-1').set({'plan': 'free'});
      when(
        () => notifications.notifySubscriptionDecision(
          ceoUid: any(named: 'ceoUid'),
          title: any(named: 'title'),
          message: any(named: 'message'),
          companyId: any(named: 'companyId'),
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('fcm down'));

      await viewModel.confirmPayment(_proof());

      expect(viewModel.isLoading, isFalse);
      expect(
        (await fake.collection('payment_proofs').doc('pay-1').get())
            .data()?['status'],
        'confirmed',
      );
      expect((await companyData('co-1'))?['plan'], 'basic');
    });
  });

  group('AdminViewModel.rejectPayment', () {
    test('success marks the proof rejected, notifies, and logs the reason',
        () async {
      await seedProof(_proof());

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.rejectPayment(_proof(), 'Screenshot unreadable');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, greaterThanOrEqualTo(2));

      final proof = (await fake.collection('payment_proofs').doc('pay-1').get())
          .data()!;
      expect(proof['status'], 'rejected');
      expect(proof['adminNotes'], 'Screenshot unreadable');

      verify(
        () => notifications.notifyPaymentStatus(
          userId: 'ceo-1',
          companyId: 'co-1',
          title: 'Payment Rejected ❌',
          message:
              'Your payment proof for subscription was rejected. Reason: Screenshot unreadable',
          data: {'status': 'rejected', 'reason': 'Screenshot unreadable'},
        ),
      ).called(1);

      final logs = await auditLogs();
      expect(logs.single['actionType'], 'reject_payment');
      expect(logs.single['reason'], 'Screenshot unreadable');
    });

    test('missing proof is swallowed and loading is cleared', () async {
      await viewModel.rejectPayment(_proof(), 'nope');

      expect(viewModel.isLoading, isFalse);
      expect(await auditLogs(), isEmpty);
    });
  });

  group('AdminViewModel CEO approval', () {
    test('loadCEOs pairs each CEO with their company', () async {
      await seedUser(_user());
      await seedCompany(_company());
      await seedUser(
        _user(uid: 'ceo-2', name: 'No Co', companyId: 'missing-co'),
      );

      await viewModel.loadCEOs();

      expect(viewModel.ceosList, hasLength(2));
      final withCompany = viewModel.ceosList.firstWhere(
        (row) => (row['ceo'] as UserModel).uid == 'ceo-1',
      );
      expect((withCompany['company'] as CompanyModel).name, 'Acme Builders');
      final orphan = viewModel.ceosList.firstWhere(
        (row) => (row['ceo'] as UserModel).uid == 'ceo-2',
      );
      expect(orphan['company'], isNull);
    });

    test('acceptCEO activates the CEO badge, company, and invite code',
        () async {
      await seedUser(_user());
      await seedCompany(_company());

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.acceptCEO('co-1', 'ceo-1');
      await _waitUntil(
        () => viewModel.ceosList.any((row) {
          final ceo = row['ceo'] as UserModel;
          return ceo.uid == 'ceo-1' && ceo.approved && ceo.status == 'active';
        }),
        because: 'CEO list did not refresh after approval',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, greaterThanOrEqualTo(2));

      final ceo = await userData('ceo-1');
      expect(ceo?['status'], 'active');
      expect(ceo?['approved'], isTrue);

      final company = await companyData('co-1');
      expect(company?['status'], 'active');
      expect(company?['inviteCode'], startsWith('RB-'));

      final logs = await auditLogs();
      expect(logs.single['actionType'], 'approve_ceo');
      expect(logs.single['targetId'], 'ceo-1');
      expect(logs.single['description'], contains('Ali CEO'));
      expect(logs.single['description'], contains('Acme Builders'));
    });

    test('approveCEO is an alias of acceptCEO', () async {
      await seedUser(_user());
      await seedCompany(_company());

      await viewModel.approveCEO('co-1', 'ceo-1');

      expect((await userData('ceo-1'))?['approved'], isTrue);
      expect((await companyData('co-1'))?['status'], 'active');
    });

    test('acceptCEO with a null companyId only approves the user', () async {
      await seedUser(_user(companyId: ''));

      await viewModel.acceptCEO(null, 'ceo-1');

      expect((await userData('ceo-1'))?['approved'], isTrue);
      expect((await userData('ceo-1'))?['status'], 'active');
      expect(await companyData('co-1'), isNull);
    });

    test('acceptCEO failure on a missing user is propagated after loading',
        () async {
      await expectLater(
        viewModel.acceptCEO('co-1', 'missing-ceo'),
        throwsA(anything),
      );
      expect(viewModel.isLoading, isFalse);
    });

    test('suspendCEO bans the CEO and company', () async {
      await seedUser(_user(status: 'active', approved: true));
      await seedCompany(_company(status: 'active'));

      await viewModel.suspendCEO('co-1', 'ceo-1');
      await _waitUntil(
        () => viewModel.ceosList.any(
          (row) => (row['ceo'] as UserModel).status == 'suspended',
        ),
        because: 'CEO list did not refresh after suspend',
      );

      expect((await userData('ceo-1'))?['status'], 'suspended');
      expect((await companyData('co-1'))?['status'], 'suspended');
      expect((await auditLogs()).single['actionType'], 'ban_company');
    });

    test('suspendCEO resolves companyId from the user when omitted', () async {
      await seedUser(_user(status: 'active', approved: true));
      await seedCompany(_company(status: 'active'));

      await viewModel.suspendCEO(null, 'ceo-1');

      expect((await companyData('co-1'))?['status'], 'suspended');
    });

    test('activateCEO restores the CEO and company', () async {
      await seedUser(_user(status: 'suspended', approved: true));
      await seedCompany(_company(status: 'suspended'));

      await viewModel.activateCEO('co-1', 'ceo-1');

      expect((await userData('ceo-1'))?['status'], 'active');
      expect((await companyData('co-1'))?['status'], 'active');
      expect((await auditLogs()).single['actionType'], 'reactivate_company');
    });

    test('rejectCEO writes the rejection reason on user and company', () async {
      await seedUser(_user());
      await seedCompany(_company());

      await viewModel.rejectCEO('co-1', 'ceo-1', 'Incomplete documents');

      expect((await userData('ceo-1'))?['status'], 'rejected');
      expect((await userData('ceo-1'))?['rejectionReason'],
          'Incomplete documents');
      expect((await companyData('co-1'))?['status'], 'rejected');
      expect((await companyData('co-1'))?['rejectionReason'],
          'Incomplete documents');
      expect((await auditLogs()).single['actionType'], 'reject_ceo');
      expect((await auditLogs()).single['reason'], 'Incomplete documents');
    });

    test('suspendCEO fails when the user doc is missing', () async {
      await expectLater(
        viewModel.suspendCEO('co-1', 'missing-ceo'),
        throwsA(anything),
      );
    });
  });

  group('AdminViewModel supplier approval and badges', () {
    test('loadSuppliers maps supplier users', () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          name: 'Cement House',
          role: 'Supplier',
          companyId: '',
          status: 'pending',
        ),
      );

      await viewModel.loadSuppliers();

      expect(viewModel.suppliersList, hasLength(1));
      expect((viewModel.suppliersList.single['user'] as UserModel).uid, 'sup-1');
    });

    test('approveSupplier assigns verified badge and Active status', () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          name: 'Cement House',
          role: 'Supplier',
          companyId: '',
          status: 'pending',
        ),
      );
      await seedSupplierProfile('sup-1');

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.approveSupplier('sup-1');
      await _waitUntil(
        () => viewModel.suppliersList.any((row) {
          final user = row['user'] as UserModel;
          return user.uid == 'sup-1' && user.approved && user.status == 'active';
        }),
        because: 'supplier list did not refresh after approval',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, greaterThanOrEqualTo(2));

      expect((await userData('sup-1'))?['status'], 'active');
      expect((await userData('sup-1'))?['approved'], isTrue);

      final profile = await supplierData('sup-1');
      expect(profile?['status'], 'Active');
      expect(profile?['isVerified'], isTrue);

      final logs = await auditLogs();
      expect(logs.single['actionType'], 'approve_supplier');
      expect(logs.single['description'], contains('Cement House'));
    });

    test('approveSupplier fails when the supplier profile is missing',
        () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          role: 'Supplier',
          companyId: '',
          status: 'pending',
        ),
      );

      await expectLater(viewModel.approveSupplier('sup-1'), throwsA(anything));
      expect(viewModel.isLoading, isFalse);
      expect((await userData('sup-1'))?['approved'], isTrue);
    });

    test('suspendSupplier bans without clearing the verified badge', () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          name: 'Cement House',
          role: 'Supplier',
          companyId: '',
          status: 'active',
          approved: true,
        ),
      );
      await seedSupplierProfile('sup-1', status: 'Active', isVerified: true);

      await viewModel.suspendSupplier('sup-1');

      expect((await userData('sup-1'))?['status'], 'suspended');
      expect((await supplierData('sup-1'))?['status'], 'Suspended');
      expect((await supplierData('sup-1'))?['isVerified'], isTrue);
      expect((await auditLogs()).single['actionType'], 'ban_supplier');
    });

    test('reactivateSupplier restores Active status and verified badge',
        () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          name: 'Cement House',
          role: 'Supplier',
          companyId: '',
          status: 'suspended',
          approved: true,
        ),
      );
      await seedSupplierProfile(
        'sup-1',
        status: 'Suspended',
        isVerified: false,
      );

      await viewModel.reactivateSupplier('sup-1');

      expect((await userData('sup-1'))?['status'], 'active');
      expect((await userData('sup-1'))?['approved'], isTrue);
      expect((await supplierData('sup-1'))?['status'], 'Active');
      expect((await supplierData('sup-1'))?['isVerified'], isTrue);
      expect((await auditLogs()).single['actionType'], 'reactivate_supplier');
    });

    test('rejectSupplier writes the rejection reason', () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          name: 'Cement House',
          role: 'Supplier',
          companyId: '',
          status: 'pending',
        ),
      );
      await seedSupplierProfile('sup-1');

      await viewModel.rejectSupplier('sup-1', 'Invalid NTN');

      expect((await userData('sup-1'))?['status'], 'rejected');
      expect((await userData('sup-1'))?['rejectionReason'], 'Invalid NTN');
      expect((await supplierData('sup-1'))?['status'], 'Rejected');
      expect((await auditLogs()).single['actionType'], 'reject_supplier');
      expect((await auditLogs()).single['reason'], 'Invalid NTN');
    });

    test('deleteSupplierPermanently removes user and profile docs', () async {
      await seedUser(
        _user(
          uid: 'sup-1',
          role: 'Supplier',
          companyId: '',
          status: 'rejected',
        ),
      );
      await seedSupplierProfile('sup-1');

      await viewModel.deleteSupplierPermanently('sup-1');

      expect((await fake.collection('users').doc('sup-1').get()).exists, isFalse);
      expect(
        (await fake.collection('suppliers').doc('sup-1').get()).exists,
        isFalse,
      );
      expect((await auditLogs()).single['actionType'], 'delete_supplier');
    });

    test('suspendSupplier fails when the user doc is missing', () async {
      await expectLater(viewModel.suspendSupplier('missing-sup'), throwsA(anything));
    });
  });

  group('AdminViewModel categories', () {
    test('addCategory writes an active category and audit log', () async {
      await viewModel.addCategory(
        'Cement',
        'bag',
        const ['Lucky'],
        const ['OPC 53'],
      );

      final snap = await fake.collection('categories').get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.single.data()['name'], 'Cement');
      expect(snap.docs.single.data()['unit'], 'bag');
      expect(snap.docs.single.data()['brands'], ['Lucky']);
      expect(snap.docs.single.data()['grades'], ['OPC 53']);
      expect(snap.docs.single.data()['icon'], 'construction_outlined');
      expect(snap.docs.single.data()['active'], isTrue);
      expect((await auditLogs()).single['actionType'], 'add_category');
      expect((await auditLogs()).single['targetId'], snap.docs.single.id);
    });

    test('editCategory updates fields and optional active flag', () async {
      await fake.collection('categories').doc('cat-1').set({
        'name': 'Cement',
        'unit': 'bag',
        'brands': ['Lucky'],
        'grades': ['OPC'],
        'active': true,
      });

      await viewModel.editCategory(
        'cat-1',
        'Steel',
        'ton',
        const ['Amreli'],
        const ['60 grade'],
        isActive: false,
      );

      final data =
          (await fake.collection('categories').doc('cat-1').get()).data()!;
      expect(data['name'], 'Steel');
      expect(data['unit'], 'ton');
      expect(data['active'], isFalse);
      expect((await auditLogs()).single['actionType'], 'edit_category');
    });

    test('editCategory without isActive leaves active unchanged', () async {
      await fake.collection('categories').doc('cat-1').set({
        'name': 'Cement',
        'unit': 'bag',
        'brands': <String>[],
        'grades': <String>[],
        'active': true,
      });

      await viewModel.editCategory('cat-1', 'Cement', 'bag', const [], const []);

      expect(
        (await fake.collection('categories').doc('cat-1').get()).data()?['active'],
        isTrue,
      );
    });

    test('setCategoryActive writes activate and deactivate audit actions',
        () async {
      await fake.collection('categories').doc('cat-1').set({'active': true});

      await viewModel.setCategoryActive('cat-1', false);
      expect(
        (await fake.collection('categories').doc('cat-1').get()).data()?['active'],
        isFalse,
      );
      expect((await auditLogs()).last['actionType'], 'deactivate_category');

      await viewModel.setCategoryActive('cat-1', true);
      expect(
        (await fake.collection('categories').doc('cat-1').get()).data()?['active'],
        isTrue,
      );
      expect((await auditLogs()).last['actionType'], 'activate_category');
    });

    test('deleteCategory removes the document', () async {
      await fake.collection('categories').doc('cat-1').set({'name': 'Cement'});

      await viewModel.deleteCategory('cat-1');

      expect(
        (await fake.collection('categories').doc('cat-1').get()).exists,
        isFalse,
      );
      expect((await auditLogs()).single['actionType'], 'delete_category');
    });

    test('editCategory fails when the category is missing', () async {
      await expectLater(
        viewModel.editCategory('missing', 'X', 'bag', const [], const []),
        throwsA(anything),
      );
    });
  });

  group('AdminViewModel.settleSupplierCommissions', () {
    test('empty unsettled snapshot is a no-op', () async {
      await viewModel.settleSupplierCommissions(
        supplierUid: 'sup-1',
        supplierName: 'Cement House',
        unsettledAmount: 100,
        orderCount: 1,
      );

      expect(await auditLogs(), isEmpty);
    });

    test('success marks matching transactions settled', () async {
      await fake.collection('transactions').doc('tx-1').set({
        'supplierUid': 'sup-1',
        'status': 'unsettled',
      });
      await fake.collection('transactions').doc('tx-2').set({
        'supplierUid': 'sup-1',
        'status': 'settled',
      });
      await fake.collection('transactions').doc('tx-3').set({
        'supplierUid': 'sup-other',
        'status': 'unsettled',
      });

      await viewModel.settleSupplierCommissions(
        supplierUid: 'sup-1',
        supplierName: 'Cement House',
        unsettledAmount: 400,
        orderCount: 1,
      );

      expect(
        (await fake.collection('transactions').doc('tx-1').get())
            .data()?['status'],
        'settled',
      );
      expect(
        (await fake.collection('transactions').doc('tx-2').get())
            .data()?['status'],
        'settled',
      );
      expect(
        (await fake.collection('transactions').doc('tx-3').get())
            .data()?['status'],
        'unsettled',
      );
      expect((await auditLogs()).single['actionType'], 'settle_commission');
      expect(
        (await auditLogs()).single['description'],
        contains('Cement House'),
      );
    });
  });

  group('AdminViewModel watch streams', () {
    test('user count streams reflect status filters', () async {
      await seedUser(_user(uid: 'u-1', role: 'field_user', status: 'active'));
      await seedUser(_user(uid: 'u-2', role: 'CEO', status: 'active'));
      await seedUser(_user(uid: 'u-3', role: 'Supplier', status: 'suspended'));
      await seedUser(_user(uid: 'u-4', role: 'CEO', status: 'pending'));

      expect(await viewModel.watchActiveUsersCount().first, 2);
      expect(await viewModel.watchSuspendedUsersCount().first, 1);
      expect(await viewModel.watchPendingUsersCount().first, 1);
    });

    test('watchCategories skips blank names and sorts by name', () async {
      await fake.collection('categories').doc('b').set({
        'name': 'Steel',
        'unit': 'ton',
        'brands': <String>[],
        'grades': <String>[],
      });
      await fake.collection('categories').doc('a').set({
        'name': 'Cement',
        'unit': 'bag',
        'brands': <String>[],
        'grades': <String>[],
      });
      await fake.collection('categories').doc('empty').set({
        'name': '',
        'unit': 'bag',
      });

      final cats = await viewModel.watchCategories().first;

      expect(cats.map((c) => c.name), ['Cement', 'Steel']);
      expect(cats, everyElement(isA<CategoryModel>()));
    });
  });
}
