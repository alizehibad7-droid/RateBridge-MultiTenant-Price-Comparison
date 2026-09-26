import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ratebridge/viewmodels/locale_viewmodel.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
  });

  late MockSharedPreferences prefs;
  late Map<String, String> store;
  late LocaleViewModel viewModel;

  setUp(() {
    prefs = MockSharedPreferences();
    store = <String, String>{};

    when(() => prefs.getString(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments.first as String;
      return store[key];
    });
    when(() => prefs.setString(any(), any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1] as String;
      store[key] = value;
      return true;
    });

    viewModel = LocaleViewModel(prefs: prefs);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('LocaleViewModel defaults', () {
    test('starts on English before anything is loaded', () {
      expect(viewModel.languageCode, 'en');
      expect(viewModel.locale, const Locale('en'));
    });
  });

  group('LocaleViewModel.setLocale', () {
    test('switches to Urdu, persists the code, and notifies once', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.setLocale('ur');

      expect(viewModel.languageCode, 'ur');
      expect(viewModel.locale, const Locale('ur'));
      expect(notifies, 1);
      verify(() => prefs.setString('preferred_language', 'ur')).called(1);
      expect(store['preferred_language'], 'ur');
    });

    test('switches to Roman Urdu with the PK_ROMAN country tag', () async {
      await viewModel.setLocale('ur_roman');

      expect(viewModel.languageCode, 'ur_roman');
      expect(viewModel.locale, const Locale('ur', 'PK_ROMAN'));
      expect(store['preferred_language'], 'ur_roman');
    });

    test('switches back to English from Urdu', () async {
      await viewModel.setLocale('ur');
      await viewModel.setLocale('en');

      expect(viewModel.languageCode, 'en');
      expect(viewModel.locale, const Locale('en'));
      expect(store['preferred_language'], 'en');
    });

    test('unknown codes keep the raw languageCode but fall back to English locale',
        () async {
      await viewModel.setLocale('fr');

      expect(viewModel.languageCode, 'fr');
      expect(viewModel.locale, const Locale('en'));
      expect(store['preferred_language'], 'fr');
    });

    test('persist failure still applies the locale but does not notify',
        () async {
      when(() => prefs.setString(any(), any()))
          .thenThrow(Exception('prefs unavailable'));

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await expectLater(
        viewModel.setLocale('ur'),
        throwsA(isA<Exception>()),
      );

      expect(viewModel.languageCode, 'ur');
      expect(viewModel.locale, const Locale('ur'));
      expect(notifies, 0);
    });
  });

  group('LocaleViewModel.loadSavedLocale', () {
    test('returns false and does not notify when nothing is saved', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      final loaded = await viewModel.loadSavedLocale();

      expect(loaded, isFalse);
      expect(notifies, 0);
      expect(viewModel.languageCode, 'en');
      expect(viewModel.locale, const Locale('en'));
      verify(() => prefs.getString('preferred_language')).called(1);
      verifyNever(() => prefs.setString(any(), any()));
    });

    test('returns false for an empty saved value', () async {
      store['preferred_language'] = '';

      final loaded = await viewModel.loadSavedLocale();

      expect(loaded, isFalse);
      expect(viewModel.languageCode, 'en');
    });

    test('applies a saved Urdu locale and notifies', () async {
      store['preferred_language'] = 'ur';

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      final loaded = await viewModel.loadSavedLocale();

      expect(loaded, isTrue);
      expect(notifies, 1);
      expect(viewModel.languageCode, 'ur');
      expect(viewModel.locale, const Locale('ur'));
    });

    test('applies a saved Roman Urdu locale', () async {
      store['preferred_language'] = 'ur_roman';

      final loaded = await viewModel.loadSavedLocale();

      expect(loaded, isTrue);
      expect(viewModel.languageCode, 'ur_roman');
      expect(viewModel.locale, const Locale('ur', 'PK_ROMAN'));
    });

    test('applies a saved English locale', () async {
      await viewModel.setLocale('ur');
      store['preferred_language'] = 'en';

      final loaded = await viewModel.loadSavedLocale();

      expect(loaded, isTrue);
      expect(viewModel.languageCode, 'en');
      expect(viewModel.locale, const Locale('en'));
    });

    test('read failure propagates without changing the current locale',
        () async {
      when(() => prefs.getString(any())).thenThrow(Exception('prefs down'));

      await expectLater(
        viewModel.loadSavedLocale(),
        throwsA(isA<Exception>()),
      );
      expect(viewModel.languageCode, 'en');
    });
  });

  group('LocaleViewModel persistence round-trip', () {
    test('a new view model restores the locale written by setLocale', () async {
      await viewModel.setLocale('ur_roman');

      final restored = LocaleViewModel(prefs: prefs);
      addTearDown(restored.dispose);

      final loaded = await restored.loadSavedLocale();

      expect(loaded, isTrue);
      expect(restored.languageCode, 'ur_roman');
      expect(restored.locale, const Locale('ur', 'PK_ROMAN'));
    });
  });
}
