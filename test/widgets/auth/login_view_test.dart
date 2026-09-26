import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/auth/login_view.dart';

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

  testWidgets('shows error banner when AuthViewModel has an error',
      (tester) async {
    when(() => auth.errorMessage).thenReturn('Incorrect email or password.');

    await pumpAuthScreen(
      tester,
      child: const LoginView(),
      auth: auth,
    );

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('shows a spinner on Sign In while loading', (tester) async {
    when(() => auth.isLoading).thenReturn(true);

    await pumpAuthScreen(
      tester,
      child: const LoginView(),
      auth: auth,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('shows validation messages for empty and invalid input',
      (tester) async {
    await pumpAuthScreen(
      tester,
      child: const LoginView(),
      auth: auth,
    );

    await tapVisible(tester, primaryButton('Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(() => auth.signIn(any(), any()));

    await tester.enterText(textFieldByHint('Enter your email'), 'not-an-email');
    await tester.enterText(textFieldByHint('Enter your password'), 'secret');
    await tapVisible(tester, primaryButton('Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    verifyNever(() => auth.signIn(any(), any()));
  });

  testWidgets('Sign In calls clearError then signIn with field values',
      (tester) async {
    await pumpAuthScreen(
      tester,
      child: const LoginView(),
      auth: auth,
    );

    await tester.enterText(
      textFieldByHint('Enter your email'),
      'ceo@acme.test',
    );
    await tester.enterText(
      textFieldByHint('Enter your password'),
      'correct-horse',
    );
    await tapVisible(tester, primaryButton('Sign In'));
    await tester.pump();

    verifyInOrder([
      auth.clearError,
      () => auth.signIn('ceo@acme.test', 'correct-horse'),
    ]);
  });
}
