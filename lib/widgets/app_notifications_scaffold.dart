import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/notification_model.dart';
import '../theme/field_theme.dart';
import '../utils/app_navigation.dart';
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
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, size: 22),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        actions: [
          if (vm.unreadCount > 0)
            TextButton.icon(
              onPressed: () => _markAllRead(context),
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('Mark all read'),
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
                      : RefreshIndicator(
                          onRefresh: () async => _retryLoad(context),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: vm.notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isUnread
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread
                  ? iconConfig.color.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.1),
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: isUnread ? [
              BoxShadow(
                color: iconConfig.color.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconConfig.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconConfig.icon,
                    size: 20,
                    color: iconConfig.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                                color: const Color(0xFF1E326E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: iconConfig.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isUnread ? const Color(0xFF1E326E).withValues(alpha: 0.8) : Colors.grey,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            relativeTime,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E326E).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E326E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No new notifications at the moment. We\'ll let you know when something important happens.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Color(0xFFE25730),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load notifications',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
