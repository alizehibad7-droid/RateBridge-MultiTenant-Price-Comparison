import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_notifications_viewmodel.dart';

import '../../mocks/mocks.dart';

NotificationModel _notif({
  String id = 'notif-1',
  bool isRead = false,
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: 'field-1',
    recipientRole: 'field_user',
    type: 'order',
    title: 'Order update',
    message: 'Your order was accepted',
    data: const {'orderId': 'order-1'},
    isRead: isRead,
    createdAt: DateTime.utc(2026, 4, 1, 10),
    companyId: 'co-1',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(_notif());
  });

  late MockNotificationRepository notificationRepo;
  late StreamController<List<NotificationModel>> notificationsStream;
  late StreamController<int> unreadStream;
  late FieldNotificationsViewModel viewModel;

  setUp(() {
    notificationRepo = MockNotificationRepository();
    notificationsStream =
        StreamController<List<NotificationModel>>.broadcast();
    unreadStream = StreamController<int>.broadcast();

    when(() => notificationRepo.watchNotifications(any()))
        .thenAnswer((_) => notificationsStream.stream);
    when(() => notificationRepo.watchUnreadCount(any()))
        .thenAnswer((_) => unreadStream.stream);
    when(() => notificationRepo.markAsRead(any())).thenAnswer((_) async {});
    when(() => notificationRepo.markAllRead(any())).thenAnswer((_) async {});

    viewModel = FieldNotificationsViewModel(notificationRepo);
  });

  tearDown(() async {
    viewModel.dispose();
    if (!notificationsStream.isClosed) await notificationsStream.close();
    if (!unreadStream.isClosed) await unreadStream.close();
  });

  group('FieldNotificationsViewModel.watchNotifications', () {
    test('stores notifications and unread count independently', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      viewModel.watchNotifications('field-1');
      expect(loadingOnFirst, isTrue);
      verify(() => notificationRepo.watchNotifications('field-1')).called(1);
      verify(() => notificationRepo.watchUnreadCount('field-1')).called(1);

      notificationsStream.add([_notif(), _notif(id: 'n-2', isRead: true)]);
      unreadStream.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.notifications, hasLength(2));
      expect(viewModel.unreadCount, 1);
      expect(notifies, 3);
    });

    test('later emissions replace state; errors set errorMessage', () async {
      viewModel.watchNotifications('field-1');
      notificationsStream.add([_notif()]);
      unreadStream.add(4);
      await Future<void>.delayed(Duration.zero);

      notificationsStream.add(const []);
      unreadStream.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);

      notificationsStream.addError(AppException('index building'));
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.errorMessage, 'index building');
      expect(viewModel.isLoading, isFalse);
    });

    test('unread stream error does not clear the list', () async {
      viewModel.watchNotifications('field-1');
      notificationsStream.add([_notif()]);
      await Future<void>.delayed(Duration.zero);

      unreadStream.addError(AppException('unread index missing'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notifications, hasLength(1));
      expect(viewModel.errorMessage, 'unread index missing');
    });
  });

  group('FieldNotificationsViewModel.markAsRead', () {
    test('success forwards only notifId', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.markAsRead('field-1', 'notif-1');

      expect(notifies, 0);
      expect(viewModel.errorMessage, isNull);
      verify(() => notificationRepo.markAsRead('notif-1')).called(1);
    });

    test('failure sets errorMessage', () async {
      when(() => notificationRepo.markAsRead(any()))
          .thenThrow(AppException('mark failed'));

      await viewModel.markAsRead('field-1', 'notif-1');

      expect(viewModel.errorMessage, 'mark failed');
    });
  });

  group('FieldNotificationsViewModel.markAllRead', () {
    test('success forwards uid', () async {
      await viewModel.markAllRead('field-1');
      verify(() => notificationRepo.markAllRead('field-1')).called(1);
    });

    test('failure sets errorMessage', () async {
      when(() => notificationRepo.markAllRead(any()))
          .thenThrow(AppException('mark all failed'));

      await viewModel.markAllRead('field-1');
      expect(viewModel.errorMessage, 'mark all failed');
    });
  });

  group('FieldNotificationsViewModel.clearError', () {
    test('clears errorMessage', () async {
      when(() => notificationRepo.markAsRead(any()))
          .thenThrow(AppException('boom'));
      await viewModel.markAsRead('field-1', 'n-1');

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
