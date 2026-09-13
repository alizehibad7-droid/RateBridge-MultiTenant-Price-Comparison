import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/partnership_request_model.dart';
import 'package:ratebridge/repositories/partnership_request_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/utils/app_exception.dart';

import '../mocks/mocks.dart';

Future<void> _waitUntil(
  bool Function() test, {
  String because = 'condition never became true',
}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
  });

  late FakeFirebaseFirestore fake;
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late PartnershipRequestRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    when(() => callable.call(any())).thenThrow(Exception('not deployed'));

    repo = PartnershipRequestRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
      functions: functions,
    );
  });

  Future<void> seedCompanyAndSupplier() async {
    await fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'status': 'active',
      'plan': 'premium',
    });
    await fake.collection('suppliers').doc('sup-1').set({
      'name': 'Cement House',
      'city': 'Lahore',
      'businessType': 'Cement',
      'totalCompanies': 1,
    });
  }

  group('PartnershipRequestRepository.createRequest', () {
    test('creates a pending supplier-initiated request', () async {
      await seedCompanyAndSupplier();

      final id = await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
        message: 'Please partner',
        supplierCity: 'Lahore',
        supplierCategories: const ['Cement'],
        supplierRating: 4.5,
      );

      final doc =
          await fake.collection('partnershipRequests').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['status'], 'pending');
      expect(doc.data()?['initiatedBy'], 'supplier');
      expect(doc.data()?['message'], 'Please partner');
      expect(doc.data()?['requestId'], id);
    });

    test('CEO-initiated request succeeds when the plan is unlimited', () async {
      await seedCompanyAndSupplier();

      final id = await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'ceo',
      );

      final doc =
          await fake.collection('partnershipRequests').doc(id).get();
      expect(doc.data()?['initiatedBy'], 'ceo');
    });

    test('rejects a duplicate pending or accepted pair', () async {
      await seedCompanyAndSupplier();
      await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
      );

      await expectLater(
        repo.createRequest(
          companyId: 'co-1',
          companyName: 'Acme Builders',
          supplierId: 'sup-1',
          supplierName: 'Cement House',
          initiatedBy: 'ceo',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });
  });

  group('PartnershipRequestRepository streams', () {
    test('watchLatestForPair emits the newest request', () async {
      await fake.collection('partnershipRequests').doc('older').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'companyName': 'Acme',
        'supplierName': 'Cement House',
        'initiatedBy': 'supplier',
        'status': 'rejected',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
      });
      await fake.collection('partnershipRequests').doc('newer').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'companyName': 'Acme',
        'supplierName': 'Cement House',
        'initiatedBy': 'supplier',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });

      final events = <PartnershipRequestModel?>[];
      final sub = repo
          .watchLatestForPair(companyId: 'co-1', supplierId: 'sup-1')
          .listen(events.add);

      await _waitUntil(
        () => events.any((e) => e?.requestId == 'newer'),
        because: 'latest pair stream did not emit the newest request',
      );

      await sub.cancel();
    });

    test('watchForCompany and watchForSupplier filter by initiator', () async {
      await seedCompanyAndSupplier();
      await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
      );

      final companyEvents = <List<PartnershipRequestModel>>[];
      final supplierEvents = <List<PartnershipRequestModel>>[];
      final companySub = repo
          .watchForCompany(companyId: 'co-1', initiatedBy: 'supplier')
          .listen(companyEvents.add);
      final supplierSub = repo
          .watchForSupplier(supplierId: 'sup-1', initiatedBy: 'supplier')
          .listen(supplierEvents.add);

      await _waitUntil(
        () =>
            companyEvents.any((e) => e.isNotEmpty) &&
            supplierEvents.any((e) => e.isNotEmpty),
        because: 'initiator streams did not emit',
      );
      expect(companyEvents.last.single.supplierId, 'sup-1');
      expect(supplierEvents.last.single.companyId, 'co-1');

      await companySub.cancel();
      await supplierSub.cancel();
    });

    test('watchPendingCountForCompany counts supplier-initiated pending',
        () async {
      await seedCompanyAndSupplier();
      await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
      );

      final counts = <int>[];
      final sub = repo.watchPendingCountForCompany('co-1').listen(counts.add);

      await _waitUntil(
        () => counts.any((c) => c == 1),
        because: 'pending count did not become 1',
      );

      await sub.cancel();
    });
  });

  group('PartnershipRequestRepository status changes', () {
    test('acceptRequest falls back to a local accept and link docs', () async {
      await seedCompanyAndSupplier();
      final id = await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
      );

      await repo.acceptRequest(id);

      final req =
          await fake.collection('partnershipRequests').doc(id).get();
      expect(req.data()?['status'], 'accepted');

      final companyLink = await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-1')
          .get();
      expect(companyLink.exists, isTrue);
      expect(companyLink.data()?['status'], 'active');
      expect(companyLink.data()?['name'], 'Cement House');

      final supplierLink = await fake
          .collection('suppliers')
          .doc('sup-1')
          .collection('companies')
          .doc('co-1')
          .get();
      expect(supplierLink.exists, isTrue);
      expect(supplierLink.data()?['name'], 'Acme Builders');
    });

    test('acceptRequest throws when the request is missing or not pending',
        () async {
      await expectLater(
        repo.acceptRequest('missing'),
        throwsA(isA<AppException>()),
      );

      await fake.collection('partnershipRequests').doc('done').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'companyName': 'Acme',
        'supplierName': 'Cement House',
        'initiatedBy': 'supplier',
        'status': 'rejected',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      await expectLater(
        repo.acceptRequest('done'),
        throwsA(isA<AppException>()),
      );
    });

    test('rejectRequest stores the reason', () async {
      await seedCompanyAndSupplier();
      final id = await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
      );

      await repo.rejectRequest(id, '  Not a fit  ');
      final doc =
          await fake.collection('partnershipRequests').doc(id).get();
      expect(doc.data()?['status'], 'rejected');
      expect(doc.data()?['rejectionReason'], 'Not a fit');
    });

    test('withdrawRequest deletes a pending request', () async {
      await seedCompanyAndSupplier();
      final id = await repo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
        initiatedBy: 'supplier',
      );

      await repo.withdrawRequest(id);
      final doc =
          await fake.collection('partnershipRequests').doc(id).get();
      expect(doc.exists, isFalse);
    });

    test('withdrawRequest rejects non-pending requests', () async {
      await fake.collection('partnershipRequests').doc('acc').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'companyName': 'Acme',
        'supplierName': 'Cement House',
        'initiatedBy': 'supplier',
        'status': 'accepted',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      await expectLater(
        repo.withdrawRequest('acc'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.withdrawRequest('missing'),
        throwsA(isA<AppException>()),
      );
    });

    test('removePartnership deletes links and marks the accepted request',
        () async {
      await seedCompanyAndSupplier();
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-1')
          .set({'status': 'active', 'name': 'Cement House'});
      await fake
          .collection('suppliers')
          .doc('sup-1')
          .collection('companies')
          .doc('co-1')
          .set({'status': 'active', 'name': 'Acme Builders'});
      await fake.collection('partnershipRequests').doc('acc').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'companyName': 'Acme',
        'supplierName': 'Cement House',
        'initiatedBy': 'supplier',
        'status': 'accepted',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      await repo.removePartnership(companyId: 'co-1', supplierId: 'sup-1');

      expect(
        (await fake
                .collection('companies')
                .doc('co-1')
                .collection('suppliers')
                .doc('sup-1')
                .get())
            .exists,
        isFalse,
      );
      expect(
        (await fake
                .collection('suppliers')
                .doc('sup-1')
                .collection('companies')
                .doc('co-1')
                .get())
            .exists,
        isFalse,
      );
      expect(
        (await fake.collection('partnershipRequests').doc('acc').get())
            .data()?['status'],
        'removed',
      );
      expect(
        (await fake.collection('suppliers').doc('sup-1').get())
            .data()?['totalCompanies'],
        0,
      );
    });
  });
}
