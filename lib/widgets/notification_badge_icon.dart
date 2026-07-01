import 'package:flutter/material.dart';

/// Bell icon with optional unread count badge.
class NotificationBadgeIcon extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final String tooltip;

  const NotificationBadgeIcon({
    super.key,
    required this.unreadCount,
    this.onPressed,
    this.iconColor,
    this.tooltip = 'Notifications',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
        child: Icon(
          Icons.notifications_none_outlined,
          color: iconColor,
        ),
      ),
    );
  }
}
