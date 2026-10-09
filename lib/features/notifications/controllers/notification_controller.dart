import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_api_service.dart';
import '../../../services/push_notification_service.dart';

class NotificationController extends GetxController {
  static NotificationController get to => Get.find<NotificationController>();

  var notifications = <dynamic>[].obs;
  var unreadCount = 0.obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasMore = true.obs;
  var page = 1.obs;

  var ringTrigger = 0.obs;
  var selectedNotificationTap = <String, dynamic>{}.obs;
  final Set<String> _processedNotificationKeys = {};

  void handleNotificationTapEvent(Map<String, dynamic> data) {
    selectedNotificationTap.value = Map<String, dynamic>.from(data);
  }

  @override
  void onInit() {
    super.onInit();
    _loadProcessedNotificationKeys();
    fetchUnreadCount();
  }

  void ringBell() {
    ringTrigger.value++;
  }

  Future<void> _loadProcessedNotificationKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString('local_driver_notifications');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> list = jsonDecode(saved);
        for (var item in list) {
          final String key = _buildDedupKey(item);
          if (key.isNotEmpty) _processedNotificationKeys.add(key);
        }
      }
    } catch (e) {
      debugPrint('Error loading local driver notification keys: $e');
    }
  }

  Future<void> _saveLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_driver_notifications', jsonEncode(notifications.toList()));
    } catch (e) {
      debugPrint('Error saving local driver notifications: $e');
    }
  }

  void _recalculateUnreadCount() {
    int unread = 0;
    for (var n in notifications) {
      if (n['isRead'] == false) unread++;
    }
    unreadCount.value = unread;
  }

  String _buildDedupKey(dynamic item) {
    if (item is! Map) return '';
    final id = item['id'] ?? item['_id'];
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }
    final meta = item['metadata'] is Map
        ? item['metadata']
        : (item['data'] is Map ? item['data'] : null);
    final bookingId = (meta?['bookingId'] ?? meta?['rideId'] ?? meta?['tripId'])?.toString();
    final type = (meta?['type'] ?? meta?['event'])?.toString().toUpperCase();
    if (bookingId != null && bookingId.isNotEmpty && type != null && type.isNotEmpty) {
      return '${bookingId}_$type';
    }
    return '';
  }

  List<dynamic> _extractNotificationList(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return const [];

    for (final key in const ['notifications', 'data', 'items', 'results']) {
      final value = data[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractNotificationList(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }

  void addLocalNotification({
    required String title,
    required String body,
    required String type,
    String? bookingId,
    Map<String, dynamic>? extraData,
    bool showSystemBanner = true,
  }) {
    try {
      final typeUpper = type.toUpperCase();
      final dedupKey = (bookingId != null && bookingId.isNotEmpty)
          ? '${bookingId}_$typeUpper'
          : 'notif_${title}_$typeUpper';

      if (_processedNotificationKeys.contains(dedupKey)) {
        debugPrint('[DRIVER_NOTIFICATION][DEDUP] Duplicate notification ignored: $dedupKey');
        return;
      }

      final exists = notifications.any((n) {
        final key = _buildDedupKey(n);
        return key == dedupKey;
      });

      if (exists) {
        _processedNotificationKeys.add(dedupKey);
        return;
      }

      _processedNotificationKeys.add(dedupKey);

      final id = 'loc_${DateTime.now().millisecondsSinceEpoch}_${bookingId ?? ''}_$typeUpper';
      final newNotif = {
        'id': id,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        'metadata': {
          'type': typeUpper,
          'bookingId': bookingId,
          ...?extraData,
        },
      };

      notifications.insert(0, newNotif);
      notifications.refresh();
      _recalculateUnreadCount();
      ringBell();
      _saveLocalNotifications();

      if (showSystemBanner) {
        PushNotificationService.instance.showSystemNotification(
          title: title,
          body: body,
          payload: jsonEncode({
            'type': typeUpper,
            'bookingId': bookingId,
            ...?extraData,
          }),
        );
      }
    } catch (e) {
      debugPrint('Error adding local driver notification: $e');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final count = await NotificationApiService.fetchUnreadCount();
      if (count > unreadCount.value) {
        ringBell();
      }
      unreadCount.value = count;
    } catch (e) {
      debugPrint('Failed to fetch unread count: $e');
    }
  }

  Future<void> refreshList() async {
    page.value = 1;
    hasMore.value = true;
    await fetchNotifications(isRefresh: true);
    fetchUnreadCount();
  }

  Future<void> fetchNotifications({bool isRefresh = false}) async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;

    if (isRefresh) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final data = await NotificationApiService.fetchNotifications(page: page.value, limit: 20);
      final List<dynamic> newNotifications = _extractNotificationList(data);

      if (isRefresh) {
        _processedNotificationKeys.clear();
        for (var n in newNotifications) {
          final key = _buildDedupKey(n);
          if (key.isNotEmpty) _processedNotificationKeys.add(key);
        }
        final remoteList = List<dynamic>.from(newNotifications);
        remoteList.sort((a, b) {
          final aDate = a['createdAt'] ?? a['created_at'] ?? '';
          final bDate = b['createdAt'] ?? b['created_at'] ?? '';
          return bDate.toString().compareTo(aDate.toString());
        });
        notifications.assignAll(remoteList);
      } else {
        for (var n in newNotifications) {
          final key = _buildDedupKey(n);
          if (key.isEmpty || !_processedNotificationKeys.contains(key)) {
            notifications.add(n);
            if (key.isNotEmpty) _processedNotificationKeys.add(key);
          }
        }
      }

      _recalculateUnreadCount();
      _saveLocalNotifications();

      if (newNotifications.length < 20) {
        hasMore.value = false;
      } else {
        page.value++;
      }
    } catch (e) {
      debugPrint('Failed to load remote driver notifications: $e');
      if (isRefresh) {
        notifications.clear();
        unreadCount.value = 0;
        await _saveLocalNotifications();
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> markAsRead(String id, int index) async {
    if (index < 0 || index >= notifications.length) return;
    if (notifications[index]['isRead'] == true) return;
    
    // Optimistic update
    notifications[index]['isRead'] = true;
    notifications.refresh();
    _recalculateUnreadCount();
    _saveLocalNotifications();

    if (!id.startsWith('loc_')) {
      try {
        await NotificationApiService.markAsRead(id);
      } catch (e) {
        debugPrint('Failed to sync markAsRead with server: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in notifications) {
      n['isRead'] = true;
    }
    notifications.refresh();
    unreadCount.value = 0;
    _saveLocalNotifications();

    try {
      await NotificationApiService.markAllAsRead();
    } catch (e) {
      debugPrint('Failed to sync markAllAsRead with server: $e');
    }
  }

  Future<void> deleteNotification(String id, int index) async {
    if (index < 0 || index >= notifications.length) return;
    final removedItem = notifications[index];
    notifications.removeAt(index);
    _recalculateUnreadCount();
    _saveLocalNotifications();

    if (!id.startsWith('loc_')) {
      try {
        await NotificationApiService.deleteNotification(id);
      } catch (e) {
        notifications.insert(index, removedItem);
        _recalculateUnreadCount();
        _saveLocalNotifications();
        Get.snackbar('Error', 'Failed to delete notification.');
      }
    }
  }
}
