import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../views/main_screen.dart';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // GlobalKey to navigate without BuildContext
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // 1. Request Permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Initialize Local Notifications (For Foreground Taps)
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Handles tap when app is OPEN
          _handleNotificationClick();
        },
      );

      // 3. Create High Importance Channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important custody alerts.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Firebase Foreground Presentation Options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. LISTENERS FOR DIFFERENT APP STATES

      // A. FOREGROUND: App is open and in use
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android.smallIcon,
                importance: Importance.max,
                priority: Priority.high,
                ticker: 'ticker',
              ),
            ),
          );
        }
      });

      // B. BACKGROUND: App is minimized (not closed)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick();
      });

      // C. TERMINATED: App is completely closed
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick();
      }

      // 6. Token Management
      String? token = await _fcm.getToken();
      if (token != null) {
        print("-------------------------------------------------------");
        print("FCM TOKEN: $token");
        print("-------------------------------------------------------");
        await _saveTokenToFirestore(token);
      }

      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    }
  }

  // Navigation Logic
   static void _handleNotificationClick() {
    // navigatorKey.currentState is the equivalent of Navigator.of(context)
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      MainScreen.routeName, // Uses your static route name variable
          (route) => false,      // Removes all previous routes from the stack
      arguments: 0,         // Passes the index 0 to your MainScreen
    );
  }


  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // We use instanceFor to point specifically to your 'clearcase' database
           await FirebaseFirestore.instanceFor(databaseId: 'clearcase', app: Firebase.app(), )
            .collection('users')
            .doc(user.uid)
            .set({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print("✅ FCM Token successfully saved to 'clearcase' DB for: ${user.uid}");
      } else {
        print("⚠️ No user logged in. Token not saved.");
      }
    } catch (e) {
      print("❌ Error saving token: $e");
    }
  }

  static Future<void> deleteTokenOnLogout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Remove the token from the 'clearcase' database
        await FirebaseFirestore.instanceFor(databaseId: 'clearcase', app: Firebase.app())
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': FieldValue.delete(),
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
       }

      // 2. Tell Firebase to invalidate the token on this device
      await _fcm.deleteToken();

    } catch (e) {
      print("❌ Error during token deletion: $e");
    }
  }
}