// MVVM: Repository — Firestore access only
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../constants/app_constants.dart';
import '../utils/app_exception.dart';

class TransactionRepository {
  final FirebaseFirestore _db;

  TransactionRepository(FirestoreService _, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Live stream of every unsettled commission record for [supplierUid].
  Stream<List<TransactionModel>> watchSupplierUnsettledTransactions(String supplierUid) {
    return _db.collection(FirestorePaths.transactionsCol)
        .where('supplierUid', isEqualTo: supplierUid)
        .where('status', isEqualTo: 'unsettled')
        .snapshots()
        .map((snapshot) {
      final txs = snapshot.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList();
      txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return txs;
    });
  }

  /// Watches all settled transactions for history.
  Stream<List<TransactionModel>> watchSupplierSettledTransactions(String supplierUid) {
     return _db.collection(FirestorePaths.transactionsCol)
          .where('supplierUid', isEqualTo: supplierUid)
          .where('status', isEqualTo: 'settled')
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }

  /// Watches transactions for a specific month.
  Stream<List<TransactionModel>> watchSupplierEarnings(String supplierUid, String month) {
    final start = _monthStart(month);
    final end = _monthEnd(month);
    return _db.collection(FirestorePaths.transactionsCol)
        .where('supplierUid', isEqualTo: supplierUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((d) => TransactionModel.fromMap(d.id, d.data()))
          .where((tx) => !tx.createdAt.isBefore(start) && tx.createdAt.isBefore(end))
          .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Creates an unsettled commission transaction when delivery is confirmed.
  /// Uses a deterministic ID based on orderId to prevent duplicates.
  Future<void> createUnsettledCommissionTransaction({
    required String orderId,
    required String companyId,
    required String supplierUid,
    required double totalAmount,
    required double commissionAmount,
    required double supplierEarning,
  }) async {
    try {
      final txId = 'comm_$orderId'; 
      final docRef = _db.collection(FirestorePaths.transactionsCol).doc(txId);
      final doc = await docRef.get();
      if (doc.exists) return; 

      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await docRef.set({
        'orderId': orderId,
        'companyId': companyId,
        'supplierUid': supplierUid,
        'totalAmount': totalAmount,
        'commissionRate': AppConstants.commissionRate,
        'commissionAmount': commissionAmount,
        'supplierEarning': supplierEarning,
        'status': 'unsettled',
        'type': 'order_payment',
        'month': month,
        'year': now.year,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to create commission transaction: ${e.message}');
    }
  }

  // --- Admin Ledger Integration (Source of Truth) ---

  /// Live stream of the entire ledger, reactive to both transactions and payments.
  Stream<CommissionLedgerSnapshot> watchCommissionLedger() {
    late StreamController<CommissionLedgerSnapshot> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? txSub;

    Future<void> refresh() async {
      if (controller.isClosed) return;
      try {
        final txSnap = await _db
            .collection(FirestorePaths.transactionsCol)
            .orderBy('createdAt', descending: true)
            .get();

        final snapshot = await _buildSnapshotFromData(txSnap);
        if (!controller.isClosed) controller.add(snapshot);
      } catch (e) {
        developer.log('Error refreshing commission ledger: $e');
      }
    }

    controller = StreamController<CommissionLedgerSnapshot>.broadcast(
      onListen: () {
        txSub ??= _db
            .collection(FirestorePaths.transactionsCol)
            .snapshots()
            .listen((_) => refresh());
        refresh();
      },
      onCancel: () {
        txSub?.cancel();
        txSub = null;
      },
    );

    return controller.stream;
  }

  Future<CommissionLedgerSnapshot> _buildSnapshotFromData(
    QuerySnapshot<Map<String, dynamic>> txSnap,
  ) async {
    final allTxs =
        txSnap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList();

    final now = DateTime.now();
    double collectedThisMonth = 0;
    double grandTotalCollected = 0;

    for (final tx in allTxs) {
      if (!tx.isSettled) continue;
      grandTotalCollected += tx.commissionAmount;
      final date = tx.settledAt ?? tx.createdAt;
      if (date.year == now.year && date.month == now.month) {
        collectedThisMonth += tx.commissionAmount;
      }
    }

    // Outstanding = unsettled txs only (settled via Stripe drop out of the list).
    final dataBySupplier = <String, Map<String, dynamic>>{};
    for (final tx in allTxs) {
      if (!tx.isUnsettled) continue;
      dataBySupplier.putIfAbsent(
        tx.supplierUid,
        () => {'generated': 0.0, 'orders': 0, 'txIds': <String>[]},
      );
      dataBySupplier[tx.supplierUid]!['generated'] += tx.commissionAmount;
      dataBySupplier[tx.supplierUid]!['orders'] += 1;
      dataBySupplier[tx.supplierUid]!['txIds'].add(tx.txId);
    }

    final suppliers = <SupplierUnsettledSummary>[];
    for (final uid in dataBySupplier.keys) {
      final netOwed = dataBySupplier[uid]!['generated'] as double;
      if (netOwed > 0.01) {
        final sDoc = await _db.collection('suppliers').doc(uid).get();
        final name = sDoc.data()?['name'] ??
            sDoc.data()?['businessName'] ??
            uid;

        suppliers.add(SupplierUnsettledSummary(
          supplierUid: uid,
          supplierName: name.toString(),
          unsettledAmount: netOwed,
          orderCount: dataBySupplier[uid]!['orders'] as int,
          transactionIds: List<String>.from(dataBySupplier[uid]!['txIds']),
        ));
      }
    }

    suppliers.sort((a, b) => b.unsettledAmount.compareTo(a.unsettledAmount));
    final outstandingThisMonth =
        suppliers.fold(0.0, (sum, s) => sum + s.unsettledAmount);

    return CommissionLedgerSnapshot(
      outstandingThisMonth: outstandingThisMonth,
      collectedThisMonth: collectedThisMonth,
      grandTotalCollected: grandTotalCollected,
      suppliers: suppliers,
    );
  }

  Future<void> settleSupplierCommissions(String supplierUid, List<String> transactionIds) async {
    final batch = _db.batch();
    for (final id in transactionIds) {
      batch.update(_db.collection(FirestorePaths.transactionsCol).doc(id), {
        'status': 'settled',
        'settledAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<List<MonthlyEarning>> getMonthlyEarningsSummary(String supplierUid, int count) async {
    final results = <MonthlyEarning>[];
    for (int i = 0; i < count; i++) {
      final date = DateTime.now().subtract(Duration(days: 30 * i));
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final start = DateTime.parse('$month-01');
      final end = DateTime(date.month == 12 ? date.year + 1 : date.year, date.month == 12 ? 1 : date.month + 1, 1);
      final snap = await _db.collection(FirestorePaths.transactionsCol)
          .where('supplierUid', isEqualTo: supplierUid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end)).get();
      final txs = snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList();
      double gross = 0; double comm = 0; double net = 0;
      for (final tx in txs) { gross += tx.totalAmount; comm += tx.commissionAmount; net += tx.supplierEarning; }
      results.add(MonthlyEarning(month: month, gross: gross, commission: comm, net: net, orderCount: txs.length));
    }
    return results;
  }

  DateTime _monthStart(String month) => DateTime.parse('$month-01');
  DateTime _monthEnd(String month) {
    final parts = month.split('-');
    final y = int.parse(parts[0]); final m = int.parse(parts[1]);
    return DateTime(m == 12 ? y + 1 : y, m == 12 ? 1 : m + 1, 1);
  }

  /// Soft-delete: Hide transaction for current user
  Future<void> hideTransactionForUser(String txId, String userId) async {
    await _db.collection(FirestorePaths.transactionsCol).doc(txId).update({
      'hiddenBy': FieldValue.arrayUnion([userId]),
    });
  }

  /// Bulk soft-delete transactions
  Future<void> hideTransactionsForUser(List<String> txIds, String userId) async {
    final batch = _db.batch();
    for (final id in txIds) {
      batch.update(_db.collection(FirestorePaths.transactionsCol).doc(id), {
        'hiddenBy': FieldValue.arrayUnion([userId]),
      });
    }
    await batch.commit();
  }

  /// Clear entire payment history for supplier
  Future<void> hideAllPaymentProofsForUser(String supplierUid) async {
    final snap = await _db
        .collection('payment_proofs')
        .where('payerId', isEqualTo: supplierUid)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'hiddenBy': FieldValue.arrayUnion([supplierUid]),
      });
    }
    await batch.commit();
  }
}
