import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/invitation_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/views/auth/invite_landing_view.dart';

import '../../mocks/mocks.dart';
import 'auth_widget_harness.dart';

InvitationModel _pendingInvite({
  String token = 'INVITE99',
  String status = 'pending',
}) {
  return InvitationModel(
    token: token,
    companyId: 'co-1',
    ceoUid: 'ceo-1',
    email: 'field@acme.test',
    role: 'field_user',
    companyName: 'Acme Builders',
    status: status,
    expiresAt: DateTime.now().add(const Duration(days: 7)),
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

CompanyModel _company() {
  return CompanyModel(
    id: 'co-1',
    name: 'Acme Builders',
    registrationNumber: 'NTN-1',
    address: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

UserModel _user() {
  return UserModel(
    uid: 'u-1',
    email: 'field@acme.test',
    name: 'Ali Raza',
    role: 'field_user',
    companyId: 'co-1',
    phone: '03001234567',
    city: 'Lahore',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAuthWidgetFallbacks);

  late MockAuthViewModel auth;
  late MockInviteViewModel invite;
  late MockFirestoreService firestore;

  setUp(() {
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
    invite = MockInviteViewModel();
    stubInviteViewModel(invite);
    firestore = MockFirestoreService();
    when(() => firestore.getCompany(any())).thenAnswer((_) async => _company());
  });

  testWidgets('shows a spinner while the invitation is loading',
      (tester) async {
    final gate = Completer<void>();
    when(() => invite.loadInvitation(any())).thenAnswer((_) => gate.future);

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'INVITE99'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    when(() => invite.invitation).thenReturn(_pendingInvite());
    gate.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('shows Invalid Invitation Link when loadInvitation errors',
      (tester) async {
    when(() => invite.error).thenReturn('Invite token is not recognized.');

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'BAD'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Invalid Invitation Link'), findsOneWidget);
    expect(find.text('Invite token is not recognized.'), findsOneWidget);
    expect(find.text('RETURN TO SIGN IN'), findsOneWidget);
    verify(() => invite.loadInvitation('BAD')).called(1);
  });

  testWidgets('shows expired copy when the invitation is past expiry',
      (tester) async {
    when(() => invite.invitation).thenReturn(
      InvitationModel(
        token: 'OLD',
        companyId: 'co-1',
        ceoUid: 'ceo-1',
        email: 'field@acme.test',
        role: 'field_user',
        companyName: 'Acme Builders',
        status: 'pending',
        expiresAt: DateTime.utc(2020, 1, 1),
        createdAt: DateTime.utc(2019, 1, 1),
      ),
    );

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'OLD'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Invalid Invitation Link'), findsOneWidget);
    expect(find.text('This invitation has expired.'), findsOneWidget);
  });

  testWidgets('logged-out visitors see SIGN UP and SIGN IN', (tester) async {
    when(() => invite.invitation).thenReturn(_pendingInvite());

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'INVITE99'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Corporate Invitation'), findsOneWidget);
    expect(find.text('Acme Builders'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('ACCEPT & SECURE ACCOUNT'), findsNothing);
  });

  testWidgets('ACCEPT & SECURE ACCOUNT shows a spinner while accepting',
      (tester) async {
    when(() => auth.user).thenReturn(_user());
    when(() => invite.invitation).thenReturn(_pendingInvite());
    when(() => invite.isLoading).thenReturn(true);

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'INVITE99'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('ACCEPT & SECURE ACCOUNT calls acceptInvite with the token',
      (tester) async {
    when(() => auth.user).thenReturn(_user());
    when(() => invite.invitation).thenReturn(_pendingInvite());

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'INVITE99'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );
    await tester.pump();
    await tester.pump();

    await tapVisible(tester, find.text('ACCEPT & SECURE ACCOUNT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(() => invite.acceptInvite('INVITE99')).called(greaterThanOrEqualTo(1));
    expect(find.text('Team invitation accepted! Redirecting...'), findsOneWidget);
    expect(find.text('field-home'), findsOneWidget);
  });

  testWidgets('shows an error snackbar when acceptInvite fails', (tester) async {
    when(() => auth.user).thenReturn(_user());
    when(() => invite.invitation).thenReturn(_pendingInvite());
    when(() => invite.acceptInvite(any())).thenAnswer((_) async {
      when(() => invite.error).thenReturn('This invite was already used.');
    });

    await pumpAuthScreen(
      tester,
      child: const InviteLandingView(companyId: 'co-1', code: 'INVITE99'),
      auth: auth,
      invite: invite,
      firestore: firestore,
    );
    await tester.pump();
    await tester.pump();

    await tapVisible(tester, find.text('ACCEPT & SECURE ACCOUNT'));
    await tester.pump();
    await tester.pump();

    expect(find.text('This invite was already used.'), findsOneWidget);
    expect(find.text('field-home'), findsNothing);
  });
}
