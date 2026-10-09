import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../services/socket/socket_service.dart';
import '../../services/socket/socket_events.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_constants.dart';
import '../../services/location_tracking_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/documents_upload_step_screen.dart';
import '../documents/document_upload_screen.dart';
import '../documents/document_detail_screen.dart';
import '../documents/controllers/document_controller.dart';
import '../documents/repositories/document_repository.dart';
import 'new_ride_request_detail_screen.dart';
import 'profile_screen.dart';
import 'earnings_screen.dart';
import 'navigate_to_pickup_screen.dart';
import 'trip_completed_screen.dart';
import 'trip/reached_pickup_screen.dart';
import 'trip/ride_in_progress_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/ride_request_popup_card.dart';
import '../../services/goods_driver_service.dart';
import '../../services/booking_service.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/controllers/notification_controller.dart';
import '../../widgets/notification_bell.dart';
import 'controllers/active_booking_controller.dart';
import '../subscriptions/subscription_plans_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final String? targetBookingId;
  final Map<String, dynamic>? targetPayload;
  final bool isCancelledEvent;

  const DriverHomeScreen({
    super.key,
    this.targetBookingId,
    this.targetPayload,
    this.isCancelledEvent = false,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = true;
  bool _showRequestCard = false;
  bool _isRestoringGoodsAvailability = false;
  bool _isAcceptingGoodsRequest = false;
  bool _isRejectingRide = false;
  String? _lastRestoredGoodsRequestId;
  GoogleMapController? _mapController;
  Timer? _heartbeatTimer;
  Timer? _requestTimer;
  int _remainingSeconds = 30;
  final Map<String, Map<String, dynamic>> _pendingRequests = {};
  final Set<String> _rejectedBookingIds = {};
  final Set<String> _expiredBookingIds = {};
  int _selectedRequestIndex = 0;
  final ScrollController _scrollController = ScrollController();
  Worker? _onlineWorker;
  Worker? _kycAccessWorker;
  Worker? _notificationTapWorker;

  bool get _hasPendingPaymentBooking {
    if (!Get.isRegistered<ActiveBookingController>()) return false;
    final payload = Get.find<ActiveBookingController>().bookingPayload;
    if (payload == null) return false;
    final booking = payload['booking'];
    final source = booking is Map ? booking : payload;
    final status = source['status']?.toString().toUpperCase();
    final paymentStatus =
        (source['paymentStatus'] ??
                source['payment_status'] ??
                (source['payment'] is Map ? source['payment']['status'] : null))
            ?.toString()
            .toUpperCase();
    return status == 'PAYMENT_PENDING' ||
        status == 'AWAITING_PAYMENT' ||
        paymentStatus == 'PENDING' ||
        paymentStatus == 'PAYMENT_PENDING';
  }
  final NotificationController _notificationController = Get.put(
    NotificationController(),
  );

  Map<String, dynamic>? _getActiveRequest() {
    if (_pendingRequests.isEmpty) return null;
    if (_selectedRequestIndex < 0 ||
        _selectedRequestIndex >= _pendingRequests.length) {
      _selectedRequestIndex = _pendingRequests.length - 1;
    }
    if (_selectedRequestIndex < 0) _selectedRequestIndex = 0;
    final list = _pendingRequests.values.toList();
    if (_selectedRequestIndex >= list.length) return null;
    return list[_selectedRequestIndex];
  }

  bool _isSuccessResponse(Response response, {required bool isGoods}) {
    if (isGoods) {
      return GoodsDriverService().succeeded(response);
    }
    return BookingService.to.isSuccess(response);
  }

  String _extractErrorMessage(Response response, {required bool isGoods}) {
    if (isGoods) {
      return GoodsDriverService().errorMessage(response);
    }
    if (response.body is Map && response.body['message'] != null) {
      return response.body['message'].toString();
    }
    return response.statusText ?? 'Action failed (${response.statusCode})';
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    } else {
      setState(fn);
    }
  }

  bool get _hasRideAccess {
    if (!Get.isRegistered<AuthController>()) return false;
    return Get.find<AuthController>().isRideAccessEnabled;
  }

  Future<void> _forceOfflineForKycBlock() async {
    final authCtrl = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    authCtrl?.enforceKycRideAccess();
    if (authCtrl != null && authCtrl.isOnline.value) {
      authCtrl.isOnline.value = false;
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _requestTimer?.cancel();
    _requestTimer = null;
    _pendingRequests.clear();

    _safeSetState(() {
      _isOnline = false;
      _remainingSeconds = 0;
      _showRequestCard = false;
      _currentTripRequest = null;
    });

    try {
      await SocketService.to.goOffline();
    } catch (_) {}
    try {
      await Get.find<ApiClient>().postData(ApiConstants.availabilityOffline, {});
    } catch (_) {}
    LocationTrackingService().stopTracking();
  }

  void _clearRideRequest(String targetId, {String? reason}) {
    print('[YOGESH][RIDE_REQUEST] Clearing ride request with targetId: $targetId, reason: ${reason ?? 'unknown'}');

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    if (targetId.isNotEmpty) {
      _rejectedBookingIds.add(targetId);
      _expiredBookingIds.add(targetId);
    }

    final keysToRemove = <String>[];
    _pendingRequests.forEach((key, req) {
      final bId = req['bookingId']?.toString();
      final rId = req['requestId']?.toString();
      final oId = req['offerId']?.toString();
      final tId = req['tripId']?.toString();
      final id = req['id']?.toString();

      if (key == targetId ||
          bId == targetId ||
          rId == targetId ||
          oId == targetId ||
          tId == targetId ||
          id == targetId) {
        keysToRemove.add(key);
        if (bId != null) {
          _rejectedBookingIds.add(bId);
          _expiredBookingIds.add(bId);
        }
        if (rId != null) {
          _rejectedBookingIds.add(rId);
          _expiredBookingIds.add(rId);
        }
        if (oId != null) {
          _rejectedBookingIds.add(oId);
          _expiredBookingIds.add(oId);
        }
        if (tId != null) {
          _rejectedBookingIds.add(tId);
          _expiredBookingIds.add(tId);
        }
        if (id != null) {
          _rejectedBookingIds.add(id);
          _expiredBookingIds.add(id);
        }
      }
    });

    for (final key in keysToRemove) {
      _pendingRequests.remove(key);
    }

    print('[YOGESH][RIDE_REMOVE] Removed targetId $targetId from pending request queue. Remaining count: ${_pendingRequests.length}');
    print('[YOGESH][RIDE_REJECT] Recorded targetId $targetId into rejected/expired cache set.');

    if (_pendingRequests.isEmpty) {
      _requestTimer?.cancel();
      _requestTimer = null;
      _safeSetState(() {
        _showRequestCard = false;
        _currentTripRequest = null;
        _selectedRequestIndex = 0;
      });
      print('[YOGESH][RIDE_UI] Pending requests queue is now empty. Dismissed ride request card UI.');
    } else {
      if (_selectedRequestIndex >= _pendingRequests.length) {
        _selectedRequestIndex = _pendingRequests.length - 1;
      }
      if (_selectedRequestIndex < 0) _selectedRequestIndex = 0;
      _safeSetState(() {
        _currentTripRequest = _getActiveRequest();
      });
      print('[YOGESH][RIDE_UI] Updated active request card UI. Selected index: $_selectedRequestIndex');
    }
  }

  void _startPeriodicTimer() {
    if (_requestTimer != null && _requestTimer!.isActive) {
      return;
    }
    print('[YOGESH][COUNTDOWN_START] Starting periodic countdown timer...');
    _requestTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _requestTimer = null;
        return;
      }

      final expiredBookingIds = <String>[];
      _pendingRequests.forEach((key, request) {
        final remaining = _remainingRequestSeconds(request);
        print('[YOGESH][COUNTDOWN_TICK] bookingId: $key | remaining: $remaining s');
        if (remaining == null || remaining <= 0) {
          expiredBookingIds.add(key);
        }
      });

      if (expiredBookingIds.isNotEmpty) {
        for (final key in expiredBookingIds) {
          final req = _pendingRequests.remove(key);
          print('[YOGESH][COUNTDOWN_EXPIRED] bookingId: $key expired locally.');
          if (req != null) {
            _expiredBookingIds.add(key);
            final bId = req['bookingId']?.toString() ?? key;
            final rId = req['requestId']?.toString();
            final oId = req['offerId']?.toString();
            final tId = req['tripId']?.toString();
            if (bId.isNotEmpty) _expiredBookingIds.add(bId);
            if (rId != null) _expiredBookingIds.add(rId);
            if (oId != null) _expiredBookingIds.add(oId);
            if (tId != null) _expiredBookingIds.add(tId);

            if (Get.isRegistered<NotificationController>()) {
              NotificationController.to.addLocalNotification(
                title: 'Ride Missed',
                body: 'You missed a ride request.',
                type: 'RIDE_MISSED',
                bookingId: bId,
                extraData: {
                  'pickup': req['pickupAddress'],
                  'drop': req['dropAddress'],
                  'fare': req['fare'],
                },
              );
            }
          }
          final requestId = req?['tripId'] ?? req?['bookingId'] ?? req?['requestId'];
          if (requestId != null) {
            unawaited(_releasePendingGoodsRequest({'bookingId': requestId}));
          }
        }
      }

      if (_pendingRequests.isEmpty) {
        timer.cancel();
        _requestTimer = null;
        _safeSetState(() {
          _showRequestCard = false;
          _currentTripRequest = null;
          _selectedRequestIndex = 0;
        });
        print('[YOGESH][COUNTDOWN_STOP] Queue empty, timer stopped.');
        return;
      }

      _currentTripRequest = _getActiveRequest();
      _safeSetState(() {});
    });
  }

  // Hardcoded to match user's pickup test location to be within dispatch radius
  final LatLng _pickupLatLng = LatLng(28.6294375, 77.3467344);
  final LatLng _dropLatLng = LatLng(28.5244, 77.2173);
  final LatLng _carLatLng = LatLng(28.5760, 77.2997); // Intermediate point

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Map<String, dynamic>? _currentTripRequest;

  DateTime? _parseExpiry(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is num) {
      // APIs commonly send Unix timestamps in either seconds or milliseconds.
      final milliseconds = value.abs() < 100000000000
          ? (value * 1000).round()
          : value.round();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final numeric = num.tryParse(text);
    if (numeric != null) return _parseExpiry(numeric);
    return DateTime.tryParse(text)?.toUtc();
  }

  DateTime? _requestExpiry(Map<String, dynamic> request) {
    if (request['_expiryTime'] is DateTime) {
      return request['_expiryTime'] as DateTime;
    }

    final nowUtc = DateTime.now().toUtc();
    final booking = request['booking'];
    final expiry =
        request['expiresAt'] ??
        request['expires_at'] ??
        request['offerExpiresAt'] ??
        request['requestExpiresAt'] ??
        (booking is Map
            ? booking['expiresAt'] ??
                  booking['expires_at'] ??
                  booking['offerExpiresAt'] ??
                  booking['requestExpiresAt']
            : null);
    final parsedExpiry = _parseExpiry(expiry);
    if (parsedExpiry != null) {
      final diffSeconds = parsedExpiry.difference(nowUtc).inSeconds;
      if (diffSeconds > 0 && diffSeconds <= 60) {
        request['_expiryTime'] = parsedExpiry;
        return parsedExpiry;
      }
    }

    final createdAtRaw = request['createdAt'] ??
        request['created_at'] ??
        (booking is Map ? booking['createdAt'] ?? booking['created_at'] : null);
    final parsedCreatedAt = _parseExpiry(createdAtRaw);
    if (parsedCreatedAt != null) {
      final calculatedFromCreated = parsedCreatedAt.add(const Duration(seconds: 60));
      request['_expiryTime'] = calculatedFromCreated;
      return calculatedFromCreated;
    }

    final receivedAt = request['_receivedTime'] as DateTime? ?? nowUtc;
    final calculatedExpiry = receivedAt.add(const Duration(seconds: 60));
    request['_expiryTime'] = calculatedExpiry;
    return calculatedExpiry;
  }

  int? _remainingRequestSeconds(Map<String, dynamic> request) {
    final expiry = _requestExpiry(request);
    if (expiry == null) return 0;
    final nowUtc = DateTime.now().toUtc();
    final remainingMs = expiry.difference(nowUtc).inMilliseconds;
    if (remainingMs <= 0) return 0;
    final remainingSec = (remainingMs / 1000).ceil();
    if (remainingSec <= 0) return 0;
    return remainingSec > 60 ? 60 : remainingSec;
  }

  Map<String, dynamic> _normalizeTripRequest(dynamic data) {
    dynamic rawData = data;
    if (rawData is List && rawData.isNotEmpty) {
      rawData = rawData.first;
    }
    if (rawData is Map && rawData.containsKey('data') && rawData['data'] is Map) {
      rawData = rawData['data'];
    }
    final raw = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final trip = raw['trip'] is Map
        ? Map<String, dynamic>.from(raw['trip'])
        : raw['booking'] is Map
        ? Map<String, dynamic>.from(raw['booking'])
        : raw;
    final pickupSource = trip['pickup'] ?? trip['pickupLocation'];
    final dropSource = trip['drop'] ?? trip['dropLocation'];
    final pickup = pickupSource is Map
        ? Map<String, dynamic>.from(pickupSource)
        : <String, dynamic>{};
    final drop = dropSource is Map
        ? Map<String, dynamic>.from(dropSource)
        : <String, dynamic>{};
    final customerSource =
        trip['customer'] ??
        trip['user'] ??
        trip['rider'] ??
        raw['customer'] ??
        raw['user'];
    final customer = customerSource is Map
        ? Map<String, dynamic>.from(customerSource)
        : <String, dynamic>{};
    final profileSource =
        customer['profile'] ??
        customer['userProfile'] ??
        customer['customerProfile'];
    final customerProfile = profileSource is Map
        ? Map<String, dynamic>.from(profileSource)
        : <String, dynamic>{};
    final profileName = [
      customerProfile['firstname'],
      customerProfile['lastname'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).join(' ');
    final rawDistance =
        raw['distanceKm'] ??
        raw['distance'] ??
        trip['distanceKm'] ??
        trip['distance'] ??
        trip['driverDistanceKm'];
    final distance = rawDistance?.toString().replaceAll(
      RegExp(r'\s*km\s*$', caseSensitive: false),
      '',
    );

    return <String, dynamic>{
      ...raw,
      ...trip,
      'bookingId':
          raw['bookingId'] ??
          raw['goodsBookingId'] ??
          trip['bookingId'] ??
          trip['id'] ??
          trip['tripId'],
      'requestId': raw['requestId'] ?? trip['requestId'],
      'tripId':
          raw['bookingId'] ??
          raw['goodsBookingId'] ??
          trip['bookingId'] ??
          trip['id'] ??
          raw['tripId'] ??
          trip['tripId'] ??
          raw['requestId'],
      'customerName':
          raw['customerName'] ??
          trip['customerName'] ??
          customer['displayName'] ??
          customer['name'] ??
          (profileName.isNotEmpty ? profileName : null) ??
          'Customer',
      'customerPhone':
          raw['customerPhone'] ?? trip['customerPhone'] ?? customer['phone'],
      'senderName':
          raw['senderName'] ??
          trip['senderName'] ??
          trip['sender']?['name'] ??
          customer['name'],
      'senderPhone':
          raw['senderPhone'] ??
          trip['senderPhone'] ??
          trip['sender']?['phone'] ??
          customer['phone'],
      'receiverName':
          raw['receiverName'] ??
          trip['receiverName'] ??
          trip['receiver']?['name'],
      'receiverPhone':
          raw['receiverPhone'] ??
          trip['receiverPhone'] ??
          trip['receiver']?['phone'],
      'customerImage':
          raw['customerImage'] ??
          trip['customerImage'] ??
          customerProfile['profileImageUrl'] ??
          customerProfile['profileImage'] ??
          customerProfile['profilePhoto'] ??
          customerProfile['profilePicture'] ??
          customerProfile['avatar'] ??
          customer['avatar'] ??
          customer['profileImage'] ??
          customer['profileImageUrl'] ??
          customer['profilePhoto'] ??
          customer['profilePicture'] ??
          customer['imageUrl'] ??
          customer['image'],
      'customerRating':
          raw['customerRating'] ?? trip['customerRating'] ?? customer['rating'],
      'pickupAddress':
          raw['pickupAddress'] ??
          pickup['address'] ??
          pickup['formattedAddress'] ??
          trip['pickupAddress'] ??
          'Pickup Location',
      'dropAddress':
          raw['dropAddress'] ??
          drop['address'] ??
          drop['formattedAddress'] ??
          trip['dropAddress'] ??
          'Destination',
      'pickupLatitude':
          raw['pickupLatitude'] ??
          pickup['latitude'] ??
          pickup['lat'] ??
          trip['pickupLat'],
      'pickupLongitude':
          raw['pickupLongitude'] ??
          pickup['longitude'] ??
          pickup['lng'] ??
          trip['pickupLng'],
      'dropLatitude':
          raw['dropLatitude'] ??
          drop['latitude'] ??
          drop['lat'] ??
          trip['dropLat'],
      'dropLongitude':
          raw['dropLongitude'] ??
          drop['longitude'] ??
          drop['lng'] ??
          trip['dropLng'],
      'fare':
          raw['fare'] ??
          raw['totalFare'] ??
          raw['estimatedFare'] ??
          raw['finalFare'] ??
          trip['totalFare'] ??
          trip['estimatedFare'] ??
          trip['finalFare'],
      'distance': distance,
      'distanceKm': distance,
      'estimatedDurationMin':
          raw['estimatedDurationMin'] ??
          raw['etaMinutes'] ??
          raw['reachBy'] ??
          raw['duration'] ??
          trip['estimatedDurationMin'] ??
          trip['etaMinutes'] ??
          trip['reachBy'] ??
          trip['duration'],
      'paymentMethod':
          raw['paymentMethod'] ??
          trip['paymentMethod'] ??
          trip['paymentType'] ??
          'CASH',
      'carType': raw['carType'] ?? trip['carType'] ?? trip['vehicleType'],
      'vehicle': raw['vehicle'] ?? trip['vehicle'],
      'driverPayout': raw['driverPayout'] ?? trip['driverPayout'],
      'requestTimeoutSeconds':
          raw['requestTimeoutSeconds'] ?? trip['requestTimeoutSeconds'],
      'requestedAt': raw['requestedAt'] ?? trip['requestedAt'],
      'expiresAt': raw['expiresAt'] ?? trip['expiresAt'],
      'dispatchVersion': raw['dispatchVersion'] ?? trip['dispatchVersion'],
      'moduleType': raw['moduleType'] ?? trip['moduleType'] ?? 'GOODS',
      'isGoods': raw['isGoods'] ?? trip['isGoods'] ?? false,
      'booking': trip, // preserve full booking
    };
  }

  @override
  void initState() {
    super.initState();

    if (Get.isRegistered<AuthController>()) {
      final authCtrl = Get.find<AuthController>();
      authCtrl.enforceKycRideAccess();
      _isOnline = authCtrl.isRideAccessEnabled && authCtrl.isOnline.value;
      _onlineWorker = ever(authCtrl.isOnline, (bool online) {
        if (mounted && _isOnline != online) {
          setState(() {
            _isOnline = authCtrl.isRideAccessEnabled && online;
          });
        }
      });
      _kycAccessWorker = everAll(
        [authCtrl.verificationStatus, authCtrl.onboardingStatus],
        (_) {
          if (!authCtrl.isRideAccessEnabled) {
            _forceOfflineForKycBlock();
          } else if (mounted) {
            setState(() {});
            _setupSocketListeners();
            _startHeartbeat();
          }
        },
      );
    }

    if (!Get.isRegistered<DocumentRepository>()) {
      Get.put(DocumentRepository(apiClient: Get.find<ApiClient>()));
    }
    if (!Get.isRegistered<DocumentController>()) {
      Get.put(DocumentController(documentRepository: Get.find<DocumentRepository>()));
    } else {
      Get.find<DocumentController>().fetchKycStatus();
    }

    _initMapItems();

    /* BACKEND_API & SOCKET CALLS - UNCOMMENT TO CONNECT TO BACKEND SERVER */
    Future.microtask(() async {
      await Get.find<AuthController>().checkProfileStatus();
      if (_hasRideAccess) {
        await _resumeOngoingTrip();
      } else {
        await _forceOfflineForKycBlock();
      }
    });
    _setupSocketListeners();
    _startHeartbeat();
    _initLocationTracking();

    if (widget.targetBookingId != null && widget.targetBookingId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.isCancelledEvent) {
          _clearRideRequest(widget.targetBookingId!, reason: 'user_cancelled');
          CustomSnackbar.showError(message: 'The passenger has cancelled this ride.');
        } else if (_hasRideAccess) {
          fetchAndHandleNotificationBooking(
            widget.targetBookingId!,
            extraPayload: widget.targetPayload,
          );
        }
      });
    }

    if (Get.isRegistered<NotificationController>()) {
      _notificationTapWorker = ever(
        NotificationController.to.selectedNotificationTap,
        (Map<String, dynamic> tapData) {
          if (!mounted) return;
          final type = tapData['type']?.toString().toUpperCase();
          final bookingId = tapData['bookingId']?.toString();
          final data = tapData['data'] is Map ? Map<String, dynamic>.from(tapData['data']) : null;

          if (type == 'NEW_RIDE_REQUEST' ||
              type == 'RIDE_REQUEST' ||
              type == 'DISPATCH_OFFER' ||
              type == 'GOODS_REQUEST') {
            if (bookingId != null && bookingId.isNotEmpty) {
              if (!_hasRideAccess) return;
              fetchAndHandleNotificationBooking(bookingId, extraPayload: data);
            }
          } else if (type == 'RIDE_CANCELLED' ||
              type == 'BOOKING_CANCELLED' ||
              type == 'USER_CANCELLED') {
            if (bookingId != null && bookingId.isNotEmpty) {
              _clearRideRequest(bookingId, reason: 'user_cancelled');
              CustomSnackbar.showError(message: 'The passenger has cancelled this ride.');
            }
          }
        },
      );
    }
  }

  Future<void> _initLocationTracking() async {
    await Permission.notification.request();
    await Permission.location.request();
    await Permission.locationAlways.request();
    await LocationTrackingService().initializeService();
  }

  Future<void> _checkOngoingTrip() async {
    try {
      if (!_hasRideAccess) return;
      final apiClient = Get.find<ApiClient>();
      final response = await apiClient.getData(ApiConstants.ongoingTrips);
      if (response.statusCode == 200 && response.body != null) {
        final data = response.body;
        if (data['success'] == true && data['data'] != null) {
          dynamic rawBooking;
          if (data['data'] is Map) {
            rawBooking = data['data'];
          } else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
            rawBooking = (data['data'] as List).first;
          }

          if (rawBooking != null && rawBooking is Map) {
            final requestData = _normalizeTripRequest(rawBooking);
            final status = rawBooking['status']?.toString().toUpperCase();
            final paymentStatus =
                (rawBooking['paymentStatus'] ??
                        rawBooking['payment_status'] ??
                        rawBooking['payment']?['status'])
                    ?.toString()
                    .toUpperCase();

            if (paymentStatus == 'PENDING' ||
                paymentStatus == 'PAYMENT_PENDING' ||
                status == 'PAYMENT_PENDING' ||
                status == 'AWAITING_PAYMENT') {
              if (mounted) {
                Get.off(() => TripCompletedScreen(requestData: requestData));
              }
            } else if (status == 'DRIVER_ASSIGNED' ||
                status == 'ACCEPTED' ||
                status == 'ACCEPTED_RIDE' ||
                status == 'ON_THE_WAY' ||
                status == 'DRIVER_ARRIVING' ||
                status == 'SEARCHING_DRIVER') {
              if (mounted) {
                Get.off(() => NavigateToPickupScreen(requestData: requestData));
              }
            } else if (status == 'DRIVER_ARRIVED' || status == 'AT_PICKUP' || status == 'ARRIVED') {
              if (mounted) {
                Get.off(() => ReachedPickupScreen(requestData: requestData));
              }
            } else if (status == 'PICKED_UP' ||
                status == 'IN_TRANSIT' ||
                status == 'TRIP_STARTED' ||
                status == 'IN_PROGRESS' ||
                status == 'STARTED') {
              if (mounted) {
                Get.off(() => RideInProgressScreen(requestData: requestData));
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking ongoing trip: $e');
    }
  }

  Future<void> _resumeOngoingTrip() async {
    if (!_hasRideAccess) return;
    final resumedGoods = await _checkOngoingGoodsTrip();
    if (!resumedGoods) await _checkOngoingTrip();
  }

  Future<bool> _checkOngoingGoodsTrip() async {
    try {
      if (!_hasRideAccess) return false;
      final service = GoodsDriverService();
      final response = await service.getBookings();
      if (!service.succeeded(response) || response.body is! Map) return false;

      final data = response.body['data'];
      final active = data is Map ? data['activeBooking'] : null;
      if (active is! Map) return false;

      final requestData = _normalizeTripRequest({
        'booking': Map<String, dynamic>.from(active),
        'isGoods': true,
      });
      final status = active['status']?.toString().toUpperCase();
      final paymentStatus =
          (active['paymentStatus'] ??
                  active['payment_status'] ??
                  active['payment']?['status'])
              ?.toString()
              .toUpperCase();
      if (!mounted) return false;
      if (paymentStatus == 'PENDING' ||
          paymentStatus == 'PAYMENT_PENDING' ||
          status == 'PAYMENT_PENDING' ||
          status == 'AWAITING_PAYMENT') {
        Get.off(() => TripCompletedScreen(requestData: requestData));
      } else if (status == 'DRIVER_ASSIGNED' || status == 'ACCEPTED' || status == 'ACCEPTED_RIDE' || status == 'ON_THE_WAY') {
        Get.off(() => NavigateToPickupScreen(requestData: requestData));
      } else if (status == 'AT_PICKUP' || status == 'GOODS_PICKED_UP' || status == 'DRIVER_ARRIVED' || status == 'ARRIVED') {
        Get.off(() => ReachedPickupScreen(requestData: requestData));
      } else if (status == 'IN_TRANSIT' || status == 'ARRIVED_DESTINATION' || status == 'TRIP_STARTED' || status == 'IN_PROGRESS' || status == 'STARTED') {
        Get.off(() => RideInProgressScreen(requestData: requestData));
      } else {
        return false;
      }
      return true;
    } catch (e) {
      print('Error checking ongoing goods booking: $e');
      return false;
    }
  }

  void _startHeartbeat() {
    if (!_hasRideAccess) return;
    _sendHeartbeatData(); // Send immediately once
    // Then send periodically every 5 seconds when driver is online
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasRideAccess && _isOnline && mounted) {
        _sendHeartbeatData();
      }
    });
  }

  Future<bool> _sendHeartbeatData() async {
    try {
      if (!_hasRideAccess) return false;
      if (!SocketService.to.isConnected) {
        await SocketService.to.ensureConnected();
      }
      if (SocketService.to.isConnected) {
        final ack = await SocketService.to.sendHeartbeat();
        print('[YOGESH][SOCKET][DRIVER] Heartbeat ACK Response: $ack');
        if (_hasRideAccess && _isOnline) {
          await LocationTrackingService().sendFreshLocationUpdate();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('--- [SOCKET_IO] Heartbeat check exception: $e ---');
      return false;
    }
  }

  String? _requestIdFrom(dynamic data) {
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return null;
    final booking = payload['booking'];
    return (payload['bookingId'] ??
            payload['goodsBookingId'] ??
            payload['tripId'] ??
            payload['requestId'] ??
            payload['offerId'] ??
            payload['id'] ??
            (booking is Map ? booking['id'] : null))
        ?.toString();
  }

  Future<void> _releasePendingGoodsRequest(
    dynamic data, {
    bool showCancelledMessage = false,
  }) async {
    if (!mounted || _isAcceptingGoodsRequest) {
      return;
    }

    final targetId = _requestIdFrom(data) ??
        (_currentTripRequest?['tripId'] ??
                _currentTripRequest?['bookingId'] ??
                _currentTripRequest?['requestId'] ??
                _currentTripRequest?['booking']?['id'])
            ?.toString();

    print('[YOGESH][RIDE_REMOVE] Releasing pending request data: $data, targetId: $targetId');

    if (targetId != null && targetId.isNotEmpty) {
      _clearRideRequest(targetId, reason: 'release_pending_request');
    } else {
      _requestTimer?.cancel();
      _requestTimer = null;
      setState(() {
        _remainingSeconds = 0;
        _showRequestCard = false;
        _currentTripRequest = null;
      });
    }

    if (showCancelledMessage) {
      CustomSnackbar.showError(
        message: 'The booking was cancelled.',
      );
    }

    final recoveryId = targetId;
    if (!_hasRideAccess ||
        !_isOnline ||
        _isRestoringGoodsAvailability ||
        (recoveryId != null && recoveryId == _lastRestoredGoodsRequestId)) {
      return;
    }

    _isRestoringGoodsAvailability = true;
    final restored = await _sendHeartbeatData();
    if (restored && mounted) {
      _lastRestoredGoodsRequestId = recoveryId;
      setState(() => _isOnline = true);
      print(
        '--- Pending request released; driver is available again. ---',
      );
    }
    _isRestoringGoodsAvailability = false;
  }

  void _handleIncomingTripRequest(dynamic data, {bool isGoods = false}) {
    try {
      print('[YOGESH][SOCKET][DRIVER] [RIDE_REQUEST_RECEIVED] Incoming ride request event received.');
      print('[YOGESH][SOCKET][DRIVER] [RIDE_REQUEST_RECEIVED] Raw Payload: $data');
      if (!mounted || !_hasRideAccess || !_isOnline) {
        print('[YOGESH][TRIP][DRIVER] Ignored request because driver is offline, KYC is not approved, or screen unmounted.');
        return;
      }

      final request = _normalizeTripRequest(data);
      if (isGoods) {
        request['isGoods'] = true;
        request['moduleType'] = 'GOODS';
      }

      final bookingId = request['bookingId']?.toString();
      final requestId = request['requestId']?.toString() ?? request['offerId']?.toString() ?? bookingId;
      final offerId = request['offerId']?.toString() ?? requestId;
      final tripId = request['tripId']?.toString() ?? bookingId;

      if (bookingId == null ||
          bookingId.isEmpty ||
          request['pickupAddress'] == null ||
          request['dropAddress'] == null) {
        print(
          '[YOGESH][TRIP][DRIVER] Ignoring invalid request: missing booking/route data',
        );
        return;
      }

      if (_rejectedBookingIds.contains(bookingId) ||
          _expiredBookingIds.contains(bookingId) ||
          (requestId != null &&
              (_rejectedBookingIds.contains(requestId) ||
                  _expiredBookingIds.contains(requestId))) ||
          (offerId != null &&
              (_rejectedBookingIds.contains(offerId) ||
                  _expiredBookingIds.contains(offerId))) ||
          (tripId != null &&
              (_rejectedBookingIds.contains(tripId) ||
                  _expiredBookingIds.contains(tripId)))) {
        print(
          '[YOGESH][TRIP][DRIVER] [STALE_EVENT_IGNORED] Ignoring request $bookingId (already rejected/expired by driver)',
        );
        return;
      }

      if (_pendingRequests.containsKey(bookingId)) {
        print(
          '[YOGESH][TRIP][DRIVER] Request $bookingId already in pending queue. Preserving active countdown.',
        );
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      request['_receivedTime'] = nowUtc;
      _requestExpiry(request);

      final remainingSeconds = _remainingRequestSeconds(request);
      if (remainingSeconds == null || remainingSeconds <= 0) {
        print('[YOGESH][TRIP][DRIVER] Ignoring expired trip request (ID: $bookingId)');
        return;
      }

      final customerName = request['customerName'] ?? request['senderName'] ?? 'Customer';
      final pickup = request['pickupAddress'] ?? '';
      final drop = request['dropAddress'] ?? '';
      final fare = request['fare'] ?? '0';
      _pendingRequests[bookingId] = request;

      if (Get.isRegistered<NotificationController>()) {
        final isScheduledRide = request['isScheduled'] == true ||
            request['bookingType'] == 'SCHEDULED' ||
            request['scheduledAt'] != null;
        NotificationController.to.addLocalNotification(
          title: isScheduledRide ? 'New Scheduled Ride' : 'New Ride Request',
          body: isScheduledRide
              ? 'You have received a new scheduled ride request.'
              : 'You have received a new ride request.',
          type: 'NEW_RIDE_REQUEST',
          bookingId: bookingId,
          extraData: {
            'pickup': pickup,
            'drop': drop,
            'fare': fare,
            'requestId': requestId,
            'offerId': offerId,
            'customerName': customerName,
          },
          showSystemBanner: true,
        );
      }

      final vehicleType = request['vehicleType'] ?? request['vehicleCategory'] ?? request['vehicleCategoryId'] ?? '';
      final serviceType = request['serviceType'] ?? request['bookingType'] ?? 'RIDE';

      print('[YOGESH][TRIP_REQUEST] received');
      print('[YOGESH][TRIP_REQUEST] bookingId= $bookingId');
      print('[YOGESH][TRIP_REQUEST] requestId= $requestId');
      print('[YOGESH][TRIP_REQUEST] vehicleType= $vehicleType');
      print('[YOGESH][TRIP_REQUEST] serviceType= $serviceType');
      print('[YOGESH][TRIP_REQUEST] timer started=60');

      print('[YOGESH][DRIVER_REQUEST] event received');
      print('[YOGESH][DRIVER_REQUEST] bookingId= $bookingId');
      print('[YOGESH][DRIVER_REQUEST] requestId= $requestId');
      print('[YOGESH][DRIVER_REQUEST] vehicleType= $vehicleType');
      print('[YOGESH][DRIVER_REQUEST] UI displayed= true');

      print('[YOGESH][DRIVER_REQUEST_RECEIVED] eventName= dispatch:offer / NEW_TRIP_REQUEST');
      print('[YOGESH][DRIVER_REQUEST_RECEIVED] payload= $request');
      print('''
=== NEW RIDE REQUEST RECEIVED ===
bookingId: $bookingId
requestId: $requestId
user: $customerName
pickup: $pickup
drop: $drop
fare: $fare
pending request count: ${_pendingRequests.length}
=== REQUEST ADDED TO DRIVER QUEUE ===
''');

      final activeList = _pendingRequests.values.toList();
      if (_selectedRequestIndex >= activeList.length) {
        _selectedRequestIndex = activeList.length - 1;
      }
      if (_selectedRequestIndex < 0) _selectedRequestIndex = 0;

      setState(() {
        _currentTripRequest = activeList[_selectedRequestIndex];
        _showRequestCard = true;
      });

      final bool isScheduledRide = request['isScheduled'] == true ||
          request['bookingType'] == 'SCHEDULED' ||
          request['scheduledAt'] != null;
      if (isScheduledRide) {
        print('\n========== SCHEDULED RIDE RECEIVED ==========');
        print('[SCHEDULED][DRIVER][EVENT_RECEIVED] Event received for bookingId: $bookingId');
        print('[SCHEDULED][DRIVER][REQUEST_SHOWN] Displaying offer for bookingId: $bookingId | ScheduledAt: ${request['scheduledAt']}');
        print('=============================================\n');
      }

      _startPeriodicTimer();
    } catch (e, stack) {
      print('[YOGESH][TRIP][DRIVER] Exception parsing trip request payload: $e\n$stack');
    }
  }

  Future<void> _setupSocketListeners() async {
    print('[YOGESH][DRIVER_SOCKET] connected= ${SocketService.to.isConnected}');
    print('[YOGESH][DRIVER_SOCKET] driverId= ${SocketService.to.driverId}');
    print('[YOGESH][DRIVER_SOCKET] online= $_isOnline');
    print('[YOGESH][DRIVER_SOCKET] rideRequestListener registered= true');
    _removeSocketListeners();
    if (!_hasRideAccess) {
      await _forceOfflineForKycBlock();
    }
    await SocketService.to.ensureConnected();

    SocketService.to.onConnectionEstablished = () async {
      print(
        '[YOGESH][DRIVER][STATUS] Socket connected/reconnected. Emitting driver:online...',
      );
      if (_hasRideAccess && _isOnline) {
        await _syncDriverOnlinePresence(source: 'socket_reconnect');
      }
    };

    if (_hasRideAccess && _isOnline) {
      print(
        '[YOGESH][DRIVER][STATUS] Driver is online. Emitting driver:online...',
      );
      await _syncDriverOnlinePresence(source: 'listener_setup');
    }

    // 1. Listen to driver:online:success
    SocketService.to.listenTo(SocketEvents.driverOnlineSuccess, (data) {
      print('[YOGESH][DRIVER][STATUS] Received driver:online:success: $data');
    });

    // 2. Listen to NEW_TRIP_REQUEST
    SocketService.to.listenTo(
      SocketEvents.newTripRequest,
      (data) => _handleIncomingTripRequest(data, isGoods: false),
    );

    SocketService.to.listenTo(
      SocketEvents.goodsBookingRequestSent,
      (data) => _handleIncomingTripRequest(data, isGoods: true),
    );
    SocketService.to.listenTo(
      SocketEvents.goodsBookingRequestSentAlias,
      (data) => _handleIncomingTripRequest(data, isGoods: true),
    );
    SocketService.to.listenTo(
      SocketEvents.goodsRequestNew,
      (data) => _handleIncomingTripRequest(data, isGoods: true),
    );
    SocketService.to.listenTo(
      SocketEvents.dispatchOfferCanonical,
      (data) => _handleIncomingTripRequest(data, isGoods: false),
    );
    SocketService.to.listenTo(
      SocketEvents.dispatchOffer,
      (data) => _handleIncomingTripRequest(data, isGoods: false),
    );
    SocketService.to.listenTo(
      SocketEvents.bookingCancelled,
      (data) => _releasePendingGoodsRequest(data, showCancelledMessage: true),
    );
    SocketService.to.listenTo(
      SocketEvents.bookingCanceledAlias,
      (data) => _releasePendingGoodsRequest(data, showCancelledMessage: true),
    );

    void goodsAcceptSuccessHandler(dynamic data) {
      if (!mounted || !_hasRideAccess) return;
      final acceptedId = _requestIdFrom(data);
      final currentBookingId = _currentTripRequest?['bookingId']?.toString();
      if (acceptedId != null &&
          currentBookingId != null &&
          acceptedId != currentBookingId) {
        return;
      }
      print('--- [GOODS] Booking accept confirmed: $data ---');
    }

    void goodsAcceptErrorHandler(dynamic data) {
      if (!mounted || !_hasRideAccess || !_isAcceptingGoodsRequest) return;
      final payload = data is List && data.isNotEmpty ? data.first : data;
      final message = payload is Map
          ? payload['message']?.toString() ?? 'Unable to accept booking.'
          : 'Unable to accept booking.';
      setState(() => _isAcceptingGoodsRequest = false);
      CustomSnackbar.showError(message: message);
    }

    for (final event in <String>[
      SocketEvents.goodsBookingAcceptSuccess,
      SocketEvents.goodsBookingAccepted,
      SocketEvents.goodsDriverAssigned,
      SocketEvents.goodsRequestAccepted,
    ]) {
      SocketService.to.listenTo(event, goodsAcceptSuccessHandler);
    }
    SocketService.to.listenTo(
      SocketEvents.goodsBookingAcceptError,
      goodsAcceptErrorHandler,
    );
    SocketService.to.listenTo(SocketEvents.goodsError, goodsAcceptErrorHandler);

    SocketService.to.listenTo(
      SocketEvents.goodsBookingRequestTimeout,
      _releasePendingGoodsRequest,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsBookingRequestExpired,
      _releasePendingGoodsRequest,
    );

    // 3. Listen to TRIP_REQUEST_EXPIRED
    SocketService.to.listenTo(SocketEvents.tripRequestExpired, (data) async {
      print('--- [SOCKET_IO] Received TRIP_REQUEST_EXPIRED: $data ---');
      if (!mounted || !_hasRideAccess) return;

      var eventData = data is List && data.isNotEmpty ? data.first : data;
      final expiredTripId = eventData is Map
          ? (eventData['tripId'] ??
                eventData['id'] ??
                eventData['bookingId'] ??
                eventData['requestId'])
          : null;
      final currentTripId =
          _currentTripRequest?['tripId'] ??
          _currentTripRequest?['bookingId'] ??
          _currentTripRequest?['requestId'];

      if (currentTripId == null ||
          expiredTripId == null ||
          currentTripId == expiredTripId) {
        _requestTimer?.cancel();
        setState(() {
          _showRequestCard = false;
          _currentTripRequest = null;
        });
        if (_isOnline) {
          await _sendHeartbeatData();
        }
      }
    });

    // 4. Listen to TRIP_CANCELLED variations
    final cancelHandler = (data) async {
      print('--- [SOCKET_IO] Received Cancellation Event: $data ---');
      if (!mounted || !_hasRideAccess) return;

      final parsedData = data is Map ? Map<String, dynamic>.from(data) : null;
      final String? eventBookingId = parsedData?['bookingId']?.toString() ??
          parsedData?['tripId']?.toString() ??
          parsedData?['id']?.toString() ??
          parsedData?['requestId']?.toString();

      final String? currentBookingId = _currentTripRequest?['bookingId']?.toString() ??
          _currentTripRequest?['tripId']?.toString() ??
          _currentTripRequest?['requestId']?.toString() ??
          _currentTripRequest?['id']?.toString();

      print('[DRIVER_OFFER_EVENT] bookingId=${eventBookingId ?? 'N/A'}, currentId=${currentBookingId ?? 'N/A'}, payload=$data');

      if (_currentTripRequest != null && currentBookingId != null && eventBookingId != null && eventBookingId.isNotEmpty) {
        if (eventBookingId != currentBookingId) {
          print('[DRIVER_OFFER_EVENT] Ignoring cancellation for different bookingId: $eventBookingId (active: $currentBookingId)');
          return;
        }
      }

      if (_currentTripRequest?['isGoods'] == true) {
        await _releasePendingGoodsRequest(data, showCancelledMessage: true);
        return;
      }

      // Preserve the existing passenger-ride cancellation behavior.
      if (_showRequestCard) {
        _requestTimer?.cancel();
        _requestTimer = null;
        setState(() {
          _remainingSeconds = 0;
          _showRequestCard = false;
          _currentTripRequest = null;
        });
        CustomSnackbar.showError(
          message: 'The ride request was cancelled by the user.',
        );
        if (_isOnline) await _sendHeartbeatData();
      }
    };

    SocketService.to.listenTo(SocketEvents.tripCancelled, cancelHandler);
    SocketService.to.listenTo('TRIP_CANCELLED_BY_USER', cancelHandler);
    SocketService.to.listenTo('cars:booking:cancelled', cancelHandler);
    SocketService.to.listenTo(
      SocketEvents.goodsBookingCancelled,
      cancelHandler,
    );

    final socketClearHandler = (dynamic data) {
      print('[YOGESH][SOCKET][DRIVER] Received rejection/cancellation socket event: $data');
      final targetId = _requestIdFrom(data);
      final currentId = _currentTripRequest?['bookingId']?.toString() ??
          _currentTripRequest?['tripId']?.toString() ??
          _currentTripRequest?['requestId']?.toString() ??
          _currentTripRequest?['id']?.toString();

      print('[DRIVER_OFFER_EVENT] socketClearHandler targetId=$targetId, currentId=$currentId');

      if (targetId != null && targetId.isNotEmpty) {
        if (currentId == null || targetId == currentId) {
          _clearRideRequest(targetId, reason: 'socket_rejection_cancellation');
        } else {
          print('[DRIVER_OFFER_EVENT] Ignoring clear for non-matching offer targetId: $targetId (current: $currentId)');
        }
      }
    };

    SocketService.to.listenTo('dispatch:rejected', socketClearHandler);
    SocketService.to.listenTo('dispatch:offer-expired', socketClearHandler);
    SocketService.to.listenTo('dispatch:offer_expired', socketClearHandler);
    SocketService.to.listenTo('dispatch:offer-cancelled', (data) => _releasePendingGoodsRequest(data, showCancelledMessage: true));
    SocketService.to.listenTo('dispatch:offer_cancelled', (data) => _releasePendingGoodsRequest(data, showCancelledMessage: true));
    SocketService.to.listenTo('booking:cancelled', (data) => _releasePendingGoodsRequest(data, showCancelledMessage: true));
    SocketService.to.listenTo('goods.booking.cancelled', (data) => _releasePendingGoodsRequest(data, showCancelledMessage: true));
    SocketService.to.listenTo('booking:cancelled-by-driver', socketClearHandler);
    SocketService.to.listenTo('booking:cancelled_by_driver', socketClearHandler);
    SocketService.to.listenTo('booking:no-driver-found', socketClearHandler);

    if (_hasRideAccess && _isOnline) {
      print(
        '--- [SOCKET_IO] Initializing: Driver is online, ensuring connection ---',
      );
      Future.microtask(() async {
        await SocketService.to.ensureConnected();
        await LocationTrackingService().startTracking(null);
      });
    }
  }

  void _removeSocketListeners() {
    SocketService.to.stopListening(SocketEvents.driverOnlineSuccess);
    SocketService.to.stopListening(SocketEvents.newTripRequest);
    SocketService.to.stopListening(SocketEvents.goodsBookingRequestSent);
    SocketService.to.stopListening(SocketEvents.goodsBookingRequestSentAlias);
    SocketService.to.stopListening(SocketEvents.goodsRequestNew);
    SocketService.to.stopListening(SocketEvents.dispatchOfferCanonical);
    SocketService.to.stopListening(SocketEvents.dispatchOffer);
    SocketService.to.stopListening(SocketEvents.bookingCancelled);
    SocketService.to.stopListening(SocketEvents.bookingCanceledAlias);
    SocketService.to.stopListening('dispatch:offer-cancelled');
    SocketService.to.stopListening('dispatch:offer_cancelled');
    SocketService.to.stopListening('booking:cancelled');
    SocketService.to.stopListening('goods.booking.cancelled');
    SocketService.to.stopListening(SocketEvents.goodsBookingAcceptSuccess);
    SocketService.to.stopListening(SocketEvents.goodsBookingAccepted);
    SocketService.to.stopListening(SocketEvents.goodsDriverAssigned);
    SocketService.to.stopListening(SocketEvents.goodsRequestAccepted);
    SocketService.to.stopListening(SocketEvents.goodsBookingAcceptError);
    SocketService.to.stopListening(SocketEvents.goodsError);
    SocketService.to.stopListening(SocketEvents.goodsBookingRequestTimeout);
    SocketService.to.stopListening(SocketEvents.goodsBookingRequestExpired);
    SocketService.to.stopListening(SocketEvents.tripRequestExpired);
    SocketService.to.stopListening(SocketEvents.tripCancelled);
    SocketService.to.stopListening('TRIP_CANCELLED_BY_USER');
    SocketService.to.stopListening('cars:booking:cancelled');
    SocketService.to.stopListening(SocketEvents.goodsBookingCancelled);
    SocketService.to.stopListening('dispatch:rejected');
    SocketService.to.stopListening('dispatch:offer-expired');
    SocketService.to.stopListening('dispatch:offer_expired');
    SocketService.to.stopListening('booking:cancelled-by-driver');
    SocketService.to.stopListening('booking:cancelled_by_driver');
    SocketService.to.stopListening('booking:no-driver-found');
  }

  @override
  void dispose() {
    _onlineWorker?.dispose();
    _kycAccessWorker?.dispose();
    _notificationTapWorker?.dispose();
    _scrollController.dispose();
    _heartbeatTimer?.cancel();
    _requestTimer?.cancel();
    _removeSocketListeners();
    super.dispose();
  }

  void _initMapItems() {
    _markers = {
      Marker(
        markerId: MarkerId('pickup'),
        position: _pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
      Marker(
        markerId: MarkerId('drop'),
        position: _dropLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      Marker(
        markerId: MarkerId('car'),
        position: _carLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: PolylineId('route'),
        points: [_pickupLatLng, _carLatLng, _dropLatLng],
        color: const Color(0xFF00ABE4),
        width: 4,
      ),
    };

    // Demo Ride Request disabled so popup only shows on real API/Socket requests
    _currentTripRequest = null;
    _showRequestCard = false;
    _remainingSeconds = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeaderSection(),
              Obx(
                () {
                  final authController = Get.find<AuthController>();
                  if (!authController.isRideAccessEnabled) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
                    child: _buildOnlineStatusBanner(),
                  );
                },
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Get.find<AuthController>().fetchDashboardData(isRefresh: true);
                    await Get.find<AuthController>().checkProfileStatus();
                    if (_hasRideAccess && _isOnline) {
                      await _sendHeartbeatData();
                    }
                    if (_hasRideAccess) {
                      await _resumeOngoingTrip();
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    child: GetX<AuthController>(
                      builder: (authController) {
                        final status =
                            authController.verificationStatus.value.toUpperCase();
                        final isPending =
                            (status == 'PENDING' || status == 'UNDER_REVIEW');

                        if (isPending) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 12.h),
                              _buildVerificationPendingBanner(),
                              SizedBox(height: 14.h),
                              _buildDocumentStatusListCard(),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 12.h),
                            _buildEarningsCard(),
                            SizedBox(height: 10.h),
                            if (!_showRequestCard ||
                                _currentTripRequest == null) ...[
                              _buildOverviewSection(),
                              SizedBox(height: 14.h),
                            ],
                            _buildInlineStateSection(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showRequestCard && _currentTripRequest != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: 16.w,
                        right: 16.w,
                        bottom: 60.h,
                      ),
                      child: _buildRideRequestCard(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Obx(() {
      final authController = Get.find<AuthController>();
      final profile = authController.userProfile.value;
      String driverName = '';
      if (profile != null) {
        final rawName = profile.name.trim().isNotEmpty
            ? profile.name.trim()
            : profile.firstname.trim();
        if (rawName.isNotEmpty && rawName != 'Driver') {
          driverName = rawName.split(' ').first;
        }
      }
      if (driverName.isEmpty) {
        driverName = 'Driver';
      }
      final avatarUrl = _profileImageUrl(profile?.avatar ?? '') ?? '';

      void handleProfileTap() {
        print('\n=====================================================');
        print('🚀 [DEBUG] DRIVER PROFILE TOUCHED ON HOME SCREEN');
        print('URL: ${ApiConstants.baseUrl}${ApiConstants.driverProfile}');
        print('=====================================================\n');
        authController.debugFetchAndPrintProfile();
        Get.to(() => ProfileScreen(showBackButton: true));
      }

      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10.h,
          bottom: 12.h,
          left: 16.w,
          right: 16.w,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFAE1),
          border: Border(
            bottom: BorderSide(color: Color(0xFFFFEF9E), width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: handleProfileTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFCC00),
                        border: Border.all(color: Colors.white, width: 2.w),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.person, color: Colors.white, size: 26.sp),
                              )
                            : Icon(Icons.person, color: Colors.white, size: 26.sp),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hi, $driverName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _hasRideAccess && _isOnline
                                ? 'Online'
                                : 'Offline',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const NotificationBell(),
          ],
        ),
      );
    });
  }

  Future<bool> _syncDriverOnlinePresence({String source = 'manual'}) async {
    if (!_hasRideAccess) return false;
    try {
      await SocketService.to.ensureConnected();
      final tracker = LocationTrackingService();
      final position = await tracker.fetchBestCurrentPosition();
      if (position == null) {
        CustomSnackbar.showError(
          message: 'Unable to get current location. Please enable GPS to go online.',
        );
        print('[DRIVER_PRESENCE] action=ONLINE source=$source location=missing');
        return false;
      }

      await tracker.startTracking(null);
      final resp =
          await Get.find<ApiClient>().postData(ApiConstants.availabilityOnline, {});
      final ok = resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 300 &&
          !(resp.body is Map && resp.body['success'] == false);
      if (!ok) {
        final failure = _onlineFailureMessage(resp);
        print(
          '[DRIVER_PRESENCE] action=ONLINE source=$source onlineSync=failed status=${resp.statusCode} body=${resp.body}',
        );
        CustomSnackbar.showError(message: failure);
        if (_isSubscriptionRequired(resp)) {
          Get.to(() => SubscriptionPlansScreen(showBackButton: true));
        }
        return false;
      }

      final ack = await SocketService.to.goOnline(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        sequence: 1,
      );
      await tracker.sendFreshLocationUpdate();
      await SocketService.to.sendHeartbeat();
      print(
        '[DRIVER_PRESENCE] action=ONLINE source=$source socketConnected=${SocketService.to.isConnected} onlineSync=success available=true ack=$ack',
      );
      return true;
    } catch (e) {
      print('[DRIVER_PRESENCE] action=ONLINE source=$source onlineSync=error error=$e');
      return false;
    }
  }

  Future<void> _syncDriverOfflinePresence() async {
    try {
      await SocketService.to.ensureConnected();
      await SocketService.to.goOffline();
      await Get.find<ApiClient>().postData(ApiConstants.availabilityOffline, {});
    } catch (e) {
      print('[DRIVER_PRESENCE] action=OFFLINE sync=error error=$e');
    } finally {
      await LocationTrackingService().stopTracking();
    }
  }

  bool _isSubscriptionRequired(Response response) {
    final text = '${response.body} ${response.statusText}'.toUpperCase();
    return response.statusCode == 403 &&
        text.contains('DRIVER_SUBSCRIPTION_REQUIRED');
  }

  String _onlineFailureMessage(Response response) {
    final text = '${response.body} ${response.statusText}'.toUpperCase();
    if (text.contains('DRIVER_SUBSCRIPTION_REQUIRED')) {
      return 'Please activate a driver subscription plan to go online.';
    }
    if (text.contains('DRIVER_NOT_ELIGIBLE')) {
      return 'Your driver profile or vehicle is not eligible to go online.';
    }
    final body = response.body;
    if (body is Map) {
      final message = body['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return response.statusText ?? 'Could not go online. Please try again.';
  }

  String _getInitials(String name) {
    final nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.isEmpty || nameParts.first.isEmpty) return 'D';
    if (nameParts.length == 1) return nameParts.first[0].toUpperCase();
    return (nameParts.first[0] + nameParts.last[0]).toUpperCase();
  }

  String? _profileImageUrl(String avatar) {
    final trimmed = avatar.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http')) return trimmed;
    if (trimmed.startsWith('/')) return '${ApiConstants.fileBaseUrl}$trimmed';
    if (trimmed.startsWith('assets/')) return null;
    return '${ApiConstants.fileBaseUrl}/$trimmed';
  }

  Widget _buildRoundHeaderButton(Widget iconWidget, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE9ECEF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: iconWidget),
      ),
    );
  }

  Widget _buildSocketStatusDot() {
    return Obx(() {
      final status = SocketService.to.connectionStatus.value;
      final Color color;
      switch (status) {
        case SocketConnectionStatus.connected:
          color = const Color(0xFF0A9421);
          break;
        case SocketConnectionStatus.connecting:
          color = AppColors.warning;
          break;
        case SocketConnectionStatus.error:
          color = AppColors.error;
          break;
        case SocketConnectionStatus.disconnected:
          color = Colors.grey;
          break;
      }

      return Container(
        width: 12.w,
        height: 12.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOnlineStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFFE6F7EB)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? const Color(0xFF35AF30)
                          : const Color(0xFF9CA3AF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isOnline ? 'You are Online' : 'You are Offline',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                          color: const Color(0xFF131913),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _isOnline
                            ? 'You will receive delivery requests'
                            : 'Go online to start receiving requests',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: const Color(0xFF727272),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: _isOnline,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF35AF30),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD1D5DB),
              onChanged: (willBeOnline) async {
                if (!_hasRideAccess) {
                  await _forceOfflineForKycBlock();
                  CustomSnackbar.showError(
                    message: 'Cannot go online until your KYC is approved.',
                  );
                  return;
                }
                if (willBeOnline && _hasPendingPaymentBooking) {
                  CustomSnackbar.showWarning(
                    message:
                        'Please complete payment confirmation before going online.',
                  );
                  setState(() => _isOnline = false);
                  return;
                }
                if (willBeOnline && Get.isRegistered<AuthController>()) {
                  final authCtrl = Get.find<AuthController>();
                  final vStatus = authCtrl.verificationStatus.value.toUpperCase();
                  final oStatus = authCtrl.onboardingStatus.value.toUpperCase();
                  if (vStatus == 'PENDING' || vStatus == 'UNDER_REVIEW') {
                    CustomSnackbar.showError(
                      message: 'Cannot go online: Your documents are under verification by admin.',
                    );
                    setState(() => _isOnline = false);
                    return;
                  }
                  if (oStatus == 'REJECTED' || vStatus == 'REJECTED') {
                    CustomSnackbar.showError(
                      message: 'Cannot go online: Your driver profile verification was rejected.',
                    );
                    setState(() => _isOnline = false);
                    return;
                  }
                }
                print(
                  '[YOGESH][DRIVER][STATUS] Driver toggled switch: _isOnline = $willBeOnline',
                );
                if (willBeOnline) {
                  final synced =
                      await _syncDriverOnlinePresence(source: 'dashboard_toggle');
                  if (!synced) {
                    if (Get.isRegistered<AuthController>()) {
                      Get.find<AuthController>().isOnline.value = false;
                    }
                    if (mounted) setState(() => _isOnline = false);
                    return;
                  }
                } else {
                  await _syncDriverOfflinePresence();
                  _showRequestCard = false;
                  _currentTripRequest = null;
                  _requestTimer?.cancel();
                }
                if (Get.isRegistered<AuthController>()) {
                  Get.find<AuthController>().isOnline.value = willBeOnline;
                }
                if (mounted) {
                  setState(() {
                    _isOnline = willBeOnline;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPendingBanner() {
    return GetX<AuthController>(
      builder: (authController) {
        final status = authController.verificationStatus.value.toUpperCase();
        if (status != 'PENDING' && status != 'UNDER_REVIEW') {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 4.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFFFC700), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC700).withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC700).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: const Color(0xFFB48500),
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Verification Pending',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D0D0D),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1C2),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            'Under Review',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB48500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Your profile and documents have been submitted and are currently being reviewed by our team. You can accept rides once approved.',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () async {
                        await authController.checkProfileStatus();
                        CustomSnackbar.showSuccess(
                          message: 'Verification status updated',
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC700),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'Check Status 🔄',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D0D0D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentStatusListCard() {
    final docs = [
      {'title': 'Aadhar Card (Front)', 'key': 'Aadhaar Card'},
      {'title': 'Aadhar Card (Back)', 'key': 'Aadhaar Card'},
      {'title': 'PAN Card', 'key': 'PAN Card'},
      {'title': 'Driving License (Front)', 'key': 'Driving Licence'},
      {'title': 'Driving License (Back)', 'key': 'Driving Licence'},
      {'title': 'RC (Registration Certificate)', 'key': 'Vehicle RC'},
      {'title': 'Insurance Certificate', 'key': 'Vehicle Insurance'},
      {'title': 'Commercial Permit (if Applicable)', 'key': 'Commercial Permit'},
    ];

    return Obx(() {
      if (!Get.isRegistered<DocumentController>()) {
        return const SizedBox.shrink();
      }
      final docController = Get.find<DocumentController>();
      
      return Column(
        children: docs.map((docData) {
          final docName = docData['title']!;
          final docKey = docData['key']!;
          
          final status = docController.documentStatuses[docKey] ?? DocumentStatus.pending;
          
          String statusText = 'Pending 🕐';
          Color statusColor = const Color(0xFFB48500);
          Color statusBgColor = const Color(0xFFFFF9E6);
          IconData statusIcon = Icons.visibility_outlined;
          
          if (status == DocumentStatus.approved) {
            statusText = 'Approved';
            statusColor = const Color(0xFF2E7D32);
            statusBgColor = const Color(0xFFE8F5E9);
            statusIcon = Icons.check_circle_outline;
          } else if (status == DocumentStatus.rejected) {
            statusText = 'Rejected';
            statusColor = const Color(0xFFD32F2F);
            statusBgColor = const Color(0xFFFFEBEE);
            statusIcon = Icons.error_outline;
          } else if (status == DocumentStatus.underVerification) {
            statusText = 'Under Review';
            statusColor = const Color(0xFFB48500);
            statusBgColor = const Color(0xFFFFF9E6);
            statusIcon = Icons.hourglass_top_outlined;
          }

          return GestureDetector(
            onTap: () {
              Get.to(() => const DocumentsUploadStepScreen());
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      docName,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131913),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20.sp,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  String _formatInrAmount(dynamic amount) {
    if (amount == null) return '₹0';
    final num? value = amount is num ? amount : num.tryParse(amount.toString());
    if (value == null) return '₹0';
    final formatter = NumberFormat('#,##0', 'en_IN');
    return '₹${formatter.format(value.round())}';
  }

  (String, Color) _getWeeklyChangeSubtextAndColor(dynamic rawPercent) {
    if (rawPercent == null) {
      return ('No data for last week', const Color(0xFF757575));
    }
    final num? percentNum =
        rawPercent is num ? rawPercent : num.tryParse(rawPercent.toString());
    if (percentNum == null) {
      return ('No data for last week', const Color(0xFF757575));
    }
    final int rounded = percentNum.round();
    if (rounded > 0) {
      return ('↑ $rounded% vs last week', const Color(0xFF35AF30));
    } else if (rounded < 0) {
      return ('↓ ${rounded.abs()}% vs last week', const Color(0xFFE53935));
    } else {
      return ('— vs last week', const Color(0xFF757575));
    }
  }

  Widget _buildEarningsSkeletonCard() {
    return Container(
      width: double.infinity,
      height: 76.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFDBDBDB), width: 1.w),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 64,
            child: Row(
              children: [
                Container(
                  width: 49.w,
                  height: 49.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60.w,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 80.w,
                        height: 10.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 95.w,
                        height: 9.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1.w,
            height: 49.h,
            color: const Color(0xFFDBDBDB),
          ),
          Expanded(
            flex: 36,
            child: Padding(
              padding: EdgeInsets.only(left: 28.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70.w,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: 50.w,
                    height: 10.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: 80.w,
                    height: 9.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsErrorCard(AuthController authController) {
    return Container(
      width: double.infinity,
      height: 76.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.w),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: const Color(0xFFD32F2F),
                size: 24.w,
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Unable to load earnings',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD32F2F),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Tap retry to try again',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              authController.fetchDashboardData(isRefresh: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    final authController = Get.find<AuthController>();

    return Obx(() {
      final isLoading = authController.isDashboardLoading.value;
      final isError = authController.isDashboardError.value;
      final dashMap = authController.dashboardData.value;

      if (isLoading && dashMap == null) {
        return _buildEarningsSkeletonCard();
      }

      if (isError && dashMap == null) {
        return _buildEarningsErrorCard(authController);
      }

      final rawTodayEarnings = dashMap?['todayEarnings'];
      final rawTodayTrips = dashMap?['todayTrips'];
      final rawWeekEarnings = dashMap?['currentWeekEarnings'];
      final rawWeeklyChange = dashMap?['weeklyChangePercent'];

      final int todayTrips = rawTodayTrips is int
          ? rawTodayTrips
          : (rawTodayTrips is num
              ? rawTodayTrips.toInt()
              : (int.tryParse(rawTodayTrips?.toString() ?? '0') ?? 0));

      final todayEarningsText = _formatInrAmount(rawTodayEarnings);
      final weekEarningsText = _formatInrAmount(rawWeekEarnings);

      final tripsSubtext = todayTrips == 1
          ? '1 Delivery Completed'
          : '$todayTrips Deliveries Completed';

      final (weeklyChangeText, weeklyChangeColor) =
          _getWeeklyChangeSubtextAndColor(rawWeeklyChange);

      return Container(
        width: double.infinity,
        height: 76.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: const Color(0xFFDBDBDB), width: 1.w),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Today's Earnings
            Expanded(
              flex: 64,
              child: Row(
                children: [
                  Container(
                    width: 49.w,
                    height: 49.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF35AF30).withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/icons/Group1.png',
                      width: 25.w,
                      height: 25.w,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          todayEarningsText,
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            color: const Color(0xFF131913),
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Today's Earnings",
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            color: const Color(0xFF131913),
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          tripsSubtext,
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: const Color(0xFF35AF30),
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Vertical Divider
            Container(
              width: 1.w,
              height: 49.h,
              color: const Color(0xFFDBDBDB),
            ),
            // This Week
            Expanded(
              flex: 36,
              child: Padding(
                padding: EdgeInsets.only(left: 28.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekEarningsText,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: const Color(0xFF131913),
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'This Week',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        color: const Color(0xFF131913),
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      weeklyChangeText,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: weeklyChangeColor,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatOverviewDistance(double meters) {
    if (meters <= 0) return '0 km';
    final double km = meters / 1000.0;
    if (km % 1 == 0) return '${km.toInt()} km';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatOverviewOnlineTime(int seconds, double fallbackHours) {
    int totalSec = seconds;
    if (totalSec <= 0 && fallbackHours > 0) {
      totalSec = (fallbackHours * 3600).round();
    }
    if (totalSec <= 0) return '0m';
    final int hours = totalSec ~/ 3600;
    final int minutes = (totalSec % 3600) ~/ 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  Widget _buildOverviewSection() {
    final profile = Get.find<AuthController>().userProfile.value;
    final int tripsCount = profile?.todayTrips ?? profile?.totalTrips ?? 0;
    final double distanceMeters = profile?.todayDistanceMeters ?? 0.0;
    final int onlineSeconds = profile?.todayOnlineSeconds ?? 0;
    final double fallbackHours = profile?.hoursOnline ?? 0.0;

    final String distanceStr = _formatOverviewDistance(distanceMeters);
    final String onlineTimeStr =
        _formatOverviewOnlineTime(onlineSeconds, fallbackHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildOverviewCard(
                iconWidget: Icon(
                  Icons.work_outline_rounded,
                  color: const Color(0xFFFD7502),
                  size: 16.sp,
                ),
                iconBg: const Color(0x2EFD7502),
                value: '$tripsCount',
                label: 'Trips',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildOverviewCard(
                iconWidget: Icon(
                  Icons.search_rounded,
                  color: const Color(0xFF0167FA),
                  size: 16.sp,
                ),
                iconBg: const Color(0x330167FA),
                value: distanceStr,
                label: 'Distance',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildOverviewCard(
                iconWidget: Image.asset(
                  'assets/icons/Group1.png',
                  width: 16.w,
                  height: 16.w,
                ),
                iconBg: const Color(0x3335AF30),
                value: onlineTimeStr,
                label: 'Online Time',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required Widget iconWidget,
    required Color iconBg,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFDBDBDB), width: 1.w),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 27.w,
            height: 27.w,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: iconWidget,
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF131913),
              height: 1.0,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF131913),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatDivider() {
    return Container(
      width: 1.5,
      height: double.infinity,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color bgCircleColor,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: bgCircleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppFonts.h2.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemWithCustomIcon(
    String value,
    String label,
    Widget iconWidget,
    Color bgCircleColor,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: bgCircleColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: iconWidget),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppFonts.h2.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStateSection() {
    if (!_isOnline) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12.h),
            Text(
              'You are offline',
              style: AppFonts.h2.copyWith(
                fontSize: 16.sp,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Switch to online mode to receive requests.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    if (!_showRequestCard || _currentTripRequest == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 18.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.8,
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 76.h,
                  height: 76.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                ),
                SizedBox(
                  height: 60.h,
                  width: 60.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: const Color(0xFF00ABE4),
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                  ),
                ),
                Container(
                  width: 44.h,
                  height: 44.h,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00ABE4),
                  ),
                  child: Icon(
                    Icons.radar_rounded,
                    size: 26.sp,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              'Searching for nearby requests...',
              textAlign: TextAlign.center,
              style: AppFonts.h2.copyWith(
                fontSize: 17.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Stay on this screen. New trip requests will pop up automatically as soon as riders book nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            SizedBox(height: 18.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: const Color(0xFFA7F3D0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8.h,
                    height: 8.h,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Driver Online & Ready',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatOnlineDuration(double hours) {
    final totalMinutes = (hours * 60).round();
    final wholeHours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${wholeHours}h ${minutes}m';
  }

  Widget _buildRequestContactLine(String label, dynamic name, dynamic phone) {
    final displayName = name?.toString().trim();
    final displayPhone = phone?.toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${displayName?.isNotEmpty == true ? displayName : 'Not provided'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF334155),
          ),
        ),
        if (displayPhone?.isNotEmpty == true)
          Text(
            displayPhone!,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
      ],
    );
  }

  Future<void> _handleRejectRequest(String targetBookingId) async {
    if (!_hasRideAccess) {
      await _forceOfflineForKycBlock();
      return;
    }

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    if (_isRejectingRide || !_pendingRequests.containsKey(targetBookingId)) return;

    final targetReq = _pendingRequests[targetBookingId];
    if (targetReq == null) return;

    final bookingId = targetReq['bookingId']?.toString() ?? targetBookingId;
    final requestId = targetReq['requestId']?.toString() ?? targetReq['offerId']?.toString() ?? bookingId;
    final offerId = targetReq['offerId']?.toString() ?? requestId;
    final tripId = targetReq['tripId']?.toString() ?? bookingId;

    print('[YOGESH][REJECT_FLOW] [REJECT_PRESSED] Driver pressed Reject');
    print('[YOGESH][REJECT_FLOW] [BOOKING_ID] $bookingId');
    print('[YOGESH][REJECT_FLOW] [OFFER_ID] $offerId');
    print('[YOGESH][REJECT_FLOW] [REQUEST_ID] $requestId');
    print('[YOGESH][REJECT_FLOW] [TRIP_ID] $tripId');

    _isRejectingRide = true;

    // 1. Instantly record identifiers in rejected/expired cache sets to block stale events
    _rejectedBookingIds.add(targetBookingId);
    _rejectedBookingIds.add(bookingId);
    _rejectedBookingIds.add(requestId);
    _rejectedBookingIds.add(offerId);
    _rejectedBookingIds.add(tripId);

    _expiredBookingIds.add(targetBookingId);
    _expiredBookingIds.add(bookingId);
    _expiredBookingIds.add(requestId);
    _expiredBookingIds.add(offerId);
    _expiredBookingIds.add(tripId);

    // 2. Immediately remove target request from queue and dismiss/update popup UI
    _clearRideRequest(targetBookingId, reason: 'manual_reject_pressed');

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Ride Missed',
        body: 'You missed a ride request.',
        type: 'RIDE_MISSED',
        bookingId: bookingId,
        extraData: {
          'pickup': targetReq['pickupAddress'],
          'drop': targetReq['dropAddress'],
          'fare': targetReq['fare'],
        },
      );
    }

    // 3. Immediately emit socket dispatch:reject event
    print('[YOGESH][REJECT_FLOW] [REJECT_EVENT_SENT] Emitting socket dispatch:reject for offerId: $offerId');
    SocketService.to.rejectDispatch(
      offerId: offerId,
      reason: 'DRIVER_MANUAL_REJECT',
    );

    // 4. Asynchronously send backend reject HTTP request
    final isGoods = targetReq['isGoods'] == true || targetReq['moduleType'] == 'GOODS';
    try {
      Response response;
      if (isGoods) {
        response = await GoodsDriverService().reject(
          bookingId,
          requestId: requestId,
          offerId: offerId,
        );
      } else {
        response = await BookingService.to.rejectBooking(
          bookingId,
          requestId: requestId,
          offerId: offerId,
        );
      }

      final success = _isSuccessResponse(response, isGoods: isGoods);
      print('[YOGESH][REJECT_FLOW] [REJECT_API_RESPONSE] status=${response.statusCode} body=${response.body} success=$success');
    } catch (e) {
      print('[YOGESH][REJECT_FLOW] [REJECT_API_ERROR] Exception sending reject HTTP request: $e');
    } finally {
      if (mounted) {
        _isRejectingRide = false;
        _safeSetState(() {});
      }
    }
  }

  Future<void> _handleAcceptRequest(String targetBookingId) async {
    if (!_hasRideAccess) {
      await _forceOfflineForKycBlock();
      CustomSnackbar.showError(
        message: 'Cannot accept rides until your KYC is approved.',
      );
      return;
    }

    if (_isAcceptingGoodsRequest || !_pendingRequests.containsKey(targetBookingId)) return;

    final targetReq = _pendingRequests[targetBookingId];
    if (targetReq == null) return;

    final bookingId = targetReq['bookingId']?.toString() ?? targetBookingId;
    final requestId = targetReq['requestId']?.toString() ?? targetReq['offerId']?.toString() ?? bookingId;
    final offerId = targetReq['offerId']?.toString() ?? requestId;

    _isAcceptingGoodsRequest = true;
    setState(() {});

    Map<String, dynamic>? acceptedBookingData;
    try {
      final isGoods = targetReq['isGoods'] == true || targetReq['moduleType'] == 'GOODS';
      final dispatchVersion = targetReq['dispatchVersion']?.toString();
      Response response;
      if (isGoods) {
        response = await GoodsDriverService().accept(
          bookingId,
          requestId: requestId,
          offerId: offerId,
          dispatchVersion: dispatchVersion,
        );
      } else {
        response = await BookingService.to.acceptBooking(bookingId);
      }

      if (!_isSuccessResponse(response, isGoods: isGoods)) {
        _isAcceptingGoodsRequest = false;
        if (response.statusCode == 409 || response.statusCode == 404) {
          _pendingRequests.remove(bookingId);
          if (_pendingRequests.isEmpty) {
            _requestTimer?.cancel();
            _requestTimer = null;
            _showRequestCard = false;
            _currentTripRequest = null;
            _selectedRequestIndex = 0;
          } else {
            _currentTripRequest = _getActiveRequest();
          }
          CustomSnackbar.showError(
            message: 'Booking is no longer available.',
          );
          return;
        }
        CustomSnackbar.showError(
          message: _extractErrorMessage(response, isGoods: isGoods),
        );
        return;
      }

      if (response.body is Map && response.body['data'] is Map) {
        acceptedBookingData = Map<String, dynamic>.from(response.body['data']);
      }

      final reqData = acceptedBookingData != null
          ? _normalizeTripRequest({
              ...targetReq,
              'booking': acceptedBookingData,
              'isGoods': isGoods,
            })
          : Map<String, dynamic>.from(targetReq);

      _pendingRequests.clear();
      _requestTimer?.cancel();
      _requestTimer = null;
      _showRequestCard = false;
      _currentTripRequest = null;
      _selectedRequestIndex = 0;

      if (Get.isRegistered<NotificationController>()) {
        NotificationController.to.addLocalNotification(
          title: 'Ride Accepted',
          body: 'Ride accepted successfully.',
          type: 'RIDE_ACCEPTED',
          bookingId: bookingId,
        );
      }

      Get.to(() => NavigateToPickupScreen(requestData: reqData));
    } catch (e) {
      print('Error accepting ride: $e');
      CustomSnackbar.showError(message: 'Error accepting ride: $e');
    } finally {
      if (mounted) {
        _isAcceptingGoodsRequest = false;
        setState(() {});
      }
    }
  }

  Widget _buildRideRequestCard() {
    final activeRequest = _getActiveRequest();
    if (activeRequest == null) return const SizedBox.shrink();

    final requestsList = _pendingRequests.values.toList();
    final remaining = _remainingRequestSeconds(activeRequest) ?? 0;
    final activeBookingId = activeRequest['bookingId']?.toString() ?? '';

    return RideRequestPopupCard(
      requestData: activeRequest,
      remainingSeconds: remaining,
      isSubmitting: _isAcceptingGoodsRequest || _isRejectingRide,
      totalRequests: requestsList.length,
      currentIndex: _selectedRequestIndex,
      onPreviousRequest: () {
        if (_selectedRequestIndex > 0) {
          setState(() {
            _selectedRequestIndex--;
            _currentTripRequest = _getActiveRequest();
          });
        }
      },
      onNextRequest: () {
        if (_selectedRequestIndex < requestsList.length - 1) {
          setState(() {
            _selectedRequestIndex++;
            _currentTripRequest = _getActiveRequest();
          });
        }
      },
      onReject: () => _handleRejectRequest(activeBookingId),
      onAccept: () => _handleAcceptRequest(activeBookingId),
    );
  }

  void _openRequestDetails() {
    if (_currentTripRequest == null) return;
    final targetId = _currentTripRequest?['bookingId']?.toString() ??
        _currentTripRequest?['tripId']?.toString() ??
        _currentTripRequest?['requestId']?.toString() ??
        _currentTripRequest?['id']?.toString() ??
        '';
    _requestTimer?.cancel();
    Get.to(
      () => NewRideRequestDetailScreen(requestData: _currentTripRequest),
    )?.then((result) {
      if (result == true) {
        setState(() {
          _showRequestCard = false;
          _currentTripRequest = null;
        });
      } else if (result == false || result == 'rejected') {
        if (targetId.isNotEmpty) {
          _clearRideRequest(targetId, reason: 'detail_screen_rejection');
        } else {
          setState(() {
            _showRequestCard = false;
            _currentTripRequest = null;
          });
        }
      }
    });
  }

  Widget _buildAddressRow({
    required String title,
    required String address,
    required String time,
    required Color iconColor,
    required bool isPickup,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                isPickup ? Icons.radio_button_checked : Icons.location_on,
                color: iconColor,
                size: 20.sp,
              ),
              if (isPickup)
                Container(
                  width: 2.w,
                  height: 40.h,
                  color: Colors.grey.shade300,
                ),
            ],
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  time,
                  style: AppFonts.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    double minLat = _pickupLatLng.latitude < _dropLatLng.latitude
        ? _pickupLatLng.latitude
        : _dropLatLng.latitude;
    double maxLat = _pickupLatLng.latitude > _dropLatLng.latitude
        ? _pickupLatLng.latitude
        : _dropLatLng.latitude;
    double minLng = _pickupLatLng.longitude < _dropLatLng.longitude
        ? _pickupLatLng.longitude
        : _dropLatLng.longitude;
    double maxLng = _pickupLatLng.longitude > _dropLatLng.longitude
        ? _pickupLatLng.longitude
        : _dropLatLng.longitude;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.02, minLng - 0.02),
      northeast: LatLng(maxLat + 0.02, maxLng + 0.02),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 15));
  }

  Future<void> fetchAndHandleNotificationBooking(
    String bookingId, {
    Map<String, dynamic>? extraPayload,
  }) async {
    if (bookingId.isEmpty) return;
    if (!_hasRideAccess) {
      await _forceOfflineForKycBlock();
      return;
    }

    if (_rejectedBookingIds.contains(bookingId) || _expiredBookingIds.contains(bookingId)) {
      CustomSnackbar.showError(message: 'This ride request is no longer available.');
      return;
    }

    try {
      final response = await BookingService.to.getBookingDetails(bookingId);
      if (response.statusCode == 200 && response.body != null) {
        final body = response.body;
        final rawData = (body is Map && body['data'] != null) ? body['data'] : body;
        if (rawData is Map) {
          final status = (rawData['status'] ?? rawData['booking']?['status'])?.toString().toUpperCase();

          if (status == 'SEARCHING_DRIVER' ||
              status == 'PENDING' ||
              status == 'DISPATCHING' ||
              status == 'CREATED' ||
              status == 'OFFERED') {
            final normalized = _normalizeTripRequest({
              ...Map<String, dynamic>.from(rawData),
              if (extraPayload != null) ...extraPayload,
            });

            _handleIncomingTripRequest(normalized);
            return;
          } else if (status == 'CANCELLED' || status == 'EXPIRED' || status == 'COMPLETED') {
            CustomSnackbar.showError(message: 'This ride request is no longer available.');
            _clearRideRequest(bookingId, reason: 'request_inactive');
            return;
          } else if (status == 'ACCEPTED' || status == 'DRIVER_ASSIGNED' || status == 'ON_THE_WAY') {
            final requestData = _normalizeTripRequest(rawData);
            Get.off(() => NavigateToPickupScreen(requestData: requestData));
            return;
          }
        }
      }

      if (extraPayload != null && extraPayload.isNotEmpty) {
        final normalized = _normalizeTripRequest(extraPayload);
        if (normalized['pickupAddress'] != null && normalized['dropAddress'] != null) {
          _handleIncomingTripRequest(normalized);
          return;
        }
      }

      CustomSnackbar.showError(message: 'This ride request is no longer available.');
    } catch (e) {
      debugPrint('[DRIVER_HOME] Error fetching notification booking details: $e');
      if (extraPayload != null && extraPayload.isNotEmpty) {
        final normalized = _normalizeTripRequest(extraPayload);
        _handleIncomingTripRequest(normalized);
      } else {
        CustomSnackbar.showError(message: 'This ride request is no longer available.');
      }
    }
  }
}
