import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/repositories/invitation_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/utils/app_exception.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late InvitationRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = InvitationRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  Future<void> seedPremiumCompany() {
    return fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'status': 'active',
      'plan': 'premium',
    });
  }

  group('InvitationRepository.createFieldUserInvite', () {
    test('writes a pending field-user invite and returns the code', () async {
      final code = await repo.createFieldUserInvite('co-1', 'ceo-1', 'Acme');

      expect(code, startsWith('RB-'));
      expect(code.length, 9);
      final doc = await fake.collection('invitations').doc(code).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['role'], 'field_user');
      expect(doc.data()?['status'], 'pending');
      expect(doc.data()?['companyId'], 'co-1');
      expect(doc.data()?['ceoUid'], 'ceo-1');
      expect(doc.data()?['companyName'], 'Acme');
    });
  });

  group('InvitationRepository.getInvitation', () {
    test('returns null when the token is missing', () async {
      expect(await repo.getInvitation('RB-MISSING'), isNull);
    });

    test('returns a pending invitation that is still valid', () async {
      await fake.collection('invitations').doc('RB-VALID1').set({
        'companyId': 'co-1',
        'ceoUid': 'ceo-1',
        'companyName': 'Acme',
        'role': 'field_user',
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final invite = await repo.getInvitation('RB-VALID1');
      expect(invite, isNotNull);
      expect(invite!.status, 'pending');
      expect(invite.companyName, 'Acme');
    });

    test('auto-expires a pending invitation past its expiry', () async {
      await fake.collection('invitations').doc('RB-OLD001').set({
        'companyId': 'co-1',
        'ceoUid': 'ceo-1',
        'companyName': 'Acme',
        'role': 'field_user',
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 40)),
        ),
      });

      final invite = await repo.getInvitation('RB-OLD001');
      expect(invite!.status, 'expired');
      final stored =
          await fake.collection('invitations').doc('RB-OLD001').get();
      expect(stored.data()?['status'], 'expired');
    });
  });

  group('InvitationRepository.updateStatus', () {
    test('patches the invitation status', () async {
      await fake.collection('invitations').doc('RB-STAT01').set({
        'companyId': 'co-1',
        'status': 'pending',
        'companyName': 'Acme',
        'ceoUid': 'ceo-1',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      await repo.updateStatus('RB-STAT01', 'accepted');
      final doc = await fake.collection('invitations').doc('RB-STAT01').get();
      expect(doc.data()?['status'], 'accepted');
    });
  });

  group('InvitationRepository.createInvitation', () {
    test('creates a pending supplier invitation when the plan allows it',
        () async {
      await seedPremiumCompany();

      final id = await repo.createInvitation(
        'co-1',
        'ceo-1',
        'sup-1',
        'Acme Builders',
      );

      final doc = await fake.collection('invitations').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['supplierUid'], 'sup-1');
      expect(doc.data()?['status'], 'pending');
      expect(doc.data()?['companyId'], 'co-1');
    });

    test('throws when the company document is missing', () async {
      await expectLater(
        repo.createInvitation('missing', 'ceo-1', 'sup-1', 'Acme'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
