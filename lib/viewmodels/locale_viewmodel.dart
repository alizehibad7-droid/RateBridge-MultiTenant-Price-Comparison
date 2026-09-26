import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'preferred_language';

/// Supported locale codes: 'en' | 'ur' | 'ur_roman'
class LocaleViewModel extends ChangeNotifier {
  final SharedPreferences? _prefs;

  Locale _locale = const Locale('en');
  String _languageCode = 'en';

  LocaleViewModel({SharedPreferences? prefs}) : _prefs = prefs;

  Locale get locale => _locale;
  String get languageCode => _languageCode;

  Future<SharedPreferences> _storage() async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// Attempts to load a previously saved locale.
  /// Returns true if one was found and applied, false otherwise.
  Future<bool> loadSavedLocale() async {
    final prefs = await _storage();
    final saved = prefs.getString(_prefKey);
    if (saved == null || saved.isEmpty) {
      return false;
    }
    _applyCode(saved);
    notifyListeners();
    return true;
  }

  /// Sets and persists the selected language code.
  Future<void> setLocale(String code) async {
    _applyCode(code);
    final prefs = await _storage();
    await prefs.setString(_prefKey, code);
    notifyListeners();
  }

  void _applyCode(String code) {
    _languageCode = code;
    switch (code) {
      case 'ur':
        _locale = const Locale('ur');
        break;
      case 'ur_roman':
        // Roman Urdu uses Urdu content rendered with Latin script;
        // tagged as a custom country code to distinguish in lookups.
        _locale = const Locale('ur', 'PK_ROMAN');
        break;
      case 'en':
      default:
        _locale = const Locale('en');
    }
  }
}
