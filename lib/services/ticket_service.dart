import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import '../data/api/api_client.dart';
import '../data/api/api_constants.dart';

class TicketService extends GetxService {
  TicketService();

  final ApiClient _apiClient = Get.find<ApiClient>();
  String? lastErrorMessage;

  /// GET /v1/driver/support/categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    lastErrorMessage = null;
    try {
      final response = await _apiClient.getData(ApiConstants.driverSupportCategories);
      if (response.isOk && response.body != null) {
        final body = response.body;
        final raw = body is Map ? (body['data'] ?? body['items'] ?? body) : body;
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      print('Error fetching driver support categories: $e');
    }
    return [];
  }

  /// Upload Attachment (POST /v1/driver/support/attachments)
  /// Multipart field 'attachment', max size ≤ 10 MB for Driver
  Future<Map<String, dynamic>?> uploadAttachment(String filePath) async {
    lastErrorMessage = null;
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        lastErrorMessage = 'File size exceeds max 10 MB limit';
        return {'error': 'File size exceeds 10 MB limit'};
      }

      final fileName = filePath.split(RegExp(r'[\\/]')).last;
      final formData = FormData({
        'attachment': MultipartFile(
          filePath,
          filename: fileName,
          contentType: _contentTypeFromPath(filePath),
        ),
      });

      final response = await _apiClient.postData(ApiConstants.driverSupportAttachments, formData);
      if (response.isOk && response.body != null) {
        final body = response.body;
        final data = body is Map ? (body['data'] ?? body) : body;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      lastErrorMessage = _responseMessage(response) ?? 'Upload failed';
    } catch (e) {
      print('Error uploading attachment: $e');
      lastErrorMessage = e.toString();
    }
    return null;
  }

  bool _isValidUuid(String? str) {
    if (str == null || str.trim().isEmpty) return false;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str.trim());
  }

  /// POST /v1/driver/support/tickets
  Future<Map<String, dynamic>?> raiseTicket({
    required String subject,
    required String description,
    String? categoryId,
    String? bookingId,
    List<Map<String, dynamic>>? attachments,
  }) async {
    lastErrorMessage = null;
    try {
      final payload = <String, dynamic>{
        'subject': subject.trim(),
        'description': description.trim(),
        if (_isValidUuid(categoryId)) 'categoryId': categoryId,
        if (_isValidUuid(bookingId)) 'bookingId': bookingId,
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      };

      final response = await _apiClient.postData(ApiConstants.driverSupportTickets, payload);
      if (response.isOk && response.body != null) {
        final body = response.body;
        final data = body is Map ? (body['data'] ?? body) : body;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      lastErrorMessage = _responseMessage(response) ?? 'Failed to create ticket';
    } catch (e) {
      print('Error creating driver ticket: $e');
      lastErrorMessage = e.toString();
    }
    return null;
  }

  /// GET /v1/driver/support/tickets?page=...&limit=...
  Future<Map<String, dynamic>?> getTickets({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    lastErrorMessage = null;
    try {
      final query = <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final endpoint = Uri(path: ApiConstants.driverSupportTickets, queryParameters: query).toString();
      final response = await _apiClient.getData(endpoint);

      if (response.isOk && response.body != null) {
        final body = response.body;
        if (body is Map) {
          final data = body['data'];
          final meta = body['meta'] ?? {};
          List items = [];
          if (data is List) items = data;
          else if (data is Map) items = (data['tickets'] ?? data['items'] ?? []) as List;
          return {
            'items': items,
            'meta': meta,
          };
        }
      }
      lastErrorMessage = _responseMessage(response);
    } catch (e) {
      print('Error fetching driver tickets: $e');
    }
    return null;
  }

  /// GET /v1/driver/support/tickets/:ticketId
  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    lastErrorMessage = null;
    try {
      final response = await _apiClient.getData(ApiConstants.driverSupportTicket(ticketId));
      if (response.isOk && response.body != null) {
        final body = response.body;
        final data = body is Map ? (body['data'] ?? body) : body;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      lastErrorMessage = _responseMessage(response);
    } catch (e) {
      print('Error fetching driver ticket detail: $e');
    }
    return null;
  }

  /// POST /v1/driver/support/tickets/:ticketId/messages
  Future<Map<String, dynamic>?> sendMessage({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>>? attachments,
    String? attachmentUrl,
  }) async {
    lastErrorMessage = null;
    try {
      final payload = <String, dynamic>{
        'message': message.trim(),
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
        if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
      };

      final response = await _apiClient.postData(
        ApiConstants.driverSupportTicketMessages(ticketId),
        payload,
      );

      if (response.statusCode == 409) {
        return {'error': 'CONFLICT', 'message': 'Ticket is resolved or closed.'};
      }

      if (response.isOk && response.body != null) {
        final body = response.body;
        final data = body is Map ? (body['data'] ?? body) : body;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      lastErrorMessage = _responseMessage(response);
    } catch (e) {
      print('Error sending message: $e');
    }
    return null;
  }

  /// PATCH /v1/driver/support/tickets/:ticketId/messages/read
  Future<bool> markRead(String ticketId) async {
    try {
      final response = await _apiClient.patchData(
        ApiConstants.driverSupportTicketMessagesRead(ticketId),
        <String, dynamic>{},
      );
      return response.isOk;
    } catch (e) {
      print('Error marking read: $e');
      return false;
    }
  }

  /// POST /v1/driver/support/tickets/:ticketId/close
  Future<bool> closeTicket(String ticketId) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.driverSupportTicketClose(ticketId),
        <String, dynamic>{},
      );
      return response.isOk;
    } catch (e) {
      print('Error closing ticket: $e');
      return false;
    }
  }

  String _contentTypeFromPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String? _responseMessage(Response response) {
    final body = response.body;
    if (body is Map) {
      if (body['errors'] != null) {
        final errs = body['errors'];
        if (errs is List && errs.isNotEmpty) {
          final first = errs.first;
          if (first is Map && first['message'] != null) {
            final path = (first['path'] as List?)?.join('.') ?? '';
            return path.isNotEmpty ? '$path: ${first['message']}' : first['message'].toString();
          }
        }
      }
      return body['message']?.toString() ??
          body['error']?.toString() ??
          body['errors']?.toString();
    }
    return response.statusText;
  }
}
