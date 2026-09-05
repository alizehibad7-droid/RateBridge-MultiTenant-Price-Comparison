import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/route_names.dart';
import '../models/chat_thread_model.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import '../theme/field_theme.dart';
import '../utils/chat_id_utils.dart';
import '../views/field_user/chat/field_chat_thread_args.dart';

class NotificationIconConfig {
  final IconData icon;
  final Color color;

  const NotificationIconConfig(this.icon, this.color);
}

NotificationIconConfig notificationIconForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('chat')) {
    return const NotificationIconConfig(
      Icons.chat_bubble_outline,
      FieldColors.primaryNavy,
    );
  }
  if (normalized.contains('delivery') || normalized.contains('delivered')) {
    return const NotificationIconConfig(
      Icons.local_shipping_outlined,
      FieldColors.statusSuccess,
    );
  }
  if (normalized.contains('neworder')) {
    return const NotificationIconConfig(
      Icons.add_shopping_cart_outlined,
      FieldColors.primaryNavy,
    );
  }
  if (normalized.contains('rating')) {
    return const NotificationIconConfig(
      Icons.star_outline_rounded,
      FieldColors.accentAmber,
    );
  }
  if (normalized.contains('approval')) {
    return const NotificationIconConfig(
      Icons.verified_outlined,
      FieldColors.statusWarning,
    );
  }
  if (normalized.contains('commission') || normalized.contains('payment')) {
    return const NotificationIconConfig(
      Icons.payments_outlined,
      FieldColors.statusSuccess,
    );
  }
  if (normalized.contains('partnership')) {
    return const NotificationIconConfig(
      Icons.handshake_outlined,
      FieldColors.accentAmber,
    );
  }
  if (normalized.contains('cancel')) {
    return const NotificationIconConfig(
      Icons.cancel_outlined,
      FieldColors.statusDanger,
    );
  }
  return const NotificationIconConfig(
    Icons.receipt_long_outlined,
    FieldColors.primaryNavy,
  );
}

String notificationRelativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(date);
}

String _notifHaystack(NotificationModel notification) {
  return '${notification.type} ${notification.title} ${notification.message}'
      .toLowerCase();
}

bool _notifContains(NotificationModel notification, String keyword) {
  return _notifHaystack(notification).contains(keyword.toLowerCase());
}

bool _isAwardedRfq(NotificationModel notification) {
  final awarded = notification.data['awarded']?.toString().toLowerCase();
  if (awarded == 'true' || awarded == '1') return true;
  return _notifContains(notification, 'awarded');
}

String? _dataString(Map<String, dynamic> data, String key) {
  final value = data[key]?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

void navigateForFieldNotification(
  BuildContext context,
  NotificationModel notification,
) {
  final data = notification.data;
  final orderId = _dataString(data, 'orderId');

  if (_notifContains(notification, 'chat')) {
    final supplierUid =
        _dataString(data, 'supplierUid') ?? _dataString(data, 'supplierId');
    final supplierName = _dataString(data, 'supplierName') ?? 'Supplier';
    if (supplierUid != null) {
      context.push(
        RouteNames.fieldChatThread.replaceFirst(':orderId', supplierUid),
        extra: FieldChatThreadArgs(
          supplierUid: supplierUid,
          supplierName: supplierName,
          orderId: orderId,
        ),
      );
      return;
    }
    context.push(RouteNames.fieldChat);
    return;
  }

  if (_notifContains(notification, 'dispute')) {
    context.push(RouteNames.fieldMyDisputes);
    return;
  }

  if (_notifContains(notification, 'rfq')) {
    final rfqId = _dataString(data, 'rfqId');
    if (rfqId != null) {
      context.push(RouteNames.fieldRfqDetail.replaceFirst(':rfqId', rfqId));
      return;
    }
    context.push(RouteNames.fieldRfqs);
    return;
  }

  if (orderId != null) {
    context.push(RouteNames.fieldOrderDetail.replaceFirst(':orderId', orderId));
    return;
  }

  context.push(RouteNames.fieldHome);
}

ChatThreadModel supplierChatThreadFromOrder({
  required OrderModel order,
  required String supplierUid,
}) {
  final chatId = ChatIdUtils.buildChatId(
    companyId: order.companyId,
    fieldUserId: order.fieldUserUid,
    supplierId: supplierUid,
  );
  return ChatThreadModel(
    chatId: chatId,
    companyId: order.companyId,
    fieldUserId: order.fieldUserUid,
    supplierId: supplierUid,
    supplierName: order.supplierName,
    fieldUserName: order.fieldUserName,
    lastMessage: '',
    lastMessageAt: DateTime.now(),
  );
}

void navigateForSupplierNotification(
  BuildContext context,
  NotificationModel notification,
) {
  final data = notification.data;
  final orderId = _dataString(data, 'orderId');

  if (_notifContains(notification, 'chat')) {
    final chatId = _dataString(data, 'chatId');
    final companyId = _dataString(data, 'companyId') ?? '';
    final fieldUserId = _dataString(data, 'fieldUserId') ?? '';
    final fieldUserName = _dataString(data, 'fieldUserName') ?? 'Field User';
    final supplierId =
        _dataString(data, 'supplierId') ?? _dataString(data, 'supplierUid') ?? '';
    if (chatId != null) {
      context.push(
        RouteNames.supplierChatThread.replaceFirst(':orderId', chatId),
        extra: ChatThreadModel(
          chatId: chatId,
          companyId: companyId,
          fieldUserId: fieldUserId,
          supplierId: supplierId,
          fieldUserName: fieldUserName,
          supplierName: _dataString(data, 'supplierName') ?? '',
          lastMessage: notification.body,
          lastMessageAt: notification.createdAt,
          lastSenderId: fieldUserId,
        ),
      );
      return;
    }
    context.push(RouteNames.supplierChat);
    return;
  }

  if (_notifContains(notification, 'partnership')) {
    final event = (_dataString(data, 'event') ?? '').toLowerCase();
    if (event == 'invitation_received') {
      context.push('${RouteNames.supplierMyCompanies}?tab=1');
      return;
    }
    context.push(RouteNames.supplierMyCompanies);
    return;
  }

  if (_notifContains(notification, 'rating')) {
    context.push(RouteNames.supplierRatings);
    return;
  }

  if (_notifContains(notification, 'commission') ||
      _notifContains(notification, 'payment')) {
    context.push(RouteNames.supplierEarnings);
    return;
  }

  if (_notifContains(notification, 'dispute')) {
    context.push(RouteNames.supplierMyDisputes);
    return;
  }

  if (_notifContains(notification, 'rfq')) {
    if (_isAwardedRfq(notification) || orderId != null) {
      context.push(RouteNames.supplierOrders);
      return;
    }
    final rfqId = _dataString(data, 'rfqId');
    if (rfqId != null) {
      context.push(RouteNames.supplierSubmitBid.replaceFirst(':rfqId', rfqId));
      return;
    }
    context.push(RouteNames.supplierRfqs);
    return;
  }

  if (orderId != null ||
      _notifContains(notification, 'order') ||
      _notifContains(notification, 'delivery')) {
    context.push(RouteNames.supplierOrders);
    return;
  }

  context.push(RouteNames.supplierDashboard);
}

void navigateForCeoNotification(
  BuildContext context,
  NotificationModel notification,
) {
  final data = notification.data;
  final orderId = _dataString(data, 'orderId');

  if (_notifContains(notification, 'partnership')) {
    context.push(RouteNames.ceoJoinRequests);
    return;
  }

  if (_notifContains(notification, 'rfq')) {
    final rfqId = _dataString(data, 'rfqId');
    if (rfqId != null) {
      context.push(RouteNames.ceoRfqDetail.replaceFirst(':rfqId', rfqId));
      return;
    }
    context.push(RouteNames.ceoRfqs);
    return;
  }

  if (_notifContains(notification, 'dispute')) {
    context.push(RouteNames.ceoDisputes);
    return;
  }

  if (_notifContains(notification, 'payment') ||
      _notifContains(notification, 'commission') ||
      _notifContains(notification, 'subscription')) {
    context.push(RouteNames.ceoSubscription);
    return;
  }

  if (orderId != null) {
    if (data['status'] == 'pending_approval') {
      context.push('${RouteNames.ceoOrders}?tab=1');
    } else {
      context.push(RouteNames.ceoOrders);
    }
    return;
  }

  context.push(RouteNames.ceoDashboard);
}

void navigateForAdminNotification(
  BuildContext context,
  NotificationModel notification,
) {
  if (_notifContains(notification, 'dispute')) {
    context.push(RouteNames.adminDisputes);
    return;
  }
  if (_notifContains(notification, 'subscription') ||
      (_notifContains(notification, 'payment') &&
          !_notifContains(notification, 'commission'))) {
    context.push(RouteNames.adminSubscription);
    return;
  }
  if (_notifContains(notification, 'commission') ||
      _notifContains(notification, 'payment')) {
    context.push(RouteNames.adminPayments);
    return;
  }
  if (_notifContains(notification, 'approval')) {
    context.push(RouteNames.adminCompanies);
    return;
  }
  context.push(RouteNames.adminDashboard);
}
