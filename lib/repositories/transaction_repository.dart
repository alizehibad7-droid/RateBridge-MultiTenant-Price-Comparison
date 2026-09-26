// MVVM: Repository — Firestore access only
import 'dart:async';
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
    String? companyName,
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
        if (companyName != null) 'companyName': companyName,
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

  /// Live stream of the entire ledger, reactive to transactions.
  Stream<CommissionLedgerSnapshot> watchCommissionLedger() {
    return _db.collection(FirestorePaths.transactionsCol)
        .snapshots()
        .asyncMap((snap) => _buildSnapshotFromData(snap));
  }

  Future<CommissionLedgerSnapshot> _buildSnapshotFromData(
    QuerySnapshot<Map<String, dynamic>> txSnap
  ) async {
    final allTxs = txSnap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList();

    double collectedThisMonth = 0;
    double grandTotalCollected = 0;
    final now = DateTime.now();

    final dataBySupplier = <String, Map<String, dynamic>>{};
    
    for (final tx in allTxs) {
      if (tx.isSettled) {
        grandTotalCollected += tx.commissionAmount;
        final settledAt = tx.settledAt ?? tx.createdAt;
        if (settledAt.year == now.year && settledAt.month == now.month) {
          collectedThisMonth += tx.commissionAmount;
        }
      }

      if (tx.isUnsettled) {
        dataBySupplier.putIfAbsent(tx.supplierUid, () => {'generated': 0.0, 'orders': 0, 'txIds': <String>[]});
        dataBySupplier[tx.supplierUid]!['generated'] += tx.commissionAmount;
        dataBySupplier[tx.supplierUid]!['orders'] += 1;
        dataBySupplier[tx.supplierUid]!['txIds'].add(tx.txId);
      }
    }

    final proofSnap = await _db.collection('payment_proofs')
        .where('status', isEqualTo: 'confirmed')
        .get();
    final paidBySupplier = <String, double>{};
    for (final doc in proofSnap.docs) {
      final p = doc.data();
      final payerId = (p['payerId'] ?? p['supplierUid'] ?? '').toString();
      final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
      if (payerId.isNotEmpty) {
        paidBySupplier[payerId] = (paidBySupplier[payerId] ?? 0.0) + amt;
        grandTotalCollected += amt;
        final confirmedAt = (p['confirmedAt'] as Timestamp?)?.toDate() ?? now;
        if (confirmedAt.year == now.year && confirmedAt.month == now.month) {
          collectedThisMonth += amt;
        }
      }
    }

    final suppliers = <SupplierUnsettledSummary>[];
    for (final uid in dataBySupplier.keys) {
      final generated = dataBySupplier[uid]!['generated'] as double;
      final paid = paidBySupplier[uid] ?? 0.0;
      final netOwed = generated - paid;

      if (netOwed > 0.01) {
        // Fetch name
        final sDoc = await _db.collection('suppliers').doc(uid).get();
        final name = sDoc.data()?['name'] ?? uid;

        suppliers.add(SupplierUnsettledSummary(
          supplierUid: uid,
          supplierName: name,
          unsettledAmount: netOwed,
          orderCount: dataBySupplier[uid]!['orders'] as int,
          transactionIds: List<String>.from(dataBySupplier[uid]!['txIds']),
        ));
      }
    }

    suppliers.sort((a, b) => b.unsettledAmount.compareTo(a.unsettledAmount));
    final outstandingThisMonth = suppliers.fold(0.0, (acc, s) => acc + s.unsettledAmount);

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
}
