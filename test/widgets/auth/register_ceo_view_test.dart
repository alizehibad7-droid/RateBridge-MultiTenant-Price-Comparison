import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/constants/ceo_registration_options.dart';
import 'package:ratebridge/views/auth/register_ceo_view.dart';

import '../../mocks/mocks.dart';
import 'auth_widget_harness.dart';

final _cnicFront = kTinyPngBytes;
final _cnicBack = kTinyPngBytes;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAuthWidgetFallbacks);

  late MockAuthViewModel auth;

  setUp(() {
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
  });

  testWidgets('shows a spinner on Next while loading', (tester) async {
    when(() => auth.isLoading).thenReturn(true);

    await pumpAuthScreen(
      tester,
      child: const RegisterCeoView(),
      auth: auth,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Next'), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows a snackbar when AuthViewModel reports an error',
      (tester) async {
    when(() => auth.errorMessage)
        .thenReturn('Could not create the company account.');

    await pumpAuthScreen(
      tester,
      child: const RegisterCeoView(),
      auth: auth,
    );
    await tester.pump();

    expect(find.text('Could not create the company account.'), findsOneWidget);
    verify(auth.clearError).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Next shows form validation errors for invalid step-1 input',
      (tester) async {
    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: const RegisterCeoView(),
      auth: auth,
    );

    await tester.ensureVisible(primaryButton('Next'));
    await tester.tap(primaryButton('Next'));
    await tester.pump();

    expect(find.text('Company name is required'), findsOneWidget);
    expect(find.text('Years in operation is required'), findsOneWidget);
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('CNIC is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(
      () => auth.registerCEO(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        phone: any(named: 'phone'),
        companyName: any(named: 'companyName'),
        companyType: any(named: 'companyType'),
        yearsInOperation: any(named: 'yearsInOperation'),
        registrationNumber: any(named: 'registrationNumber'),
        designation: any(named: 'designation'),
        cnic: any(named: 'cnic'),
        city: any(named: 'city'),
        address: any(named: 'address'),
        estimatedMonthlyVolume: any(named: 'estimatedMonthlyVolume'),
        activeSitesCount: any(named: 'activeSitesCount'),
        cnicFrontBytes: any(named: 'cnicFrontBytes'),
        cnicBackBytes: any(named: 'cnicBackBytes'),
        registrationCertBytes: any(named: 'registrationCertBytes'),
        officePhotoBytes: any(named: 'officePhotoBytes'),
      ),
    );

    await tester.enterText(
      textFieldByHint('ceo@company.com'),
      'not-an-email',
    );
    await tester.enterText(textFieldByHint('••••••••').first, 'short');
    await tester.ensureVisible(primaryButton('Next'));
    await tester.tap(primaryButton('Next'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('Next requires CNIC photos even when text fields are valid',
      (tester) async {
    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: const RegisterCeoView(),
      auth: auth,
    );

    await _fillCeoStepOne(tester);
    await tester.ensureVisible(primaryButton('Next'));
    await tester.tap(primaryButton('Next'));
    await tester.pump();

    expect(find.text('CNIC front and back photos are required'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('Submit Application calls registerCEO with form values',
      (tester) async {
    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: RegisterCeoView(
        debugCnicFrontBytes: _cnicFront,
        debugCnicBackBytes: _cnicBack,
      ),
      auth: auth,
    );

    await _fillCeoStepOne(tester);
    await tapVisible(tester, primaryButton('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);

    await selectDropdownValue(tester, hint: 'Select city', value: 'Lahore');
    await tester.enterText(
      textFieldByHint('Office address with landmark'),
      '12 Mall Road',
    );
    await selectDropdownValue(
      tester,
      hint: 'Select volume band',
      value: kProcurementVolumeBands.first,
    );
    await tester.enterText(textFieldByHint('3'), '3');

    await tapVisible(tester, primaryButton('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tapVisible(tester, primaryButton('Submit Application'));
    await tester.pump();

    verify(auth.clearError).called(greaterThanOrEqualTo(1));
    verify(
      () => auth.registerCEO(
        fullName: 'Ahmed Khan',
        email: 'ceo@acme.test',
        password: 'password1',
        phone: '03001234567',
        companyName: 'Usman Associates',
        companyType: kCompanyTypes.first,
        yearsInOperation: 10,
        registrationNumber: null,
        designation: kCeoDesignations.first,
        cnic: '35202-1234567-1',
        city: 'Lahore',
        address: '12 Mall Road',
        estimatedMonthlyVolume: kProcurementVolumeBands.first,
        activeSitesCount: 3,
        cnicFrontBytes: _cnicFront,
        cnicBackBytes: _cnicBack,
        registrationCertBytes: null,
        officePhotoBytes: null,
      ),
    ).called(1);
  });
}

Future<void> _fillCeoStepOne(WidgetTester tester) async {
  await tester.enterText(textFieldByHint('Usman Associates'), 'Usman Associates');
  await tester.enterText(textFieldByHint('10'), '10');
  await tester.enterText(textFieldByHint('Ahmed Khan'), 'Ahmed Khan');
  await tester.enterText(textFieldByHint('35202-1234567-1'), '3520212345671');
  await tester.enterText(textFieldByHint('0300 1234567'), '03001234567');
  await tester.enterText(textFieldByHint('ceo@company.com'), 'ceo@acme.test');
  final passwords = textFieldByHint('••••••••');
  await tester.enterText(passwords.at(0), 'password1');
  await tester.enterText(passwords.at(1), 'password1');
}
