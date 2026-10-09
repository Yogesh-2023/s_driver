import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../services/socket/socket_service.dart';
import '../../services/socket/socket_events.dart';
import 'navigate_to_pickup_screen.dart';
import '../../services/goods_driver_service.dart';
import '../../services/booking_service.dart';
import '../../data/api/api_constants.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/ride_request_popup_card.dart';
import '../auth/controllers/auth_controller.dart';

class NewRideRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  const NewRideRequestDetailScreen({super.key, this.requestData});

  @override
  State<NewRideRequestDetailScreen> createState() =>
      _NewRideRequestDetailScreenState();
}

class _NewRideRequestDetailScreenState
    extends State<NewRideRequestDetailScreen> {
  GoogleMapController? _mapController;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isSubmitting = false;

  bool get _hasRideAccess {
    if (!Get.isRegistered<AuthController>()) return false;
    return Get.find<AuthController>().isRideAccessEnabled;
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

  late final LatLng _pickupLatLng;
  late final LatLng _dropLatLng;
  late final LatLng _carLatLng;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    final pLat =
        double.tryParse(
          widget.requestData?['pickupLatitude']?.toString() ?? '',
        ) ??
        28.6276;
    final pLng =
        double.tryParse(
          widget.requestData?['pickupLongitude']?.toString() ?? '',
        ) ??
        77.3820;
    final dLat =
        double.tryParse(
          widget.requestData?['dropLatitude']?.toString() ?? '',
        ) ??
        28.5244;
    final dLng =
        double.tryParse(
          widget.requestData?['dropLongitude']?.toString() ?? '',
        ) ??
        77.2173;

    _pickupLatLng = LatLng(pLat, pLng);
    _dropLatLng = LatLng(dLat, dLng);
    _carLatLng = LatLng((pLat + dLat) / 2, (pLng + dLng) / 2);

    _initMapItems();
    _startTimer();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    SocketService.to.listenTo(SocketEvents.tripAccepted, (data) {
      if (!mounted) return;
      final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
      final acceptedTripId = payload is Map
          ? (payload['tripId'] ?? payload['booking']?['id'])?.toString()
          : null;
      final currentTripId = widget.requestData?['tripId']?.toString();
      if (currentTripId != null &&
          acceptedTripId != null &&
          acceptedTripId != currentTripId) {
        return;
      }

      _timer?.cancel();
      setState(() => _isSubmitting = false);
      Get.off(() => NavigateToPickupScreen(requestData: widget.requestData));
    });

    SocketService.to.listenTo(SocketEvents.tripAcceptError, (data) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
      final message = payload is Map
          ? (payload['message']?.toString() ?? 'Unable to accept trip')
          : 'Unable to accept trip';
      CustomSnackbar.showError(message: message);
    });

    final cancelHandler = (data) {
      if (!mounted) return;
      final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
      final cancelledTripId = payload is Map
          ? (payload['tripId'] ??
                    payload['bookingId'] ??
                    payload['goodsBookingId'] ??
                    payload['requestId'] ??
                    payload['id'] ??
                    payload['booking']?['id'])
                ?.toString()
          : null;
      final currentTripId =
          widget.requestData?['tripId']?.toString() ??
          widget.requestData?['bookingId']?.toString() ??
          widget.requestData?['requestId']?.toString() ??
          widget.requestData?['id']?.toString() ??
          widget.requestData?['booking']?['id']?.toString();

      if (currentTripId != null &&
          cancelledTripId != null &&
          cancelledTripId != currentTripId) {
        return;
      }

      _timer?.cancel();
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        Get.back();
      }
      Get.back();
      CustomSnackbar.showError(
        message: 'The ride request was cancelled or expired.',
      );
    };

    SocketService.to.listenTo(SocketEvents.tripCancelled, cancelHandler);
    SocketService.to.listenTo('TRIP_CANCELLED_BY_USER', cancelHandler);
    SocketService.to.listenTo('cars:booking:cancelled', cancelHandler);
    SocketService.to.listenTo(
      SocketEvents.goodsBookingCancelled,
      cancelHandler,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsBookingRequestTimeout,
      cancelHandler,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsBookingRequestExpired,
      cancelHandler,
    );
    SocketService.to.listenTo(SocketEvents.tripRequestExpired, cancelHandler);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService.to.stopListening(SocketEvents.tripAccepted);
    SocketService.to.stopListening(SocketEvents.tripAcceptError);
    SocketService.to.stopListening(SocketEvents.tripCancelled);
    SocketService.to.stopListening('TRIP_CANCELLED_BY_USER');
    SocketService.to.stopListening('cars:booking:cancelled');
    SocketService.to.stopListening(SocketEvents.goodsBookingCancelled);
    SocketService.to.stopListening(SocketEvents.goodsBookingRequestTimeout);
    SocketService.to.stopListening(SocketEvents.goodsBookingRequestExpired);
    SocketService.to.stopListening(SocketEvents.tripRequestExpired);
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        _safeSetState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _timer = null;
        if (mounted) {
          Get.back(result: 'rejected');
        }
      }
    });
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
        width: 5,
      ),
    };
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
      southwest: LatLng(minLat - 0.015, minLng - 0.015),
      northeast: LatLng(maxLat + 0.015, maxLng + 0.015),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Widget _buildContactLine(String label, dynamic name, dynamic phone) {
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
            fontSize: 14.sp,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _carLatLng,
                zoom: 11.5,
              ),
              markers: _markers,
              polylines: _polylines,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                _fitMapBounds();
              },
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),

          // Ride Request Popup Card
          Positioned(
            bottom: 60.h,
            left: 16.w,
            right: 16.w,
            child: RideRequestPopupCard(
              requestData: widget.requestData,
              remainingSeconds: _secondsRemaining,
              isSubmitting: _isSubmitting,
              onReject: () async {
                if (!_hasRideAccess) {
                  Get.find<AuthController>().enforceKycRideAccess();
                  return;
                }
                if (Get.isSnackbarOpen) {
                  Get.closeCurrentSnackbar();
                }
                final bookingId = widget.requestData?['bookingId']?.toString() ?? widget.requestData?['tripId']?.toString();
                final requestId = widget.requestData?['requestId']?.toString() ?? widget.requestData?['offerId']?.toString() ?? bookingId;
                final offerId = widget.requestData?['offerId']?.toString() ?? requestId;

                print('[YOGESH][REJECT_FLOW] [REJECT_PRESSED] Driver pressed Reject in detail screen');
                print('[YOGESH][REJECT_FLOW] [BOOKING_ID] $bookingId');
                print('[YOGESH][REJECT_FLOW] [OFFER_ID] $offerId');

                if (offerId != null && offerId.isNotEmpty) {
                  print('[YOGESH][REJECT_FLOW] [REJECT_EVENT_SENT] Emitting socket dispatch:reject for offerId: $offerId');
                  SocketService.to.rejectDispatch(
                    offerId: offerId,
                    reason: 'DRIVER_MANUAL_REJECT',
                  );
                }

                if (bookingId != null && bookingId.isNotEmpty) {
                  final isGoods = widget.requestData?['isGoods'] == true || widget.requestData?['moduleType'] == 'GOODS';
                  try {
                    if (isGoods) {
                      unawaited(GoodsDriverService().reject(bookingId, requestId: requestId, offerId: offerId));
                    } else {
                      unawaited(BookingService.to.rejectBooking(bookingId, requestId: requestId, offerId: offerId));
                    }
                  } catch (e) {
                    print('[YOGESH][REJECT_FLOW] [REJECT_API_ERROR] $e');
                  }
                }

                if (mounted) {
                  Get.back(result: 'rejected');
                }
              },
              onAccept: _acceptTrip,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner() {
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Material(
        color: Colors.white,
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.w),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'New Ride Request',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Accept before the request expires',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDetailsCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      String? imgUrl =
                          widget.requestData?['customerImage']?.toString() ??
                          widget.requestData?['customer']?['avatar']
                              ?.toString() ??
                          widget.requestData?['customer']?['profileImage']
                              ?.toString();
                      if (imgUrl != null && imgUrl.isNotEmpty) {
                        if (imgUrl.contains('localhost') ||
                            imgUrl.contains('cars.carosa.in')) {
                          final uri = Uri.tryParse(imgUrl);
                          if (uri != null && uri.path.isNotEmpty) {
                            imgUrl = '${ApiConstants.baseUrl}${uri.path}';
                          }
                        }
                        if (!imgUrl.startsWith('http')) {
                          imgUrl =
                              '${ApiConstants.baseUrl}${imgUrl.startsWith('/') ? '' : '/'}$imgUrl';
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20.r),
                          child: Image.network(
                            imgUrl,
                            width: 40.r,
                            height: 40.r,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                CircleAvatar(
                                  radius: 20.r,
                                  backgroundColor: AppColors.primary
                                      .withOpacity(0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 20.sp,
                                  ),
                                ),
                          ),
                        );
                      }
                      return CircleAvatar(
                        radius: 20.r,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 20.sp,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.requestData?['isGoods'] == true) ...[
                          _buildContactLine(
                            'Sender',
                            widget.requestData?['senderName'],
                            widget.requestData?['senderPhone'],
                          ),
                          SizedBox(height: 6.h),
                          _buildContactLine(
                            'Receiver',
                            widget.requestData?['receiverName'],
                            widget.requestData?['receiverPhone'],
                          ),
                        ] else ...[
                          Text(
                            (widget.requestData?['customerName'] ??
                                        widget.requestData?['customer']?['name'] ??
                                        widget.requestData?['customer']
                                            ?['displayName'])
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true
                                ? (widget.requestData?['customerName'] ??
                                        widget.requestData?['customer']
                                            ?['name'] ??
                                        widget.requestData?['customer']
                                            ?['displayName'])
                                    .toString()
                                : 'Customer',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          Text(
                            widget.requestData?['customerPhone'] ?? '',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: const Color(0xFFF59E0B),
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          (widget.requestData?['customerRating'] ?? 0)
                              .toString(),
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Divider(color: Colors.grey.shade200),
              SizedBox(height: 10.h),

              // Ride title & payment type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ride Details',
                    style: AppFonts.h2.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Text(
                    _paymentLabel,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F9F59),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              // Pickup and drop route
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      SizedBox(height: 12.h),
                      _buildRouteDot(
                        Colors.orange,
                        Icons.radio_button_checked_rounded,
                      ),
                      Container(
                        width: 2.w,
                        height: 52.h,
                        margin: EdgeInsets.symmetric(vertical: 4.h),
                        color: const Color(0xFFE2E8F0),
                      ),
                      _buildRouteDot(
                        Colors.redAccent,
                        Icons.location_on_rounded,
                      ),
                    ],
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      children: [
                        _buildAddressBox(
                          'Pick-up Location',
                          widget.requestData?['pickupAddress'] ??
                              'Unknown Pickup',
                          '',
                          const Color(0xFFBBF7D0),
                        ),
                        SizedBox(height: 8.h),
                        _buildAddressBox(
                          'Drop Location',
                          widget.requestData?['dropAddress'] ?? 'Unknown Drop',
                          '',
                          const Color(0xFFC7D2FE),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Equally aligned ride stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatWidget(
                      Icons.route_outlined,
                      'Distance',
                      '${widget.requestData?['distance']?.toString() ?? widget.requestData?['distanceKm']?.toString() ?? '0'} km',
                      const Color(0xFFBAE6FD),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildStatWidget(
                      Icons.access_time_rounded,
                      'Time',
                      '${widget.requestData?['estimatedDurationMin']?.toString() ?? '0'} min',
                      const Color(0xFFFDE68A),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildStatWidget(
                      Icons.currency_rupee_rounded,
                      'Fare',
                      '₹${widget.requestData?['fare']?.toString() ?? '0'}',
                      const Color(0xFFBBF7D0),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              // Payment information
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF9EE),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFF0F9F59).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCashPayment
                          ? Icons.monetization_on_outlined
                          : Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF0F9F59),
                      size: 24.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _isCashPayment
                            ? 'Collect the exact fare from the customer after completing the ride.'
                            : 'Payment is online. Do not collect cash from the customer.',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: const Color(
                            0xFF0A703F,
                          ), // Darker high-contrast green
                          fontWeight:
                              FontWeight.w800, // Make it very bold and readable
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Action Buttons
              Row(
                children: [
                  // Reject Button
                  Expanded(
                    child: SizedBox(
                      height: 40.h,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFECEF),
                          side: BorderSide(color: Color(0xFFFFD2D7)),
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (!_hasRideAccess) {
                                  Get.find<AuthController>().enforceKycRideAccess();
                                  CustomSnackbar.showError(
                                    message: 'Cannot reject rides until your KYC is approved.',
                                  );
                                  return;
                                }
                                final bookingId = widget.requestData?['bookingId']?.toString() ?? widget.requestData?['tripId']?.toString();
                                final requestId = widget.requestData?['requestId']?.toString() ?? widget.requestData?['offerId']?.toString() ?? bookingId;
                                final offerId = widget.requestData?['offerId']?.toString() ?? requestId;
                                final tripId = widget.requestData?['tripId']?.toString() ?? bookingId;

                                print('[YOGESH][RIDE_REJECT] button pressed');
                                print('[YOGESH][RIDE_REJECT] requestId = $requestId');
                                print('[YOGESH][RIDE_REJECT] bookingId = $bookingId');
                                print('[YOGESH][RIDE_REJECT] tripId = $tripId');
                                print('[YOGESH][RIDE_REJECT] sending reject request');

                                if (bookingId == null || bookingId.isEmpty) {
                                  Get.back(result: 'rejected');
                                  return;
                                }

                                setState(() => _isSubmitting = true);
                                try {
                                  final isGoods = widget.requestData?['isGoods'] == true || widget.requestData?['moduleType'] == 'GOODS';
                                  Response response;
                                  if (isGoods) {
                                    response = await GoodsDriverService().reject(bookingId, requestId: requestId, offerId: offerId);
                                  } else {
                                    response = await BookingService.to.rejectBooking(bookingId, requestId: requestId, offerId: offerId);
                                  }

                                  final success = isGoods
                                      ? GoodsDriverService().succeeded(response)
                                      : BookingService.to.isSuccess(response);

                                  print('[YOGESH][RIDE_REJECT] API/socket response = ${response.body}');
                                  print('[YOGESH][RIDE_REJECT] success = $success');

                                  if (!success) {
                                    if (!mounted) return;
                                    final errorMsg = isGoods
                                        ? GoodsDriverService().errorMessage(response)
                                        : (response.body is Map && response.body['message'] != null
                                            ? response.body['message'].toString()
                                            : response.statusText ?? 'Action failed (${response.statusCode})');
                                    CustomSnackbar.showError(message: errorMsg);
                                    return;
                                  }

                                  if (mounted) {
                                    Get.back(result: 'rejected');
                                  }
                                } catch (e) {
                                  print('[YOGESH][RIDE_REJECT] Exception: $e');
                                  print('[YOGESH][RIDE_REJECT] success = false');
                                  if (mounted) {
                                    CustomSnackbar.showError(message: 'Error rejecting ride: $e');
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isSubmitting = false);
                                  }
                                }
                              },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close,
                                color: const Color(0xFFDC3545),
                                size: 18.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Reject',
                                style: AppFonts.buttonText.copyWith(
                                  color: const Color(0xFFDC3545),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Accept Button
                  Expanded(
                    child: SizedBox(
                      height: 40.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F9F59),
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _acceptTrip,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                _isSubmitting ? 'Accepting...' : 'Accept',
                                style: AppFonts.buttonText.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteDot(Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14.sp),
    );
  }

  void _acceptTrip() {
    _acceptTripRequest();
  }

  bool get _isCashPayment {
    final method = widget.requestData?['paymentMethod']
        ?.toString()
        .toUpperCase();
    return method == null || method == 'CASH' || method == 'COD';
  }

  String get _paymentLabel => _isCashPayment
      ? 'Cash to Collect'
      : '${widget.requestData?['paymentMethod']?.toString().toUpperCase()} Payment';

  Future<void> _acceptTripRequest() async {
    if (!_hasRideAccess) {
      Get.find<AuthController>().enforceKycRideAccess();
      CustomSnackbar.showError(
        message: 'Cannot accept rides until your KYC is approved.',
      );
      return;
    }

    if (_secondsRemaining <= 0) {
      CustomSnackbar.showError(message: 'This booking request has expired.');
      return;
    }
    final isGoods = widget.requestData?['isGoods'] == true;
    final dynamic rawTripId;
    if (isGoods) {
      rawTripId =
          widget.requestData?['bookingId'] ??
          widget.requestData?['booking']?['id'];
    } else {
      rawTripId = widget.requestData?['tripId'];
    }
    final tripId = rawTripId?.toString();
    if (tripId == null || tripId.isEmpty) {
      CustomSnackbar.showError(message: 'Trip id is missing');
      return;
    }

    setState(() => _isSubmitting = true);
    if (isGoods) {
      final service = GoodsDriverService();
      final response = await service.accept(
        tripId,
        dispatchVersion: widget.requestData?['dispatchVersion']?.toString(),
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (!service.succeeded(response)) {
        CustomSnackbar.showError(message: service.errorMessage(response));
        return;
      }
      final accepted = response.body is Map && response.body['data'] is Map
          ? Map<String, dynamic>.from(response.body['data'])
          : <String, dynamic>{};
      final requestData = <String, dynamic>{
        ...?widget.requestData,
        ...accepted,
        'tripId': tripId,
        'isGoods': true,
        'booking': accepted,
      };
      Get.off(() => NavigateToPickupScreen(requestData: requestData));
      return;
    }
    print(
      '--- [SOCKET_IO] Driver accepting trip: $tripId, emitting dispatch:accept ---',
    );
    SocketService.to.acceptDispatch(offerId: tripId);
    final emitted = SocketService.to.emitEvent(SocketEvents.acceptTrip, {
      'tripId': tripId,
    });

    if (!emitted) {
      setState(() => _isSubmitting = false);
      CustomSnackbar.showError(
        message: 'Socket disconnected. Please reconnect and try again.',
      );
    }
  }

  Widget _buildAddressBox(
    String label,
    String address,
    String time,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  color: const Color(0xFF94A3B8),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: const Color(0xFF334155),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatWidget(
    IconData icon,
    String label,
    String value,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 18.sp),
          SizedBox(height: 5.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: const Color(0xFF64748B),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: const Color(0xFF334155),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
