import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Navigator key untuk navigate dari notifikasi
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ─── Init ─────────────────────────────────────────────────
  Future<void> init() async {
    // Request permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Setup local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Buat channel notifikasi Android
    await _createNotificationChannel();

    // Handler saat app di foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler saat user tap notifikasi (app di background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Cek apakah app dibuka dari notifikasi saat terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // ─── Buat channel Android ─────────────────────────────────
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'dikari_channel',
      'Dikari Notifications',
      description: 'Notifikasi dari aplikasi Dikari',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // ─── Handle foreground message ────────────────────────────
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'dikari_channel',
          'Dikari Notifications',
          channelDescription: 'Notifikasi dari aplikasi Dikari',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF1565C0), // AppTheme.primary
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _buildPayload(message.data),
    );
  }

  // ─── Handle tap notifikasi ────────────────────────────────
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    _navigateFromPayload(response.payload!);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final payload = _buildPayload(message.data);
    _navigateFromPayload(payload);
  }

  // ─── Navigate berdasarkan type notifikasi ─────────────────
  void _navigateFromPayload(String payload) {
    final parts = payload.split(':');
    if (parts.length < 2) return;

    final type = parts[0];
    final orderId = parts[1];

    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'order_confirmed':
      case 'waiting_confirmation':
      case 'order_completed':
      case 'order_assigned':
        // Navigate ke detail order
        Navigator.of(context).pushNamed('/pesanan');
        break;
      case 'balance_released':
        Navigator.of(context).pushNamed('/pesanan');
        break;
      case 'subscription_confirmed':
      case 'subscription_session_assigned':
        Navigator.of(context).pushNamed('/langganan');
        break;
    }
  }

  String _buildPayload(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final orderId = data['order_id'] ?? '';
    return '$type:$orderId';
  }

  // ─── Get FCM Token ────────────────────────────────────────
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // ─── Listen token refresh ─────────────────────────────────
  void onTokenRefresh(Function(String) callback) {
    _fcm.onTokenRefresh.listen(callback);
  }
}
