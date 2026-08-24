import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String id;
  final String actorId;
  final String actorName;
  final String actionType;
  final String targetType; // 'ceo' | 'supplier' | 'company' | 'category' | 'dispute' | 'transaction'
  final String targetId;
  final String description;
  final String? reason;
  final DateTime timestamp;

  AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.description,
    this.reason,
    required this.timestamp,
  });

  /// Historical action types written before Ban/Reactivate/Settle were named
  /// explicitly. Activity Log filters should include these aliases.
  static Set<String> matchingActionTypes(String selected) {
    switch (selected) {
      case 'all':
        return const {};
      case 'ban_company':
        return const {'ban_company', 'suspend_ceo'};
      case 'reactivate_company':
        return const {'reactivate_company', 'activate_ceo'};
      case 'ban_supplier':
        return const {'ban_supplier', 'suspend_supplier'};
      case 'reactivate_supplier':
        return const {'reactivate_supplier'};
      case 'settle_commission':
        return const {'settle_commission'};
      case 'restrict_supplier_commission':
        return const {'restrict_supplier_commission'};
      case 'lift_commission_restriction':
        return const {'lift_commission_restriction'};
      case 'update_commission_settings':
        return const {'update_commission_settings'};
      default:
        return {selected};
    }
  }

  static DateTime parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is num) {
      final millis = value > 9999999999 ? value.toInt() : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory AuditLogModel.fromMap(String id, Map<String, dynamic> map) {
    return AuditLogModel(
      id: id,
      actorId: map['actorId']?.toString() ?? '',
      actorName: map['actorName']?.toString() ?? 'Admin',
      actionType: map['actionType']?.toString() ?? '',
      targetType: map['targetType']?.toString() ?? '',
      targetId: map['targetId']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      reason: map['reason']?.toString(),
      timestamp: parseTimestamp(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'actionType': actionType,
      'targetType': targetType,
      'targetId': targetId,
      'description': description,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
