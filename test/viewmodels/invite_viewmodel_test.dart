import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/invitation_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/invite_viewmodel.dart';

import '../mocks/mocks.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

InvitationModel _invite({
  String token = 'tok-1',
  String status = 'pending',
  String companyId = 'co-1',
  String companyName = 'Acme Builders',
}) {
  return InvitationModel(
    token: token,
    companyId: companyId,
    ceoUid: 'ceo-1',
    supplierUid: 'sup-1',
    companyName: companyName,
    status: status,
    expiresAt: DateTime.utc(2026, 5, 1),
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

UserModel _user({
  String uid = 'sup-1',
  String role = 'Supplier',
  String companyId = 'co-1',
}) {
  return UserModel(
    uid: uid,
    email: '$uid@co.test',
    name: 'Test User',
    role: role,
    companyId: companyId,
    phone: '03001234567',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invite = _invite();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(invite);
  });

  late MockInvitationRepository invitationRepo;
  late MockJoinRequestRepository joinRequestRepo;
  late MockDynamicLinkService dynamicLinks;
  late MockCloudFunctionService cloudFunctions;
  late MockAuthViewModel auth;
  late InviteViewModel viewModel;

  String? sharedText;
  String? sharedSubject;
  bool shareThrows = false;

  void createViewModel() {
    viewModel = InviteViewModel(
      invitationRepo,
      joinRequestRepo,
      dynamicLinks,
      cloudFunctions,
      shareText: (text, {subject}) async {
        sharedText = text;
        sharedSubject = subject;
        if (shareThrows) throw AppException('share failed');
      },
    );
  }

  setUp(() {
    invitationRepo = MockInvitationRepository();
    joinRequestRepo = MockJoinRequestRepository();
    dynamicLinks = MockDynamicLinkService();
    cloudFunctions = MockCloudFunctionService();
    auth = MockAuthViewModel();
    sharedText = null;
    sharedSubject = null;
    shareThrows = false;

    when(() => invitationRepo.getInvitation(any()))
        .thenAnswer((_) async => invite);
    when(() => invitationRepo.createInvitation(any(), any(), any(), any()))
        .thenAnswer((_) async => 'tok-1');
    when(() => invitationRepo.updateStatus(any(), any()))
        .thenAnswer((_) async {});
    when(
      () => joinRequestRepo.createJoinRequest(
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((_) async => 'req-1');
    when(
      () => joinRequestRepo.updateRequestStatus(
        any(),
        any(),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(() => dynamicLinks.generateInviteLink(any()))
        .thenAnswer((_) async => 'https://ratebridge.page.link/abc');
    when(() => cloudFunctions.callFunction(any(), any()))
        .thenAnswer((_) async => null);
    when(() => auth.user).thenReturn(_user());

    createViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('InviteViewModel.updateAuth', () {
    test('stores supplier uid and companyId and notifies', () {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.updateAuth(auth);

      expect(notifies, 1);
      expect(viewModel.error, isNull);
    });

    test('clears ids when auth has no user', () async {
      viewModel.updateAuth(auth);
      when(() => auth.user).thenReturn(null);

      viewModel.updateAuth(auth);

      await viewModel.loadInvitation('tok-1');
      await viewModel.acceptInvite('tok-1');

      verify(
        () => cloudFunctions.callFunction('onInviteAccepted', {
          'token': 'tok-1',
          'companyId': 'co-1',
          'supplierUid': null,
        }),
      ).called(1);
    });
  });

  group('InviteViewModel.loadInvitation', () {
    test('success stores a pending invite and toggles loading', () async {
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

      await viewModel.loadInvitation('tok-1');

      expect(loadingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.isExpired, isFalse);
      expect(viewModel.invitation, same(invite));
      expect(notifies, 2);
      verify(() => invitationRepo.getInvitation('tok-1')).called(1);
    });

    test('null invitation is treated as invalid', () async {
      when(() => invitationRepo.getInvitation(any()))
          .thenAnswer((_) async => null);

      await viewModel.loadInvitation('missing');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.invitation, isNull);
      expect(viewModel.isExpired, isFalse);
      expect(viewModel.error, 'Invitation not found or has been used.');
    });

    test('expired status flags the invite without setting error', () async {
      when(() => invitationRepo.getInvitation(any())).thenAnswer(
        (_) async => _invite(status: 'expired'),
      );

      await viewModel.loadInvitation('tok-1');

      expect(viewModel.isExpired, isTrue);
      expect(viewModel.error, isNull);
      expect(viewModel.invitation?.status, 'expired');
      expect(viewModel.isAccepted, isFalse);
      expect(viewModel.isRejected, isFalse);
    });

    test('accepted and rejected statuses still load as valid invites', () async {
      when(() => invitationRepo.getInvitation(any())).thenAnswer(
        (_) async => _invite(status: 'accepted'),
      );
      await viewModel.loadInvitation('tok-1');
      expect(viewModel.isExpired, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.invitation?.status, 'accepted');

      when(() => invitationRepo.getInvitation(any())).thenAnswer(
        (_) async => _invite(status: 'rejected'),
      );
      await viewModel.loadInvitation('tok-1');
      expect(viewModel.isExpired, isFalse);
      expect(viewModel.invitation?.status, 'rejected');
    });

    test('repository failure sets error and clears loading', () async {
      when(() => invitationRepo.getInvitation(any()))
          .thenThrow(AppException('lookup failed'));

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadInvitation('tok-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 2);
      expect(viewModel.error, 'lookup failed');
      expect(viewModel.invitation, isNull);
    });
  });

  group('InviteViewModel.acceptInvite', () {
    test('no-ops when no invitation has been loaded', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.acceptInvite('tok-1');

      expect(notifies, 0);
      expect(viewModel.isAccepted, isFalse);
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => cloudFunctions.callFunction(any(), any()));
    });

    test('success calls onInviteAccepted with auth supplier uid', () async {
      viewModel.updateAuth(auth);
      await viewModel.loadInvitation('tok-1');

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.acceptInvite('tok-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isAccepted, isTrue);
      expect(viewModel.error, isNull);
      expect(notifies, 2);
      verify(
        () => cloudFunctions.callFunction('onInviteAccepted', {
          'token': 'tok-1',
          'companyId': 'co-1',
          'supplierUid': 'sup-1',
        }),
      ).called(1);
    });

    test('cloud function failure sets error and leaves isAccepted false',
        () async {
      await viewModel.loadInvitation('tok-1');
      when(() => cloudFunctions.callFunction(any(), any()))
          .thenThrow(AppException('accept denied'));

      await viewModel.acceptInvite('tok-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isAccepted, isFalse);
      expect(viewModel.error, 'accept denied');
    });
  });

  group('InviteViewModel.rejectInvite', () {
    test('success marks the invite rejected', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.rejectInvite('tok-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isRejected, isTrue);
      expect(viewModel.error, isNull);
      expect(notifies, 2);
      verify(() => invitationRepo.updateStatus('tok-1', 'rejected')).called(1);
    });

    test('repository failure sets error and leaves isRejected false', () async {
      when(() => invitationRepo.updateStatus(any(), any()))
          .thenThrow(AppException('reject denied'));

      await viewModel.rejectInvite('tok-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isRejected, isFalse);
      expect(viewModel.error, 'reject denied');
    });
  });

  group('InviteViewModel.sendInvitation', () {
    test('success generates a token, builds a link, and shares it', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.sendInvitation(
        'sup-1',
        'co-1',
        'ceo-1',
        'Acme Builders',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);
      verify(
        () => invitationRepo.createInvitation(
          'co-1',
          'ceo-1',
          'sup-1',
          'Acme Builders',
        ),
      ).called(1);
      verify(() => dynamicLinks.generateInviteLink('tok-1')).called(1);
      expect(
        sharedText,
        'You have been invited to supply on RateBridge.\nTap to accept: https://ratebridge.page.link/abc',
      );
      expect(sharedSubject, 'RateBridge Supplier Invitation');
    });

    test('createInvitation failure skips link generation and share', () async {
      when(() => invitationRepo.createInvitation(any(), any(), any(), any()))
          .thenThrow(AppException('capacity reached'));

      await viewModel.sendInvitation(
        'sup-1',
        'co-1',
        'ceo-1',
        'Acme Builders',
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'capacity reached');
      verifyNever(() => dynamicLinks.generateInviteLink(any()));
      expect(sharedText, isNull);
    });

    test('generateInviteLink failure skips share', () async {
      when(() => dynamicLinks.generateInviteLink(any()))
          .thenThrow(AppException('link failed'));

      await viewModel.sendInvitation(
        'sup-1',
        'co-1',
        'ceo-1',
        'Acme Builders',
      );

      expect(viewModel.error, 'link failed');
      expect(sharedText, isNull);
    });

    test('share failure sets error after the link was generated', () async {
      shareThrows = true;

      await viewModel.sendInvitation(
        'sup-1',
        'co-1',
        'ceo-1',
        'Acme Builders',
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'share failed');
      verify(() => dynamicLinks.generateInviteLink('tok-1')).called(1);
    });
  });

  group('InviteViewModel.sendJoinRequest', () {
    test('success creates the request then notifies the company', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.sendJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const ['Cement'],
        4.5,
        'Ready stock',
      );

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(notifies, 2);
      verify(
        () => joinRequestRepo.createJoinRequest(
          'sup-1',
          'co-1',
          'Cement House',
          'Lahore',
          ['Cement'],
          4.5,
          'Ready stock',
        ),
      ).called(1);
      verify(
        () => cloudFunctions.callFunction('sendJoinRequestNotification', {
          'companyId': 'co-1',
          'supplierName': 'Cement House',
          'reqId': 'req-1',
        }),
      ).called(1);
    });

    test('createJoinRequest failure skips the notification', () async {
      when(
        () => joinRequestRepo.createJoinRequest(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenThrow(AppException('already requested'));

      await viewModel.sendJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const [],
        0,
        null,
      );

      expect(viewModel.error, 'already requested');
      verifyNever(() => cloudFunctions.callFunction(any(), any()));
    });

    test('notification failure sets error after the request is created',
        () async {
      when(() => cloudFunctions.callFunction(any(), any()))
          .thenThrow(AppException('notify failed'));

      await viewModel.sendJoinRequest(
        'sup-1',
        'co-1',
        'Cement House',
        'Lahore',
        const ['Cement'],
        4.5,
        null,
      );

      expect(viewModel.error, 'notify failed');
      verify(
        () => joinRequestRepo.createJoinRequest(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).called(1);
    });
  });

  group('InviteViewModel.acceptJoinRequest', () {
    test('success uses companyId from auth', () async {
      viewModel.updateAuth(auth);

      await viewModel.acceptJoinRequest('req-1', 'sup-9');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      verify(
        () => cloudFunctions.callFunction('onInviteAccepted', {
          'reqId': 'req-1',
          'companyId': 'co-1',
          'supplierUid': 'sup-9',
        }),
      ).called(1);
    });

    test('passes a null companyId when auth was never updated', () async {
      await viewModel.acceptJoinRequest('req-1', 'sup-9');

      verify(
        () => cloudFunctions.callFunction('onInviteAccepted', {
          'reqId': 'req-1',
          'companyId': null,
          'supplierUid': 'sup-9',
        }),
      ).called(1);
    });

    test('cloud function failure sets error', () async {
      when(() => cloudFunctions.callFunction(any(), any()))
          .thenThrow(AppException('join accept denied'));

      await viewModel.acceptJoinRequest('req-1', 'sup-9');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'join accept denied');
    });
  });

  group('InviteViewModel.rejectJoinRequest', () {
    test('forwards status and reason', () async {
      await viewModel.rejectJoinRequest('req-1', 'Not a fit');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      verify(
        () => joinRequestRepo.updateRequestStatus(
          'req-1',
          'rejected',
          reason: 'Not a fit',
        ),
      ).called(1);
    });

    test('allows a null reason', () async {
      await viewModel.rejectJoinRequest('req-1', null);

      verify(
        () => joinRequestRepo.updateRequestStatus(
          'req-1',
          'rejected',
          reason: null,
        ),
      ).called(1);
    });

    test('repository failure sets error', () async {
      when(
        () => joinRequestRepo.updateRequestStatus(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(AppException('join reject denied'));

      await viewModel.rejectJoinRequest('req-1', 'Nope');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'join reject denied');
    });
  });
}
