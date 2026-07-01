import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';

/// In-app notifications for field users.
class FieldNotificationsViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepo;

  bool _isLoading = false;
  String? _errorMessage;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<List<NotificationModel>>? _notifSubscription;
  StreamSubscription<int>? _unreadSubscription;

  FieldNotificationsViewModel(this._notificationRepo);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void watchNotifications(String uid) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _notifSubscription?.cancel();
    _unreadSubscription?.cancel();

    _notifSubscription = _notificationRepo.watchNotifications(uid).listen(
      (data) {
        _notifications = data;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    _unreadSubscription = _notificationRepo.watchUnreadCount(uid).listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String uid, String notifId) async {
    _errorMessage = null;
    try {
      await _notificationRepo.markAsRead(uid, notifId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllRead(String uid) async {
    _errorMessage = null;
    try {
      await _notificationRepo.markAllRead(uid);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
