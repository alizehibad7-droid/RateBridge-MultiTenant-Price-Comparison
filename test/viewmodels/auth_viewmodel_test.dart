import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';

import '../mocks/mocks.dart';

UserModel _user({
  String uid = 'user-1',
  String role = 'CEO',
  String companyId = 'company-1',
}) {
  return UserModel(
    uid: uid,
    email: 'ceo@acme.test',
    name: 'Ayesha Khan',
    role: role,
    companyId: companyId,
    phone: '03001234567',
    city: 'Lahore',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = _user();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(testUser);
    registerFallbackValue(
      const ActiveCompanyInvite(companyId: 'fallback'),
    );
  });

  late MockUserRepository userRepo;
  late MockFirebaseAuthService authService;
  late MockNotificationService notificationService;
  late MockFirebaseUser firebaseUser;
  late MockUserCredential userCredential;
  late StreamController<User?> authChanges;
  late Completer<UserModel?> sessionCompleter;
  late AuthViewModel viewModel;

  void stubWatchUserDoc() {
    when(() => userRepo.watchUserDoc(any())).thenAnswer(
      (_) => const Stream<UserModel>.empty(),
    );
  }

  AuthViewModel createViewModel({
    Future<UserModel?> Function()? session,
  }) {
    if (session != null) {
      when(() => userRepo.getSessionUser()).thenAnswer((_) => session());
    } else {
      sessionCompleter = Completer<UserModel?>();
      when(() => userRepo.getSessionUser()).thenAnswer(
        (_) => sessionCompleter.future,
      );
    }

    when(() => authService.authStateChanges).thenAnswer(
      (_) => authChanges.stream,
    );
    when(() => authService.currentUser).thenReturn(null);
    when(() => authService.emailAlreadyRegistered(any()))
        .thenAnswer((_) async => false);
    stubWatchUserDoc();
    when(() => userRepo.updateFcmToken(any(), any())).thenAnswer((_) async {});
    when(() => userRepo.createUserDoc(any(), any())).thenAnswer((_) async {});
    when(
      () => userRepo.linkFieldUserToCompany(
        companyId: any(named: 'companyId'),
        uid: any(named: 'uid'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        cnicNumber: any(named: 'cnicNumber'),
        jobTitle: any(named: 'jobTitle'),
        assignedSite: any(named: 'assignedSite'),
      ),
    ).thenAnswer((_) async {});
    when(() => userRepo.logout()).thenAnswer((_) async {});

    return AuthViewModel(userRepo, authService, notificationService);
  }

  Future<AuthViewModel> createSettledViewModel() async {
    final vm = createViewModel(session: () async => null);
    await _flush();
    return vm;
  }

  setUp(() {
    userRepo = MockUserRepository();
    authService = MockFirebaseAuthService();
    notificationService = MockNotificationService();
    firebaseUser = MockFirebaseUser();
    userCredential = MockUserCredential();
    authChanges = StreamController<User?>.broadcast();
    sessionCompleter = Completer<UserModel?>();

    when(() => firebaseUser.uid).thenReturn(testUser.uid);
    when(() => firebaseUser.getIdToken()).thenAnswer((_) async => 'token');
    when(() => firebaseUser.getIdToken(true)).thenAnswer((_) async => 'token');
    when(() => firebaseUser.delete()).thenAnswer((_) async {});
    when(() => userCredential.user).thenReturn(firebaseUser);
  });

  tearDown(() async {
    if (!sessionCompleter.isCompleted) {
      sessionCompleter.complete(null);
      await _flush();
    }
    viewModel.dispose();
    if (!authChanges.isClosed) {
      await authChanges.close();
    }
  });

  group('AuthViewModel', () {
    test('initial status is AuthStatus.loading', () {
      var notifies = 0;
      viewModel = createViewModel();
      viewModel.addListener(() => notifies++);

      expect(viewModel.status, AuthStatus.loading);
      expect(viewModel.user, isNull);
      expect(viewModel.isLoading, isTrue);
      expect(notifies, 0);
    });

    test(
      'auth state change with a valid user authenticates and exposes getters',
      () async {
        viewModel = createViewModel();
        var notifies = 0;
        viewModel.addListener(() => notifies++);

        sessionCompleter.complete(null);
        await _flush();

        expect(viewModel.status, AuthStatus.unauthenticated);
        expect(notifies, 1);

        when(() => userRepo.getSessionUser()).thenAnswer((_) async => testUser);

        authChanges.add(firebaseUser);
        await _flush();
        await _flush();

        expect(viewModel.status, AuthStatus.authenticated);
        expect(viewModel.user, same(testUser));
        expect(viewModel.currentUser, same(testUser));
        expect(viewModel.companyId, testUser.companyId);
        expect(viewModel.role, testUser.role);
        expect(viewModel.isAuthenticated, isTrue);
        expect(notifies, 2);
      },
    );

    test(
      'auth state change to null logs out and clears the user',
      () async {
        when(() => userRepo.getSessionUser()).thenAnswer((_) async => testUser);
        viewModel = createViewModel(session: () async => testUser);
        await _flush();
        await _flush();

        expect(viewModel.status, AuthStatus.authenticated);
        expect(viewModel.user, same(testUser));

        var notifies = 0;
        viewModel.addListener(() => notifies++);

        authChanges.add(null);
        await _flush();

        expect(viewModel.status, AuthStatus.unauthenticated);
        expect(viewModel.user, isNull);
        expect(viewModel.currentUser, isNull);
        expect(viewModel.companyId, isNull);
        expect(viewModel.role, isNull);
        expect(viewModel.isAuthenticated, isFalse);
        expect(notifies, 1);
      },
    );

    test(
      'registerFieldUser sets isRegistered on success and notifies twice',
      () async {
        viewModel = await createSettledViewModel();
        viewModel.pendingInviteCompanyId = 'company-1';
        viewModel.pendingInvitePlan = 'premium';

        when(() => userRepo.findActiveCompanyByInviteCode('JOINME')).thenAnswer(
          (_) async => ActiveCompanyInvite(
            companyId: 'company-1',
            companyName: 'Acme Builders',
            plan: 'premium',
            inviteCodeGeneratedAt:
                DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        );

        when(() => authService.createUser(any(), any())).thenAnswer(
          (_) async => userCredential,
        );

        var notifies = 0;
        AuthStatus? statusOnFirstNotify;
        var registeredOnFirstNotify = true;
        viewModel.addListener(() {
          notifies++;
          if (notifies == 1) {
            statusOnFirstNotify = viewModel.status;
            registeredOnFirstNotify = viewModel.isRegistered;
          }
        });

        await viewModel.registerFieldUser(
          fullName: 'Ali Raza',
          email: 'field@acme.test',
          password: 'password12',
          phone: '03001234567',
          inviteCode: 'JOINME',
          cnicNumber: '3520212345671',
          jobTitle: 'Site Engineer',
          assignedSite: 'Lahore Site',
        );

        expect(statusOnFirstNotify, AuthStatus.loading);
        expect(registeredOnFirstNotify, isFalse);
        expect(viewModel.isRegistered, isTrue);
        expect(viewModel.status, AuthStatus.authenticated);
        expect(viewModel.user?.role, 'field_user');
        expect(viewModel.companyId, 'company-1');
        expect(notifies, greaterThanOrEqualTo(2));
      },
    );

    test(
      'registerFieldUser leaves isRegistered false when auth service fails',
      () async {
        viewModel = await createSettledViewModel();
        when(() => authService.createUser(any(), any())).thenThrow(
          FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'in use',
          ),
        );

        var notifies = 0;
        viewModel.addListener(() => notifies++);

        await viewModel.registerFieldUser(
          fullName: 'Ali Raza',
          email: 'field@acme.test',
          password: 'password12',
          phone: '03001234567',
          inviteCode: 'JOINME',
          cnicNumber: '3520212345671',
          jobTitle: 'Site Engineer',
          assignedSite: 'Lahore Site',
        );

        expect(viewModel.isRegistered, isFalse);
        expect(viewModel.status, AuthStatus.error);
        expect(
          viewModel.errorMessage,
          'An account already exists with this email.',
        );
        expect(notifies, 2);
      },
    );

    test(
      'validateInviteCode toggles isValidatingInvite and stores company on success',
      () async {
        viewModel = await createSettledViewModel();
        when(() => userRepo.findActiveCompanyByInviteCode('JOINME')).thenAnswer(
          (_) async => ActiveCompanyInvite(
            companyId: 'company-9',
            companyName: 'Acme Builders',
            plan: 'basic',
            inviteCodeGeneratedAt:
                DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        );

        var notifies = 0;
        final validatingSnapshots = <bool>[];
        viewModel.addListener(() {
          notifies++;
          validatingSnapshots.add(viewModel.isValidatingInvite);
        });

        final ok = await viewModel.validateInviteCode('  joinme  ');

        expect(ok, isTrue);
        expect(validatingSnapshots, [true, false]);
        expect(viewModel.isValidatingInvite, isFalse);
        expect(viewModel.inviteError, isNull);
        expect(viewModel.pendingInviteCompanyId, 'company-9');
        expect(viewModel.pendingInviteCompanyName, 'Acme Builders');
        expect(viewModel.pendingInvitePlan, 'basic');
        expect(notifies, 2);
      },
    );

    test(
      'validateInviteCode sets inviteError and clears pending fields on failure',
      () async {
        viewModel = await createSettledViewModel();
        viewModel.pendingInviteCompanyId = 'stale';
        viewModel.pendingInviteCompanyName = 'Stale Co';
        viewModel.pendingInvitePlan = 'free';

        when(() => userRepo.findActiveCompanyByInviteCode('BADCODE')).thenAnswer(
          (_) async => null,
        );

        var notifies = 0;
        final validatingSnapshots = <bool>[];
        viewModel.addListener(() {
          notifies++;
          validatingSnapshots.add(viewModel.isValidatingInvite);
        });

        final ok = await viewModel.validateInviteCode('badcode');

        expect(ok, isFalse);
        expect(validatingSnapshots, [true, false]);
        expect(viewModel.isValidatingInvite, isFalse);
        expect(viewModel.pendingInviteCompanyId, isNull);
        expect(viewModel.pendingInviteCompanyName, isNull);
        expect(viewModel.pendingInvitePlan, isNull);
        expect(
          viewModel.inviteError,
          'This invite code is invalid, expired, or already inactive. Ask your CEO for the current company code.',
        );
        expect(notifies, 2);
      },
    );

    test(
      'validateInviteCode blocks when the company field-user seats are full',
      () async {
        viewModel = await createSettledViewModel();
        when(() => userRepo.findActiveCompanyByInviteCode('JOINME')).thenAnswer(
          (_) async => ActiveCompanyInvite(
            companyId: 'company-9',
            companyName: 'Acme Builders',
            plan: 'free',
            fieldUserCount: 3,
            inviteCodeGeneratedAt:
                DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        );

        final ok = await viewModel.validateInviteCode('JOINME');

        expect(ok, isFalse);
        expect(viewModel.pendingInviteCompanyId, isNull);
        expect(
          viewModel.inviteError,
          contains('already been used by the maximum number of Field Users'),
        );
      },
    );

    test(
      'validateInviteCode blocks an expired field-user invite code',
      () async {
        viewModel = await createSettledViewModel();
        when(() => userRepo.findActiveCompanyByInviteCode('JOINME')).thenAnswer(
          (_) async => ActiveCompanyInvite(
            companyId: 'company-9',
            companyName: 'Acme Builders',
            plan: 'basic',
            inviteCodeGeneratedAt:
                DateTime.now().subtract(const Duration(minutes: 31)),
          ),
        );

        final ok = await viewModel.validateInviteCode('JOINME');

        expect(ok, isFalse);
        expect(viewModel.pendingInviteCompanyId, isNull);
        expect(
          viewModel.inviteError,
          'This invite code has expired. Ask your CEO to generate a new one and try again.',
        );
      },
    );

    test(
      'validateInviteCode treats a missing generation timestamp as expired',
      () async {
        viewModel = await createSettledViewModel();
        when(() => userRepo.findActiveCompanyByInviteCode('JOINME')).thenAnswer(
          (_) async => const ActiveCompanyInvite(
            companyId: 'company-9',
            companyName: 'Acme Builders',
            plan: 'basic',
          ),
        );

        final ok = await viewModel.validateInviteCode('JOINME');

        expect(ok, isFalse);
        expect(
          viewModel.inviteError,
          contains('invite code has expired'),
        );
      },
    );

    test(
      'validateRegistrationEmail sets an error when the email is taken',
      () async {
        viewModel = await createSettledViewModel();
        when(() => authService.emailAlreadyRegistered('taken@acme.test'))
            .thenAnswer((_) async => true);

        await viewModel.validateRegistrationEmail('taken@acme.test');

        expect(
          viewModel.registrationEmailError,
          'An account already exists with this email.',
        );
      },
    );

    test(
      'validateInviteCode maps Firestore permission errors',
      () async {
        viewModel = await createSettledViewModel();
        when(() => userRepo.findActiveCompanyByInviteCode(any())).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'denied',
          ),
        );

        var notifies = 0;
        viewModel.addListener(() => notifies++);

        final ok = await viewModel.validateInviteCode('JOINME');

        expect(ok, isFalse);
        expect(
          viewModel.inviteError,
          'Could not verify code. Firestore access denied — deploy the latest security rules.',
        );
        expect(notifies, 2);
      },
    );

    test(
      'signIn maps a Firestore internal assertion to a refresh prompt',
      () async {
        viewModel = await createSettledViewModel();
        when(() => authService.signIn(any(), any())).thenThrow(
          Exception(
            'FIRESTORE (11.9.1) INTERNAL ASSERTION FAILED: Unexpected state (ID: b815)',
          ),
        );

        final ok = await viewModel.signIn('ceo@acme.test', 'password12');

        expect(ok, isFalse);
        expect(viewModel.status, AuthStatus.error);
        expect(
          viewModel.errorMessage,
          'Connection to the database was interrupted. Refresh the page and sign in again.',
        );
      },
    );

    test(
      'signIn sets errorMessage and AuthStatus.error when the auth service throws',
      () async {
        viewModel = await createSettledViewModel();
        when(() => authService.signIn(any(), any())).thenThrow(
          FirebaseAuthException(
            code: 'wrong-password',
            message: 'bad password',
          ),
        );

        var notifies = 0;
        AuthStatus? statusOnFirstNotify;
        viewModel.addListener(() {
          notifies++;
          if (notifies == 1) {
            statusOnFirstNotify = viewModel.status;
          }
        });

        final ok = await viewModel.signIn('ceo@acme.test', 'wrong');

        expect(ok, isFalse);
        expect(statusOnFirstNotify, AuthStatus.loading);
        expect(viewModel.status, AuthStatus.error);
        expect(viewModel.errorMessage, 'Incorrect email or password.');
        expect(notifies, 2);
      },
    );

    test(
      'signIn still loads the profile if authStateChanges fires before Firestore',
      () async {
        viewModel = await createSettledViewModel();
        final profiles = StreamController<UserModel>.broadcast();
        addTearDown(profiles.close);

        when(() => userRepo.watchUserDoc(any())).thenAnswer(
          (_) => profiles.stream,
        );
        when(() => authService.signIn(any(), any())).thenAnswer((_) async {
          when(() => authService.currentUser).thenReturn(firebaseUser);
          return userCredential;
        });

        final pending = viewModel.signIn('ceo@acme.test', 'password12');
        await _flush();
        authChanges.add(firebaseUser);
        await _flush();
        profiles.add(testUser);
        await _flush();

        expect(await pending, isTrue);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.user?.uid, testUser.uid);
        expect(viewModel.status, AuthStatus.authenticated);
      },
    );
  });
}
