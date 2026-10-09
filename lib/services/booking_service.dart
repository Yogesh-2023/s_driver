import 'package:get/get.dart';
import '../data/api/api_client.dart';
import '../data/api/api_constants.dart';

class BookingService extends GetxService {
  static BookingService get to {
    try {
      return Get.find<BookingService>();
    } catch (_) {
      return Get.put(BookingService());
    }
  }

  ApiClient get _api => Get.find<ApiClient>();

  /// Accept incoming booking
  Future<Response> acceptBooking(String bookingId) async {
    final uri = ApiConstants.acceptBooking(bookingId);
    print("=== DRIVER API REQUEST ===");
    print("Method: POST");
    print("URL: ${ApiConstants.baseUrl}$uri");

    final response = await _api.postData(uri, {});

    print("=== DRIVER API RESPONSE ===");
    print("Method: POST");
    print("URL: $uri");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Reject incoming booking
  Future<Response> rejectBooking(
    String bookingId, {
    String? requestId,
    String? offerId,
    String? reason,
  }) async {
    final targetId = requestId ?? offerId ?? bookingId;
    final uri = ApiConstants.rejectBooking(bookingId);
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'requestId': targetId,
      'offerId': targetId,
      'reasonCode': reason ?? 'DRIVER_MANUAL_REJECT',
      'reason': reason ?? 'Driver rejected the request',
    };
    print('=== REJECT RIDE START ===');
    print('bookingId: $bookingId');
    print('requestId: $targetId');
    print('offerId: $targetId');
    print('endpoint: ${ApiConstants.baseUrl}$uri');
    print('payload: $payload');

    final response = await _api.postData(uri, payload);

    print('response status: ${response.statusCode}');
    print('response body: ${response.body}');
    if (isSuccess(response)) {
      print('=== REJECT RIDE SUCCESS ===');
    } else {
      print('=== REJECT RIDE ERROR ===');
    }

    return response;
  }

  /// Mark arrived at pickup location
  Future<Response> arriveAtPickup(String bookingId) async {
    final uri = ApiConstants.arriveBooking(bookingId);
    print("=== DRIVER API REQUEST ===");
    print("Method: POST");
    print("URL: ${ApiConstants.baseUrl}$uri");

    final response = await _api.postData(uri, {});

    print("=== DRIVER API RESPONSE ===");
    print("Method: POST");
    print("URL: $uri");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Start trip with customer OTP
  Future<Response> startTrip(String bookingId, String otp) async {
    final uri = ApiConstants.startBooking(bookingId);
    print("=== DRIVER API REQUEST ===");
    print("Method: POST");
    print("URL: ${ApiConstants.baseUrl}$uri");
    print("Payload: { otp: $otp }");

    final response = await _api.postData(uri, {
      'otp': otp,
    });

    print("=== DRIVER API RESPONSE ===");
    print("Method: POST");
    print("URL: $uri");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Complete trip (Drop-off)
  Future<Response> completeTrip(String bookingId) async {
    final uri = ApiConstants.completeBooking(bookingId);
    print("=== DRIVER API REQUEST ===");
    print("Method: POST");
    print("URL: ${ApiConstants.baseUrl}$uri");

    final response = await _api.postData(uri, {});

    print("=== DRIVER API RESPONSE ===");
    print("Method: POST");
    print("URL: $uri");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Confirm cash payment from customer
  Future<Response> confirmCashPayment(
    String bookingId, {
    String? idempotencyKey,
  }) async {
    final uri = ApiConstants.confirmCashPayment(bookingId);
    print("=== DRIVER API REQUEST ===");
    print("Method: POST");
    print("URL: ${ApiConstants.baseUrl}$uri");

    final response = await _api.postData(
      uri,
      {},
      headers: idempotencyKey == null || idempotencyKey.isEmpty
          ? null
          : {'x-idempotency-key': idempotencyKey},
    );

    print("=== DRIVER API RESPONSE ===");
    print("Method: POST");
    print("URL: $uri");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Fetch single booking details by booking ID
  Future<Response> getBookingDetails(String bookingId) async {
    final uri = '/v1/driver/bookings/$bookingId';
    print("=== DRIVER API REQUEST (GET BOOKING DETAILS) ===");
    print("Method: GET");
    print("URL: ${ApiConstants.baseUrl}$uri");

    final response = await _api.getData(uri);

    print("=== DRIVER API RESPONSE ===");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  bool isSuccess(Response response) =>
      response.statusCode != null &&
      response.statusCode! >= 200 &&
      response.statusCode! < 300 &&
      response.body is Map &&
      response.body['success'] != false;
}
