import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../views/main_screen.dart';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important custody alerts.',
    importance: Importance.max,
  );

  // GlobalKey to navigate without BuildContext
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // Request permission. We do NOT gate the rest of initialization on the
    // result — Android can issue an FCM token without notification permission,
    // and iOS will return null until the user grants it (at which point
    // onTokenRefresh fires once APNs registration completes).
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Local notifications setup (Android foreground display + tap routing).
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _handleNotificationClick();
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // iOS foreground display: ask FCM to render the notification automatically
    // while the app is in foreground. Android does not auto-display in
    // foreground, so the onMessage listener below handles it explicitly.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final RemoteNotification? notification = message.notification;
      if (notification == null) return;

      if (Platform.isAndroid) {
        final AndroidNotification? android = notification.android;
        if (android == null) return;

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
            ),
          ),
        );
      }
      // iOS: handled by setForegroundNotificationPresentationOptions above.
    });

    // BACKGROUND tap (app minimized, brought to foreground by tap)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick();
    });

    // TERMINATED tap (app launched by tapping the notification)
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick();
    }

    // Token management — runs regardless of permission grant.
    final String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  // Navigation Logic
  static void _handleNotificationClick() {
    // navigatorKey.currentState is the equivalent of Navigator.of(context)
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      MainScreen.routeName, // Uses your static route name variable
      (route) => false, // Removes all previous routes from the stack
      arguments: 0, // Passes the index 0 to your MainScreen
    );
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instanceFor(
        databaseId: 'clearcase',
        app: Firebase.app(),
      ).collection('users').doc(user.uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token save failed: $e');
      }
    }
  }

  static Future<void> deleteTokenOnLogout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instanceFor(
          databaseId: 'clearcase',
          app: Firebase.app(),
        ).collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _fcm.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token deletion failed: $e');
      }
    }
  }
}
