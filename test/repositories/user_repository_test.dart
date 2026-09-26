import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

import '../mocks/mocks.dart';

UserModel _user({
  String uid = 'user-1',
  String name = 'Ali Raza',
  List<String> fcmTokens = const [],
}) {
  return UserModel(
    uid: uid,
    email: '$uid@co.test',
    name: name,
    role: 'field_user',
    companyId: 'co-1',
    phone: '03001234567',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
    fcmTokens: fcmTokens,
  );
}

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
  final user = _user();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(false);
    registerFallbackValue(user);
  });

  late FakeFirebaseFirestore fake;
  late MockFirebaseAuthService auth;
  late UserRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    auth = MockFirebaseAuthService();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.login(any(), any())).thenAnswer((_) async => user);
    when(
      () => auth.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
        role: any(named: 'role'),
        companyId: any(named: 'companyId'),
        phone: any(named: 'phone'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => user);
    when(() => auth.signOut()).thenAnswer((_) async {});

    repo = UserRepository(
      auth,
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  group('UserRepository session', () {
    test('getSessionUser returns null and clears cache when signed out',
        () async {
      await repo.createUserDoc(user.uid, user);
      expect(repo.cachedUser, isNotNull);

      final session = await repo.getSessionUser();
      expect(session, isNull);
      expect(repo.cachedUser, isNull);
    });

    test('getSessionUser loads the Firestore user after attaching a token',
        () async {
      final firebaseUser = MockFirebaseUser();
      when(() => firebaseUser.uid).thenReturn(user.uid);
      when(() => firebaseUser.getIdToken()).thenAnswer((_) async => 'id-token');
      when(() => firebaseUser.getIdToken(true))
          .thenAnswer((_) async => 'id-token');
      when(() => auth.currentUser).thenReturn(firebaseUser);
      await repo.createUserDoc(user.uid, user);

      final session = await repo.getSessionUser();
      expect(session?.uid, user.uid);
      expect(session?.name, 'Ali Raza');
      expect(repo.cachedUser?.uid, user.uid);
      verify(() => firebaseUser.getIdToken()).called(1);
    });

    test('login caches the auth user', () async {
      final loggedIn = await repo.login('ali@co.test', 'secret');
      expect(loggedIn?.uid, user.uid);
      expect(repo.cachedUser?.uid, user.uid);
      verify(() => auth.login('ali@co.test', 'secret')).called(1);
    });

    test('register caches the created user', () async {
      final created = await repo.register(
        email: 'ali@co.test',
        password: 'secret',
        name: 'Ali Raza',
        role: 'field_user',
        companyId: 'co-1',
        phoneNumber: '0300',
      );
      expect(created.uid, user.uid);
      expect(repo.cachedUser?.uid, user.uid);
    });

    test('logout clears cache and signs out', () async {
      await repo.login('ali@co.test', 'secret');
      await repo.logout();
      expect(repo.cachedUser, isNull);
      verify(() => auth.signOut()).called(1);
    });
  });

  group('UserRepository CRUD', () {
    test('createUserDoc then getUserDoc returns the document', () async {
      await repo.createUserDoc(user.uid, user);
      final loaded = await repo.getUserDoc(user.uid);
      expect(loaded.name, 'Ali Raza');
      expect(loaded.email, 'user-1@co.test');
      expect(repo.cachedUser?.uid, user.uid);
    });

    test('getUserDoc throws when the document is missing', () async {
      await expectLater(
        repo.getUserDoc('missing'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('User model not found'),
          ),
        ),
      );
    });

    test('updateUserDoc patches fields and refreshes cache', () async {
      await repo.createUserDoc(user.uid, user);
      await repo.updateUserDoc(user.uid, {'name': 'Sara Khan', 'city': 'Karachi'});

      final loaded = await repo.getUserDoc(user.uid);
      expect(loaded.name, 'Sara Khan');
      expect(loaded.city, 'Karachi');
      expect(repo.cachedUser?.name, 'Sara Khan');
    });

    test('updateFcmToken unions a token and can clear the array', () async {
      await repo.createUserDoc(user.uid, user);
      await repo.updateFcmToken(user.uid, 'tok-a');
      await repo.updateFcmToken(user.uid, 'tok-b');
      await repo.updateFcmToken(user.uid, 'tok-a');

      var loaded = await repo.getUserDoc(user.uid);
      expect(loaded.fcmTokens, ['tok-a', 'tok-b']);
      expect(repo.cachedUser?.fcmTokens, ['tok-a', 'tok-b']);

      await repo.updateFcmToken(user.uid, null);
      loaded = await repo.getUserDoc(user.uid);
      expect(loaded.fcmTokens, isEmpty);
      expect(repo.cachedUser?.fcmTokens, isEmpty);
    });

    test('deleteUserDoc removes the document and cache', () async {
      await repo.createUserDoc(user.uid, user);
      await repo.deleteUserDoc(user.uid);
      expect(repo.cachedUser, isNull);
      await expectLater(repo.getUserDoc(user.uid), throwsA(isA<Exception>()));
    });

    test('findActiveCompanyByInviteCode returns the active company', () async {
      await fake.collection('companies').doc('co-1').set({
        'name': 'Acme Builders',
        'inviteCode': 'RB-ACTIVE',
        'inviteCodeGeneratedAt': Timestamp.fromDate(
          DateTime.utc(2026, 9, 7, 6, 30),
        ),
        'status': 'active',
        'plan': 'premium',
      });
      await fake.collection('companies').doc('co-pending').set({
        'name': 'Pending Co',
        'inviteCode': 'RB-ACTIVE',
        'status': 'pending',
        'plan': 'free',
      });

      final hit = await repo.findActiveCompanyByInviteCode('RB-ACTIVE');
      expect(hit, isNotNull);
      expect(hit!.companyId, 'co-1');
      expect(hit.companyName, 'Acme Builders');
      expect(hit.plan, 'premium');
      expect(hit.inviteCodeGeneratedAt?.toUtc(), DateTime.utc(2026, 9, 7, 6, 30));
      expect(await repo.findActiveCompanyByInviteCode('NOPE'), isNull);
    });

    test('linkFieldUserToCompany writes the nested field-user doc', () async {
      await repo.linkFieldUserToCompany(
        companyId: 'co-1',
        uid: 'user-1',
        fullName: 'Ali Raza',
        email: 'ali@co.test',
        phone: '0300',
        cnicNumber: '35202',
        jobTitle: 'Site Engineer',
        assignedSite: 'Site 12',
      );

      final doc = await fake
          .collection('companies')
          .doc('co-1')
          .collection('fieldUsers')
          .doc('user-1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['fullName'], 'Ali Raza');
      expect(doc.data()?['jobTitle'], 'Site Engineer');
      expect(doc.data()?['status'], 'active');
      final company = await fake.collection('companies').doc('co-1').get();
      expect(company.data()?['fieldUserCount'], 1);
    });
  });

  group('UserRepository.watchUserDoc', () {
    test('emits the current document and later updates', () async {
      await repo.createUserDoc(user.uid, user);
      final events = <UserModel>[];
      final sub = repo.watchUserDoc(user.uid).listen(events.add);

      await _waitUntil(
        () => events.any((u) => u.name == 'Ali Raza'),
        because: 'initial user snapshot did not emit',
      );

      await repo.updateUserDoc(user.uid, {'name': 'Updated Ali'});
      await _waitUntil(
        () => events.any((u) => u.name == 'Updated Ali'),
        because: 'user update did not emit',
      );

      await sub.cancel();
    });

    test('errors when the document is missing', () async {
      Object? error;
      final sub = repo.watchUserDoc('missing').listen(
        (_) {},
        onError: (e) => error = e,
      );

      await _waitUntil(
        () => error != null,
        because: 'missing user doc did not error the stream',
      );
      expect(error.toString(), contains('User doc does not exist'));
      await sub.cancel();
    });
  });
}
