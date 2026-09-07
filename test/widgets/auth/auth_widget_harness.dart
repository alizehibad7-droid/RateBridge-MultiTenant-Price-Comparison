import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/repositories/material_repository.dart';
import 'package:ratebridge/services/firebase_auth_service.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/invite_viewmodel.dart';

import '../../mocks/mocks.dart';

Finder textFieldByHint(String hint) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.hintText == hint,
    ),
    matching: find.byType(EditableText),
  );
}

Finder primaryButton(String label) {
  return find.widgetWithText(ElevatedButton, label);
}

/// 1x1 PNG so Image.memory can decode debug registration photos.
final Uint8List kTinyPngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> selectDropdownValue(
  WidgetTester tester, {
  required String hint,
  required String value,
}) async {
  await tapVisible(tester, find.text(hint));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(value).last);
  await tester.pump();
}

void stubAuthViewModel(MockAuthViewModel auth) {
  when(() => auth.isLoading).thenReturn(false);
  when(() => auth.errorMessage).thenReturn(null);
  when(() => auth.isAuthenticated).thenReturn(false);
  when(() => auth.isRegistered).thenReturn(false);
  when(() => auth.user).thenReturn(null);
  when(() => auth.role).thenReturn(null);
  when(() => auth.pendingInviteCompanyId).thenReturn(null);
  when(() => auth.pendingInviteCompanyName).thenReturn(null);
  when(() => auth.inviteError).thenReturn(null);
  when(() => auth.isValidatingInvite).thenReturn(false);
  when(() => auth.registrationEmailError).thenReturn(null);
  when(() => auth.isCheckingEmail).thenReturn(false);
  when(auth.clearError).thenReturn(null);
  when(auth.clearInviteValidation).thenReturn(null);
  when(auth.clearRegistrationEmailError).thenReturn(null);
  when(() => auth.signIn(any(), any())).thenAnswer((_) async => false);
  when(() => auth.validateInviteCode(any())).thenAnswer((_) async => true);
  when(() => auth.validateRegistrationEmail(any())).thenAnswer((_) async {});
  when(
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
  ).thenAnswer((_) async {});
  when(
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
  ).thenAnswer((_) async {});
  when(
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
  ).thenAnswer((_) async {});
}

void stubInviteViewModel(MockInviteViewModel invite) {
  when(() => invite.invitation).thenReturn(null);
  when(() => invite.error).thenReturn(null);
  when(() => invite.isLoading).thenReturn(false);
  when(() => invite.loadInvitation(any())).thenAnswer((_) async {});
  when(() => invite.acceptInvite(any())).thenAnswer((_) async {});
}

void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpAuthScreen(
  WidgetTester tester, {
  required Widget child,
  required MockAuthViewModel auth,
  MockInviteViewModel? invite,
  MockFirebaseAuthService? authService,
  MockFirestoreService? firestore,
  MockMaterialRepository? materials,
}) async {
  useLargeSurface(tester);
  GoogleFonts.config.allowRuntimeFetching = false;
  Provider.debugCheckInvalidValueType = null;

  final inviteVm = invite ?? MockInviteViewModel();
  if (invite == null) stubInviteViewModel(inviteVm);

  final firebaseAuth = authService ?? MockFirebaseAuthService();
  final firestoreService = firestore ?? MockFirestoreService();
  final materialRepo = materials ?? MockMaterialRepository();

  if (authService == null) {
    when(() => firebaseAuth.sendPasswordReset(any())).thenAnswer((_) async {});
  }
  if (firestore == null) {
    when(() => firestoreService.getCompany(any())).thenAnswer((_) async => null);
  }
  if (materials == null) {
    when(() => materialRepo.getCategories()).thenAnswer((_) async => []);
  }

  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('root-screen')),
        routes: [
          GoRoute(path: 'screen', builder: (_, __) => child),
        ],
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const Scaffold(body: Text('login-screen')),
      ),
      GoRoute(
        path: RouteNames.registerCEO,
        builder: (_, __) => const Scaffold(body: Text('ceo-reg')),
      ),
      GoRoute(
        path: RouteNames.registerSupplier,
        builder: (_, __) => const Scaffold(body: Text('supplier-reg')),
      ),
      GoRoute(
        path: RouteNames.registerFieldUser,
        builder: (_, __) => const Scaffold(body: Text('field-reg')),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (_, __) => const Scaffold(body: Text('forgot-screen')),
      ),
      GoRoute(
        path: RouteNames.fieldHome,
        builder: (_, __) => const Scaffold(body: Text('field-home')),
      ),
      GoRoute(
        path: RouteNames.ceoPending,
        builder: (_, __) => const Scaffold(body: Text('ceo-pending')),
      ),
      GoRoute(
        path: RouteNames.supplierPending,
        builder: (_, __) => const Scaffold(body: Text('supplier-pending')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthViewModel>.value(value: auth),
        Provider<InviteViewModel>.value(value: inviteVm),
        Provider<FirebaseAuthService>.value(value: firebaseAuth),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<MaterialRepository>.value(value: materialRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void registerAuthWidgetFallbacks() {
  Provider.debugCheckInvalidValueType = null;
  registerFallbackValue('');
  registerFallbackValue(0);
  registerFallbackValue(0.0);
  registerFallbackValue(Uint8List(0));
  registerFallbackValue(<String>[]);
  registerFallbackValue(<int>[]);
}
