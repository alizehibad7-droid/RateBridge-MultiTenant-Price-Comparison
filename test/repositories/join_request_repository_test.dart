import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/join_request_model.dart';
import 'package:ratebridge/repositories/join_request_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

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
  late FakeFirebaseFirestore fake;
  late JoinRequestRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = JoinRequestRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  group('JoinRequestRepository', () {
    test('createJoinRequest writes a pending request and returns its id',
        () async {
      final id = await repo.createJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const ['Cement'],
        4.5,
        'Please add us',
      );

      final doc = await fake.collection('joinRequests').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['supplierUid'], 'sup-1');
      expect(doc.data()?['companyId'], 'co-1');
      expect(doc.data()?['status'], 'pending');
      expect(doc.data()?['initiatedBy'], 'supplier');
      expect(doc.data()?['message'], 'Please add us');
      expect(doc.data()?['supplierRating'], 4.5);
    });

    test('createJoinRequest stores a custom initiatedBy', () async {
      final id = await repo.createJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const ['Cement'],
        4.0,
        null,
        initiatedBy: 'company',
      );

      final doc = await fake.collection('joinRequests').doc(id).get();
      expect(doc.data()?['initiatedBy'], 'company');
      expect(doc.data()?['message'], isNull);
    });

    test('watchPendingRequests emits only pending requests for that company',
        () async {
      final events = <List<JoinRequestModel>>[];
      final sub = repo.watchPendingRequests('co-1').listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no join-request snapshot');
      expect(events.last, isEmpty);

      final pendingId = await repo.createJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const ['Cement'],
        4.5,
        'Hi',
      );
      await repo.createJoinRequest(
        'sup-2',
        'co-2',
        'Other',
        'Karachi',
        const ['Steel'],
        3,
        null,
      );

      await _waitUntil(
        () => events.any((e) => e.any((r) => r.reqId == pendingId)),
        because: 'pending join request did not emit',
      );
      expect(events.last.single.supplierName, 'Cement House');

      await repo.updateRequestStatus(pendingId, 'accepted');
      await _waitUntil(
        () => events.any((e) => e.isEmpty),
        because: 'accepted request was not removed from pending stream',
      );

      await sub.cancel();
    });

    test('updateRequestStatus stores rejection reason', () async {
      final id = await repo.createJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const ['Cement'],
        4.5,
        null,
      );

      await repo.updateRequestStatus(id, 'rejected', reason: 'Not a fit');

      final doc = await fake.collection('joinRequests').doc(id).get();
      expect(doc.data()?['status'], 'rejected');
      expect(doc.data()?['rejectionReason'], 'Not a fit');
    });
  });
}
