import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/notification_model.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/notification_utils.dart';
import '../../../viewmodels/field_user/field_notifications_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../widgets/field_async_states.dart';

/// Notifications list — stream is started by [FieldShellView._bootstrapSession].
class FieldNotificationsView extends StatelessWidget {
  const FieldNotificationsView({super.key});

  Future<void> _markAllRead(BuildContext context) async {
    final uid = context.read<FieldSessionViewModel>().user?.uid;
    if (uid == null) return;
    await context.read<FieldNotificationsViewModel>().markAllRead(uid);
  }

  void _retryLoad(BuildContext context) {
    final uid = context.read<FieldSessionViewModel>().user?.uid;
    if (uid == null) return;
    context.read<FieldNotificationsViewModel>().watchNotifications(uid);
  }

  Future<void> _onNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final uid = context.read<FieldSessionViewModel>().user?.uid;
    if (uid == null) return;

    if (!notification.isRead) {
      await context.read<FieldNotificationsViewModel>().markAsRead(
        uid,
        notification.notifId,
      );
    }

    if (!context.mounted) return;
    navigateForFieldNotification(context, notification);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FieldNotificationsViewModel>();

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: FieldAppBar(
          title: 'Notifications',
          actions: [
            if (vm.unreadCount > 0)
              TextButton(
                onPressed: () => _markAllRead(context),
                child: Text(
                  'Mark all read',
                  style: FieldTypography.labelSmall.copyWith(
                    color: FieldColors.accentAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        body:
            vm.errorMessage != null && vm.notifications.isEmpty
                ? FieldErrorState(
                    title: 'Could not load notifications',
                    message: vm.errorMessage!,
                    onRetry: () => _retryLoad(context),
                  )
                : vm.isLoading && vm.notifications.isEmpty
                ? const FieldListSkeleton(itemCount: 5)
                : vm.notifications.isEmpty
                ? const FieldEmptyState(
                    icon: Icons.notifications_none_outlined,
                    title: 'No notifications yet',
                    subtitle:
                        'Updates about your orders and messages will appear here.',
                  )
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    FieldSpacing.lg,
                    FieldSpacing.sm,
                    FieldSpacing.lg,
                    FieldSpacing.xxl,
                  ),
                  itemCount: vm.notifications.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: FieldSpacing.sm),
                  itemBuilder: (context, index) {
                    final notification = vm.notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      relativeTime: notificationRelativeTime(notification.createdAt),
                      onTap: () => _onNotificationTap(context, notification),
                    );
                  },
                ),
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
            color:
                isUnread
                    ? FieldColors.primaryNavy.withValues(alpha: 0.04)
                    : FieldColors.surfaceWhite,
            borderRadius: BorderRadius.circular(FieldRadius.card),
            border: Border.all(
              color:
                  isUnread
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
                          borderRadius: BorderRadius.circular(
                            FieldRadius.button,
                          ),
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
                                    isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
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
