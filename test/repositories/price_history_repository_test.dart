import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/price_history_model.dart';
import 'package:ratebridge/repositories/price_history_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

Future<void> _waitUntil(
  bool Function() test, {
  String because = 'condition never became true',
}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  late FakeFirebaseFirestore fake;
  late PriceHistoryRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PriceHistoryRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  CollectionReference<Map<String, dynamic>> historyCol() {
    return fake
        .collection('companies')
        .doc('co-1')
        .collection('materials')
        .doc('mat-1')
        .collection('priceHistory');
  }

  Future<void> seedCompany({String plan = 'premium'}) {
    return fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'status': 'active',
      'plan': plan,
    });
  }

  Future<void> seedHistoryPoint({
    required String id,
    required DateTime at,
    String supplierUid = 'sup-1',
    double price = 1200,
  }) {
    return historyCol().doc(id).set({
      'materialId': 'mat-1',
      'supplierUid': supplierUid,
      'companyId': 'co-1',
      'price': price,
      'timestamp': Timestamp.fromDate(at),
    });
  }

  group('PriceHistoryRepository.watchPriceHistory', () {
    test('emits history newest first for an unlimited plan', () async {
      await seedCompany();
      await seedHistoryPoint(
        id: 'h-old',
        at: DateTime.utc(2026, 1, 1),
        price: 1000,
      );
      await seedHistoryPoint(
        id: 'h-new',
        at: DateTime.utc(2026, 4, 1),
        price: 1300,
      );

      final events = <List<PriceHistoryModel>>[];
      final sub = repo.watchPriceHistory('mat-1', 'co-1', null).listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'price history stream did not emit both points',
      );
      expect(events.last.first.histId, 'h-new');
      expect(events.last.last.histId, 'h-old');

      await sub.cancel();
    });

    test('date range and free-plan window drop older points', () async {
      await seedCompany(plan: 'free');
      final now = DateTime.now();
      await seedHistoryPoint(
        id: 'recent',
        at: now.subtract(const Duration(days: 5)),
        price: 1100,
      );
      await seedHistoryPoint(
        id: 'old',
        at: now.subtract(const Duration(days: 80)),
        price: 900,
      );

      final events = <List<PriceHistoryModel>>[];
      final sub = repo
          .watchPriceHistory(
            'mat-1',
            'co-1',
            DateTimeRange(
              start: now.subtract(const Duration(days: 10)),
              end: now,
            ),
          )
          .listen(events.add);

      await _waitUntil(
        () => events.isNotEmpty,
        because: 'ranged price history stream did not emit',
      );
      expect(events.last.map((h) => h.histId), ['recent']);

      await sub.cancel();
    });
  });

  group('PriceHistoryRepository.getPriceHistoryForChart', () {
    test('returns supplier points in chronological order', () async {
      await seedCompany();
      await seedHistoryPoint(
        id: 'h-2',
        at: DateTime.utc(2026, 4, 1),
        price: 1300,
      );
      await seedHistoryPoint(
        id: 'h-1',
        at: DateTime.utc(2026, 3, 1),
        price: 1200,
      );
      await seedHistoryPoint(
        id: 'other',
        at: DateTime.utc(2026, 3, 15),
        supplierUid: 'sup-2',
        price: 1500,
      );

      final points = await repo.getPriceHistoryForChart(
        'mat-1',
        'sup-1',
        'co-1',
      );
      expect(points.map((p) => p.histId).toList(), ['h-1', 'h-2']);
      expect(points.first.price, 1200);
    });
  });

  group('PriceHistoryRepository.archivePrice', () {
    test('appends a history row and updates the material price', () async {
      await seedCompany();
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .set({'name': 'OPC Cement', 'currentPrice': 1000});

      await repo.archivePrice('mat-1', 1000, 1150, 'co-1', 'sup-1');

      final material = await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .get();
      expect(material.data()?['currentPrice'], 1150);

      final history = await historyCol().get();
      expect(history.docs, hasLength(1));
      expect(history.docs.first.data()['price'], 1150);
      expect(history.docs.first.data()['previousPrice'], 1000);
      expect(history.docs.first.data()['changePercent'], 15.0);
      expect(history.docs.first.data()['supplierUid'], 'sup-1');
    });
  });
}
