// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../constants/app_constants.dart';
import '../utils/app_exception.dart';

class TransactionRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TransactionRepository(this._firestoreService);

  Stream<List<TransactionModel>> watchSupplierEarnings(
    String supplierUid,
    String month,
  ) {
    try {
      return _db
          .collection(FirestorePaths.transactionsCol)
          .where('supplierUid', isEqualTo: supplierUid)
          .where('createdAt', isGreaterThanOrEqualTo: _monthStart(month))
          .where('createdAt', isLessThan: _monthEnd(month))
          .orderBy('createdAt', descending: true)
          .limit(AppConstants.paginationLimit)
          .snapshots()
          .map((s) => s.docs.map((d) =>
            TransactionModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch supplier earnings: ${e.message}');
    }
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
          results.add(MonthlyEarning.fromMap(month, doc.data() as Map<String, dynamic>));
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
            TransactionModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch admin revenue: ${e.message}');
    }
  }

  DateTime _monthStart(String month) => DateTime.parse('$month-01');
  DateTime _monthEnd(String month) {
    final parts = month.split('-');
    final next = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 1);
    return next;
  }
}
