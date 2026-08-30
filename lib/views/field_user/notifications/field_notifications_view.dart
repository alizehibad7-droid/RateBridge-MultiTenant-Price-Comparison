import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/field_theme.dart';
import '../../../utils/notification_utils.dart';
import '../../../viewmodels/notification_viewmodel.dart';
import '../../../widgets/app_notifications_scaffold.dart';

/// Notifications list for Field Users.
/// Now uses the unified [AppNotificationsScaffold] and [NotificationViewModel].
class FieldNotificationsView extends StatelessWidget {
  const FieldNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FieldTheme.theme,
      child: AppNotificationsScaffold(
        title: 'Notifications',
        backgroundColor: FieldColors.screenBackground,
        onNotificationTap: navigateForFieldNotification,
      ),
    );
  }
}
