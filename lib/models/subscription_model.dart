// Models — plain data classes, no logic beyond getters/serialization.

import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanId { free, basic, premium }

class PlanDefinition {
  final PlanId id;
  final String name;
  final int priceRs;
  final int durationDays;
  final List<String> features;
  final bool aiUnlocked;
  final int maxActiveOrders;
  final int maxSuppliers;
  final int maxFieldUsers;
  final int priceHistoryDays;

  const PlanDefinition({
    required this.id,
    required this.name,
    required this.priceRs,
    required this.durationDays,
    required this.features,
    required this.aiUnlocked,
    this.maxActiveOrders = -1, // -1 means unlimited
    this.maxSuppliers = -1,
    this.maxFieldUsers = -1,
    this.priceHistoryDays = -1,
  });

  String get planKey => id.name;
}

const kPlans = <PlanDefinition>[
  PlanDefinition(
    id: PlanId.free,
    name: 'Free',
    priceRs: 0,
    durationDays: 0,
    maxActiveOrders: 5,
    maxSuppliers: 3,
    maxFieldUsers: 3,
    priceHistoryDays: 30,
    features: [
      'Browse supplier marketplace',
      'Max 3 linked suppliers',
      'Up to 5 active orders',
      'Max 3 field users',
      '30-day price trends',
    ],
    aiUnlocked: false,
  ),
  PlanDefinition(
    id: PlanId.basic,
    name: 'Basic',
    priceRs: 1000,
    durationDays: 30,
    maxActiveOrders: -1,
    maxSuppliers: 15,
    maxFieldUsers: 15,
    priceHistoryDays: -1,
    features: [
      'Everything in Free',
      'Unlimited active orders',
      'Max 15 linked suppliers',
      'Max 15 field users',
      'Full price trend history',
    ],
    aiUnlocked: true,
  ),
  PlanDefinition(
    id: PlanId.premium,
    name: 'Premium',
    priceRs: 5000,
    durationDays: 30,
    maxActiveOrders: -1,
    maxSuppliers: -1,
    maxFieldUsers: -1,
    priceHistoryDays: -1,
    features: [
      'Everything in Basic',
      'Unlimited linked suppliers',
      'Unlimited field users',
    ],
    aiUnlocked: true,
  ),
];

class SubscriptionModel {
  final String companyId;
  final String plan;
  final String status; // active | expired | cancelled | admin_granted
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool adminGranted;
  final String? adminNote;
  final List<SubscriptionHistoryEntry> history;

  const SubscriptionModel({
    required this.companyId,
    required this.plan,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.adminGranted = false,
    this.adminNote,
    this.history = const [],
  });

  bool get isActive {
    // Free never expires — treat as always available when present.
    if (plan == 'free') {
      return status == 'active' || status == 'admin_granted' || status.isEmpty;
    }
    if (status != 'active' && status != 'admin_granted') return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  int get daysRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  PlanDefinition get planDef => kPlans.firstWhere(
        (p) => p.planKey == plan,
        orElse: () => kPlans.first,
      );

  /// The definition of the plan that is currently in effect (falls back to Free if inactive).
  PlanDefinition get effectivePlanDef => isActive ? planDef : kPlans.first;

  /// Centralized feature check.
  /// Hierarchy: premium > basic > free
  bool hasAccess(PlanId requiredPlan) {
    final current = effectivePlanDef.id;
    
    switch (current) {
      case PlanId.premium:
        return true;
      case PlanId.basic:
        return requiredPlan == PlanId.basic || requiredPlan == PlanId.free;
      case PlanId.free:
        return requiredPlan == PlanId.free;
    }
  }

  factory SubscriptionModel.fromMap(
      String companyId, Map<String, dynamic> map) {
    final rawHistory = map['history'] as List<dynamic>? ?? [];
    final history = <SubscriptionHistoryEntry>[];
    for (final e in rawHistory) {
      if (e is! Map) continue;
      try {
        history.add(
          SubscriptionHistoryEntry.fromMap(Map<String, dynamic>.from(e)),
        );
      } catch (_) {
        // Skip malformed history rows so one bad entry cannot blank the plan UI.
      }
    }
    return SubscriptionModel(
      companyId: companyId,
      plan: (map['plan'] as String?)?.trim().isNotEmpty == true
          ? (map['plan'] as String).trim()
          : 'free',
      status: (map['status'] as String?)?.trim().isNotEmpty == true
          ? (map['status'] as String).trim()
          : 'active',
      startedAt: _readDate(map['startedAt']),
      expiresAt: _readDate(map['expiresAt']),
      adminGranted: map['adminGranted'] == true,
      adminNote: map['adminNote'] as String?,
      history: history,
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() => {
        'plan': plan,
        'status': status,
        'startedAt':
            startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'expiresAt':
            expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'adminGranted': adminGranted,
        'adminNote': adminNote,
      };
}

class SubscriptionHistoryEntry {
  final String plan;
  final String action; // purchased | admin_granted | expired | cancelled
  final DateTime date;
  final int? amountPaid;
  final String? note;
  final String? stripePaymentIntentId;

  const SubscriptionHistoryEntry({
    required this.plan,
    required this.action,
    required this.date,
    this.amountPaid,
    this.note,
    this.stripePaymentIntentId,
  });

  factory SubscriptionHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SubscriptionHistoryEntry(
      plan: map['plan']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      date: SubscriptionModel._readDate(map['date']) ?? DateTime.now(),
      amountPaid: map['amountPaid'] is num
          ? (map['amountPaid'] as num).round()
          : int.tryParse('${map['amountPaid'] ?? ''}'),
      note: map['note']?.toString(),
      stripePaymentIntentId: map['stripePaymentIntentId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'plan': plan,
        'action': action,
        'date': Timestamp.fromDate(date),
        if (amountPaid != null) 'amountPaid': amountPaid,
        if (note != null) 'note': note,
        if (stripePaymentIntentId != null && stripePaymentIntentId!.isNotEmpty)
          'stripePaymentIntentId': stripePaymentIntentId,
      };
}
