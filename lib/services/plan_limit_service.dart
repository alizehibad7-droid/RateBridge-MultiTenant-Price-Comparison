import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/subscription_model.dart';
import '../utils/app_exception.dart';

/// Centralized, point-of-action checks for subscription plan limits.
class PlanLimitService {
  PlanLimitService._();

  static const List<String> activeOrderStatuses = [
    'pending_approval',
    'pending',
    'accepted',
    'inProgress',
    'inprogress',
    'in_progress',
    'delivered',
  ];

  static PlanDefinition planForKey(Object? value) {
    final key = value?.toString().toLowerCase() ?? 'free';
    return kPlans.firstWhere(
      (plan) => plan.planKey == key,
      orElse: () => kPlans.first,
    );
  }

  static Future<PlanDefinition> companyPlan(
    FirebaseFirestore db,
    String companyId,
  ) async {
    final results = await Future.wait([
      db.collection('companies').doc(companyId).get(),
      db.collection('subscriptions').doc(companyId).get(),
    ]);
    final company = results[0];
    final subscription = results[1];
    if (!company.exists) {
      throw AppException(
        'Company not found. Please verify your invite or account.',
      );
    }

    if (subscription.exists) {
      final data = subscription.data();
      final status = data?['status']?.toString().toLowerCase() ?? '';
      final expiresAt = data?['expiresAt'];
      final isExpired =
          expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now());
      final isActive =
          (status == 'active' || status == 'admin_granted') && !isExpired;
      final effectivePlan = isActive && data != null ? data['plan'] : 'free';
      return planForKey(effectivePlan);
    }

    return planForKey(company.data()?['plan']);
  }

  static Future<void> ensureActiveOrderCapacity(
    FirebaseFirestore db,
    String companyId,
  ) async {
    final plan = await companyPlan(db, companyId);
    if (plan.maxActiveOrders == -1) return;

    try {
      final count =
          await db
              .collectionGroup('orders')
              .where('companyId', isEqualTo: companyId)
              .where('status', whereIn: activeOrderStatuses)
              .count()
              .get();
      if ((count.count ?? 0) >= plan.maxActiveOrders) {
        throw AppException(
          'Active order limit reached (${plan.maxActiveOrders}) for the '
              '${plan.name} plan. Please upgrade to place another order.',
          'limit_reached',
        );
      }
    } on FirebaseException catch (error) {
      if (error.code == 'failed-precondition') {
        throw AppException(
          'Order limit check is temporarily unavailable while its Firestore '
              'index builds. Please try again shortly.',
          'index_building',
        );
      }
      throw AppException(
        'Could not verify the active order limit. Please try again.',
        error.code,
      );
    }
  }

  static Future<void> ensureSupplierCapacity(
    FirebaseFirestore db,
    String companyId, {
    String? supplierId,
  }) async {
    final links = db
        .collection('companies')
        .doc(companyId)
        .collection('suppliers');

    if (supplierId != null && supplierId.isNotEmpty) {
      final existing = await links.doc(supplierId).get();
      final status = existing.data()?['status']?.toString().toLowerCase();
      if (existing.exists && (status == 'active' || status == 'approved')) {
        return;
      }
    }

    final plan = await companyPlan(db, companyId);
    if (plan.maxSuppliers == -1) return;

    final count =
        await links
            .where('status', whereIn: const ['active', 'approved'])
            .count()
            .get();
    if ((count.count ?? 0) >= plan.maxSuppliers) {
      throw AppException(
        'Supplier limit reached for the ${plan.name} plan '
            '(${plan.maxSuppliers}). Please upgrade to link another supplier.',
        'limit_reached',
      );
    }
  }

  static Future<void> ensureFieldUserCapacity(
    FirebaseFirestore db,
    String companyId,
  ) async {
    final plan = await companyPlan(db, companyId);
    if (plan.maxFieldUsers == -1) return;

    final count =
        await db
            .collection('companies')
            .doc(companyId)
            .collection('fieldUsers')
            .where('status', isEqualTo: 'active')
            .count()
            .get();
    if ((count.count ?? 0) >= plan.maxFieldUsers) {
      throw AppException(
        'Team size limit reached for this company (${plan.maxFieldUsers}) on '
            'the ${plan.name} plan. Please contact your CEO to upgrade.',
        'limit_reached',
      );
    }
  }
}
