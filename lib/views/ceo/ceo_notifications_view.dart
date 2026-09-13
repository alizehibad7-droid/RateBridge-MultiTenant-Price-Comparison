import 'package:flutter/material.dart';

import '../../theme/ceo_theme.dart';
import '../../utils/notification_utils.dart';
import '../../widgets/app_notifications_scaffold.dart';

class CeoNotificationsView extends StatelessWidget {
  const CeoNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNotificationsScaffold(
      title: 'Notifications',
      backgroundColor: CeoColors.screenBg,
      onNotificationTap: navigateForCeoNotification,
    );
  }
}
