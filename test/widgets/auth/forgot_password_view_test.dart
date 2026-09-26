import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/views/auth/forgot_password_view.dart';

import '../../mocks/mocks.dart';
import 'auth_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAuthWidgetFallbacks);

  late MockAuthViewModel auth;
  late MockFirebaseAuthService authService;

  setUp(() {
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
    authService = MockFirebaseAuthService();
    when(() => authService.sendPasswordReset(any())).thenAnswer((_) async {});
  });

  testWidgets('shows a spinner on the primary button while sending reset',
      (tester) async {
    final gate = Completer<void>();
    when(() => authService.sendPasswordReset(any()))
        .thenAnswer((_) => gate.future);

    await pumpAuthScreen(
      tester,
      child: const ForgotPasswordView(),
      auth: auth,
      authService: authService,
    );

    await tester.enterText(
      textFieldByHint('name@company.com'),
      'ops@acme.test',
    );
    await tester.tap(primaryButton('Dispatch recovery link'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error snackbar when reset fails', (tester) async {
    when(() => authService.sendPasswordReset(any()))
        .thenThrow(AppException('No account for that email.'));

    await pumpAuthScreen(
      tester,
      child: const ForgotPasswordView(),
      auth: auth,
      authService: authService,
    );

    await tester.enterText(
      textFieldByHint('name@company.com'),
      'missing@acme.test',
    );
    await tester.tap(primaryButton('Dispatch recovery link'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Error: No account for that email.'), findsOneWidget);
  });

  testWidgets('rejects emails without @', (tester) async {
    await pumpAuthScreen(
      tester,
      child: const ForgotPasswordView(),
      auth: auth,
      authService: authService,
    );

    await tester.enterText(textFieldByHint('name@company.com'), 'not-an-email');
    await tester.tap(primaryButton('Dispatch recovery link'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    verifyNever(() => authService.sendPasswordReset(any()));
  });

  testWidgets('Dispatch recovery link sends the trimmed email', (tester) async {
    await pumpAuthScreen(
      tester,
      child: const ForgotPasswordView(),
      auth: auth,
      authService: authService,
    );

    await tester.enterText(
      textFieldByHint('name@company.com'),
      '  ceo@acme.test  ',
    );
    await tester.tap(primaryButton('Dispatch recovery link'));
    await tester.pumpAndSettle();

    verify(() => authService.sendPasswordReset('ceo@acme.test')).called(1);
    expect(
      find.text('Account recovery instructions dispatched successfully.'),
      findsOneWidget,
    );
    expect(find.text('root-screen'), findsOneWidget);
  });
}
