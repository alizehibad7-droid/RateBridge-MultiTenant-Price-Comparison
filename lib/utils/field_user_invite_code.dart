import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

/// 30-minute validity for the CEO **company** field-user invite code.
///
/// Supplier partnership invites use [AppConstants.inviteTokenExpiry] on the
/// `invitations` collection and are not governed by this helper.
class FieldUserInviteCode {
  FieldUserInviteCode._();

  static DateTime? parseGeneratedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static DateTime expiresAt(DateTime generatedAt) =>
      generatedAt.add(AppConstants.fieldUserInviteCodeExpiry);

  static bool isExpired(DateTime? generatedAt, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (generatedAt == null) return true;
    return !clock.isBefore(expiresAt(generatedAt));
  }

  static Duration remaining(DateTime? generatedAt, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (generatedAt == null) return Duration.zero;
    final left = expiresAt(generatedAt).difference(clock);
    return left.isNegative ? Duration.zero : left;
  }

  static String statusLabel(DateTime? generatedAt, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (isExpired(generatedAt, now: clock)) {
      return 'Expired — regenerate a new code';
    }
    final left = remaining(generatedAt, now: clock);
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;
    if (minutes > 0) {
      return 'Valid for ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return 'Valid for ${seconds}s';
  }

  static const expiredRegistrationMessage =
      'This invite code has expired. Ask your CEO to generate a new one and try again.';
}
