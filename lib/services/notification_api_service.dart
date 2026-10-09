import 'package:get/get.dart';
import '../data/api/api_client.dart';
import '../data/api/api_constants.dart';

class NotificationApiService {
  static final ApiClient _api = Get.find<ApiClient>();

  static Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
    String? from,
    String? to,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (type != null) queryParams['type'] = type;
    if (isRead != null) queryParams['isRead'] = isRead.toString();
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;

    final response = await _api.get(ApiConstants.notifications, query: queryParams);
    return response.body ?? {};
  }

  static Future<Map<String, dynamic>> fetchNotificationDetail(String id) async {
    final response = await _api.get(ApiConstants.notificationDetail(id));
    return response.body ?? {};
  }

  static Future<int> fetchUnreadCount() async {
    final response = await _api.get(ApiConstants.unreadNotificationCount);
    final body = response.body;
    if (body is Map) {
      final rawCount =
          body['count'] ?? body['unreadCount'] ?? body['unread'] ?? body['total'];
      if (rawCount is num) return rawCount.toInt();
      final parsedCount = int.tryParse(rawCount?.toString() ?? '');
      if (parsedCount != null) return parsedCount;

      final data = body['data'];
      if (data is Map) {
        final rawDataCount = data['count'] ??
            data['unreadCount'] ??
            data['unread'] ??
            data['total'];
        if (rawDataCount is num) return rawDataCount.toInt();
        return int.tryParse(rawDataCount?.toString() ?? '') ?? 0;
      }
    }
    return 0;
  }

  static Future<bool> markAsRead(String id) async {
    final response = await _api.patch(ApiConstants.markNotificationRead(id), {});
    return response.isOk;
  }

  static Future<bool> markAsUnread(String id) async {
    final response = await _api.patch(ApiConstants.markNotificationUnread(id), {});
    return response.isOk;
  }

  static Future<bool> markAllAsRead() async {
    final response = await _api.patch(ApiConstants.markAllNotificationsRead, {});
    return response.isOk;
  }

  static Future<bool> deleteNotification(String id) async {
    final response = await _api.delete(ApiConstants.notificationDetail(id));
    return response.isOk;
  }

  static Future<bool> clearReadNotifications() async {
    final response = await _api.delete(ApiConstants.notifications, query: {'scope': 'read'});
    return response.isOk;
  }

  static Future<Map<String, dynamic>> fetchPreferences() async {
    final response = await _api.get(ApiConstants.notificationPreferences);
    return response.body ?? {};
  }

  static Future<bool> updatePreferences(Map<String, dynamic> data) async {
    final response = await _api.patch(ApiConstants.notificationPreferences, data);
    return response.isOk;
  }

  static Future<void> registerToken(Map<String, dynamic> data) async {
    await _api.post(ApiConstants.registerToken, data);
  }

  static Future<void> updateToken(Map<String, dynamic> data) async {
    await _api.put(ApiConstants.notificationToken, data);
  }

  static Future<void> deleteToken(String token) async {
    await _api.delete(ApiConstants.notificationToken, query: {'token': token});
  }
}
