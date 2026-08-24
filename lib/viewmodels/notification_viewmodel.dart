// MVVM: ViewModel — business logic only
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../constants/firestore_paths.dart';
import 'auth_viewmodel.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepo;
  NotificationViewModel(this._notificationRepo);

  String? _uid;
  String? _role;
  String? _companyId;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _unreadSubscription;

  void updateAuth(AuthViewModel auth) {
    final newUser = auth.user;
    final newUid = newUser?.uid;
    final newRole = newUser?.role;
    final newCompanyId = newUser?.companyId;

    if (newUid == _uid && newRole == _role && newCompanyId == _companyId) return;

    _uid = newUid;
    _role = newRole;
    _companyId = newCompanyId;

    if (_uid != null) {
      final path = _getNotificationPath();
      watchUnreadCount(_uid!, path: path);
      loadNotifications(_uid!, path: path);
    } else {
      _notifSubscription?.cancel();
      _unreadSubscription?.cancel();
      _notifications = [];
      _unreadCount = 0;
    }
    notifyListeners();
  }

  String? _getNotificationPath() {
    if (_role == null) return null;
    final roleLower = _role!.toLowerCase();
    
    if (roleLower == 'admin' || roleLower == 'administrator') {
      return FirestorePaths.adminNotificationsCol;
    }
    if (roleLower == 'supplier') {
      return FirestorePaths.supplierNotificationsCol(_uid!);
    }
    if (_companyId != null && _companyId!.isNotEmpty) {
      return FirestorePaths.companyNotificationsCol(_companyId!);
    }
    return null; // Fallback to root 'notifications'
  }

  String? get uid => _uid;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadNotifications(String uid, {String? path}) {
    _notifSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _notifSubscription = _notificationRepo
      .watchNotifications(uid, path: path)
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

  void watchUnreadCount(String uid, {String? path}) {
    _unreadSubscription?.cancel();
    _unreadSubscription = _notificationRepo
      .watchUnreadCount(uid, path: path)
      .listen((count) {
        _unreadCount = count;
        notifyListeners();
      }, onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      });
  }

  Future<void> markAsRead(String uid, String notifId) async {
    final path = _getNotificationPath();
    await _notificationRepo.markAsRead(uid, notifId, path: path);
  }

  Future<void> markAllRead(String uid) async {
    final path = _getNotificationPath();
    await _notificationRepo.markAllRead(uid, path: path);
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
