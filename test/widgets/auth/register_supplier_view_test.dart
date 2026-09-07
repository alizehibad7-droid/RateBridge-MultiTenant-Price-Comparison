import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/constants/pakistan_cities.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/views/auth/register_supplier_view.dart';

import '../../mocks/mocks.dart';
import 'auth_widget_harness.dart';

final _cnicFront = kTinyPngBytes;
final _cnicBack = kTinyPngBytes;
final _shopPhoto = kTinyPngBytes;

CategoryModel _cement() => CategoryModel(
      id: 'cement',
      name: 'Cement',
      unit: 'bag',
      brands: const [],
      grades: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAuthWidgetFallbacks);

  late MockAuthViewModel auth;
  late MockMaterialRepository materials;

  setUp(() {
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
    materials = MockMaterialRepository();
    when(() => materials.getCategories()).thenAnswer((_) async => [_cement()]);
  });

  testWidgets('shows a spinner on Next while loading', (tester) async {
    when(() => auth.isLoading).thenReturn(true);

    await pumpAuthScreen(
      tester,
      child: const RegisterSupplierView(),
      auth: auth,
      materials: materials,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Next'), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows a snackbar when AuthViewModel reports an error',
      (tester) async {
    when(() => auth.errorMessage)
        .thenReturn('Could not create the supplier account.');

    await pumpAuthScreen(
      tester,
      child: const RegisterSupplierView(),
      auth: auth,
      materials: materials,
    );
    await tester.pump();

    expect(
      find.text('Could not create the supplier account.'),
      findsOneWidget,
    );
    verify(auth.clearError).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Next shows form validation errors for invalid step-1 input',
      (tester) async {
    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: const RegisterSupplierView(),
      auth: auth,
      materials: materials,
    );

    await tester.ensureVisible(primaryButton('Next'));
    await tester.tap(primaryButton('Next'));
    await tester.pump();

    expect(find.text('Business name is required'), findsOneWidget);
    expect(find.text('Years in business is required'), findsOneWidget);
    expect(find.text('Owner name is required'), findsOneWidget);
    expect(find.text('CNIC is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(
      () => auth.registerSupplier(
        ownerName: any(named: 'ownerName'),
        businessName: any(named: 'businessName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        phone: any(named: 'phone'),
        city: any(named: 'city'),
        cnic: any(named: 'cnic'),
        businessType: any(named: 'businessType'),
        businessAddress: any(named: 'businessAddress'),
        categories: any(named: 'categories'),
        yearsInBusiness: any(named: 'yearsInBusiness'),
        businessRegistrationNumber: any(named: 'businessRegistrationNumber'),
        deliveryCoverageAreas: any(named: 'deliveryCoverageAreas'),
        cnicFrontBytes: any(named: 'cnicFrontBytes'),
        cnicBackBytes: any(named: 'cnicBackBytes'),
        shopPhotoBytes: any(named: 'shopPhotoBytes'),
        businessLicenseBytes: any(named: 'businessLicenseBytes'),
        certificationBytes: any(named: 'certificationBytes'),
      ),
    );

    await tester.enterText(
      textFieldByHint('sales@business.com'),
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
      child: const RegisterSupplierView(),
      auth: auth,
      materials: materials,
    );

    await _fillSupplierStepOne(tester);
    await tester.ensureVisible(primaryButton('Next'));
    await tester.tap(primaryButton('Next'));
    await tester.pump();

    expect(find.text('CNIC front and back photos are required'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('Submit Application calls registerSupplier with form values',
      (tester) async {
    useLargeSurface(tester);
    await pumpAuthScreen(
      tester,
      child: RegisterSupplierView(
        debugCnicFrontBytes: _cnicFront,
        debugCnicBackBytes: _cnicBack,
        debugShopPhotoBytes: _shopPhoto,
      ),
      auth: auth,
      materials: materials,
    );
    await tester.pumpAndSettle();

    await _fillSupplierStepOne(tester);
    await tapVisible(tester, primaryButton('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);

    await selectDropdownValue(tester, hint: 'Select city', value: 'Lahore');
    await tester.enterText(
      textFieldByHint('Warehouse / shop address with landmark'),
      'Shop 4 Industrial Area',
    );

    await tapVisible(tester, find.widgetWithText(FilterChip, 'Karachi'));
    await tester.pump();

    await tapVisible(tester, primaryButton('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tapVisible(tester, find.text('Cement'));
    await tester.pump();

    await tapVisible(tester, primaryButton('Submit Application'));
    await tester.pump();

    verify(auth.clearError).called(greaterThanOrEqualTo(1));
    verify(
      () => auth.registerSupplier(
        ownerName: 'Ahmed Khan',
        businessName: 'Skyline Building Materials',
        email: 'sales@acme.test',
        password: 'password1',
        phone: '03001234567',
        city: 'Lahore',
        cnic: '35202-1234567-1',
        businessType: kSupplierLegalBusinessTypes.first,
        businessAddress: 'Shop 4 Industrial Area',
        categories: ['Cement'],
        yearsInBusiness: 5,
        businessRegistrationNumber: null,
        deliveryCoverageAreas: ['Karachi'],
        cnicFrontBytes: _cnicFront,
        cnicBackBytes: _cnicBack,
        shopPhotoBytes: _shopPhoto,
        businessLicenseBytes: null,
        certificationBytes: null,
      ),
    ).called(1);
  });
}

Future<void> _fillSupplierStepOne(WidgetTester tester) async {
  await tester.enterText(
    textFieldByHint('Skyline Building Materials'),
    'Skyline Building Materials',
  );
  await tester.enterText(textFieldByHint('5'), '5');
  await tester.enterText(textFieldByHint('Ahmed Khan'), 'Ahmed Khan');
  await tester.enterText(textFieldByHint('35202-1234567-1'), '3520212345671');
  await tester.enterText(textFieldByHint('0300 1234567'), '03001234567');
  await tester.enterText(
    textFieldByHint('sales@business.com'),
    'sales@acme.test',
  );
  final passwords = textFieldByHint('••••••••');
  await tester.enterText(passwords.at(0), 'password1');
  await tester.enterText(passwords.at(1), 'password1');
}
