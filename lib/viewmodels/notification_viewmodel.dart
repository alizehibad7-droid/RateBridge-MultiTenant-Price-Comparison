// MVVM: ViewModel — business logic only
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_viewmodel.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepo;
  NotificationViewModel(this._notificationRepo);

  String? _uid;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _unreadSubscription;

  void updateAuth(AuthViewModel auth) {
    _uid = auth.user?.uid;
    if (_uid != null) {
      watchUnreadCount(_uid!);
    } else {
      _notifSubscription?.cancel();
      _unreadSubscription?.cancel();
      _notifications = [];
      _unreadCount = 0;
    }
    notifyListeners();
  }

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void loadNotifications(String uid) {
    _notifSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _notifSubscription = _notificationRepo
      .watchNotifications(uid)
      .listen((notifs) {
        _notifications = notifs;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _isLoading = false;
        notifyListeners();
      });
  }

  void watchUnreadCount(String uid) {
    _unreadSubscription?.cancel();
    _unreadSubscription = _notificationRepo
      .watchUnreadCount(uid)
      .listen((count) {
        _unreadCount = count;
        notifyListeners();
      });
  }

  Future<void> markAsRead(String uid, String notifId) async {
    await _notificationRepo.markAsRead(uid, notifId);
  }

  Future<void> markAllRead(String uid) async {
    await _notificationRepo.markAllRead(uid);
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
