import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';

import '../mocks/mocks.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

NotificationModel _notif({
  String id = 'notif-1',
  String recipientUserId = 'user-1',
  bool isRead = false,
  String title = 'Order placed',
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: recipientUserId,
    recipientRole: 'CEO',
    type: 'order',
    title: title,
    message: 'A new order needs attention',
    data: const {'orderId': 'order-1'},
    isRead: isRead,
    createdAt: DateTime.utc(2026, 4, 1, 10),
    companyId: 'co-1',
  );
}

UserModel _user({String uid = 'user-1'}) {
  return UserModel(
    uid: uid,
    email: '$uid@co.test',
    name: 'Ali CEO',
    role: 'CEO',
    companyId: 'co-1',
    phone: '03001234567',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fallbackNotif = _notif();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(fallbackNotif);
    registerFallbackValue(<String, dynamic>{});
  });

  late MockNotificationRepository notificationRepo;
  late MockAuthViewModel auth;
  late StreamController<List<NotificationModel>> notificationsStream;
  late StreamController<int> unreadStream;
  late NotificationViewModel viewModel;

  setUp(() {
    notificationRepo = MockNotificationRepository();
    auth = MockAuthViewModel();
    notificationsStream =
        StreamController<List<NotificationModel>>.broadcast();
    unreadStream = StreamController<int>.broadcast();

    when(() => notificationRepo.watchNotifications(any())).thenAnswer(
      (_) => notificationsStream.stream,
    );
    when(() => notificationRepo.watchUnreadCount(any())).thenAnswer(
      (_) => unreadStream.stream,
    );
    when(() => notificationRepo.markAsRead(any())).thenAnswer((_) async {});
    when(() => notificationRepo.markAllRead(any())).thenAnswer((_) async {});
    when(() => auth.user).thenReturn(_user());

    viewModel = NotificationViewModel(notificationRepo);
  });

  tearDown(() async {
    viewModel.dispose();
    if (!notificationsStream.isClosed) await notificationsStream.close();
    if (!unreadStream.isClosed) await unreadStream.close();
  });

  group('NotificationViewModel.updateAuth', () {
    test('starts listening when an authenticated uid appears', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      viewModel.updateAuth(auth);

      expect(viewModel.uid, 'user-1');
      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.errorMessage, isNull);
      verify(() => notificationRepo.watchNotifications('user-1')).called(1);
      verify(() => notificationRepo.watchUnreadCount('user-1')).called(1);

      notificationsStream.add([_notif(), _notif(id: 'notif-2', isRead: true)]);
      unreadStream.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.notifications, hasLength(2));
      expect(viewModel.unreadCount, 1);
      expect(notifies, 3);
    });

    test('same uid does not resubscribe', () {
      viewModel.updateAuth(auth);
      viewModel.updateAuth(auth);

      verify(() => notificationRepo.watchNotifications('user-1')).called(1);
      verify(() => notificationRepo.watchUnreadCount('user-1')).called(1);
    });

    test('logout clears notifications, unread count, and subscriptions',
        () async {
      viewModel.updateAuth(auth);
      notificationsStream.add([_notif()]);
      unreadStream.add(4);
      await Future<void>.delayed(Duration.zero);

      when(() => auth.user).thenReturn(null);
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.updateAuth(auth);

      expect(viewModel.uid, isNull);
      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
      expect(viewModel.isLoading, isFalse);
      expect(notifies, 1);

      notificationsStream.add([_notif(id: 'after-logout')]);
      unreadStream.add(9);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
    });

    test('switching users cancels the previous subscriptions', () async {
      final firstNotifs = StreamController<List<NotificationModel>>.broadcast();
      final secondNotifs =
          StreamController<List<NotificationModel>>.broadcast();
      final firstUnread = StreamController<int>.broadcast();
      final secondUnread = StreamController<int>.broadcast();
      addTearDown(() async {
        if (!firstNotifs.isClosed) await firstNotifs.close();
        if (!secondNotifs.isClosed) await secondNotifs.close();
        if (!firstUnread.isClosed) await firstUnread.close();
        if (!secondUnread.isClosed) await secondUnread.close();
      });

      when(() => notificationRepo.watchNotifications('user-1'))
          .thenAnswer((_) => firstNotifs.stream);
      when(() => notificationRepo.watchNotifications('user-2'))
          .thenAnswer((_) => secondNotifs.stream);
      when(() => notificationRepo.watchUnreadCount('user-1'))
          .thenAnswer((_) => firstUnread.stream);
      when(() => notificationRepo.watchUnreadCount('user-2'))
          .thenAnswer((_) => secondUnread.stream);

      viewModel.updateAuth(auth);

      when(() => auth.user).thenReturn(_user(uid: 'user-2'));
      viewModel.updateAuth(auth);

      firstNotifs.add([_notif(id: 'stale')]);
      firstUnread.add(8);
      secondNotifs.add([_notif(id: 'fresh', recipientUserId: 'user-2')]);
      secondUnread.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.uid, 'user-2');
      expect(viewModel.notifications.single.notifId, 'fresh');
      expect(viewModel.unreadCount, 2);
    });
  });

  group('NotificationViewModel.loadNotifications', () {
    test('stores streamed notifications and unread count independently',
        () async {
      viewModel.loadNotifications('user-1');

      expect(viewModel.uid, 'user-1');
      expect(viewModel.isLoading, isTrue);

      notificationsStream.add([
        _notif(id: 'n-1', isRead: true),
        _notif(id: 'n-2', isRead: false),
        _notif(id: 'n-3', isRead: false),
      ]);
      unreadStream.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.notifications.map((n) => n.notifId), ['n-1', 'n-2', 'n-3']);
      expect(viewModel.unreadCount, 2);
    });

    test('later emissions replace the list and unread count', () async {
      viewModel.loadNotifications('user-1');
      notificationsStream.add([_notif()]);
      unreadStream.add(1);
      await Future<void>.delayed(Duration.zero);

      notificationsStream.add(const []);
      unreadStream.add(0);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
      expect(viewModel.isLoading, isFalse);
    });

    test('unread count is taken from watchUnreadCount, not the list', () async {
      viewModel.loadNotifications('user-1');
      notificationsStream.add([
        _notif(id: 'n-1', isRead: false),
        _notif(id: 'n-2', isRead: false),
      ]);
      unreadStream.add(0);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notifications, hasLength(2));
      expect(viewModel.unreadCount, 0);
    });

    test('does not resubscribe when already listening for the same uid', () {
      viewModel.loadNotifications('user-1');
      viewModel.loadNotifications('user-1');

      verify(() => notificationRepo.watchNotifications('user-1')).called(1);
      verify(() => notificationRepo.watchUnreadCount('user-1')).called(1);
    });

    test('restarts listening after logout for the same uid', () {
      viewModel.loadNotifications('user-1');
      when(() => auth.user).thenReturn(null);
      viewModel.updateAuth(auth);

      viewModel.loadNotifications('user-1');

      verify(() => notificationRepo.watchNotifications('user-1')).called(2);
    });

    test('notification stream error sets errorMessage and clears loading',
        () async {
      viewModel.loadNotifications('user-1');

      notificationsStream.addError(AppException('index building'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'index building');
    });

    test('unread stream error sets errorMessage without clearing the list',
        () async {
      viewModel.loadNotifications('user-1');
      notificationsStream.add([_notif()]);
      await Future<void>.delayed(Duration.zero);

      unreadStream.addError(AppException('unread index missing'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notifications, hasLength(1));
      expect(viewModel.errorMessage, 'unread index missing');
    });
  });

  group('NotificationViewModel watch aliases', () {
    test('watchNotifications delegates to loadNotifications', () async {
      viewModel.watchNotifications('user-1');

      verify(() => notificationRepo.watchNotifications('user-1')).called(1);
      verify(() => notificationRepo.watchUnreadCount('user-1')).called(1);

      notificationsStream.add([_notif(title: 'Via watch')]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notifications.single.title, 'Via watch');
    });

    test('watchUnreadCount also starts both listeners', () async {
      viewModel.watchUnreadCount('user-1');

      unreadStream.add(5);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.unreadCount, 5);
      verify(() => notificationRepo.watchNotifications('user-1')).called(1);
      verify(() => notificationRepo.watchUnreadCount('user-1')).called(1);
    });
  });

  group('NotificationViewModel.markAsRead', () {
    test('success forwards notifId and ignores the unused second argument',
        () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.markAsRead('notif-1', 'user-1');

      expect(notifies, 0);
      expect(viewModel.errorMessage, isNull);
      verify(() => notificationRepo.markAsRead('notif-1')).called(1);
    });

    test('repository failure sets errorMessage and notifies', () async {
      when(() => notificationRepo.markAsRead(any()))
          .thenThrow(AppException('mark failed'));

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.markAsRead('notif-1');

      expect(notifies, 1);
      expect(viewModel.errorMessage, 'mark failed');
    });
  });

  group('NotificationViewModel.markAllRead', () {
    test('no-ops when no uid is available', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.markAllRead();

      expect(notifies, 0);
      verifyNever(() => notificationRepo.markAllRead(any()));
    });

    test('uses the explicit uid argument', () async {
      await viewModel.markAllRead('user-9');

      expect(viewModel.errorMessage, isNull);
      verify(() => notificationRepo.markAllRead('user-9')).called(1);
    });

    test('falls back to the authenticated uid', () async {
      viewModel.updateAuth(auth);

      await viewModel.markAllRead();

      verify(() => notificationRepo.markAllRead('user-1')).called(1);
    });

    test('repository failure sets errorMessage and notifies', () async {
      when(() => notificationRepo.markAllRead(any()))
          .thenThrow(AppException('mark all failed'));

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await viewModel.markAllRead('user-1');

      expect(notifies, 1);
      expect(viewModel.errorMessage, 'mark all failed');
    });
  });

  group('NotificationViewModel.clearError', () {
    test('clears errorMessage and notifies listeners', () async {
      viewModel.loadNotifications('user-1');
      notificationsStream.addError(Exception('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.errorMessage, isNotNull);

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.clearError();

      expect(viewModel.errorMessage, isNull);
      expect(notifies, 1);
    });
  });
}
