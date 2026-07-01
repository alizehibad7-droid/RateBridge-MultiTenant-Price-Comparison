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

void navigateForFieldNotification(
  BuildContext context,
  NotificationModel notification,
) {
  final data = notification.data;
  final type = notification.type.toLowerCase();
  final orderId = data['orderId'] as String?;

  if (type.contains('chat')) {
    final supplierUid =
        data['supplierUid'] as String? ?? data['supplierId'] as String?;
    final supplierName = data['supplierName'] as String? ?? 'Supplier';
    if (supplierUid != null && supplierUid.isNotEmpty) {
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
  }

  if (orderId != null && orderId.isNotEmpty) {
    context.push(RouteNames.fieldOrderDetail.replaceFirst(':orderId', orderId));
    return;
  }

  if (type.contains('payment')) {
    context.push(RouteNames.fieldProfile);
  }
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
  final type = notification.type.toLowerCase();
  final orderId = data['orderId'] as String?;

  if (type.contains('partnership')) {
    final event = (data['event'] as String? ?? '').toLowerCase();
    if (event == 'invitation_received') {
      context.push('${RouteNames.supplierMyCompanies}?tab=1');
      return;
    }
    context.push(RouteNames.supplierMyCompanies);
    return;
  }

  if (type.contains('chat')) {
    final chatId = data['chatId'] as String?;
    final companyId = data['companyId'] as String? ?? '';
    final fieldUserId = data['fieldUserId'] as String? ?? '';
    final fieldUserName = data['fieldUserName'] as String? ?? 'Field User';
    final supplierId =
        data['supplierId'] as String? ?? data['supplierUid'] as String? ?? '';
    if (chatId != null && chatId.isNotEmpty) {
      context.push(
        RouteNames.supplierChatThread.replaceFirst(':orderId', chatId),
        extra: ChatThreadModel(
          chatId: chatId,
          companyId: companyId,
          fieldUserId: fieldUserId,
          supplierId: supplierId,
          fieldUserName: fieldUserName,
          supplierName: data['supplierName'] as String? ?? '',
          lastMessage: notification.body,
          lastMessageAt: notification.createdAt,
          lastSenderId: fieldUserId,
        ),
      );
      return;
    }
  }

  if (orderId != null && orderId.isNotEmpty) {
    context.push(RouteNames.supplierOrders);
    return;
  }

  context.push(RouteNames.supplierChat);
}

void navigateForAdminNotification(
  BuildContext context,
  NotificationModel notification,
) {
  final type = notification.type.toLowerCase();
  if (type.contains('payment') || type.contains('subscription')) {
    context.push(RouteNames.adminSubscription);
    return;
  }
  if (type.contains('commission')) {
    context.push(RouteNames.adminDashboard);
    return;
  }
  if (type.contains('approval')) {
    context.push(RouteNames.adminCompanies);
    return;
  }
  context.push(RouteNames.adminDashboard);
}
