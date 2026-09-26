import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/audit_log_model.dart';

void main() {
  group('AuditLogModel.fromMap', () {
    test('parses missing timestamps without throwing', () {
      final log = AuditLogModel.fromMap('log-1', {
        'actorId': 'admin-1',
        'actorName': 'Admin',
        'actionType': 'approve_ceo',
        'targetType': 'ceo',
        'targetId': 'ceo-1',
        'description': 'Approved CEO Test User for company Acme',
      });

      expect(log.actorId, 'admin-1');
      expect(log.targetId, 'ceo-1');
      expect(log.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('parses ISO timestamp strings', () {
      final log = AuditLogModel.fromMap('log-2', {
        'actorId': 'admin-1',
        'actionType': 'settle_commission',
        'targetType': 'supplier',
        'targetId': 'sup-1',
        'description': 'Marked 2 commission transaction(s) as settled for Steel Co (Rs 1500)',
        'timestamp': '2026-08-18T10:00:00.000Z',
      });

      expect(log.timestamp.toUtc(), DateTime.utc(2026, 8, 18, 10));
    });
  });

  group('AuditLogModel.matchingActionTypes', () {
    test('ban/reactivate filters include historical aliases', () {
      expect(
        AuditLogModel.matchingActionTypes('ban_company'),
        {'ban_company', 'suspend_ceo'},
      );
      expect(
        AuditLogModel.matchingActionTypes('reactivate_company'),
        {'reactivate_company', 'activate_ceo'},
      );
      expect(
        AuditLogModel.matchingActionTypes('ban_supplier'),
        {'ban_supplier', 'suspend_supplier'},
      );
    });

    test('exact action types filter only that type', () {
      expect(
        AuditLogModel.matchingActionTypes('approve_ceo'),
        {'approve_ceo'},
      );
      expect(
        AuditLogModel.matchingActionTypes('settle_commission'),
        {'settle_commission'},
      );
    });
  });
}
