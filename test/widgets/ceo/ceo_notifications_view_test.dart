import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_notifications_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;
  late MockNotificationViewModel notifications;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
    notifications = MockNotificationViewModel();
    stubNotificationViewModel(notifications);
  });

  testWidgets('shows a spinner when the CEO uid is not ready', (tester) async {
    when(() => notifications.uid).thenReturn(null);

    await pumpCeoScreen(
      tester,
      child: const CeoNotificationsView(),
      ceo: ceo,
      notifications: notifications,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error copy and Try Again reloads notifications',
      (tester) async {
    when(() => notifications.errorMessage).thenReturn('offline');
    when(() => notifications.notifications).thenReturn(const []);

    await pumpCeoScreen(
      tester,
      child: const CeoNotificationsView(),
      ceo: ceo,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tapVisible(tester, find.text('Try Again'));
    await tester.pump();

    verify(() => notifications.loadNotifications('ceo-1')).called(1);
  });

  testWidgets('shows empty copy when there are no notifications',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoNotificationsView(),
      ceo: ceo,
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

    await pumpCeoScreen(
      tester,
      child: const CeoNotificationsView(),
      ceo: ceo,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('New join request'), findsNWidgets(2));
    expect(find.text('Mark all read'), findsOneWidget);

    await tapVisible(tester, find.text('Mark all read'));
    await tester.pump();

    verify(() => notifications.markAllRead('ceo-1')).called(1);
  });

  testWidgets('tapping a dispute notification opens that dispute',
      (tester) async {
    when(() => notifications.notifications).thenReturn([
      sampleNotification(
        type: 'dispute',
        title: 'Dispute on company order',
        message: 'Hassan Field (Field User) reported Wrong Material on OPC Cement.',
        data: const {'disputeId': 'd-1', 'orderId': 'order-1'},
      ),
    ]);

    await pumpCeoScreen(
      tester,
      child: const CeoNotificationsView(),
      ceo: ceo,
      notifications: notifications,
    );
    await tester.pump();

    await tester.tap(find.text('Dispute on company order'));
    await tester.pumpAndSettle();

    expect(find.text('ceo-dispute-detail'), findsOneWidget);
  });
}
