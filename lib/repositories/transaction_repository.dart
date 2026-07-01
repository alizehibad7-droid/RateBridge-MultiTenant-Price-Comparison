// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../constants/app_constants.dart';
import '../utils/app_exception.dart';

class TransactionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TransactionRepository(FirestoreService _);

  Stream<List<TransactionModel>> watchSupplierEarnings(
    String supplierUid,
    String month,
  ) {
    final start = _monthStart(month);
    final end = _monthEnd(month);

    return _db
        .collection(FirestorePaths.transactionsCol)
        .where('supplierUid', isEqualTo: supplierUid)
        .snapshots()
        .map((snapshot) {
      final txs = snapshot.docs
          .map((d) => TransactionModel.fromMap(d.id, d.data()))
          .where(
            (tx) => !tx.createdAt.isBefore(start) && tx.createdAt.isBefore(end),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (txs.length > AppConstants.paginationLimit) {
        return txs.take(AppConstants.paginationLimit).toList();
      }
      return txs;
    });
  }

  Future<List<MonthlyEarning>> getMonthlyEarningsSummary(
    String supplierUid,
    int months,
  ) async {
    try {
      final results = <MonthlyEarning>[];
      for (int i = 0; i < months; i++) {
        final date = DateTime.now().subtract(Duration(days: 30 * i));
        final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final doc = await _db
            .collection(FirestorePaths.suppliersCol)
            .doc(supplierUid)
            .collection('earnings')
            .doc(month)
            .get();
        if (doc.exists) {
          results.add(
            MonthlyEarning.fromMap(
              month,
              Map<String, dynamic>.from(doc.data()!),
            ),
          );
        } else {
          results.add(MonthlyEarning(month: month, gross: 0, commission: 0, net: 0, orderCount: 0));
        }
      }
      return results.reversed.toList(); // chronological order
    } on FirebaseException catch (e) {
      throw AppException('Failed to get monthly earnings: ${e.message}');
    }
  }

  Stream<List<TransactionModel>> watchAdminRevenue() {
    try {
      return _db
          .collection(FirestorePaths.transactionsCol)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map((d) =>
            TransactionModel.fromMap(d.id, d.data())).toList());
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch admin revenue: ${e.message}');
    }
  }

  Future<bool> hasTransactionForOrder(String orderId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.transactionsCol)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      throw AppException('Failed to check transaction: ${e.message}');
    }
  }

  /// Creates an unsettled commission transaction when delivery is confirmed.
  Future<void> createUnsettledCommissionTransaction({
    required String orderId,
    required String companyId,
    required String supplierUid,
    required double totalAmount,
    required double commissionAmount,
    required double supplierEarning,
  }) async {
    try {
      if (await hasTransactionForOrder(orderId)) return;

      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await _db.collection(FirestorePaths.transactionsCol).add({
        'orderId': orderId,
        'companyId': companyId,
        'supplierUid': supplierUid,
        'totalAmount': totalAmount,
        'commissionRate': AppConstants.commissionRate,
        'commissionAmount': commissionAmount,
        'supplierEarning': supplierEarning,
        'status': 'unsettled',
        'month': month,
        'year': now.year,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to create commission transaction: ${e.message}');
    }
  }

  DateTime _monthStart(String month) => DateTime.parse('$month-01');
  DateTime _monthEnd(String month) {
    final parts = month.split('-');
    final next = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 1);
    return next;
  }

  bool _isInCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _txInCurrentMonth(TransactionModel tx) {
    final monthKey = tx.createdAt;
    if (_isInCurrentMonth(monthKey)) return true;
    return false;
  }

  bool _settledInCurrentMonth(TransactionModel tx) {
    final settled = tx.settledAt;
    if (settled == null) return false;
    return _isInCurrentMonth(settled);
  }

  Stream<CommissionLedgerSnapshot> watchCommissionLedger() {
    try {
      return _db
          .collection(FirestorePaths.transactionsCol)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap(_buildCommissionLedgerSnapshot);
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch commission ledger: ${e.message}');
    }
  }

  Future<CommissionLedgerSnapshot> loadCommissionLedger() async {
    try {
      final snap = await _db
          .collection(FirestorePaths.transactionsCol)
          .orderBy('createdAt', descending: true)
          .get();
      final txs = snap.docs
          .map((d) => TransactionModel.fromMap(d.id, d.data()))
          .toList();
      return _buildCommissionLedgerSnapshotFromList(txs);
    } on FirebaseException catch (e) {
      throw AppException('Failed to load commission ledger: ${e.message}');
    }
  }

  Future<void> settleSupplierCommissions(String supplierUid) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.transactionsCol)
          .where('supplierUid', isEqualTo: supplierUid)
          .where('status', isEqualTo: 'unsettled')
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'status': 'settled',
          'settledAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to settle commissions: ${e.message}');
    }
  }

  Future<CommissionLedgerSnapshot> _buildCommissionLedgerSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final txs = snap.docs
        .map((d) => TransactionModel.fromMap(d.id, d.data()))
        .toList();
    return _buildCommissionLedgerSnapshotFromList(txs);
  }

  Future<CommissionLedgerSnapshot> _buildCommissionLedgerSnapshotFromList(
    List<TransactionModel> txs,
  ) async {
    double outstandingThisMonth = 0;
    double collectedThisMonth = 0;
    double grandTotalCollected = 0;

    final unsettledBySupplier = <String, List<TransactionModel>>{};

    for (final tx in txs) {
      if (tx.isUnsettled) {
        if (_txInCurrentMonth(tx)) {
          outstandingThisMonth += tx.commissionAmount;
        }
        unsettledBySupplier.putIfAbsent(tx.supplierUid, () => []).add(tx);
      } else if (tx.isSettled) {
        grandTotalCollected += tx.commissionAmount;
        if (_settledInCurrentMonth(tx)) {
          collectedThisMonth += tx.commissionAmount;
        } else if (tx.settledAt == null && _txInCurrentMonth(tx)) {
          collectedThisMonth += tx.commissionAmount;
        }
      }
    }

    final supplierUids = unsettledBySupplier.keys.toList();
    final nameCache = await _supplierNamesFor(supplierUids);

    final suppliers = supplierUids.map((uid) {
      final rows = unsettledBySupplier[uid]!;
      final amount = rows.fold<double>(0, (acc, tx) => acc + tx.commissionAmount);
      return SupplierUnsettledSummary(
        supplierUid: uid,
        supplierName: nameCache[uid] ?? uid,
        unsettledAmount: amount,
        orderCount: rows.length,
        transactionIds: rows.map((tx) => tx.txId).toList(),
      );
    }).toList()
      ..sort((a, b) => b.unsettledAmount.compareTo(a.unsettledAmount));

    return CommissionLedgerSnapshot(
      outstandingThisMonth: outstandingThisMonth,
      collectedThisMonth: collectedThisMonth,
      grandTotalCollected: grandTotalCollected,
      suppliers: suppliers,
    );
  }

  Future<Map<String, String>> _supplierNamesFor(List<String> supplierUids) async {
    final names = <String, String>{};
    for (final uid in supplierUids) {
      if (uid.isEmpty) continue;
      final doc = await _db.collection(FirestorePaths.suppliersCol).doc(uid).get();
      final data = doc.data();
      names[uid] = (data?['name'] as String?)?.trim().isNotEmpty == true
          ? data!['name'] as String
          : uid;
    }
    return names;
  }
}
