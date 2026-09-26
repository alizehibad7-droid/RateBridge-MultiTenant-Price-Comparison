import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/auth/register_field_user_view.dart';

import '../../mocks/mocks.dart';
import 'auth_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAuthWidgetFallbacks);

  late MockAuthViewModel auth;

  setUp(() {
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
  });

  testWidgets('shows invite error chip when invite validation failed',
      (tester) async {
    when(() => auth.inviteError).thenReturn('Invite code is not valid.');

    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    expect(find.text('Invite code is not valid.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsWidgets);
  });

  testWidgets('shows company chip and disables Create Account while loading',
      (tester) async {
    when(() => auth.pendingInviteCompanyId).thenReturn('co-1');
    when(() => auth.pendingInviteCompanyName).thenReturn('Acme Builders');
    when(() => auth.isLoading).thenReturn(true);

    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    expect(find.text("You'll join Acme Builders"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Create Account'), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows a snackbar when AuthViewModel reports an error',
      (tester) async {
    when(() => auth.errorMessage).thenReturn('Email is already in use.');
    when(() => auth.pendingInviteCompanyId).thenReturn('co-1');

    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Email is already in use.'), findsOneWidget);
    verify(auth.clearError).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Create Account is disabled until an invite company is resolved',
      (tester) async {
    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    expect(
      tester.widget<ElevatedButton>(primaryButton('Create Account')).onPressed,
      isNull,
    );
  });

  testWidgets('shows validation messages for invalid input', (tester) async {
    when(() => auth.pendingInviteCompanyId).thenReturn('co-1');
    when(() => auth.pendingInviteCompanyName).thenReturn('Acme Builders');

    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    await tester.ensureVisible(primaryButton('Create Account'));
    await tester.tap(primaryButton('Create Account'));
    await tester.pump();

    expect(find.text('Invite code is required'), findsOneWidget);
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(
      () => auth.registerFieldUser(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        phone: any(named: 'phone'),
        inviteCode: any(named: 'inviteCode'),
        cnicNumber: any(named: 'cnicNumber'),
        jobTitle: any(named: 'jobTitle'),
        assignedSite: any(named: 'assignedSite'),
      ),
    );

    await tester.enterText(textFieldByHint('you@example.com'), 'bad-email');
    await tester.enterText(textFieldByHint('••••••••').first, 'short');
    await tester.ensureVisible(primaryButton('Create Account'));
    await tester.tap(primaryButton('Create Account'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('Create Account calls registerFieldUser with form values',
      (tester) async {
    when(() => auth.pendingInviteCompanyId).thenReturn('co-1');
    when(() => auth.pendingInviteCompanyName).thenReturn('Acme Builders');

    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    await tester.enterText(textFieldByHint('RB-X7K2PQ'), 'RB-X7K2PQ');
    await tester.enterText(textFieldByHint('Ali Raza'), 'Ali Raza');
    await tester.enterText(textFieldByHint('0300 1234567'), '03001234567');
    await tester.enterText(textFieldByHint('you@example.com'), 'ali@acme.test');

    final passwords = textFieldByHint('••••••••');
    await tester.enterText(passwords.at(0), 'password1');
    await tester.enterText(passwords.at(1), 'password1');

    await tester.enterText(textFieldByHint('35202-1234567-1'), '3520212345671');
    await tester.enterText(
      textFieldByHint('Site B - DHA Phase 6'),
      'Site B - DHA Phase 6',
    );

    await tester.ensureVisible(primaryButton('Create Account'));
    await tester.tap(primaryButton('Create Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    verify(auth.clearError).called(greaterThanOrEqualTo(1));
    verify(
      () => auth.registerFieldUser(
        fullName: 'Ali Raza',
        email: 'ali@acme.test',
        password: 'password1',
        phone: '03001234567',
        inviteCode: 'RB-X7K2PQ',
        cnicNumber: '35202-1234567-1',
        jobTitle: 'Site Supervisor',
        assignedSite: 'Site B - DHA Phase 6',
      ),
    ).called(1);
  });

  testWidgets('validates invite code when the field loses focus',
      (tester) async {
    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    await tester.enterText(textFieldByHint('RB-X7K2PQ'), 'RB-USED01');
    await tester.enterText(textFieldByHint('Ali Raza'), 'Ali Raza');
    await tester.pump();

    verify(() => auth.validateInviteCode('RB-USED01'))
        .called(greaterThanOrEqualTo(1));
  });

  testWidgets('shows a claimed-code error on the invite field immediately',
      (tester) async {
    when(() => auth.inviteError).thenReturn(
      'This invite code has already been used by the maximum number of Field Users (3 on the Free plan). Ask your CEO to upgrade or free a seat.',
    );

    await pumpAuthScreen(
      tester,
      child: const RegisterFieldUserView(),
      auth: auth,
    );

    expect(
      find.textContaining('already been used by the maximum number of Field Users'),
      findsWidgets,
    );
  });
}
