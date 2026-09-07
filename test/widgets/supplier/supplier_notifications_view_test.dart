import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_notifications_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;
  late MockNotificationViewModel notifications;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
    notifications = MockNotificationViewModel();
    stubNotificationViewModel(notifications);
  });

  testWidgets('shows a spinner when the uid is not ready', (tester) async {
    when(() => notifications.uid).thenReturn(null);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error copy and Retry reloads notifications',
      (tester) async {
    when(() => notifications.errorMessage).thenReturn('offline');
    when(() => notifications.notifications).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => notifications.loadNotifications('sup-1'))
        .called(greaterThanOrEqualTo(2));
  });

  testWidgets('shows empty copy when there are no notifications',
      (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('renders notifications and Mark all read calls the ViewModel',
      (tester) async {
    when(() => notifications.unreadCount).thenReturn(2);
    when(() => notifications.notifications).thenReturn([
      sampleNotification(),
      sampleNotification(id: 'n-2', isRead: true),
    ]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    expect(find.text('New order received'), findsNWidgets(2));
    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pump();

    verify(() => notifications.markAllRead('sup-1')).called(1);
  });

  testWidgets('commission payment opens Earnings, not Messages', (tester) async {
    when(() => notifications.notifications).thenReturn([
      sampleNotification(
        type: 'payment',
        title: 'Commission Payment Confirmed ✅',
        message: 'Your commission payment of Rs 423 has been settled.',
        data: const {'status': 'settled'},
      ),
    ]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    await tester.tap(find.textContaining('Commission Payment'));
    await tester.pumpAndSettle();

    expect(find.text('supplier-earnings'), findsOneWidget);
    expect(find.text('supplier-chat'), findsNothing);
  });

  testWidgets('awarded RFQ opens Orders instead of bid submit', (tester) async {
    when(() => notifications.notifications).thenReturn([
      sampleNotification(
        type: 'rfq',
        title: 'RFQ Awarded! ✅',
        message: 'Congratulations! usman has awarded you the contract for Bricks.',
        data: const {'rfqId': 'rfq-1', 'awarded': 'true'},
      ),
    ]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    await tester.tap(find.textContaining('RFQ Awarded'));
    await tester.pumpAndSettle();

    expect(find.text('supplier-orders'), findsOneWidget);
    expect(find.text('supplier-submit-bid'), findsNothing);
  });

  testWidgets('delivery confirmed opens Orders', (tester) async {
    when(() => notifications.notifications).thenReturn([
      sampleNotification(
        type: 'orderUpdate',
        title: 'Delivery confirmed',
        message: 'Alizeh Ibad confirmed delivery of Popular uPVC Pressure Pipe.',
        data: const {'orderId': 'order-1'},
      ),
    ]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    await tester.tap(find.text('Delivery confirmed'));
    await tester.pumpAndSettle();

    expect(find.text('supplier-orders'), findsOneWidget);
  });

  testWidgets('chat notification opens the chat thread', (tester) async {
    when(() => notifications.notifications).thenReturn([
      sampleNotification(
        type: 'chat',
        title: 'Alizeh Ibad',
        message: 'share some more details with me',
        data: const {
          'chatId': 'chat-1',
          'fieldUserId': 'field-1',
          'fieldUserName': 'Alizeh Ibad',
          'supplierId': 'sup-1',
        },
      ),
    ]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierNotificationsView(),
      supplier: supplier,
      notifications: notifications,
    );
    await tester.pump();

    await tester.tap(find.text('Alizeh Ibad'));
    await tester.pumpAndSettle();

    expect(find.text('supplier-chat-thread'), findsOneWidget);
  });
}
