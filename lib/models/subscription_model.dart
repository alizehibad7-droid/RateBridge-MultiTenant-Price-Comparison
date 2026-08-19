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
      'Email support',
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
      'AI price recommendations',
      'Chat with suppliers',
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
      'Priority supplier matching',
      'Advanced AI analytics',
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

  factory SubscriptionModel.fromMap(
      String companyId, Map<String, dynamic> map) {
    final rawHistory = map['history'] as List<dynamic>? ?? [];
    return SubscriptionModel(
      companyId: companyId,
      plan: map['plan'] ?? 'free',
      status: map['status'] ?? 'active',
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
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
