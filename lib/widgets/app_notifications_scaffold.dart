import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/route_names.dart';
import '../models/notification_model.dart';
import '../theme/field_theme.dart';
import '../utils/app_navigation.dart';
import '../utils/notification_utils.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/notification_viewmodel.dart';

typedef NotificationTapHandler = void Function(
  BuildContext context,
  NotificationModel notification,
);

/// Shared notifications list used by field, CEO, and admin screens.
class AppNotificationsScaffold extends StatefulWidget {
  final String title;
  final NotificationTapHandler onNotificationTap;
  final Color? backgroundColor;
  final bool embedded;

  const AppNotificationsScaffold({
    super.key,
    required this.title,
    required this.onNotificationTap,
    this.backgroundColor,
    this.embedded = false,
  });

  @override
  State<AppNotificationsScaffold> createState() => _AppNotificationsScaffoldState();
}

class _AppNotificationsScaffoldState extends State<AppNotificationsScaffold> {
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifIds = {};

  bool get _isDesktop {
    if (kIsWeb) return true;
    try {
      final platform = defaultTargetPlatform;
      return platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;
    } catch (_) {
      return false;
    }
  }

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
    if (_isSelectionMode) {
      setState(() {
        if (_selectedNotifIds.contains(notification.notifId)) {
          _selectedNotifIds.remove(notification.notifId);
          if (_selectedNotifIds.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedNotifIds.add(notification.notifId);
        }
      });
      return;
    }

    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;

    if (!notification.isRead) {
      await vm.markAsRead(uid, notification.notifId);
    }
    if (!context.mounted) return;
    widget.onNotificationTap(context, notification);
  }

  void _handleLongPress(NotificationModel notification) {
    setState(() {
      _isSelectionMode = true;
      _selectedNotifIds.add(notification.notifId);
    });
  }

  Future<void> _confirmAndDeleteSelected(BuildContext context) async {
    if (_selectedNotifIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedNotifIds.length} items?'),
        content: const Text('Are you sure you want to delete these items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vm = context.read<NotificationViewModel>();
      try {
        await vm.deleteNotifications(_selectedNotifIds.toList());
        setState(() {
          _selectedNotifIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications deleted successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete items: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all?'),
        content: const Text('This will permanently remove all removable items from your panel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vm = context.read<NotificationViewModel>();
      try {
        await vm.deleteAllNotifications();
        setState(() {
          _selectedNotifIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to clear items: $e')),
        );
      }
    }
  }

  Future<void> _deleteSingleNotification(BuildContext context, NotificationModel notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vm = context.read<NotificationViewModel>();
      try {
        await vm.deleteNotification(notification.notifId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();
    final showAppBar = !widget.embedded || _isSelectionMode;

    Widget body = vm.uid == null
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
                        child: _buildList(vm),
                      );

    Widget mainContent = Column(
      children: [
        if (widget.embedded && !_isSelectionMode)
          _buildEmbeddedToolbar(vm),
        Expanded(child: body),
      ],
    );

    if (_isDesktop) {
      mainContent = Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: mainContent,
        ),
      );
    }

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? FieldColors.screenBackground,
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedNotifIds.clear();
                        });
                      },
                    )
                  : (widget.embedded ? null : AppNavigation.leading(context)),
              title: _isSelectionMode
                  ? Text('${_selectedNotifIds.length} selected')
                  : Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
              actions: _isSelectionMode
                  ? [
                      IconButton(
                        icon: const Icon(Icons.select_all_rounded),
                        tooltip: 'Select All',
                        onPressed: () {
                          setState(() {
                            _selectedNotifIds.addAll(vm.notifications.map((n) => n.notifId));
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        tooltip: 'Delete Selected',
                        onPressed: () => _confirmAndDeleteSelected(context),
                      ),
                    ]
                  : [
                      if (vm.notifications.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded),
                          tooltip: 'Clear All',
                          onPressed: () => _confirmAndClearAll(context),
                        ),
                      if (vm.unreadCount > 0)
                        TextButton.icon(
                          onPressed: () => _markAllRead(context),
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('Mark all read'),
                        ),
                      const SizedBox(width: 8),
                      Consumer<AuthViewModel>(
                        builder: (context, authVm, _) {
                          final user = authVm.user;
                          final role = user?.role?.toLowerCase() ?? '';
                          final name = user?.name ?? '';
                          String initials = 'P';
                          if (name.isNotEmpty) {
                            final parts = name.trim().split(RegExp(r'\s+'));
                            if (parts.isNotEmpty && parts.first.isNotEmpty) {
                              initials = parts.first[0].toUpperCase();
                            }
                          }
                          return GestureDetector(
                            onTap: () {
                              if (role == 'ceo') {
                                context.push(RouteNames.ceoProfile);
                              } else if (role == 'supplier') {
                                context.push(RouteNames.supplierProfile);
                              } else if (role == 'field_user') {
                                context.push(RouteNames.fieldProfile);
                              } else {
                                context.push(RouteNames.adminDashboard);
                              }
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF1E326E),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                    ],
            )
          : null,
      body: mainContent,
    );
  }

  Widget _buildEmbeddedToolbar(NotificationViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          if (vm.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE25730), borderRadius: BorderRadius.circular(12)),
              child: Text('${vm.unreadCount} UNREAD', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
          if (vm.notifications.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmAndClearAll(context),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          if (vm.unreadCount > 0) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _markAllRead(context),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark All Read'),
              style: ElevatedButton.styleFrom(elevation: 0),
            ),
          ],
          const SizedBox(width: 16),
          Consumer<AuthViewModel>(
            builder: (context, authVm, _) {
              final user = authVm.user;
              final role = user?.role?.toLowerCase() ?? '';
              final name = user?.name ?? '';
              String initials = 'P';
              if (name.isNotEmpty) {
                final parts = name.trim().split(RegExp(r'\s+'));
                if (parts.isNotEmpty && parts.first.isNotEmpty) {
                  initials = parts.first[0].toUpperCase();
                }
              }
              return GestureDetector(
                onTap: () {
                  if (role == 'ceo') {
                    context.push(RouteNames.ceoProfile);
                  } else if (role == 'supplier') {
                    context.push(RouteNames.supplierProfile);
                  } else if (role == 'field_user') {
                    context.push(RouteNames.fieldProfile);
                  } else {
                    context.push(RouteNames.adminDashboard);
                  }
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1E326E),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(NotificationViewModel vm) {
    return ListView.separated(
      padding: EdgeInsets.all(_isDesktop ? 32 : 16),
      itemCount: vm.notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = vm.notifications[index];
        final isSelected = _selectedNotifIds.contains(notification.notifId);
        return _NotificationTile(
          notification: notification,
          relativeTime: notificationRelativeTime(
            notification.createdAt,
          ),
          isSelectionMode: _isSelectionMode,
          isSelected: isSelected,
          onTap: () => _handleTap(context, notification),
          onLongPress: () => _handleLongPress(notification),
          onDeleteSingle: () => _deleteSingleNotification(context, notification),
          isDesktop: _isDesktop,
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String relativeTime;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDeleteSingle;
  final bool isDesktop;

  const _NotificationTile({
    required this.notification,
    required this.relativeTime,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDeleteSingle,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconConfig = notificationIconForType(notification.type);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? iconConfig.color.withValues(alpha: 0.08)
                : (isUnread ? Colors.white : Colors.white.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? iconConfig.color
                  : (isUnread
                      ? iconConfig.color.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.1)),
              width: (isSelected || isUnread) ? 1.5 : 1,
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
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: iconConfig.color,
                    onChanged: (_) => onTap(),
                  ),
                  const SizedBox(width: 8),
                ],
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
                          if (!isSelectionMode)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (val) {
                                if (val == 'delete') {
                                  onDeleteSingle();
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else if (isUnread)
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
                        maxLines: isDesktop ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              relativeTime,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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