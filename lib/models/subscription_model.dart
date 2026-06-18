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
  final bool prioritySupport;

  const PlanDefinition({
    required this.id,
    required this.name,
    required this.priceRs,
    required this.durationDays,
    required this.features,
    required this.aiUnlocked,
    required this.prioritySupport,
  });

  String get planKey => id.name;
}

const kPlans = <PlanDefinition>[
  PlanDefinition(
    id: PlanId.free,
    name: 'Free',
    priceRs: 0,
    durationDays: 0,
    features: [
      'Browse supplier marketplace',
      'Up to 5 active orders',
      'Basic material comparison',
      'Email support',
    ],
    aiUnlocked: false,
    prioritySupport: false,
  ),
  PlanDefinition(
    id: PlanId.basic,
    name: 'Basic',
    priceRs: 1000,
    durationDays: 30,
    features: [
      'Everything in Free',
      'Unlimited active orders',
      'AI price recommendations',
      'Price trend analytics',
      'Chat with suppliers',
      'Email + chat support',
    ],
    aiUnlocked: true,
    prioritySupport: false,
  ),
  PlanDefinition(
    id: PlanId.premium,
    name: 'Premium',
    priceRs: 5000,
    durationDays: 30,
    features: [
      'Everything in Basic',
      'Priority supplier matching',
      'Advanced AI analytics',
      'Dedicated account manager',
      '24/7 priority support',
      'Custom reporting',
    ],
    aiUnlocked: true,
    prioritySupport: true,
  ),
];

class SubscriptionModel {
  final String companyId;
  final String plan;
  final String status; // active | expired | cancelled | admin_granted
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? stripePaymentIntentId;
  final bool adminGranted;
  final String? adminNote;
  final List<SubscriptionHistoryEntry> history;

  const SubscriptionModel({
    required this.companyId,
    required this.plan,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.stripePaymentIntentId,
    this.adminGranted = false,
    this.adminNote,
    this.history = const [],
  });

  bool get isActive =>
      status == 'active' || status == 'admin_granted';

  int get daysRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  PlanDefinition get planDef => kPlans.firstWhere(
        (p) => p.planKey == plan,
        orElse: () => kPlans.first,
      );

  factory SubscriptionModel.fromMap(
      String companyId, Map<String, dynamic> map) {
    final rawHistory = map['history'] as List<dynamic>? ?? [];
    return SubscriptionModel(
      companyId: companyId,
      plan: map['plan'] ?? 'free',
      status: map['status'] ?? 'active',
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      stripePaymentIntentId: map['stripePaymentIntentId'],
      adminGranted: map['adminGranted'] ?? false,
      adminNote: map['adminNote'],
      history: rawHistory
          .map((e) => SubscriptionHistoryEntry.fromMap(
              e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'plan': plan,
        'status': status,
        'startedAt':
            startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'expiresAt':
            expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'stripePaymentIntentId': stripePaymentIntentId,
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

  const SubscriptionHistoryEntry({
    required this.plan,
    required this.action,
    required this.date,
    this.amountPaid,
    this.note,
  });

  factory SubscriptionHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SubscriptionHistoryEntry(
      plan: map['plan'] ?? '',
      action: map['action'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amountPaid: map['amountPaid'],
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() => {
        'plan': plan,
        'action': action,
        'date': Timestamp.fromDate(date),
        if (amountPaid != null) 'amountPaid': amountPaid,
        if (note != null) 'note': note,
      };
}
