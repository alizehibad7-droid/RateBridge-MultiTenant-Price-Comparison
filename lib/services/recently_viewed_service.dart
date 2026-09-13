import 'package:shared_preferences/shared_preferences.dart';

/// Device-local recently viewed material IDs for field users (max 20).
class RecentlyViewedService {
  static const String storageKey = 'recently_viewed_material_ids';
  static const int maxEntries = 20;

  final SharedPreferences _prefs;

  RecentlyViewedService(this._prefs);

  Future<void> persistView(String materialId) =>
      recordView(materialId, prefs: _prefs);

  Future<List<String>> readRecentIds() => getRecentIds(prefs: _prefs);

  Future<void> wipeHistory() => clearHistory(prefs: _prefs);

  static Future<void> recordView(
    String materialId, {
    SharedPreferences? prefs,
  }) async {
    final id = materialId.trim();
    if (id.isEmpty) return;

    final storage = prefs ?? await SharedPreferences.getInstance();
    final current = await getRecentIds(prefs: storage);
    final updated = [
      id,
      ...current.where((existing) => existing != id),
    ];
    if (updated.length > maxEntries) {
      updated.removeRange(maxEntries, updated.length);
    }
    await storage.setStringList(storageKey, updated);
  }

  static Future<List<String>> getRecentIds({SharedPreferences? prefs}) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    return storage.getStringList(storageKey) ?? [];
  }

  static Future<void> clearHistory({SharedPreferences? prefs}) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    await storage.remove(storageKey);
  }
}
