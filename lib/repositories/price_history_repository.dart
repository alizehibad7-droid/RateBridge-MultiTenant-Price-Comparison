// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/price_history_model.dart';
import '../services/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../utils/app_exception.dart';

class PriceHistoryRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PriceHistoryRepository(this._firestoreService);

  Stream<List<PriceHistoryModel>> watchPriceHistory(
    String matId,
    String companyId,
    DateTimeRange? dateRange,
  ) {
    try {
      Query query = _db
          .collection(FirestorePaths.materialPriceHistoryCol(companyId, matId))
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (dateRange != null) {
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      }

      return query.snapshots().map((s) =>
        s.docs.map((d) =>
          PriceHistoryModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch price history: ${e.message}');
    }
  }

  Future<List<PriceHistoryModel>> getPriceHistoryForChart(
    String matId,
    String supplierUid,
    String companyId,
  ) async {
    try {
      final snapshot = await _db
          .collection(FirestorePaths.materialPriceHistoryCol(companyId, matId))
          .where('supplierUid', isEqualTo: supplierUid)
          .orderBy('timestamp', descending: false)
          .limit(50)
          .get();

      return snapshot.docs.map((d) =>
        PriceHistoryModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();
    } on FirebaseException catch (e) {
      throw AppException('Failed to get price history for chart: ${e.message}');
    }
  }

  Future<void> archivePrice(
    String matId,
    double oldPrice,
    double newPrice,
    String companyId,
    String supplierUid,
  ) async {
    try {
      final changePercent = oldPrice > 0
        ? ((newPrice - oldPrice) / oldPrice * 100)
        : 0.0;

      final batch = _db.batch();

      // 1. Archive old price to history
      final histRef = _db
        .collection(FirestorePaths.materialPriceHistoryCol(companyId, matId))
        .doc();
      batch.set(histRef, {
        'materialId': matId,
        'supplierUid': supplierUid,
        'companyId': companyId,
        'price': newPrice,
        'previousPrice': oldPrice,
        'changePercent': double.parse(changePercent.toStringAsFixed(1)),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update material current price
      final matRef = _db
        .collection(FirestorePaths.companyMaterialsCol(companyId))
        .doc(matId);
      batch.update(matRef, {
        'currentPrice': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch(e) {
      throw AppException('Failed to archive price: ${e.message}');
    }
  }
}
