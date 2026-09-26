import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_session_viewmodel.dart';

import '../../mocks/mocks.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

UserModel _user({
  String uid = 'field-1',
  String name = 'Ali Raza',
  String phone = '03001234567',
  String companyId = 'co-1',
}) {
  return UserModel(
    uid: uid,
    email: '$uid@co.test',
    name: name,
    role: 'field_user',
    companyId: companyId,
    phone: phone,
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

CompanyModel _company({
  String id = 'co-1',
  String name = 'Acme Builders',
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _waitUntil(bool Function() test, {String because = 'timed out'}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = _user();
  final company = _company();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(user);
    registerFallbackValue(company);
  });

  late MockCompanyRepository companyRepo;
  late MockUserRepository userRepo;
  late MockAuthViewModel auth;
  late FieldSessionViewModel viewModel;

  setUp(() {
    companyRepo = MockCompanyRepository();
    userRepo = MockUserRepository();
    auth = MockAuthViewModel();
    when(() => auth.user).thenReturn(user);
    when(() => companyRepo.getCompanyById(any())).thenAnswer((_) async => company);
    when(() => userRepo.getUserDoc(any())).thenAnswer((_) async => user);
    when(() => userRepo.updateUserDoc(any(), any())).thenAnswer((_) async {});
    viewModel = FieldSessionViewModel(companyRepo, userRepo);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('FieldSessionViewModel.updateAuth', () {
    test('loads company context when a field user is signed in', () async {
      viewModel.updateAuth(auth);
      await _waitUntil(
        () => viewModel.company != null && !viewModel.isLoading,
        because: 'company context did not load',
      );

      expect(viewModel.user, same(user));
      expect(viewModel.companyId, 'co-1');
      expect(viewModel.companyName, 'Acme Builders');
      expect(viewModel.errorMessage, isNull);
      verify(() => companyRepo.getCompanyById('co-1')).called(1);
    });

    test('clears company and skips load when auth has no user', () async {
      viewModel.updateAuth(auth);
      await _waitUntil(() => viewModel.company != null);

      when(() => auth.user).thenReturn(null);
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.updateAuth(auth);

      expect(viewModel.user, isNull);
      expect(viewModel.company, isNull);
      expect(viewModel.companyId, isNull);
      expect(viewModel.companyName, 'Loading...');
      expect(notifies, 1);
    });
  });

  group('FieldSessionViewModel.loadCompanyContext', () {
    test('no-ops when no user is set', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.loadCompanyContext();

      expect(notifies, 0);
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => companyRepo.getCompanyById(any()));
    });

    test('success toggles loading and stores the company', () async {
      when(() => auth.user).thenReturn(user);
      viewModel.updateAuth(auth);
      await _waitUntil(() => !viewModel.isLoading);

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.loadCompanyContext();

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.company?.name, 'Acme Builders');
      expect(notifies, 2);
    });

    test('repository failure sets errorMessage and clears loading', () async {
      when(() => companyRepo.getCompanyById(any()))
          .thenThrow(AppException('company missing'));
      viewModel.updateAuth(auth);
      await _waitUntil(() => !viewModel.isLoading);

      expect(viewModel.errorMessage, 'company missing');
      expect(viewModel.company, isNull);
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('FieldSessionViewModel.refreshProfile', () {
    test('no-ops when no user is set', () async {
      await viewModel.refreshProfile();
      verifyNever(() => userRepo.getUserDoc(any()));
    });

    test('reloads the user then company context', () async {
      viewModel.updateAuth(auth);
      await _waitUntil(() => viewModel.company != null);

      final refreshed = _user(name: 'Ali Updated', phone: '03111111111');
      when(() => userRepo.getUserDoc('field-1')).thenAnswer((_) async => refreshed);

      await viewModel.refreshProfile();
      await _waitUntil(() => !viewModel.isLoading);

      expect(viewModel.user?.name, 'Ali Updated');
      expect(viewModel.user?.phone, '03111111111');
      expect(viewModel.companyName, 'Acme Builders');
      expect(viewModel.errorMessage, isNull);
      verify(() => userRepo.getUserDoc('field-1')).called(1);
      verify(() => companyRepo.getCompanyById('co-1')).called(greaterThan(1));
    });

    test('getUserDoc failure sets error and skips company reload', () async {
      viewModel.updateAuth(auth);
      await _waitUntil(() => !viewModel.isLoading);
      clearInteractions(companyRepo);

      when(() => userRepo.getUserDoc(any()))
          .thenThrow(AppException('profile unavailable'));

      await viewModel.refreshProfile();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'profile unavailable');
      expect(viewModel.user?.name, 'Ali Raza');
      verifyNever(() => companyRepo.getCompanyById(any()));
    });
  });

  group('FieldSessionViewModel.updateProfile', () {
    test('returns false without notifying when no user is set', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      final ok = await viewModel.updateProfile(name: 'X');

      expect(ok, isFalse);
      expect(notifies, 0);
      verifyNever(() => userRepo.updateUserDoc(any(), any()));
    });

    test('success writes only provided fields and updates local user', () async {
      viewModel.updateAuth(auth);
      await _waitUntil(() => !viewModel.isLoading);

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      final ok = await viewModel.updateProfile(name: 'New Name', phone: '0399');

      expect(ok, isTrue);
      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.user?.name, 'New Name');
      expect(viewModel.user?.phone, '0399');
      expect(notifies, 2);
      verify(() => userRepo.updateUserDoc('field-1', {
            'name': 'New Name',
            'phone': '0399',
          })).called(1);
    });

    test('omitted fields are not written', () async {
      viewModel.updateAuth(auth);
      await _waitUntil(() => !viewModel.isLoading);

      await viewModel.updateProfile(name: 'Only Name');

      verify(() => userRepo.updateUserDoc('field-1', {'name': 'Only Name'}))
          .called(1);
      expect(viewModel.user?.phone, '03001234567');
    });

    test('repository failure returns false and keeps the previous user',
        () async {
      viewModel.updateAuth(auth);
      await _waitUntil(() => !viewModel.isLoading);
      when(() => userRepo.updateUserDoc(any(), any()))
          .thenThrow(AppException('write denied'));

      final ok = await viewModel.updateProfile(name: 'Nope');

      expect(ok, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'write denied');
      expect(viewModel.user?.name, 'Ali Raza');
    });
  });

  group('FieldSessionViewModel.clearError', () {
    test('clears errorMessage and notifies', () async {
      when(() => companyRepo.getCompanyById(any()))
          .thenThrow(AppException('boom'));
      viewModel.updateAuth(auth);
      await _waitUntil(() => viewModel.errorMessage != null);

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.clearError();

      expect(viewModel.errorMessage, isNull);
      expect(notifies, 1);
    });
  });
}
