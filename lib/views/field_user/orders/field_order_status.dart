import 'package:flutter/material.dart';

import '../../../theme/field_theme.dart';

/// Status helpers for field-user order tabs and actions.
/// Flow: pending → accepted → delivered → confirmed
/// (rejected from pending; cancelled from pending or accepted).
class FieldOrderStatus {
  FieldOrderStatus._();

  static String normalize(String status) =>
      status.toLowerCase().replaceAll('_', '');

  static bool isPending(String status) {
    final s = normalize(status);
    return s == 'pendingapproval' || s == 'pending';
  }

  static bool isActive(String status) => normalize(status) == 'accepted';

  static bool isHistory(String status) {
    final s = normalize(status);
    return s == 'delivered' ||
        s == 'confirmed' ||
        s == 'cancelled' ||
        s == 'rejected';
  }

  static bool canCancel(String status) {
    final s = normalize(status);
    return s == 'pendingapproval' || s == 'pending' || s == 'accepted';
  }

  static bool canConfirmDelivery(String status) =>
      normalize(status) == 'delivered';

  static bool canRate(String status) => normalize(status) == 'confirmed';

  static bool isTerminal(String status) {
    final s = normalize(status);
    return s == 'cancelled' || s == 'rejected';
  }

  /// Step index for the order progress stepper (0–3), or -1 for terminal.
  static int stepIndex(String status) {
    final s = normalize(status);
    if (s == 'pendingapproval' || s == 'pending') return 0;
    if (s == 'accepted' || s == 'inprogress') return 1;
    if (s == 'delivered') return 2;
    if (s == 'confirmed') return 3;
    return -1;
  }

  static String displayLabel(String status) {
    final s = normalize(status);
    switch (s) {
      case 'pendingapproval':
      case 'pending':
        return 'Pending';
      case 'accepted':
      case 'inprogress':
        return 'Accepted';
      case 'delivered':
        return 'Delivered';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  /// Background and foreground colors for status pills.
  static ({Color bg, Color fg}) colorsFor(String status) =>
      FieldStatusColors.forStatus(status);
}

enum FieldOrderTab { pending, active, history }
