import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'notification_api_service.dart';
import '../features/notifications/controllers/notification_controller.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/dashboard/driver_home_screen.dart';
import '../features/dashboard/earnings_screen.dart';
import '../features/dashboard/navigate_to_pickup_screen.dart';
import '../features/auth/repositories/history_order_screen.dart';
import '../features/auth/controllers/auth_controller.dart';

const AndroidNotificationChannel _pushChannel = AndroidNotificationChannel(
  'ride_requests',
  'Ride Requests',
  description: 'High priority notifications for incoming ride requests and ride updates.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Important Notifications',
  description: 'High importance notifications channel.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _lastNavigatedNotificationId;

  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_pushChannel);
    await androidImpl?.createNotificationChannel(_highImportanceChannel);
    await androidImpl?.requestNotificationsPermission();

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    _messaging.onTokenRefresh.listen(_registerToken);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(initialMessage);
      });
    }

    _initialized = true;
    await syncToken();
  }

  Future<void> syncToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      debugPrint('FCM token unavailable: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    debugPrint('[DRIVER_APP][FCM][TOKEN] Token: $token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    try {
      await NotificationApiService.registerToken({
        'token': token,
        'platform': Platform.operatingSystem,
        'deviceId': 'device_${Platform.operatingSystem}',
        'appType': 'DRIVER',
        'appVersion': '1.0.0',
      });
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('fcm_token');
    if (token != null && token.isNotEmpty) {
      try {
        await NotificationApiService.deleteToken(token);
        await prefs.remove('fcm_token');
      } catch (e) {
        debugPrint('Failed to remove FCM token: $e');
      }
    }
  }

  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId ?? 'high_importance_channel',
            'Important Notifications',
            channelDescription: 'High priority status bar notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
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
    } catch (e) {
      debugPrint('Error showing system status bar notification: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'New Ride Request';
    final body = notification?.body ?? data['body'] ?? data['message'] ?? 'You have received a new ride request.';
    final type = (data['type'] ?? data['event'] ?? 'NEW_RIDE_REQUEST').toString();
    final bookingId = (data['bookingId'] ?? data['rideId'] ?? data['tripId'])?.toString();
    final typeUpper = type.toUpperCase();
    final isRideRequest = typeUpper == 'NEW_RIDE_REQUEST' ||
        typeUpper == 'RIDE_REQUEST' ||
        typeUpper == 'DISPATCH_OFFER' ||
        typeUpper == 'GOODS_REQUEST';

    if (isRideRequest &&
        Get.isRegistered<AuthController>() &&
        !Get.find<AuthController>().isRideAccessEnabled) {
      Get.find<AuthController>().enforceKycRideAccess();
      return;
    }

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: title,
        body: body,
        type: type,
        bookingId: bookingId,
        extraData: data,
        showSystemBanner: true,
      );
    } else {
      await showSystemNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
        channelId: 'ride_requests',
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[DRIVER_APP][FCM][TAP] Payload: ${message.data}');
    final data = message.data;
    final msgId = message.messageId ?? data['notificationId'] ?? data['id'];
    if (msgId != null && msgId == _lastNavigatedNotificationId) {
      debugPrint('[DRIVER_APP][FCM][TAP] Duplicate tap ignored for $msgId');
      return;
    }
    _lastNavigatedNotificationId = msgId?.toString();

    final type = (data['type'] ?? data['event'] ?? data['module'] ?? data['screen'])?.toString().toUpperCase();
    final bookingId = (data['rideId'] ?? data['bookingId'] ?? data['tripId'] ?? data['id'])?.toString();
    final hasRideAccess = !Get.isRegistered<AuthController>() ||
        Get.find<AuthController>().isRideAccessEnabled;

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.handleNotificationTapEvent({
        'type': type,
        'bookingId': bookingId,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    try {
      if (type == 'NEW_RIDE_REQUEST' ||
          type == 'RIDE_REQUEST' ||
          type == 'DISPATCH_OFFER' ||
          type == 'GOODS_REQUEST') {
        if (!hasRideAccess) {
          Get.find<AuthController>().enforceKycRideAccess();
          Get.offAll(() => const DriverHomeScreen());
          return;
        }
        Get.offAll(() => DriverHomeScreen(
              targetBookingId: bookingId,
              targetPayload: data,
            ));
        return;
      }

      if (type == 'RIDE_CANCELLED' || type == 'BOOKING_CANCELLED' || type == 'USER_CANCELLED') {
        Get.offAll(() => DriverHomeScreen(
              targetBookingId: bookingId,
              targetPayload: data,
              isCancelledEvent: true,
            ));
        return;
      }

      if (type == 'RIDE_MISSED' || type == 'RIDE_COMPLETED') {
        if (!hasRideAccess) {
          Get.find<AuthController>().enforceKycRideAccess();
          Get.offAll(() => const DriverHomeScreen());
          return;
        }
        Get.to(() => const BookingsHistoryScreen());
        return;
      }
      if (type == 'PAYMENT_RECEIVED' || type == 'PAYMENT_SUCCESSFUL' || type == 'EARNINGS') {
        Get.to(() => const EarningsScreen(showBackButton: true));
        return;
      }
      if (type == 'RIDE_ACCEPTED' || type == 'DRIVER_ARRIVED' || type == 'RIDE_STARTED' || type == 'TRIP_STARTED') {
        if (!hasRideAccess) {
          Get.find<AuthController>().enforceKycRideAccess();
          Get.offAll(() => const DriverHomeScreen());
          return;
        }
        if (bookingId != null && bookingId.isNotEmpty) {
          Get.to(() => NavigateToPickupScreen(requestData: {'bookingId': bookingId, ...data}));
        } else {
          Get.to(() => const DriverHomeScreen());
        }
        return;
      }
    } catch (e) {
      debugPrint('Safe fallback navigation error: $e');
    }

    // Default fallback: Go to NotificationsScreen
    Get.to(() => const NotificationsScreen());
  }
}
