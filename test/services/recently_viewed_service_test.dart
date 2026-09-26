import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ratebridge/services/recently_viewed_service.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String>[]);
  });

  late MockSharedPreferences prefs;
  late Map<String, List<String>> store;
  late RecentlyViewedService service;

  setUp(() {
    prefs = MockSharedPreferences();
    store = <String, List<String>>{};

    when(() => prefs.getStringList(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments.first as String;
      return store[key];
    });
    when(() => prefs.setStringList(any(), any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1] as List<String>;
      store[key] = List<String>.from(value);
      return true;
    });
    when(() => prefs.remove(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments.first as String;
      store.remove(key);
      return true;
    });

    service = RecentlyViewedService(prefs);
  });

  group('RecentlyViewedService instance API', () {
    test('persistView prepends ids and readRecentIds returns them', () async {
      await service.persistView('mat-1');
      await service.persistView('mat-2');

      expect(await service.readRecentIds(), ['mat-2', 'mat-1']);
      expect(
        store[RecentlyViewedService.storageKey],
        ['mat-2', 'mat-1'],
      );
    });

    test('wipeHistory removes the stored list', () async {
      await service.persistView('mat-1');
      await service.wipeHistory();

      expect(await service.readRecentIds(), isEmpty);
      expect(store.containsKey(RecentlyViewedService.storageKey), isFalse);
      verify(() => prefs.remove(RecentlyViewedService.storageKey)).called(1);
    });
  });

  group('RecentlyViewedService.recordView', () {
    test('ignores blank ids', () async {
      await RecentlyViewedService.recordView('   ', prefs: prefs);
      verifyNever(() => prefs.setStringList(any(), any()));
      expect(await RecentlyViewedService.getRecentIds(prefs: prefs), isEmpty);
    });

    test('moves a repeated id to the front without duplicating it', () async {
      await RecentlyViewedService.recordView('a', prefs: prefs);
      await RecentlyViewedService.recordView('b', prefs: prefs);
      await RecentlyViewedService.recordView('c', prefs: prefs);
      await RecentlyViewedService.recordView('a', prefs: prefs);

      expect(
        await RecentlyViewedService.getRecentIds(prefs: prefs),
        ['a', 'c', 'b'],
      );
    });

    test('caps history at maxEntries', () async {
      for (var i = 0; i < RecentlyViewedService.maxEntries + 5; i++) {
        await RecentlyViewedService.recordView('mat-$i', prefs: prefs);
      }

      final ids = await RecentlyViewedService.getRecentIds(prefs: prefs);
      expect(ids, hasLength(RecentlyViewedService.maxEntries));
      expect(ids.first, 'mat-${RecentlyViewedService.maxEntries + 4}');
      expect(ids.last, 'mat-5');
      expect(ids, isNot(contains('mat-0')));
    });
  });

  group('RecentlyViewedService.getRecentIds and clearHistory', () {
    test('returns an empty list when nothing is stored', () async {
      expect(await RecentlyViewedService.getRecentIds(prefs: prefs), isEmpty);
    });

    test('clearHistory deletes the key', () async {
      await RecentlyViewedService.recordView('mat-1', prefs: prefs);
      await RecentlyViewedService.clearHistory(prefs: prefs);

      expect(await RecentlyViewedService.getRecentIds(prefs: prefs), isEmpty);
      verify(() => prefs.remove(RecentlyViewedService.storageKey)).called(1);
    });
  });
}
