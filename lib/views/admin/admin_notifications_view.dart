import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';
import '../../utils/notification_utils.dart';
import '../../widgets/app_notifications_scaffold.dart';

class AdminNotificationsView extends StatelessWidget {
  const AdminNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNotificationsScaffold(
      title: 'Notifications',
      backgroundColor: AdminColors.screenBg,
      onNotificationTap: navigateForAdminNotification,
    );
  }
}
