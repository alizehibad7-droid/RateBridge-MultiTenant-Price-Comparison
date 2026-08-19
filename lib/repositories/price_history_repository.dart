// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/price_history_model.dart';
import '../services/firestore_service.dart';
import '../services/plan_limit_service.dart';
import '../constants/firestore_paths.dart';
import '../utils/app_exception.dart';

class PriceHistoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PriceHistoryRepository(FirestoreService _);

  Stream<List<PriceHistoryModel>> watchPriceHistory(
    String matId,
    String companyId,
    DateTimeRange? dateRange,
  ) async* {
    try {
      final plan = await PlanLimitService.companyPlan(_db, companyId);
      final planStart = plan.priceHistoryDays == -1
          ? null
          : DateTime.now().subtract(Duration(days: plan.priceHistoryDays));
      final requestedStart = dateRange?.start;
      final effectiveStart = planStart == null
          ? requestedStart
          : requestedStart == null || requestedStart.isBefore(planStart)
              ? planStart
              : requestedStart;

      Query query = _db
          .collection(FirestorePaths.materialPriceHistoryCol(companyId, matId))
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (effectiveStart != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart),
        );
      }
      if (dateRange != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end),
        );
      }

      yield* query.snapshots().map((s) =>
        s.docs.map((d) =>
          PriceHistoryModel.fromMap(
            d.id,
            Map<String, dynamic>.from(d.data() as Map),
          )).toList());
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
      final plan = await PlanLimitService.companyPlan(_db, companyId);
      Query<Map<String, dynamic>> query = _db
          .collection(FirestorePaths.materialPriceHistoryCol(companyId, matId))
          .where('supplierUid', isEqualTo: supplierUid)
          .orderBy('timestamp', descending: false)
          .limit(50);
      if (plan.priceHistoryDays != -1) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(Duration(days: plan.priceHistoryDays)),
          ),
        );
      }
      final snapshot = await query.get();

      return snapshot.docs.map((d) =>
        PriceHistoryModel.fromMap(d.id, d.data())).toList();
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
