import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../services/socket/socket_service.dart';
import '../../services/socket/socket_events.dart';
import '../../services/ride_service.dart';
import 'trip/reached_pickup_screen.dart';
import 'customer_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_tracking_service.dart';
import '../navigation/driver_navigation_screen.dart';
import '../../services/goods_driver_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/booking_service.dart';
import 'controllers/active_booking_controller.dart';
import 'customer_call_screen.dart';

class NavigateToPickupScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  const NavigateToPickupScreen({super.key, this.requestData});

  @override
  State<NavigateToPickupScreen> createState() => _NavigateToPickupScreenState();
}

class _NavigateToPickupScreenState extends State<NavigateToPickupScreen> {
  String get _paymentLabel {
    final method =
        widget.requestData?['paymentMethod']?.toString().toUpperCase() ??
        'CASH';
    return method == 'CASH' || method == 'COD'
        ? 'Cash to Collect'
        : '$method Payment';
  }

  GoogleMapController? _mapController;

  late final LatLng _pickupLatLng;
  LatLng _carLatLng = const LatLng(28.5900, 77.3500);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _isFinished = false;
  bool _isCancelledDialogShowing = false;
  bool _isReturningHome = false;
  int _simulationStep = 0;

  String _dynamicDistance = '-- km';
  String _dynamicEta = '-- min';

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
    _pickupLatLng = LatLng(pLat, pLng);
    _carLatLng = LatLng(pLat - 0.02, pLng - 0.02); // start slightly away

    final d =
        widget.requestData?['driverDistanceKm'] ??
        widget.requestData?['initialDriverToPickupDistanceKm'] ??
        widget.requestData?['booking']?['driverDistanceKm'] ??
        widget.requestData?['booking']?['initialDriverToPickupDistanceKm'] ??
        widget.requestData?['distanceKm'] ??
        widget.requestData?['distance'] ??
        widget.requestData?['booking']?['distanceKm'] ??
        widget.requestData?['booking']?['distance'];
    final distanceKm = double.tryParse(
      d?.toString().replaceAll(
            RegExp(r'\s*km\s*$', caseSensitive: false),
            '',
          ) ??
          '',
    );
    _dynamicDistance = distanceKm != null
        ? '${distanceKm.toStringAsFixed(1)} km'
        : '-- km';

    final t =
        widget.requestData?['estimatedDurationMin'] ??
        widget.requestData?['duration'] ??
        widget.requestData?['etaMinutes'] ??
        widget.requestData?['reachBy'] ??
        widget.requestData?['booking']?['estimatedDurationMin'] ??
        widget.requestData?['booking']?['duration'] ??
        widget.requestData?['booking']?['etaMinutes'];
    final etaMinutes = double.tryParse(
      t?.toString().replaceAll(
            RegExp(r'\s*min\s*$', caseSensitive: false),
            '',
          ) ??
          '',
    );
    _dynamicEta = etaMinutes != null
        ? '${etaMinutes.ceil()} min'
        : distanceKm != null
        ? '${(distanceKm * 2).ceil().clamp(1, 999)} min'
        : '-- min';

    _initMapItems();
    _startLocationSimulation();
    _setupSocketListeners();
  }

  @override
  void didUpdateWidget(covariant NavigateToPickupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.requestData, widget.requestData)) {
      Get.find<ActiveBookingController>().updateBooking(widget.requestData);
    }
  }

  void _setupSocketListeners() {
    final tripId = widget.requestData?['tripId'] ?? widget.requestData?['bookingId'] ?? widget.requestData?['booking']?['id'];
    if (tripId != null) {
      SocketService.to.headingToPickup(tripId: tripId.toString());
    }
    SocketService.to.listenTo(SocketEvents.tripCancelled, _onTripCancelled);
    SocketService.to.listenTo(
      SocketEvents.tripCancelledByUser,
      _onTripCancelled,
    );
    SocketService.to.listenTo('booking:cancelled', _onTripCancelled);
    SocketService.to.listenTo('goods.booking.cancelled', _onTripCancelled);
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
                      'The customer has cancelled this trip.',
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
      LocationTrackingService().startTracking(tripId);
    }

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (!mounted) return;
          final newPos = LatLng(position.latitude, position.longitude);
          final double distInMeters = Geolocator.distanceBetween(
            newPos.latitude,
            newPos.longitude,
            _pickupLatLng.latitude,
            _pickupLatLng.longitude,
          );
          final distKm = distInMeters / 1000.0;
          final etaMin = (distKm * 2).ceil(); // Assuming ~30km/h
          setState(() {
            _carLatLng = newPos;
            _dynamicDistance = '${distKm.toStringAsFixed(1)} km';
            _dynamicEta = '$etaMin min';
            _initMapItems();
          });
        });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
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
        markerId: MarkerId('pickup'),
        position: _pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
      Marker(
        markerId: MarkerId('car'),
        position: _carLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: PolylineId('route_to_pickup'),
        points: [_carLatLng, _pickupLatLng],
        color: const Color(0xFF00ABE4),
        width: 5,
      ),
    };
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    double minLat = _pickupLatLng.latitude < _carLatLng.latitude
        ? _pickupLatLng.latitude
        : _carLatLng.latitude;
    double maxLat = _pickupLatLng.latitude > _carLatLng.latitude
        ? _pickupLatLng.latitude
        : _carLatLng.latitude;
    double minLng = _pickupLatLng.longitude < _carLatLng.longitude
        ? _pickupLatLng.longitude
        : _carLatLng.longitude;
    double maxLng = _pickupLatLng.longitude > _carLatLng.longitude
        ? _carLatLng.longitude
        : _carLatLng.longitude;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.005, minLng - 0.005),
      northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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
            // Custom Header
            _buildHeader(),

            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Column(
                    children: [
                      // Driver/Customer Info Block
                      _buildCustomerInfoCard(),
                      SizedBox(height: 12.h),

                      // Side-by-side Pickup and Drop address cards
                      _buildAddressesRow(),
                      SizedBox(height: 12.h),

                      // Interactive Map Container
                      Expanded(child: _buildMapContainer()),
                      SizedBox(height: 12.h),

                      // Pickup Info Block (Bottom)
                      _buildPickupInfoCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
          // Circular Back Button
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
                  'Navigate to Pickup',
                  style: AppFonts.h2.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Reach the pickup location',
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
          // Header Action Buttons
          Row(
            children: [
              _buildRoundActionButton(
                Icons.navigation_outlined,
                () async {
                  final double? lat = double.tryParse(
                    widget.requestData?['pickupLatitude']?.toString() ??
                        widget.requestData?['pickupLocation']?['latitude']
                            ?.toString() ??
                        widget.requestData?['pickup']?['latitude']
                            ?.toString() ??
                        '',
                  );
                  final double? lng = double.tryParse(
                    widget.requestData?['pickupLongitude']?.toString() ??
                        widget.requestData?['pickupLocation']?['longitude']
                            ?.toString() ??
                        widget.requestData?['pickup']?['longitude']
                            ?.toString() ??
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

  Widget _buildCustomerInfoCard() {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(
            () => BookingCustomerAvatar(
              customer: Get.find<ActiveBookingController>().customer.value,
              size: 44.r,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Obx(
                        () => Text(
                          Get.find<ActiveBookingController>()
                                  .customer
                                  .value
                                  ?.name ??
                              'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _paymentLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 11.sp,
                    color: const Color(0xFF0F9F59),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            address: widget.requestData?['pickupAddress'] ?? 'Pickup Address',
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
          // Dot indicator
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFE6E6E6), width: 1.w),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _carLatLng,
                zoom: 13.5,
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
            Positioned(
              top: 10.h,
              right: 10.w,
              child: GestureDetector(
                onTap: () async {
                  final double? lat = double.tryParse(
                    widget.requestData?['pickupLatitude']?.toString() ??
                        widget.requestData?['pickupLocation']?['latitude']
                            ?.toString() ??
                        widget.requestData?['pickup']?['latitude']
                            ?.toString() ??
                        '',
                  );
                  final double? lng = double.tryParse(
                    widget.requestData?['pickupLongitude']?.toString() ??
                        widget.requestData?['pickupLocation']?['longitude']
                            ?.toString() ??
                        widget.requestData?['pickup']?['longitude']
                            ?.toString() ??
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 7.h,
                  ),
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
      ),
    );
  }

  Widget _buildPickupInfoCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup information',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          SizedBox(height: 12.h),

          // Three metric items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(
                label: 'Reach by',
                value: _dynamicEta,
                icon: Icons.access_time,
                iconColor: const Color(0xFF00ABE4),
                iconBg: const Color(0xFFE6F7FD),
              ),
              _buildMetricItem(
                label: 'Distance',
                value: _dynamicDistance,
                icon: Icons.alt_route,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFFF3E8FF),
              ),
              _buildMetricItem(
                label: 'Customer Pays',
                value: '₹ ${widget.requestData?['fare']?.toString() ?? '0'}',
                icon: Icons.currency_rupee,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFEF3C7),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Info Banner (Exact Ditto Figma Specs)
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 62.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F3),
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(color: const Color(0xFFE3F6FC), width: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28.r,
                  height: 28.r,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDF2E4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: const Color(0xFF0F9F59),
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        height: 1.3,
                        color: const Color(0xFF575757),
                      ),
                      children: const [
                        TextSpan(text: 'Please reach pickup location and tap '),
                        TextSpan(
                          text: '"Arrived at Pickup"',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F9F59),
                          ),
                        ),
                        TextSpan(text: ' to inform the customer.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Bottom Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 40.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final tripId =
                        (widget.requestData?['tripId'] ?? widget.requestData?['id'])?.toString() ?? 'TRIP_MOCK_123';
                    final bookingId =
                        (widget.requestData?['bookingId'] ?? widget.requestData?['booking']?['id'] ?? widget.requestData?['id'] ?? tripId)?.toString() ?? tripId;
                    final isGoods = widget.requestData?['isGoods'] == true ||
                        widget.requestData?['bookingType'] == 'GOODS' ||
                        widget.requestData?['moduleType'] == 'GOODS';

                    try {
                      await LocationTrackingService().sendFreshLocationUpdate(tripId: tripId);
                      if (isGoods) {
                        final service = GoodsDriverService();
                        await service.arrived(bookingId);
                      } else {
                        final service = BookingService();
                        await service.arriveAtPickup(bookingId);
                        SocketService.to.driverArrived(tripId: tripId);
                      }
                    } catch (e) {
                      print('Error reporting arrival: $e');
                    }

                    if (!context.mounted) return;
                    Get.off(
                      () =>
                          ReachedPickupScreen(requestData: widget.requestData),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Arrived at Pickup',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 40.h,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.5,
                    ),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                  onPressed: () {
                    _showCancelReasonBottomSheet(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: const Color(0xFFEF4444),
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Cancel Trip',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 16.sp),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 10.sp,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTripCancelledPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'The trip has been successfully cancelled.',
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
        );
      },
    );
  }

  void _showCancelReasonBottomSheet(BuildContext context) {
    final reasons = [
      'Customer not reachable',
      'Customer denied to pay',
      'Vehicle broke down',
      'Long waiting time',
      'Other',
    ];
    String? selectedReason;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 16.h,
                bottom: MediaQuery.of(context).padding.bottom + 20.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 20.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.w,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cancel_outlined,
                          color: const Color(0xFFEF4444),
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Cancel Trip?',
                        style: AppFonts.h2.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: const Color(0xFFEF4444),
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Cancelling too many trips may affect your driver rating.',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              color: const Color(0xFF991B1B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Select Cancellation Reason:',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ...reasons.map((reason) {
                    final isSelected = selectedReason == reason;
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {
                          selectedReason = reason;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFEF2F2)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFEF4444)
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey.shade400,
                              size: 20.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 13.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46.h,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Keep Trip',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: SizedBox(
                          height: 46.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () {
                              if (selectedReason == null || selectedReason!.trim().isEmpty) {
                                CustomSnackbar.showWarning(
                                  message: 'Please select a cancellation reason.',
                                );
                                return;
                              }
                              Navigator.pop(context);
                              _processCancelTrip(selectedReason!);
                            },
                            child: Text(
                              'Confirm Cancel',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processCancelTrip(String reason) async {
    if (reason.trim().isEmpty) {
      CustomSnackbar.showWarning(message: 'Please select a cancellation reason.');
      return;
    }
    final tripId =
        widget.requestData?['tripId']?.toString() ??
        widget.requestData?['bookingId']?.toString() ??
        widget.requestData?['booking']?['id']?.toString() ??
        widget.requestData?['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      CustomSnackbar.showError(message: 'Booking ID not found');
      return;
    }

    final payload = {
      'tripId': tripId,
      'bookingId': tripId,
      'reason': reason,
      'cancelledBy': 'DRIVER',
    };

    // Emit socket event for instant real-time notification
    SocketService.to.emitEvent('booking:cancel', payload);
    SocketService.to.emitEvent(
      widget.requestData?['isGoods'] == true
          ? SocketEvents.goodsBookingCancel
          : SocketEvents.cancelTrip,
      payload,
    );

    // Call REST cancellation endpoint to ensure DB status is updated & redispatched
    try {
      final rideService = Get.isRegistered<RideService>()
          ? Get.find<RideService>()
          : Get.put(RideService());
      await rideService.cancelRide(tripId, reason);
    } catch (e) {
      print('=== ERROR CALLING CANCEL RIDE API ===\n$e');
    }

    if (mounted) {
      _showTripCancelledPopup(context);
    }
  }
}
