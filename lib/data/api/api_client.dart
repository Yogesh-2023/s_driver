import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';
import '../../services/socket/socket_service.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../core/security/secure_session_store.dart';
import '../../widgets/custom_snackbar.dart';

class ApiClient extends GetConnect implements GetxService {
  late Map<String, String> _mainHeaders;
  bool _handlingUnauthorized = false;

  @override
  void onInit() {
    super.onInit();
    baseUrl = ApiConstants.baseUrl;
    timeout = Duration(seconds: 120);

    // Initialize default headers
    _mainHeaders = {
      'Content-type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    // Request Interceptor: Send session cookie if available.
    httpClient.addRequestModifier<dynamic>((request) async {
      final sessionCookie = await SecureSessionStore.readCookie();
      final authToken = await SecureSessionStore.readToken();
      final bearerToken = authToken ?? _tokenFromCookie(sessionCookie);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        request.headers['Cookie'] = sessionCookie;
      } else if (_mainHeaders.containsKey('Cookie')) {
        request.headers['Cookie'] = _mainHeaders['Cookie']!;
      }
      final csrfToken = await SecureSessionStore.readCsrfToken();
      if (csrfToken != null && csrfToken.isNotEmpty) {
        request.headers['x-csrf-token'] = csrfToken;
      }
      return request;
    });

    // Response Interceptor: Globally handle status codes and cookies
    httpClient.addResponseModifier((request, response) async {
      String? setCookie;
      response.headers?.forEach((key, value) {
        if (key.toLowerCase() == 'set-cookie') {
          if (setCookie == null) {
            setCookie = value;
          } else {
            setCookie = '$setCookie; $value';
          }
        }
        if (key.toLowerCase() == 'x-csrf-token' && value.isNotEmpty) {
          SecureSessionStore.writeCsrfToken(value);
        }
      });

      if (setCookie != null && setCookie!.isNotEmpty) {
        await updateSessionCookieFromSetCookie(setCookie!);
      }

      if (response.statusCode == 401) {
        _handleUnauthorized();
      }
      return _userFriendlyResponse(response);
    });
  }

  Response _userFriendlyResponse(Response response) {
    if (response.isOk) return response;

    final statusCode = response.statusCode ?? 0;
    String userMsg = 'Something went wrong. Please try again.';

    if (_isActiveBookingSessionConflict(response)) {
      userMsg =
          'You already have an active ride. Please complete or cancel it before booking a new one.';
      CustomSnackbar.showWarning(message: userMsg);
    } else if (statusCode >= 500) {
      userMsg = 'Something went wrong on the server. Please try again later.';
    } else if (statusCode == 401) {
      userMsg = 'Session expired. Please login again.';
    } else if (statusCode == 404) {
      userMsg = 'Requested data was not found.';
    } else {
      String? bodyMsg;
      if (response.body is Map) {
        bodyMsg =
            response.body['message']?.toString() ??
            response.body['error']?.toString();
      }
      final rawMsg = bodyMsg ?? response.statusText ?? '';
      if (rawMsg.isNotEmpty && !_isTechnicalError(rawMsg, response.body)) {
        userMsg = rawMsg;
      } else {
        userMsg = 'Something went wrong. Please try again.';
      }
    }

    return Response(
      statusCode: response.statusCode,
      body: response.body,
      statusText: userMsg,
      headers: response.headers,
      request: response.request,
    );
  }

  bool _isActiveBookingSessionConflict(Response response) {
    if (response.statusCode != 409 || response.body is! Map) return false;

    final body = response.body as Map;
    final message = body['message']?.toString().toLowerCase() ?? '';
    final error = body['error'];
    final code = error is Map ? error['code']?.toString().toUpperCase() : '';

    return code == 'CONFLICT' &&
        message.contains('active booking session');
  }

  bool _isTechnicalError(String msg, dynamic body) {
    final lower = msg.toLowerCase();
    if (lower.contains('prisma') ||
        lower.contains('p20') ||
        lower.contains('sql') ||
        lower.contains('database') ||
        lower.contains('error fetching') ||
        lower.contains('exception') ||
        lower.contains('column') ||
        lower.contains('syntaxerror')) {
      return true;
    }
    if (body is Map && body['code'] != null) {
      final codeStr = body['code'].toString().toUpperCase();
      if (codeStr.startsWith('P20') || codeStr.startsWith('ERR_')) {
        return true;
      }
    }
    return false;
  }

  // Handle unauthorized response (401)
  void _handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    final prefs = await SharedPreferences.getInstance();
    await SecureSessionStore.clear();
    await prefs.remove('user_id');
    await prefs.remove('is_logged_in');
    _mainHeaders.remove('Cookie');

    // Disconnect socket if any
    try {
      final socketService = Get.find<SocketService>();
      socketService.closeSocket();
    } catch (_) {}

    // CustomSnackbar.showError(
    //   message: 'Session expired. Please log in again to continue.',
    // );
    // Navigate to splash or login
    Get.offAll(() => const OnboardingScreen()); // fallback navigation
  }

  Future<void> updateSessionCookie(String cookie) async {
    _handlingUnauthorized = false;
    _mainHeaders['Cookie'] = cookie;
    await SecureSessionStore.writeCookie(cookie);
  }

  Future<Map<String, String>> _headersWithSessionCookie({
    Map<String, String>? headers,
    bool isFormData = false,
  }) async {
    final requestHeaders = Map<String, String>.from(headers ?? _mainHeaders);
    final sessionCookie = await SecureSessionStore.readCookie();
    final authToken = await SecureSessionStore.readToken();
    final bearerToken = authToken ?? _tokenFromCookie(sessionCookie);

    if (bearerToken != null && bearerToken.isNotEmpty) {
      requestHeaders['Authorization'] = 'Bearer $bearerToken';
    }

    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      requestHeaders['Cookie'] = sessionCookie;
      _mainHeaders['Cookie'] = sessionCookie;
    }

    if (isFormData) {
      requestHeaders.remove('Content-type');
    }

    return requestHeaders;
  }

  String? _tokenFromCookie(String? cookie) {
    if (cookie == null || cookie.isEmpty) return null;
    final match = RegExp(
      r'(?:^|;\s*)(?:session|better-auth\.session_token)=([^;]+)',
    ).firstMatch(cookie);
    return match?.group(1);
  }

  Future<void> updateSessionCookieFromSetCookie(String setCookie) async {
    final cookie = _cookieHeaderFromSetCookie(setCookie);
    if (cookie.isEmpty) return;
    await updateSessionCookie(cookie);
  }

  String _cookieHeaderFromSetCookie(String setCookie) {
    final cookiePairs = <String>[];
    final matches = RegExp(
      r'(^|,\s*)([A-Za-z0-9_.-]+=[^;,]+)',
    ).allMatches(setCookie);

    for (final match in matches) {
      final pair = match.group(2);
      if (pair == null) continue;
      final key = pair.split('=').first.toLowerCase();
      if (key == 'path' ||
          key == 'expires' ||
          key == 'max-age' ||
          key == 'domain' ||
          key == 'samesite') {
        continue;
      }
      cookiePairs.add(pair);
    }

    return cookiePairs.join('; ');
  }

  // POST Request Wrapper
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    try {
      final requestHeaders = await _headersWithSessionCookie(
        headers: headers,
        isFormData: body is FormData,
      );
      Response response = await post(uri, body, headers: requestHeaders);
      if (response.statusCode == null) {
        print("=== API POST RETURNED NULL STATUS CODE ===");
        print("URI: $uri");
        print("StatusText: ${response.statusText}");
        print("Response Body: ${response.body}");
        print("Headers Sent: $requestHeaders");
      }
      return response;
    } catch (e, stackTrace) {
      print("=== API POST EXCEPTION ===");
      print("URI: $uri");
      print("Exception Type: ${e.runtimeType}");
      print("Error: $e");
      print("Stack Trace: $stackTrace");
      return Response(statusCode: 1, statusText: e.toString());
    }
  }

  // GET Request Wrapper
  Future<Response> getData(
    String uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? query,
  }) async {
    if (kDebugMode) debugPrint('API GET ${ApiConstants.baseUrl}$uri query: $query');
    try {
      final requestHeaders = await _headersWithSessionCookie(headers: headers);
      Response response = await get(uri, headers: requestHeaders, query: query);
      if (kDebugMode) {
        debugPrint('API GET $uri -> ${response.statusCode}');
        debugPrint('API GET $uri RESPONSE: ${response.body}');
      }
      return response;
    } catch (e) {
      debugPrint('=== API GET ERROR ===');
      debugPrint('URL: ${ApiConstants.baseUrl}$uri');
      debugPrint('Error: $e');
      return Response(statusCode: 1, statusText: e.toString());
    }
  }

  // PUT Request Wrapper
  Future<Response> putData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    print("=== API PUT REQUEST ===");
    print("URI: $uri");
    _printRequestBody(body);
    try {
      final requestHeaders = await _headersWithSessionCookie(
        headers: headers,
        isFormData: body is FormData,
      );
      Response response = await put(uri, body, headers: requestHeaders);
      print("=== API PUT RESPONSE ===");
      print("URI: $uri");
      print("Status Code: ${response.statusCode}");
      String bodyStr = response.body?.toString() ?? '';
      if (bodyStr.length > 2000) {
        bodyStr = bodyStr.substring(0, 2000) + '... [TRUNCATED]';
      }
      print("Response Body: $bodyStr");
      return response;
    } catch (e) {
      print("=== API PUT ERROR ===");
      print("URI: $uri");
      print("Error: $e");
      return Response(statusCode: 1, statusText: e.toString());
    }
  }

  // PATCH Request Wrapper
  Future<Response> patchData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    print("=== API PATCH REQUEST ===");
    print("URI: $uri");
    _printRequestBody(body);
    try {
      final requestHeaders = await _headersWithSessionCookie(
        headers: headers,
        isFormData: body is FormData,
      );
      Response response = await patch(uri, body, headers: requestHeaders);
      print("=== API PATCH RESPONSE ===");
      print("URI: $uri");
      print("Status Code: ${response.statusCode}");
      String bodyStr = response.body?.toString() ?? '';
      if (bodyStr.length > 2000) {
        bodyStr = bodyStr.substring(0, 2000) + '... [TRUNCATED]';
      }
      print("Response Body: $bodyStr");
      return response;
    } catch (e) {
      print("=== API PATCH ERROR ===");
      print("URI: $uri");
      print("Error: $e");
      return Response(statusCode: 1, statusText: e.toString());
    }
  }

  // DELETE Request Wrapper
  Future<Response> deleteData(
    String uri, {
    Map<String, String>? headers,
  }) async {
    print("=== API DELETE REQUEST ===");
    print("URI: $uri");
    try {
      final requestHeaders = await _headersWithSessionCookie(headers: headers);
      Response response = await delete(uri, headers: requestHeaders);
      print("=== API DELETE RESPONSE ===");
      print("URI: $uri");
      print("Status Code: ${response.statusCode}");
      String bodyStr = response.body?.toString() ?? '';
      if (bodyStr.length > 2000) {
        bodyStr = bodyStr.substring(0, 2000) + '... [TRUNCATED]';
      }
      print("Response Body: $bodyStr");
      return response;
    } catch (e) {
      print("=== API DELETE ERROR ===");
      print("URI: $uri");
      print("Error: $e");
      return Response(statusCode: 1, statusText: e.toString());
    }
  }

  void _printRequestBody(dynamic body) {
    if (body is FormData) {
      print("Body: FormData");
      print("Fields:");
      for (final field in body.fields) {
        print("  ${field.key}: ${field.value}");
      }
      print("Files:");
      for (final file in body.files) {
        print(
          "  ${file.key}: ${file.value.filename} (${file.value.contentType})",
        );
      }
      return;
    }

    print("Body: $body");
  }
}
