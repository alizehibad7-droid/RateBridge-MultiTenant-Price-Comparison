import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/notifications/field_notifications_view.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockNotificationViewModel notifications;

  setUp(() {
    notifications = MockNotificationViewModel();
    stubNotificationViewModel(notifications);
  });

  testWidgets('shows a spinner when the field user uid is not ready',
      (tester) async {
    when(() => notifications.uid).thenReturn(null);

    await pumpFieldScreen(
      tester,
      child: const FieldNotificationsView(),
      notifications: notifications,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error copy and Try Again reloads notifications',
      (tester) async {
    when(() => notifications.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldNotificationsView(),
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tapVisible(tester, find.text('Try Again'));
    await tester.pump();

    verify(() => notifications.loadNotifications('field-1')).called(1);
  });

  testWidgets('shows empty copy when there are no notifications',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldNotificationsView(),
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

    await pumpFieldScreen(
      tester,
      child: const FieldNotificationsView(),
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('Order update'), findsNWidgets(2));
    expect(find.text('Mark all read'), findsOneWidget);

    await tapVisible(tester, find.text('Mark all read'));
    await tester.pump();

    verify(() => notifications.markAllRead('field-1')).called(1);
  });

  testWidgets('tapping a dispute notification opens that dispute',
      (tester) async {
    when(() => notifications.notifications).thenReturn([
      sampleNotification(
        type: 'dispute',
        title: 'Dispute submitted',
        message: 'Your report on OPC Cement (Wrong Material) was submitted.',
        data: const {'disputeId': 'd-1', 'orderId': 'order-1'},
      ),
    ]);

    await pumpFieldScreen(
      tester,
      child: const FieldNotificationsView(),
      notifications: notifications,
    );
    await tester.pump();

    await tester.tap(find.text('Dispute submitted'));
    await tester.pumpAndSettle();

    expect(find.text('field-dispute-detail'), findsOneWidget);
  });
}
