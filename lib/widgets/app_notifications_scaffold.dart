import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_model.dart';
import '../theme/field_theme.dart';
import '../utils/notification_utils.dart';
import '../viewmodels/notification_viewmodel.dart';

typedef NotificationTapHandler = void Function(
  BuildContext context,
  NotificationModel notification,
);

/// Shared notifications list used by field, supplier, and admin screens.
class AppNotificationsScaffold extends StatelessWidget {
  final String title;
  final NotificationTapHandler onNotificationTap;
  final Color? backgroundColor;

  const AppNotificationsScaffold({
    super.key,
    required this.title,
    required this.onNotificationTap,
    this.backgroundColor,
  });

  Future<void> _markAllRead(BuildContext context) async {
    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;
    await vm.markAllRead(uid);
  }

  void _retryLoad(BuildContext context) {
    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;
    vm.loadNotifications(uid);
  }

  Future<void> _handleTap(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;

    if (!notification.isRead) {
      await vm.markAsRead(uid, notification.notifId);
    }
    if (!context.mounted) return;
    onNotificationTap(context, notification);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: backgroundColor ?? FieldColors.screenBackground,
      appBar: AppBar(
        title: Text(title, style: FieldTypography.headlineMedium),
        actions: [
          if (vm.unreadCount > 0)
            TextButton(
              onPressed: () => _markAllRead(context),
              child: Text(
                'Mark all read',
                style: FieldTypography.labelSmall.copyWith(
                  color: FieldColors.primaryNavy,
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
                  onRetry: () => _retryLoad(context),
                )
              : vm.isLoading && vm.notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : vm.notifications.isEmpty
                      ? const _NotificationsEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            FieldSpacing.lg,
                            FieldSpacing.sm,
                            FieldSpacing.lg,
                            FieldSpacing.xxl,
                          ),
                          itemCount: vm.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: FieldSpacing.sm),
                          itemBuilder: (context, index) {
                            final notification = vm.notifications[index];
                            return _NotificationTile(
                              notification: notification,
                              relativeTime: notificationRelativeTime(
                                notification.createdAt,
                              ),
                              onTap: () => _handleTap(context, notification),
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

  @override
  Widget build(BuildContext context) {
    final iconConfig = notificationIconForType(notification.type);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            color: isUnread
                ? FieldColors.primaryNavy.withValues(alpha: 0.04)
                : FieldColors.surfaceWhite,
            borderRadius: BorderRadius.circular(FieldRadius.card),
            border: Border.all(
              color: isUnread
                  ? FieldColors.primaryNavy.withValues(alpha: 0.12)
                  : FieldColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUnread)
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: FieldSpacing.md),
                  decoration: BoxDecoration(
                    color: FieldColors.primaryNavy.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(FieldSpacing.xs / 2),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(FieldSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconConfig.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(FieldRadius.button),
                        ),
                        child: Icon(
                          iconConfig.icon,
                          size: 20,
                          color: iconConfig.color,
                        ),
                      ),
                      const SizedBox(width: FieldSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: FieldTypography.titleMedium.copyWith(
                                fontWeight:
                                    isUnread ? FontWeight.w700 : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: FieldSpacing.xs),
                            Text(
                              notification.body,
                              style: FieldTypography.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: FieldSpacing.sm),
                            Text(
                              relativeTime,
                              style: FieldTypography.labelSmall.copyWith(
                                fontSize: 10,
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

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 40,
              color: FieldColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: FieldSpacing.md),
            Text('No notifications yet', style: FieldTypography.titleMedium),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              'Updates about your orders and messages will appear here.',
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: FieldColors.statusDanger,
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              'Could not load notifications',
              style: FieldTypography.titleMedium,
            ),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium,
            ),
            const SizedBox(height: FieldSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
