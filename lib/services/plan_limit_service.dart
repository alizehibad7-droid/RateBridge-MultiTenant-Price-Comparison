import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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
    String companyId, {
    String? planKey,
  }) async {
    // 1. Use pre-fetched plan if available (avoids permission issues during registration/guest flow)
    if (planKey != null && planKey.isNotEmpty) {
      return planForKey(planKey);
    }

    try {
      final company = await db.collection('companies').doc(companyId).get();
      if (!company.exists) {
        throw AppException(
          'Company not found. Please verify your invite or account.',
        );
      }

      final companyData = company.data();
      Object? finalPlanKey = companyData?['plan'] ?? 'free';

      // Try to get subscription data (source of truth for active plans)
      try {
        final subscription =
            await db.collection('subscriptions').doc(companyId).get();
        if (subscription.exists) {
          final data = subscription.data();
          final status = data?['status']?.toString().toLowerCase() ?? '';
          final expiresAt = data?['expiresAt'];
          final isExpired =
              expiresAt is Timestamp &&
              expiresAt.toDate().isBefore(DateTime.now());
          final isActive =
              (status == 'active' || status == 'admin_granted') && !isExpired;
          if (isActive && data != null && data['plan'] != null) {
            finalPlanKey = data['plan'];
          }
        }
      } catch (_) {
        // Ignore errors fetching subscription details
      }

      return planForKey(finalPlanKey);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Broad permission check to handle various SDK error formats
      if (msg.contains('permission') || 
          msg.contains('denied') || 
          msg.contains('insufficient') ||
          msg.contains('missing')) {
        return planForKey('free');
      }
      rethrow;
    }
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
              .collection('orders')
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
    } on AppException {
      rethrow;
    } catch (error) {
      final msg = error.toString().toLowerCase();
      if (msg.contains('failed-precondition') || msg.contains('index')) {
        throw AppException(
          'Order limit check is temporarily unavailable while its Firestore '
              'index builds. Please try again shortly.',
          'index_building',
        );
      }
      if (msg.contains('permission') || msg.contains('denied') || msg.contains('insufficient') || msg.contains('missing')) {
        return; 
      }
      throw AppException(
        'Could not verify the active order limit. Please try again.',
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
      try {
        final existing = await links.doc(supplierId).get();
        final status = existing.data()?['status']?.toString().toLowerCase();
        if (existing.exists && (status == 'active' || status == 'approved')) {
          return;
        }
      } catch (_) {}
    }

    final plan = await companyPlan(db, companyId);
    if (plan.maxSuppliers == -1) return;

    try {
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
    } on AppException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('permission') || msg.contains('denied') || msg.contains('insufficient') || msg.contains('missing')) {
        return;
      }
      throw AppException(
        'Could not verify supplier capacity.',
      );
    }
  }

  static Future<void> ensureFieldUserCapacity(
    FirebaseFirestore db,
    String companyId, {
    String? planKey,
  }) async {
    // 1. Get current plan definition
    final plan = await companyPlan(db, companyId, planKey: planKey);
    
    // 2. If plan is unlimited, allow immediately
    if (plan.maxFieldUsers == -1) return;

    try {
      // 3. Count active field users
      final count =
          await db
              .collection('companies')
              .doc(companyId)
              .collection('fieldUsers')
              .where('status', isEqualTo: 'active')
              .count()
              .get();
              
      // 4. Check against limit
      if ((count.count ?? 0) >= plan.maxFieldUsers) {
        throw AppException(
          'Team size limit reached for this company (${plan.maxFieldUsers}) on '
              'the ${plan.name} plan. Please contact your CEO to upgrade.',
          'limit_reached',
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      // During registration, we fail OPEN for any unexpected error
      // to ensure the user isn't blocked by transient Firestore/Auth sync issues.
      debugPrint("Ignoring capacity check error: $e");
      return; 
    }
  }
}
