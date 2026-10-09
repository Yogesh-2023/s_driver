import 'package:get/get.dart';
import '../data/api/api_client.dart';
import '../data/api/api_constants.dart';

class RideService extends GetxService {
  final ApiClient _apiClient = Get.find<ApiClient>();

  Future<bool> acceptRide(String tripId) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.acceptRide,
        {'tripId': tripId},
      );
      // Wait, is it /rides/accept or /driver/accept?
      // I will also fallback to /driver/accept if the user meant that.
      // Or we just send to ApiConstants.acceptRide
      return response.isOk;
    } catch (e) {
      print('=== ACCEPT RIDE ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> rejectRide(String tripId) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.rejectRide,
        {'tripId': tripId},
      );
      return response.isOk;
    } catch (e) {
      print('=== REJECT RIDE ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> arriveAtPickup(String tripId) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.arrivePickup,
        {'tripId': tripId},
      );
      return response.isOk;
    } catch (e) {
      print('=== ARRIVE PICKUP ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> startRide(String tripId, String otp) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.startRide,
        {'tripId': tripId, 'otp': otp},
      );
      return response.isOk;
    } catch (e) {
      print('=== START RIDE ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> completeRide(String tripId) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.completeRide,
        {'tripId': tripId},
      );
      return response.isOk;
    } catch (e) {
      print('=== COMPLETE RIDE ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> verifyPickupOtp(String bookingId, String otp) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.verifyPickupOtp(bookingId),
        {'otp': otp},
      );
      return response.isOk;
    } catch (e) {
      print('=== VERIFY PICKUP OTP ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> cancelRide(String tripId, String reason) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.cancelBooking(tripId),
        {'reason': reason},
      );
      return response.isOk;
    } catch (e) {
      print('=== CANCEL RIDE ERROR ===\n$e');
      return false;
    }
  }

  Future<bool> submitReview(String tripId, int rating, String? comment) async {
    try {
      final response = await _apiClient.postData(
        ApiConstants.submitDriverReview,
        {
          'bookingId': tripId,
          'rating': rating,
          'comment': comment ?? '',
        },
      );
      return response.isOk;
    } catch (e) {
      print('=== SUBMIT REVIEW ERROR ===\n$e');
      return false;
    }
  }
}
