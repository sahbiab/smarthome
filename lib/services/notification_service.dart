import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';  // For Color
import 'dart:io' show Platform;

// ⭐ Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background message received: ${message.messageId}');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    if (_initialized) return;

    print('🔔 Initializing Notification Service...');

    try {
      // 1. Request permissions (Android 13+, iOS)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      print('📱 Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 2. Initialize local notifications
        await _initializeLocalNotifications();

        // 3. Get FCM token
        String? token = await _fcm.getToken();
        if (token != null) {
          print('🔑 FCM Token: $token');
          await _saveTokenToDatabase(token);
        }

        // 4. Handle token refresh
        _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

        // 5. Set up background handler
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        // 6. Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 7. Handle notification taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // 8. Check for notification that opened the app
        RemoteMessage? initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        _initialized = true;
        print('✅ Notification Service initialized successfully');
      } else {
        print('⚠️  Notification permission denied');
      }
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Initialize local notifications (for Android notification channels)
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Local notification tapped: ${response.payload}');
      },
    );

    // Create high importance channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Smart Home Alerts',
      description: 'Notifications for security alerts and button presses',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('📢 Notification channel created');
  }

  /// Save FCM token to Firebase
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final ref = FirebaseDatabase.instance.ref('fcm_tokens');
      await ref.child(token.replaceAll(':', '_')).set({
        'token': token,
        'platform': Platform.operatingSystem,
        'lastUpdated': ServerValue.timestamp,
      });
      print('💾 FCM token saved to database');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  /// Show a local notification manually
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Smart Home Alerts',
          channelDescription: 'Notifications for security alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFFF9800),
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.messageId}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      // Show notification using local notifications
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Smart Home Alerts',
            channelDescription: 'Notifications for security alerts',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFFF9800), // Orange color
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );

      print('📢 Foreground notification displayed');
    }
  }

  /// Handle notification tap (when user taps on notification)
  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.messageId}');
    print('   Data: ${message.data}');

    // You can navigate to specific pages based on notification type
    String? type = message.data['type'];
    if (type == 'unknown_button') {
      print('   → Button alert tapped');
      // Navigate to button/security page if needed
    } else if (type == 'unknown_face') {
      print('   → Face alert tapped');
      // Navigate to camera/security page
    }
  }

  /// Send a test notification
  Future<void> sendTestNotification() async {
    try {
      await _localNotifications.show(
        999,
        '🎉 Test Notification',
        'Push notifications are working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Smart Home Alerts',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
      print('✅ Test notification sent');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }
}
