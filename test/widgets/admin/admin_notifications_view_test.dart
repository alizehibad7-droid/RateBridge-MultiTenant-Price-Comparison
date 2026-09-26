import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/admin/admin_notifications_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;
  late MockNotificationViewModel notifications;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
    notifications = MockNotificationViewModel();
    stubNotificationViewModel(notifications);
  });

  testWidgets('shows a spinner when the admin uid is not ready', (tester) async {
    when(() => notifications.uid).thenReturn(null);

    await pumpAdminScreen(
      tester,
      child: const AdminNotificationsView(),
      admin: admin,
      notifications: notifications,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error copy and Retry reloads notifications',
      (tester) async {
    when(() => notifications.errorMessage).thenReturn('offline');
    when(() => notifications.notifications).thenReturn(const []);

    await pumpAdminScreen(
      tester,
      child: const AdminNotificationsView(),
      admin: admin,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tapVisible(tester, find.text('Try Again'));
    await tester.pump();

    verify(() => notifications.loadNotifications('admin-1')).called(1);
  });

  testWidgets('shows empty copy when there are no notifications',
      (tester) async {
    await pumpAdminScreen(
      tester,
      child: const AdminNotificationsView(),
      admin: admin,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('All caught up!'), findsOneWidget);
  });

  testWidgets('renders notifications and Mark all read calls the ViewModel',
      (tester) async {
    when(() => notifications.unreadCount).thenReturn(2);
    when(() => notifications.notifications).thenReturn([
      sampleNotification(),
      sampleNotification(id: 'n-2', isRead: true),
    ]);

    await pumpAdminScreen(
      tester,
      child: const AdminNotificationsView(),
      admin: admin,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('New CEO pending'), findsNWidgets(2));
    expect(find.text('Mark all read'), findsOneWidget);

    await tapVisible(tester, find.text('Mark all read'));
    await tester.pump();

    verify(() => notifications.markAllRead('admin-1')).called(1);
  });
}
