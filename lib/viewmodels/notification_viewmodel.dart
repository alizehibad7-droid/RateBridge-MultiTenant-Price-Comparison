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
  String? _errorMessage;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _unreadSubscription;

  void updateAuth(AuthViewModel auth) {
    final newUid = auth.user?.uid;
    if (newUid == _uid) return;
    _uid = newUid;
    if (_uid != null) {
      watchUnreadCount(_uid!);
      loadNotifications(_uid!);
    } else {
      _notifSubscription?.cancel();
      _unreadSubscription?.cancel();
      _notifications = [];
      _unreadCount = 0;
    }
    notifyListeners();
  }

  String? get uid => _uid;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadNotifications(String uid) {
    _notifSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _notifSubscription = _notificationRepo
      .watchNotifications(uid)
      .listen((notifs) {
        _notifications = notifs;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _errorMessage = e.toString();
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
      }, onError: (e) {
        _errorMessage = e.toString();
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
