import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/notification_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/notification_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/supplier/supplier_async_states.dart';

class SupplierNotificationsView extends StatefulWidget {
  const SupplierNotificationsView({super.key});

  @override
  State<SupplierNotificationsView> createState() =>
      _SupplierNotificationsViewState();
}

class _SupplierNotificationsViewState extends State<SupplierNotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWatching());
  }

  void _startWatching() {
    final uid = context.read<AuthViewModel>().user?.uid ??
        context.read<NotificationViewModel>().uid;
    if (uid == null) return;
    final vm = context.read<NotificationViewModel>();
    vm.loadNotifications(uid);
    vm.watchUnreadCount(uid);
  }

  Future<void> _markAllRead() async {
    final uid = context.read<NotificationViewModel>().uid;
    if (uid == null) return;
    await context.read<NotificationViewModel>().markAllRead(uid);
  }

  Future<void> _onNotificationTap(NotificationModel notification) async {
    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;

    if (!notification.isRead) {
      await vm.markAsRead(uid, notification.notifId);
    }

    if (!mounted) return;
    navigateForSupplierNotification(context, notification);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: SupplierAppBar(
        title: 'Notifications',
        actions: [
          if (vm.unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTextStyles.caption.copyWith(
                  color: FieldColors.accentAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: vm.uid == null
          ? const Center(child: CircularProgressIndicator())
          : vm.errorMessage != null && vm.notifications.isEmpty
              ? _NotificationsError(
                  message: vm.errorMessage!,
                  onRetry: _startWatching,
                )
              : vm.isLoading && vm.notifications.isEmpty
                  ? const SupplierListSkeleton(itemCount: 5, itemHeight: 88)
                  : vm.notifications.isEmpty
                      ? const SupplierEmptyState(
                          icon: Icons.notifications_none_outlined,
                          title: 'No notifications yet',
                          subtitle:
                              'Updates about your orders and messages will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: vm.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification = vm.notifications[index];
                            return _NotificationTile(
                              notification: notification,
                              relativeTime: notificationRelativeTime(
                                notification.createdAt,
                              ),
                              onTap: () => _onNotificationTap(notification),
                            );
                          },
                        ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String relativeTime;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.relativeTime,
    required this.onTap,
  });

  NotificationIconConfig _iconConfig(String type) {
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
        FieldColors.statusWarning,
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
    if (normalized.contains('cancel') || normalized.contains('reject')) {
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

  @override
  Widget build(BuildContext context) {
    final iconConfig = _iconConfig(notification.type);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: isUnread
                ? FieldColors.primaryNavy.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isUnread
                  ? FieldColors.primaryNavy.withValues(alpha: 0.15)
                  : FieldColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUnread)
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: FieldColors.primaryNavy.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconConfig.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          iconConfig.icon,
                          size: 20,
                          color: iconConfig.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 15,
                                fontWeight:
                                    isUnread ? FontWeight.w700 : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.body,
                              style: AppTextStyles.bodyMuted,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              relativeTime,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: FieldColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: FieldColors.statusDanger,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load notifications',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: FieldColors.primaryNavy,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
