// MVVM: Service — external API wrapper only
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Initialize Flutter Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(initializationSettings);

    // 2. Set foreground notification presentation options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Create Android notification channels
    const AndroidNotificationChannel ordersChannel = AndroidNotificationChannel(
      'orders_channel', 
      'Orders',
      description: 'Order status notifications',
      importance: Importance.high,
    );
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_channel', 
      'Chat',
      description: 'Chat message notifications',
      importance: Importance.high,
    );
    const AndroidNotificationChannel paymentsChannel = AndroidNotificationChannel(
      'payments_channel', 
      'Payments',
      description: 'Payment and subscription notifications',
      importance: Importance.defaultImportance,
    );
    const AndroidNotificationChannel invitationsChannel = AndroidNotificationChannel(
      'invitations_channel', 
      'Invitations',
      description: 'Supplier invitation notifications',
      importance: Importance.defaultImportance,
    );
    const AndroidNotificationChannel systemChannel = AndroidNotificationChannel(
      'system_channel', 
      'System',
      description: 'System notifications',
      importance: Importance.low,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(ordersChannel);
      await androidImplementation.createNotificationChannel(chatChannel);
      await androidImplementation.createNotificationChannel(paymentsChannel);
      await androidImplementation.createNotificationChannel(invitationsChannel);
      await androidImplementation.createNotificationChannel(systemChannel);
    }

    // 4. Listeners
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;
    final type = message.data['type'] ?? 'system';
    final channelId = _channelForType(type);

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId,
            channelDescription: 'RateBridge notifications',
            icon: android.smallIcon,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  String _channelForType(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('chat')) return 'chat_channel';
    if (normalized.contains('payment') || normalized.contains('commission')) {
      return 'payments_channel';
    }
    if (normalized.contains('invitation')) return 'invitations_channel';
    if (normalized.contains('order') || normalized.contains('delivery')) {
      return 'orders_channel';
    }
    return 'system_channel';
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigation logic usually goes here or is handled by a listener in the main entry point
  }

  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    // This runs in a separate isolate
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  void onTokenRefresh(Function(String) callback) {
    _messaging.onTokenRefresh.listen((token) => callback(token));
  }
}
