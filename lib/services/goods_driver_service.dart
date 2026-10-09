import 'package:get/get.dart';

import '../data/api/api_client.dart';
import '../data/api/api_constants.dart';

class GoodsDriverService {
  ApiClient get _api => Get.find<ApiClient>();

  Future<Response> getBookings() => _api.getData(ApiConstants.goodsBookings);

  Future<Response> accept(
    String bookingId, {
    String? requestId,
    String? offerId,
    String? dispatchVersion,
  }) {
    final targetId = requestId ?? offerId ?? bookingId;
    final endpoint = ApiConstants.acceptGoodsBooking(bookingId);
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'requestId': targetId,
      'offerId': targetId,
      if (dispatchVersion != null) 'dispatchVersion': dispatchVersion,
    };
    print('=== ACCEPT RIDE DEBUG ===');
    print('bookingId: $bookingId');
    print('requestId: $targetId');
    print('endpoint: $endpoint');
    print('payload: $payload');
    return _api.postData(endpoint, payload);
  }

  Future<Response> reject(
    String bookingId, {
    String? requestId,
    String? offerId,
    String? reason,
  }) async {
    final targetId = requestId ?? offerId ?? bookingId;
    final endpoint = ApiConstants.rejectGoodsBooking(bookingId);
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
    print('endpoint: ${ApiConstants.baseUrl}$endpoint');
    print('payload: $payload');

    final response = await _api.postData(endpoint, payload);

    print('response status: ${response.statusCode}');
    print('response body: ${response.body}');
    if (succeeded(response)) {
      print('=== REJECT RIDE SUCCESS ===');
    } else {
      print('=== REJECT RIDE ERROR ===');
    }
    return response;
  }

  Future<Response> arrived(String bookingId) =>
      _api.patchData(ApiConstants.arriveGoodsPickup(bookingId), {});

  Future<Response> verifyPickupOtp(String bookingId, String otp) =>
      _api.postData(ApiConstants.verifyGoodsPickupOtp(bookingId), {'otp': otp});

  Future<Response> verifyGoodsPickupOtp(String bookingId, String otp) =>
      verifyPickupOtp(bookingId, otp);

  Future<Response> start(String bookingId) =>
      _api.patchData(ApiConstants.startGoodsTrip(bookingId), {});

  Future<Response> reachedDestination(String bookingId) =>
      _api.patchData(ApiConstants.reachGoodsDestination(bookingId), {});

  Future<Response> complete(
    String bookingId, {
    required String otp,
    String paymentType = 'CASH',
    double? amount,
  }) => _api.postData(ApiConstants.completeGoodsBooking(bookingId), {
    'otp': otp,
    'paymentType': paymentType,
    if (amount != null) 'amount': amount,
  });

  bool succeeded(Response response) =>
      response.statusCode != null &&
      response.statusCode! >= 200 &&
      response.statusCode! < 300 &&
      response.body is Map &&
      response.body['success'] != false;

  String errorMessage(Response response, [String fallback = 'Action failed']) {
    if (response.body is Map && response.body['message'] != null) {
      return response.body['message'].toString();
    }
    return response.statusText ?? fallback;
  }
}
