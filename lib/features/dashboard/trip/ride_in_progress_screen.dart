import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_fonts.dart';
import '../customer_chat_screen.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/socket/socket_events.dart';
import '../../../services/ride_service.dart';
import '../trip_completed_screen.dart';
import '../../navigation/driver_navigation_screen.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/goods_driver_service.dart';
import '../../../data/api/api_constants.dart';
import '../../../widgets/custom_snackbar.dart';
import '../controllers/active_booking_controller.dart';
import '../../../services/booking_service.dart';
import '../customer_call_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../notifications/controllers/notification_controller.dart';

class RideInProgressScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  const RideInProgressScreen({super.key, this.requestData});

  @override
  State<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends State<RideInProgressScreen> {
  String get _paymentLabel {
    final method =
        widget.requestData?['paymentMethod']?.toString().toUpperCase() ??
        'CASH';
    return method == 'CASH' || method == 'COD'
        ? 'Cash to Collect'
        : '$method Payment';
  }

  String get _displayDistance {
    if (_hasLiveLocation && _dynamicDistance != '-- km') {
      return _dynamicDistance;
    }
    final d =
        widget.requestData?['distanceKm'] ??
        widget.requestData?['distance'] ??
        widget.requestData?['booking']?['distanceKm'] ??
        widget.requestData?['booking']?['distance'];
    if (d == null) return _dynamicDistance;
    final value = d.toString().trim();
    return value.toLowerCase().contains('km') ||
            value.toLowerCase().contains('meter')
        ? value
        : '$value km';
  }

  String get _displayEta {
    if (_hasLiveLocation && _dynamicEta != 'Calculating...') {
      return _dynamicEta;
    }
    final t =
        widget.requestData?['estimatedDurationMin'] ??
        widget.requestData?['durationMinutes'] ??
        widget.requestData?['estimatedDuration'] ??
        widget.requestData?['duration'] ??
        widget.requestData?['etaMinutes'] ??
        widget.requestData?['reachBy'] ??
        widget.requestData?['booking']?['estimatedDurationMin'] ??
        widget.requestData?['booking']?['durationMinutes'] ??
        widget.requestData?['booking']?['estimatedDuration'] ??
        widget.requestData?['booking']?['duration'] ??
        widget.requestData?['booking']?['etaMinutes'];
    if (t == null) return _dynamicEta;
    final value = t.toString().trim();
    if (value.isEmpty || value == '--' || value.toLowerCase() == 'null') {
      return _dynamicEta;
    }
    return value.toLowerCase().contains('min') ? value : '$value min';
  }

  GoogleMapController? _mapController;

  // Noida Sector 63 (Drop destination)
  late final LatLng _pickupLatLng;
  late final LatLng _dropLatLng;
  LatLng _carLatLng = const LatLng(28.6050, 77.3600);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;
  int _simulationStep = 0;

  String _dynamicDistance = '-- km';
  String _dynamicEta = 'Calculating...';
  bool _hasLiveLocation = false;

  double _dragPosition = 0.0;
  bool _isFinished = false;
  bool _isDraggingSlider = false;
  bool _isCompletingRide = false;
  bool _hasMarkedDestinationReached = false;
  bool _isPreparingDeliveryOtp = false;
  bool _showDeliveryOtpFields = false;
  dynamic _reachedDestinationResponseBody;
  bool _isCancelledDialogShowing = false;
  bool _isReturningHome = false;

  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );

  @override
  void initState() {
    super.initState();
    Get.find<ActiveBookingController>().updateBooking(widget.requestData);
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
    _carLatLng = LatLng(pLat, pLng); // start from pickup

    final t =
        widget.requestData?['estimatedDurationMin'] ??
        widget.requestData?['durationMinutes'] ??
        widget.requestData?['estimatedDuration'] ??
        widget.requestData?['duration'] ??
        widget.requestData?['etaMinutes'] ??
        widget.requestData?['reachBy'] ??
        widget.requestData?['booking']?['estimatedDurationMin'] ??
        widget.requestData?['booking']?['durationMinutes'] ??
        widget.requestData?['booking']?['estimatedDuration'] ??
        widget.requestData?['booking']?['duration'] ??
        widget.requestData?['booking']?['etaMinutes'];
    final initialEta = t?.toString().trim();
    _dynamicEta =
        initialEta != null &&
            initialEta.isNotEmpty &&
            initialEta != '--' &&
            initialEta.toLowerCase() != 'null'
        ? (initialEta.toLowerCase().contains('min')
              ? initialEta
              : '$initialEta min')
        : 'Calculating...';

    final d =
        widget.requestData?['distanceKm'] ??
        widget.requestData?['distance'] ??
        widget.requestData?['booking']?['distanceKm'] ??
        widget.requestData?['booking']?['distance'];
    _dynamicDistance = d != null ? '$d km' : '-- km';

    _initMapItems();
    _startLocationSimulation();
    _setupSocketListeners();
  }

  @override
  void didUpdateWidget(covariant RideInProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.requestData, widget.requestData)) {
      Get.find<ActiveBookingController>().updateBooking(widget.requestData);
    }
  }

  Future<void> _prepareGoodsDeliveryOtp() async {
    if (widget.requestData?['isGoods'] != true ||
        _hasMarkedDestinationReached ||
        _isPreparingDeliveryOtp) {
      return;
    }
    final tripId =
        widget.requestData?['tripId']?.toString() ??
        widget.requestData?['bookingId']?.toString() ??
        widget.requestData?['booking']?['id']?.toString() ??
        widget.requestData?['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      _showRideError('Booking ID not found');
      return;
    }

    setState(() => _isPreparingDeliveryOtp = true);
    final service = GoodsDriverService();
    final response = await service.reachedDestination(tripId);
    if (!mounted) return;
    setState(() => _isPreparingDeliveryOtp = false);
    if (!service.succeeded(response)) {
      _showRideError(service.errorMessage(response));
      return;
    }

    _hasMarkedDestinationReached = true;
    _reachedDestinationResponseBody = response.body;
    CustomSnackbar.showSuccess(message: 'Delivery OTP sent to the customer');
  }

  void _setupSocketListeners() {
    SocketService.to.listenTo(SocketEvents.tripCancelled, _onTripCancelled);
    SocketService.to.listenTo(
      SocketEvents.tripCancelledByUser,
      _onTripCancelled,
    );
    SocketService.to.listenTo('cars:booking:cancelled', _onTripCancelled);
    SocketService.to.listenTo(
      SocketEvents.goodsBookingCancelled,
      _onTripCancelled,
    );
  }

  void _onTripCancelled(dynamic data) {
    if (!mounted || _isCancelledDialogShowing) return;
    _isCancelledDialogShowing = true;
    final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(14.w, 28.h, 14.w, 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFCA5A5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Trip Cancelled',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  payload?['message'] ??
                      'The customer has cancelled this ride.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    color: const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ABE4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  onPressed: () {
                    if (_isReturningHome) return;
                    _isReturningHome = true;
                    Navigator.pop(context);
                    Get.offAll(
                      () => const DriverNavigationScreen(initialIndex: 0),
                    );
                  },
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startLocationSimulation() {
    final tripId = widget.requestData?['tripId'];
    if (tripId != null) {
      LocationTrackingService().startTracking(
        tripId.toString(),
        isGoods: widget.requestData?['isGoods'] == true,
      );
    }

    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).then(_updateLiveTripMetrics).catchError((error) {
      debugPrint('Unable to get current trip location: $error');
    });

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          _updateLiveTripMetrics(position);
        });
  }

  void _updateLiveTripMetrics(Position position) {
    if (!mounted) return;
    final newPosition = LatLng(position.latitude, position.longitude);
    final straightLineMeters = Geolocator.distanceBetween(
      newPosition.latitude,
      newPosition.longitude,
      _dropLatLng.latitude,
      _dropLatLng.longitude,
    );

    // Until a road-route API value is available, account for normal road
    // curvature so the remaining distance is closer to navigation distance.
    final remainingKm = (straightLineMeters / 1000) * 1.18;
    final liveSpeedKmh = position.speed > 2 ? position.speed * 3.6 : 30.0;
    final etaMinutes = remainingKm <= 0.05
        ? 0
        : ((remainingKm / liveSpeedKmh) * 60).ceil().clamp(1, 999);

    setState(() {
      _hasLiveLocation = true;
      _carLatLng = newPosition;
      _dynamicDistance = remainingKm < 0.1
          ? '${(remainingKm * 1000).round()} m'
          : '${remainingKm.toStringAsFixed(1)} km';
      _dynamicEta = etaMinutes == 0 ? 'Arrived' : '$etaMinutes min';
      _initMapItems();
    });
    _fitMapBounds();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    SocketService.to.stopListening(
      SocketEvents.tripCancelled,
      _onTripCancelled,
    );
    SocketService.to.stopListening(
      SocketEvents.tripCancelledByUser,
      _onTripCancelled,
    );
    SocketService.to.stopListening('cars:booking:cancelled', _onTripCancelled);
    SocketService.to.stopListening(
      SocketEvents.goodsBookingCancelled,
      _onTripCancelled,
    );
    super.dispose();
  }

  void _initMapItems() {
    _markers = {
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
        polylineId: PolylineId('in_progress_route'),
        points: [_carLatLng, _dropLatLng],
        color: const Color(0xFF00ABE4),
        width: 5,
      ),
    };
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    double minLat = _dropLatLng.latitude < _carLatLng.latitude
        ? _dropLatLng.latitude
        : _carLatLng.latitude;
    double maxLat = _dropLatLng.latitude > _carLatLng.latitude
        ? _dropLatLng.latitude
        : _carLatLng.latitude;
    double minLng = _dropLatLng.longitude < _carLatLng.longitude
        ? _dropLatLng.longitude
        : _carLatLng.longitude;
    double maxLng = _dropLatLng.longitude > _carLatLng.longitude
        ? _dropLatLng.longitude
        : _carLatLng.longitude;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.003, minLng - 0.003),
      northeast: LatLng(maxLat + 0.003, maxLng + 0.003),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFAF4),
        body: Column(
          children: [
            // Custom Header (Ride In Progress)
            _buildHeader(),

            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    child: Column(
                      children: [
                        _buildCustomerPhotoCard(),
                        SizedBox(height: 12.h),

                        // Side-by-side addresses
                        _buildAddressesRow(),
                        SizedBox(height: 12.h),

                        // Map with overlay
                        _buildMapContainer(),
                        SizedBox(height: 12.h),

                        // Bottom Sheet details card
                        _buildRideProgressDetailsCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _customerImageUrl {
    String? image =
        widget.requestData?['customerImage']?.toString() ??
        widget.requestData?['customer']?['profile']?['profileImage']
            ?.toString() ??
        widget.requestData?['customer']?['profile']?['image']?.toString() ??
        widget.requestData?['customer']?['avatar']?.toString() ??
        widget.requestData?['customer']?['profileImage']?.toString() ??
        widget.requestData?['customer']?['image']?.toString() ??
        widget.requestData?['booking']?['customer']?['profile']?['profileImage']
            ?.toString() ??
        widget.requestData?['booking']?['customer']?['profile']?['image']
            ?.toString() ??
        widget.requestData?['booking']?['customer']?['avatar']?.toString() ??
        widget.requestData?['booking']?['customer']?['profileImage']
            ?.toString();
    if (image == null || image.trim().isEmpty) return null;
    image = image.trim();
    if (image.startsWith('http')) {
      final uri = Uri.tryParse(image);
      if (uri != null &&
          (image.contains('localhost') || image.contains('cars.carosa.in'))) {
        return '${ApiConstants.fileBaseUrl}${uri.path}';
      }
      return image;
    }
    return '${ApiConstants.fileBaseUrl}${image.startsWith('/') ? '' : '/'}$image';
  }

  Widget _buildCustomerPhotoCard() {
    return Obx(() {
      final customer = Get.find<ActiveBookingController>().customer.value;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            BookingCustomerAvatar(customer: customer, size: 46.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Customer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.h2.copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (customer?.isOnline != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      customer!.isOnline! ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: customer.isOnline!
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCustomerAvatar() {
    final imageUrl = _customerImageUrl;
    if (imageUrl == null) {
      return Image.asset(
        'assets/images/profile.png',
        width: 46.r,
        height: 46.r,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      imageUrl,
      width: 46.r,
      height: 46.r,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 46.r,
          height: 46.r,
          alignment: Alignment.center,
          color: const Color(0xFFE6F7FD),
          child: SizedBox(
            width: 18.r,
            height: 18.r,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/profile.png',
        width: 46.r,
        height: 46.r,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12.h,
        bottom: 12.h,
        left: 14.w,
        right: 14.w,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAE1),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFEF9E), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              // Back navigation is locked during active ride flow
            },
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride In Progress',
                  style: AppFonts.h2.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Trip is ongoing',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          // Call & Chat & Nav buttons
          Row(
            children: [
              _buildRoundActionButton(
                Icons.navigation_outlined,
                () async {
                  final double? lat = double.tryParse(
                    widget.requestData?['dropLatitude']?.toString() ??
                        widget.requestData?['dropLocation']?['latitude']
                            ?.toString() ??
                        widget.requestData?['drop']?['latitude']?.toString() ??
                        '',
                  );
                  final double? lng = double.tryParse(
                    widget.requestData?['dropLongitude']?.toString() ??
                        widget.requestData?['dropLocation']?['longitude']
                            ?.toString() ??
                        widget.requestData?['drop']?['longitude']?.toString() ??
                        '',
                  );
                  if (lat != null && lng != null) {
                    final Uri googleNavUri = Uri.parse(
                      'google.navigation:q=$lat,$lng&mode=d',
                    );
                    final Uri webNavUri = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                    );
                    if (await canLaunchUrl(googleNavUri)) {
                      await launchUrl(googleNavUri);
                    } else if (await canLaunchUrl(webNavUri)) {
                      await launchUrl(
                        webNavUri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
                backgroundColor: const Color(0xFF4285F4),
                iconColor: Colors.white,
              ),
              SizedBox(width: 8.w),
              _buildRoundActionButton(Icons.phone_outlined, () {
                Get.to(
                  () => CustomerCallScreen(requestData: widget.requestData),
                );
              }),
              SizedBox(width: 8.w),
              _buildRoundActionButton(Icons.chat_bubble_outline_rounded, () {
                Get.to(
                  () => CustomerChatScreen(requestData: widget.requestData),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundActionButton(
    IconData icon,
    VoidCallback onTap, {
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.textPrimary,
          size: 18.sp,
        ),
      ),
    );
  }

  Widget _buildAddressesRow() {
    final dropAddress =
        (widget.requestData?['dropAddress']?.toString().trim() ?? '');
    final bool hasValidDrop =
        dropAddress.isNotEmpty &&
        !dropAddress.contains('------') &&
        dropAddress != '-';

    return Row(
      children: [
        Expanded(
          child: _buildAddressCard(
            isPickup: true,
            label: 'Pick-up Location',
            address: widget.requestData?['pickupAddress'] ?? 'Pickup Location',
            borderColor: const Color(0xFF0F9F59).withOpacity(0.3),
          ),
        ),
        if (hasValidDrop) ...[
          SizedBox(width: 8.w),
          Expanded(
            child: _buildAddressCard(
              isPickup: false,
              label: 'Drop',
              address: dropAddress,
              borderColor: const Color(0xFF6366F1).withOpacity(0.3),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressCard({
    required bool isPickup,
    required String label,
    required String address,
    required Color borderColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.w),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(height: 2.h),
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPickup
                        ? const Color(0xFF0F9F59)
                        : const Color(0xFFDC3545),
                    width: 3.w,
                  ),
                  color: Colors.white,
                ),
              ),
              Container(
                width: 1.5.w,
                height: 28.h,
                color: const Color(0xFFE6E6E6),
              ),
            ],
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 11.sp,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContainer() {
    return Container(
      height: 180.h,
      width: double.infinity,
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _carLatLng,
                zoom: 14.0,
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
          // Compass Overlay
          Positioned(
            left: 12.w,
            top: 12.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F7FD),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.navigation_outlined,
                      color: const Color(0xFF00ABE4),
                      size: 12.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayDistance,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        _displayEta,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12.h,
            right: 12.w,
            child: GestureDetector(
              onTap: () async {
                final double? lat = double.tryParse(
                  widget.requestData?['dropLatitude']?.toString() ??
                      widget.requestData?['dropLocation']?['latitude']
                          ?.toString() ??
                      widget.requestData?['drop']?['latitude']?.toString() ??
                      '',
                );
                final double? lng = double.tryParse(
                  widget.requestData?['dropLongitude']?.toString() ??
                      widget.requestData?['dropLocation']?['longitude']
                          ?.toString() ??
                      widget.requestData?['drop']?['longitude']?.toString() ??
                      '',
                );
                if (lat != null && lng != null) {
                  final Uri googleNavUri = Uri.parse(
                    'google.navigation:q=$lat,$lng&mode=d',
                  );
                  final Uri webNavUri = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                  );
                  if (await canLaunchUrl(googleNavUri)) {
                    await launchUrl(googleNavUri);
                  } else if (await canLaunchUrl(webNavUri)) {
                    await launchUrl(
                      webNavUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me, color: Colors.white, size: 15.sp),
                    SizedBox(width: 4.w),
                    Text(
                      'Start Navigation',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideProgressDetailsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
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
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatDetail(
                'Estimated Time',
                _displayEta,
                '',
                const Color(0xFFE6F7FD),
                const Color(0xFF00ABE4),
                Icons.access_time,
              ),
              _buildStatDetail(
                'Distance',
                _displayDistance,
                'Total route',
                const Color(0xFFF3E8FF),
                const Color(0xFF8B5CF6),
                Icons.alt_route,
              ),
              _buildStatDetail(
                'Customer Pays',
                '₹ ${widget.requestData?['fare']?.toString() ?? '0'}',
                _paymentLabel,
                const Color(0xFFFEF3C7),
                const Color(0xFFF59E0B),
                Icons.currency_rupee,
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Drive Safe Banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9EE),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF0F9F59),
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Drive safe! Do not use phone while driving',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      color: const Color(0xFF0A703F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Payment Collection Info Banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                width: 1.w,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.w,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.currency_rupee,
                    color: const Color(0xFFF59E0B),
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please Collect Payment',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB45309), // Dark amber text
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Text(
                            '₹ ${widget.requestData?['fare']?.toString() ?? '0'}',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              widget.requestData?['paymentMethod'] ?? 'CASH',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // For Goods, reveal the inline OTP fields only after sliding.
          if (widget.requestData?['isGoods'] == true && _showDeliveryOtpFields)
            Column(
              children: [
                _buildOtpVerificationCard(),
                SizedBox(height: 12.h),
                _buildDeliveryOtpContinueButton(),
              ],
            )
          else
            _buildCompleteRideButton(),
        ],
      ),
    );
  }

  Widget _buildStatDetail(
    String label,
    String value,
    String subtext,
    Color bg,
    Color iconColor,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 10.sp),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 9.sp,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          if (subtext.isNotEmpty)
            Text(
              subtext,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 9.sp,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineProgress() {
    return Container(
      height: 77.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F3),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: const Color(0xFFE3F6FC), width: 1.w),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background connector lines
          Positioned(
            left: 30.w,
            right: 30.w,
            top: 22
                .h, // Perfectly aligned to the vertical center of the 28.w circles
            child: Row(
              children: [
                Expanded(
                  child: Container(height: 2.h, color: const Color(0xFF0F9F59)),
                ),
                Expanded(
                  child: Container(height: 2.h, color: const Color(0xFF0F9F59)),
                ),
                Expanded(
                  child: Container(height: 2.h, color: const Color(0xFF8D9590)),
                ),
              ],
            ),
          ),
          // Row of Nodes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimelineNode('Accepted', '9:32 AM', status: 'done'),
              _buildTimelineNode('Arrived', '9:42 AM', status: 'done'),
              _buildTimelineNode('In Progress', '9:32 AM', status: 'active'),
              _buildTimelineNode('Completed', '', status: 'future'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(
    String label,
    String time, {
    required String status,
  }) {
    Color textColor;
    Color nodeBgColor;
    Widget iconWidget;

    if (status == 'done') {
      textColor = const Color(0xFF2E3E37);
      nodeBgColor = const Color(0xFF0F9F59);
      iconWidget = Icon(
        Icons.check_circle_outline_outlined,
        color: Colors.white,
        size: 14.sp,
      );
    } else if (status == 'active') {
      textColor = const Color(0xFF0F9F59); // Green text for active
      nodeBgColor = const Color(0xFF0F9F59);
      iconWidget = Icon(Icons.directions_car, color: Colors.white, size: 14.sp);
    } else {
      textColor = const Color(0xFF6F7672);
      nodeBgColor = const Color(0xFFE2F1E8); // Light grey-green circle
      iconWidget = Icon(
        Icons.inventory_2_outlined,
        color: Colors.black,
        size: 14.sp,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(color: nodeBgColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: iconWidget,
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        if (time.isNotEmpty)
          Text(
            time,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
      ],
    );
  }

  Widget _buildCompleteRideButton() {
    return Container(
      width: double.infinity,
      height: 40.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: const Color(0xFF35AF30), width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxDrag = constraints.maxWidth - 40.w;
          return Stack(
            children: [
              Center(
                child: Text(
                  'Complete Ride',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _isDraggingSlider
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _dragPosition + 2.w,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () async {
                    if (_isFinished || _isCompletingRide) return;
                    setState(() {
                      _dragPosition = maxDrag;
                      _isFinished = true;
                      _isCompletingRide = true;
                    });
                    final completed = await _onCompleteRide();
                    if (!completed && mounted) {
                      setState(() {
                        _dragPosition = 0;
                        _isFinished = false;
                        _isCompletingRide = false;
                      });
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isFinished || _isCompletingRide) return;
                    setState(() {
                      _isDraggingSlider = true;
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_isFinished || _isCompletingRide) return;
                    setState(() => _isDraggingSlider = false);
                    if (_dragPosition > maxDrag * 0.7) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isFinished = true;
                        _isCompletingRide = true;
                      });
                      final completed = await _onCompleteRide();
                      if (!completed && mounted) {
                        setState(() {
                          _dragPosition = 0;
                          _isFinished = false;
                          _isCompletingRide = false;
                        });
                      }
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  onHorizontalDragCancel: () {
                    if (_isFinished || _isCompletingRide) return;
                    setState(() {
                      _isDraggingSlider = false;
                      _dragPosition = 0;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 3.h),
                    width: 32.h,
                    height: 32.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFF35AF30),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isCompletingRide
                        ? Padding(
                            padding: EdgeInsets.all(7.r),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOtpVerificationCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm with Customer',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              // OTP digits
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 44.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) {
                          if (event.runtimeType == RawKeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace) {
                            if (_controllers[index].text.isEmpty && index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                              _controllers[index - 1].clear();
                            }
                          }
                        },
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: _prepareGoodsDeliveryOtp,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              if (index < 3) {
                                _otpFocusNodes[index + 1].requestFocus();
                              } else {
                                FocusScope.of(context).unfocus();
                              }
                            } else if (index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(width: 16.w),
              // Resend OTP Circular Countdown
              Container(
                width: 40.w,
                height: 40.h,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF9EE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.security,
                    color: const Color(0xFF0F9F59),
                    size: 18.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _onCompleteRide() async {
    final bookingId =
        widget.requestData?['bookingId']?.toString() ??
        widget.requestData?['booking']?['id']?.toString() ??
        widget.requestData?['tripId']?.toString() ??
        widget.requestData?['id']?.toString() ??
        '';

    final tripId =
        widget.requestData?['tripId']?.toString() ??
        widget.requestData?['trip']?['id']?.toString() ??
        bookingId;

    print("=== COMPLETE RIDE DEBUG ===");
    print("bookingId: $bookingId");
    print("tripId: $tripId");
    print("requestData: ${widget.requestData}");

    // Ensure fresh GPS location update is acquired and sent before invoking complete API
    await LocationTrackingService().sendFreshLocationUpdate(tripId: tripId);

    final bookingService = BookingService();
    final response = await bookingService.completeTrip(bookingId);

    print("HTTP status: ${response.statusCode}");
    print("response body: ${response.body}");
    print("===========================");

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      SocketService.to.emitEvent('trip:completed', {'tripId': tripId, 'bookingId': bookingId});
      SocketService.to.emitEvent(SocketEvents.endTrip, {'tripId': tripId, 'bookingId': bookingId});
      await LocationTrackingService().stopTracking();
      if (!mounted) return false;
      await _openTripCompleted();
      return true;
    } else {
      String msg = (response.body is Map && response.body['message'] != null)
          ? response.body['message'].toString()
          : (response.statusText ?? 'Failed to complete ride');

      if (response.statusCode == 409 ||
          msg.contains('DRIVER_LOCATION_STALE') ||
          msg.contains('LOCATION_STALE')) {
        msg = 'GPS signal is weak or location is outdated. Please wait for a fresh location update and try again.';
      }

      if (mounted) _showRideError(msg);
      return false;
    }
  }

  Future<void> _submitDeliveryOtp() async {
    if (_isCompletingRide) return;
    final otp = _controllers.map((controller) => controller.text).join();
    if (otp.length != 4) return;
    setState(() => _isCompletingRide = true);
    final completed = await _completeGoodsRide(otp);
    if (!completed && mounted) {
      setState(() => _isCompletingRide = false);
    }
  }

  Widget _buildDeliveryOtpContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 42.h,
      child: ElevatedButton(
        onPressed: _isCompletingRide
            ? null
            : () {
                final otp = _controllers
                    .map((controller) => controller.text)
                    .join();
                if (otp.length != 4) {
                  CustomSnackbar.showWarning(
                    message: 'Enter complete 4-digit delivery OTP',
                  );
                  return;
                }
                _submitDeliveryOtp();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00ABE4),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF00ABE4).withOpacity(0.65),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isCompletingRide
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Continue',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Future<String?> _showDeliveryOtpDialog() async {
    for (final controller in _controllers) {
      controller.clear();
    }
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Container(
          padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFD8F3FC)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00ABE4).withOpacity(0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F7FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: const Color(0xFF00ABE4),
                  size: 22.sp,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Delivery OTP',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF263548),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Enter the 4-digit OTP shared by customer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 11.sp,
                  color: const Color(0xFF7C8795),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 48.w,
                    height: 48.h,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _otpFocusNodes[index],
                      autofocus: index == 0,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 21.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF00ABE4),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF1F7FA),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF00ABE4),
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 3) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        } else if (index == 3 && value.isNotEmpty) {
                          FocusScope.of(dialogContext).unfocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42.h,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFDCE4EA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42.h,
                      child: ElevatedButton(
                        onPressed: () {
                          final value = _controllers
                              .map((controller) => controller.text)
                              .join();
                          if (value.length != 4) {
                            CustomSnackbar.showWarning(
                              message: 'Enter complete 4-digit OTP',
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, value);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ABE4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: const Text('Verify & Complete'),
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

  Future<bool> _completeGoodsRide(String otp) async {
    final tripId =
        widget.requestData?['tripId']?.toString() ??
        widget.requestData?['bookingId']?.toString() ??
        widget.requestData?['booking']?['id']?.toString() ??
        widget.requestData?['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      _showRideError('Booking ID not found');
      return false;
    }

    final service = GoodsDriverService();
    if (!_hasMarkedDestinationReached) {
      final reachedResponse = await service.reachedDestination(tripId);
      if (!service.succeeded(reachedResponse)) {
        if (mounted) _showRideError(service.errorMessage(reachedResponse));
        return false;
      }
      _hasMarkedDestinationReached = true;
      _reachedDestinationResponseBody = reachedResponse.body;
    }
    if (!mounted) return false;

    final completeResponse = await service.complete(
      tripId,
      otp: otp,
      paymentType: widget.requestData?['paymentMethod']?.toString() ?? 'CASH',
      amount: _remainingFareFromResponse(_reachedDestinationResponseBody),
    );
    if (!service.succeeded(completeResponse)) {
      if (mounted) _showRideError(service.errorMessage(completeResponse));
      return false;
    }

    final completeTripId = tripId;
    SocketService.to.completeTrip(tripId: completeTripId);

    await LocationTrackingService().stopTracking();
    if (!mounted) return false;
    await _openTripCompleted();
    return true;
  }

  void _showRideError(String message) {
    if (!mounted) return;
    CustomSnackbar.showError(message: message);
  }

  Future<void> _openTripCompleted() async {
    if (!mounted) return;

    final reqMap = widget.requestData;
    final bookingId = (reqMap?['bookingId'] ?? reqMap?['tripId'] ?? reqMap?['id'])?.toString();
    final fare = reqMap?['fare'] ?? reqMap?['totalFare'] ?? reqMap?['driverPayout'];

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Ride Completed',
        body: 'Your ride has been completed successfully.',
        type: 'RIDE_COMPLETED',
        bookingId: bookingId,
        extraData: {'fare': fare},
      );
      NotificationController.to.addLocalNotification(
        title: 'Payment Received',
        body: 'Payment received for your completed ride.',
        type: 'PAYMENT_RECEIVED',
        bookingId: bookingId,
        extraData: {'fare': fare},
      );
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) =>
            TripCompletedScreen(requestData: widget.requestData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  double? _remainingFareFromResponse(dynamic body) {
    final data = body is Map && body['data'] is Map ? body['data'] : body;
    if (data is! Map) return null;
    final value = data['remainingFareAmount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
