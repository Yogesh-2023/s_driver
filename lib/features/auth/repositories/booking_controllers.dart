import 'package:get/get.dart';

import '../../../data/api/api_client.dart';
import '../../../data/api/api_constants.dart';
import '../controllers/auth_controller.dart';
import 'booking_history_model.dart';

class BookingHistoryController extends GetxController {
  final isLoading = false.obs;
  final selectedTab = "All".obs;
  final allBookings = <BookingHistoryModel>[].obs;
  final filteredList = <BookingHistoryModel>[].obs;

  final ApiClient _apiClient = Get.find<ApiClient>();
  Worker? _verificationWorker;
  Worker? _onboardingWorker;
  bool _isFetching = false;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      _verificationWorker = ever(
        authController.verificationStatus,
        (_) => _syncBookingsWithKyc(authController),
      );
      _onboardingWorker = ever(
        authController.onboardingStatus,
        (_) => _syncBookingsWithKyc(authController),
      );
      _syncBookingsWithKyc(authController);
    } else {
      allBookings.clear();
      applyFilter(selectedTab.value);
    }
  }

  @override
  void onClose() {
    _verificationWorker?.dispose();
    _onboardingWorker?.dispose();
    super.onClose();
  }

  void _syncBookingsWithKyc(AuthController authController) {
    authController.enforceKycRideAccess();
    if (!authController.isRideAccessEnabled) {
      allBookings.clear();
      filteredList.clear();
      isLoading.value = false;
      return;
    }
    fetchBookings();
  }

  Future<void> fetchBookings({
    int page = 1,
    int limit = 20,
    String? status,
    String order = 'desc',
    String? dateFrom,
    String? dateTo,
    String? search,
    String? vehicleCategoryId,
  }) async {
    if (_isFetching) return;
    isLoading.value = true;
    _isFetching = true;
    try {
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        await authController.checkProfileStatus();
        if (!authController.isRideAccessEnabled) {
          authController.enforceKycRideAccess();
          allBookings.clear();
          filteredList.clear();
          return;
        }
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'order': order,
        if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL')
          'status': status.toUpperCase(),
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        if (search != null && search.isNotEmpty) 'search': search,
        if (vehicleCategoryId != null && vehicleCategoryId.isNotEmpty)
          'vehicleCategoryId': vehicleCategoryId,
      };

      final responses = await Future.wait([
        _apiClient.getData(ApiConstants.tripHistory, query: queryParams),
        _apiClient.getData(ApiConstants.ongoingTrips),
        _apiClient.getData(ApiConstants.goodsBookings),
      ]);

      final rawBookings = <dynamic>[];
      if (responses[0].isOk) {
        rawBookings.addAll(_extractList(responses[0].body));
      }
      if (responses[1].isOk) {
        rawBookings.addAll(_extractList(responses[1].body));
      }
      if (responses[2].isOk) {
        rawBookings.addAll(_extractGoodsBookings(responses[2].body));
      }

      final uniqueBookings = <String, BookingHistoryModel>{};
      for (final item in rawBookings) {
        final booking = BookingHistoryModel.fromJson(item);
        final key = booking.id ?? booking.bookingId;
        if (key == null || key.isEmpty) continue;
        uniqueBookings[key] = booking;
      }

      final bookings = uniqueBookings.values.toList()
        ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

      allBookings.assignAll(bookings);
      applyFilter(selectedTab.value);
    } catch (e) {
      if (allBookings.isEmpty) allBookings.clear();
      applyFilter(selectedTab.value);
    } finally {
      isLoading.value = false;
      _isFetching = false;
    }
  }

  void applyFilter(String tab) {
    selectedTab.value = tab;
    final normalizedTab = tab.toUpperCase();
    if (normalizedTab == "ALL") {
      filteredList.assignAll(allBookings);
      return;
    }

    filteredList.assignAll(
      allBookings.where((booking) {
        final status = booking.status?.toUpperCase() ?? '';
        if (normalizedTab == "COMPLETED") {
          return status == "COMPLETED";
        }
        if (normalizedTab == "CANCELLED" || normalizedTab == "DECLINED") {
          return status == "DECLINED" ||
              status == "REJECTED" ||
              status == "CANCELLED" ||
              status == "EXPIRED";
        }
        if (normalizedTab == "UPCOMING") {
          return status == "UPCOMING" ||
              status == "RESCHEDULE" ||
              status == "PENDING" ||
              status == "ACCEPTED" ||
              status == "ONGOING";
        }
        return status == normalizedTab;
      }),
    );
  }
}

List<dynamic> _extractGoodsBookings(dynamic body) {
  if (body is! Map) return const [];
  final data = body['data'];
  if (data is! Map) return _extractList(body);

  final result = <dynamic>[];
  final active = data['activeBooking'];
  if (active is Map) result.add(active);
  final nearby = data['nearbyBookings'];
  if (nearby is List) result.addAll(nearby);
  return result;
}

class BookingDetailsController extends GetxController {
  final isLoading = false.obs;
  final bookingDetails = Rxn<BookingHistoryModel>();

  final ApiClient _apiClient = Get.find<ApiClient>();

  Future<void> fetchBookingDetails(String bookingId) async {
    isLoading.value = true;
    try {
      final detailResponse =
          await _apiClient.getData('/v1/driver/bookings/$bookingId');
      if (detailResponse.isOk) {
        final detailData = _extractMap(detailResponse.body);
        if (detailData != null) {
          bookingDetails.value = BookingHistoryModel.fromJson(detailData);
          return;
        }
      }

      final response = await _apiClient.getData(ApiConstants.tripHistory);
      if (response.isOk) {
        final bookings = _extractList(
          response.body,
        ).map((item) => BookingHistoryModel.fromJson(item)).toList();
        bookingDetails.value = bookings.firstWhereOrNull(
          (booking) =>
              booking.id == bookingId || booking.bookingId == bookingId,
        );
      } else {
        bookingDetails.value = null;
      }
    } catch (e) {
      bookingDetails.value = null;
    } finally {
      isLoading.value = false;
    }
  }
}

List<dynamic> _extractList(dynamic body) {
  if (body is List) return body;
  if (body is! Map) return const [];

  for (final key in const [
    'data',
    'bookings',
    'bookingHistory',
    'trips',
    'rides',
    'history',
    'orders',
  ]) {
    final value = body[key];
    if (value is List) return value;
    if (value is Map) {
      final nested = _extractList(value);
      if (nested.isNotEmpty) return nested;
    }
  }

  return const [];
}

Map<String, dynamic>? _extractMap(dynamic body) {
  if (body is Map) {
    final data = body['data'];
    if (data is Map) {
      final nested = _extractMap(data);
      if (nested != null) return nested;
    }
    final booking = body['booking'];
    if (booking is Map) return Map<String, dynamic>.from(booking);
    final trip = body['trip'];
    if (trip is Map) return Map<String, dynamic>.from(trip);
    final ride = body['ride'];
    if (ride is Map) return Map<String, dynamic>.from(ride);
    return Map<String, dynamic>.from(body);
  }
  return null;
}
