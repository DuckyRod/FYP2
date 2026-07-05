import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/current_user.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'fypbee_channel',
    'FYPBee Notifications',
    description: 'Notifications for FYPBee updates',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (!_initialized) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_saveToken);

      _foregroundMessageSubscription =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      _initialized = true;
    }

    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(token);
    }
  }

  static Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final targetUserId = message.data['targetUserId'];

    if (targetUserId != null &&
        targetUserId.isNotEmpty &&
        targetUserId != CurrentUser.uid) {
      return;
    }

    final notification = message.notification;

    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> clearTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final token = await _messaging.getToken();
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) return;

    final userData = userDoc.data();

    if (token == null || userData?['fcmToken'] == token) {
      await userRef.update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _initialized = false;
  }
}
