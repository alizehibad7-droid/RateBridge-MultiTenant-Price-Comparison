import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/transaction_model.dart';
import 'package:ratebridge/repositories/transaction_repository.dart';
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

Map<String, dynamic> _txMap({
  required String orderId,
  required String supplierUid,
  String status = 'unsettled',
  double totalAmount = 1000,
  double commissionAmount = 20,
  double supplierEarning = 980,
  DateTime? createdAt,
}) {
  return {
    'orderId': orderId,
    'companyId': 'co-1',
    'supplierUid': supplierUid,
    'totalAmount': totalAmount,
    'commissionRate': 0.02,
    'commissionAmount': commissionAmount,
    'supplierEarning': supplierEarning,
    'status': status,
    'type': 'order_payment',
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.utc(2026, 4, 1, 10)),
  };
}

void main() {
  late FakeFirebaseFirestore fake;
  late TransactionRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = TransactionRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  group('TransactionRepository.createUnsettledCommissionTransaction', () {
    test('writes a deterministic commission document', () async {
      await repo.createUnsettledCommissionTransaction(
        orderId: 'order-1',
        companyId: 'co-1',
        supplierUid: 'sup-1',
        totalAmount: 1000,
        commissionAmount: 20,
        supplierEarning: 980,
      );

      final doc = await fake.collection('transactions').doc('comm_order-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['status'], 'unsettled');
      expect(doc.data()?['orderId'], 'order-1');
      expect(doc.data()?['commissionAmount'], 20);
      expect(doc.data()?['type'], 'order_payment');
    });

    test('is a no-op when the commission document already exists', () async {
      await fake.collection('transactions').doc('comm_order-1').set(
        _txMap(orderId: 'order-1', supplierUid: 'sup-1', commissionAmount: 5),
      );

      await repo.createUnsettledCommissionTransaction(
        orderId: 'order-1',
        companyId: 'co-1',
        supplierUid: 'sup-1',
        totalAmount: 9999,
        commissionAmount: 99,
        supplierEarning: 1,
      );

      final doc = await fake.collection('transactions').doc('comm_order-1').get();
      expect(doc.data()?['commissionAmount'], 5);
    });
  });

  group('TransactionRepository streams', () {
    test('watchSupplierUnsettledTransactions emits newest unsettled first',
        () async {
      await fake.collection('transactions').doc('old').set(_txMap(
            orderId: 'o-old',
            supplierUid: 'sup-1',
            createdAt: DateTime.utc(2026, 3, 1),
          ));
      await fake.collection('transactions').doc('new').set(_txMap(
            orderId: 'o-new',
            supplierUid: 'sup-1',
            createdAt: DateTime.utc(2026, 4, 1),
          ));
      await fake.collection('transactions').doc('settled').set(_txMap(
            orderId: 'o-s',
            supplierUid: 'sup-1',
            status: 'settled',
          ));
      await fake.collection('transactions').doc('other').set(_txMap(
            orderId: 'o-x',
            supplierUid: 'sup-2',
          ));

      final events = <List<TransactionModel>>[];
      final sub =
          repo.watchSupplierUnsettledTransactions('sup-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'unsettled stream did not emit both records',
      );
      expect(events.last.map((t) => t.txId).toList(), ['new', 'old']);

      await sub.cancel();
    });

    test('watchSupplierSettledTransactions only includes settled rows',
        () async {
      await fake.collection('transactions').doc('s1').set(_txMap(
            orderId: 'o-1',
            supplierUid: 'sup-1',
            status: 'settled',
          ));
      await fake.collection('transactions').doc('u1').set(_txMap(
            orderId: 'o-2',
            supplierUid: 'sup-1',
          ));

      final events = <List<TransactionModel>>[];
      final sub =
          repo.watchSupplierSettledTransactions('sup-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 1),
        because: 'settled stream did not emit',
      );
      expect(events.last.single.txId, 's1');

      await sub.cancel();
    });

    test('watchSupplierEarnings filters by calendar month', () async {
      await fake.collection('transactions').doc('apr').set(_txMap(
            orderId: 'o-apr',
            supplierUid: 'sup-1',
            createdAt: DateTime.utc(2026, 4, 15),
          ));
      await fake.collection('transactions').doc('mar').set(_txMap(
            orderId: 'o-mar',
            supplierUid: 'sup-1',
            createdAt: DateTime.utc(2026, 3, 15),
          ));

      final events = <List<TransactionModel>>[];
      final sub =
          repo.watchSupplierEarnings('sup-1', '2026-04').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 1),
        because: 'April earnings stream did not emit',
      );
      expect(events.last.single.txId, 'apr');

      await sub.cancel();
    });
  });

  group('TransactionRepository ledger and settlement', () {
    test('watchCommissionLedger rolls up unpaid commission by supplier',
        () async {
      await fake.collection('suppliers').doc('sup-1').set({'name': 'Cement House'});
      await fake.collection('transactions').doc('t1').set(_txMap(
            orderId: 'o-1',
            supplierUid: 'sup-1',
            commissionAmount: 50,
          ));
      await fake.collection('transactions').doc('t2').set(_txMap(
            orderId: 'o-2',
            supplierUid: 'sup-1',
            commissionAmount: 30,
          ));
      await fake.collection('payment_proofs').doc('p1').set({
        'payerId': 'sup-1',
        'amount': 20,
        'type': 'commission',
        'status': 'confirmed',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'confirmedAt': Timestamp.fromDate(DateTime.now()),
      });

      final events = <CommissionLedgerSnapshot>[];
      final sub = repo.watchCommissionLedger().listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.suppliers.isNotEmpty),
        because: 'commission ledger did not emit a supplier row',
      );

      final snap = events.last;
      expect(snap.suppliers.single.supplierName, 'Cement House');
      expect(snap.suppliers.single.unsettledAmount, 60);
      expect(snap.suppliers.single.orderCount, 2);
      expect(snap.grandTotalCollected, 20);
      expect(snap.collectedThisMonth, 20);

      await sub.cancel();
    });

    test('settleSupplierCommissions marks the listed transactions settled',
        () async {
      await fake.collection('transactions').doc('t1').set(
            _txMap(orderId: 'o-1', supplierUid: 'sup-1'),
          );
      await fake.collection('transactions').doc('t2').set(
            _txMap(orderId: 'o-2', supplierUid: 'sup-1'),
          );

      await repo.settleSupplierCommissions('sup-1', ['t1', 't2']);

      expect(
        (await fake.collection('transactions').doc('t1').get()).data()?['status'],
        'settled',
      );
      expect(
        (await fake.collection('transactions').doc('t2').get()).data()?['status'],
        'settled',
      );
    });

    test('getMonthlyEarningsSummary totals the current month', () async {
      final now = DateTime.now();
      await fake.collection('transactions').doc('this-month').set(_txMap(
            orderId: 'o-now',
            supplierUid: 'sup-1',
            totalAmount: 1000,
            commissionAmount: 20,
            supplierEarning: 980,
            createdAt: now,
          ));

      final months = await repo.getMonthlyEarningsSummary('sup-1', 1);
      expect(months, hasLength(1));
      expect(months.single.gross, 1000);
      expect(months.single.commission, 20);
      expect(months.single.net, 980);
      expect(months.single.orderCount, 1);
    });
  });
}
