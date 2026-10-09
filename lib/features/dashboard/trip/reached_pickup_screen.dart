import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_fonts.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/socket/socket_events.dart';
import '../../../services/ride_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ride_in_progress_screen.dart';
import '../customer_chat_screen.dart';
import '../../navigation/driver_navigation_screen.dart';
import '../../../services/goods_driver_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/location_tracking_service.dart';
import '../../../widgets/custom_snackbar.dart';
import '../controllers/active_booking_controller.dart';
import '../customer_call_screen.dart';

class ReachedPickupScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  const ReachedPickupScreen({super.key, this.requestData});

  @override
  State<ReachedPickupScreen> createState() => _ReachedPickupScreenState();
}

class _ReachedPickupScreenState extends State<ReachedPickupScreen> {
  String get _paymentLabel {
    final method =
        widget.requestData?['paymentMethod']?.toString().toUpperCase() ??
        'CASH';
    return method == 'CASH' || method == 'COD'
        ? 'Cash to Collect'
        : '$method Payment';
  }

  GoogleMapController? _mapController;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;

  late final LatLng _pickupLatLng;

  Set<Marker> _markers = {};

  // OTP inputs controller / values
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;

  double _dragPosition = 0.0;
  bool _isFinished = false;
  bool _isDraggingSlider = false;
  bool _isStartingRide = false;
  bool _isCancelledDialogShowing = false;
  bool _isReturningHome = false;

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

    _focusNodes = List.generate(4, (_) => FocusNode());
    _controllers = List.generate(4, (_) => TextEditingController());

    // final otpStr = widget.requestData?['otp']?.toString() ?? '';
    // if (otpStr.length == 4) {
    //   for (int i = 0; i < 4; i++) {
    //     _controllers[i].text = otpStr[i];
    //   }
    // }

    _initMapItems();
    _startWaitingTimer();
    _setupSocketListeners();
  }

  @override
  void didUpdateWidget(covariant ReachedPickupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.requestData, widget.requestData)) {
      Get.find<ActiveBookingController>().updateBooking(widget.requestData);
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    _waitingTimer?.cancel();
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
    ).whenComplete(() {
      if (mounted) _isCancelledDialogShowing = false;
    });
  }

  void _startWaitingTimer() {
    if (widget.requestData != null &&
        widget.requestData!.containsKey('arrivedAt') &&
        widget.requestData!['arrivedAt'] != null) {
      try {
        final arrivedTime = DateTime.parse(
          widget.requestData!['arrivedAt'].toString(),
        );
        final diff = DateTime.now().difference(arrivedTime);
        _waitingSeconds = diff.inSeconds > 0 ? diff.inSeconds : 0;
      } catch (e) {
        print('Error parsing arrivedAt: $e');
        _waitingSeconds = 0;
      }
    }

    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingSeconds++;
        });
      }
    });
  }

  void _initMapItems() {
    _markers = {
      Marker(
        markerId: MarkerId('pickup_arrived'),
        position: _pickupLatLng,
        infoWindow: InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    };
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
            // Custom Header (Reached Pickup)
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer card
                        _buildCustomerInfoCard(),
                        SizedBox(height: 12.h),

                        // Map showing arrived location
                        _buildMapContainer(),
                        SizedBox(height: 16.h),

                        // What's next timeline checklist
                        _buildWhatsNextSection(),
                        SizedBox(height: 16.h),

                        // Confirm OTP with Customer
                        _buildOtpVerificationCard(),
                        SizedBox(height: 16.h),

                        // Bottom slide / click action button
                        _buildStartRideButton(),
                        SizedBox(height: 12.h),

                        // Cancel Trip Button
                        _buildCancelTripButton(),
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
          // Back Button
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
                  'Reached Pickup',
                  style: AppFonts.h2.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'You have reached the pickup location',
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
          // Action Buttons
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

  Widget _buildMapContainer() {
    return Container(
      height: 150.h,
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
                target: _pickupLatLng,
                zoom: 15.0,
              ),
              markers: _markers,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),
          // Custom "You are here" label over map
          Positioned(
            left: 10.w,
            top: 10.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'You are here',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
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
                      widget.requestData?['pickup']?['latitude']?.toString() ??
                      '',
                );
                final double? lng = double.tryParse(
                  widget.requestData?['pickupLongitude']?.toString() ??
                      widget.requestData?['pickupLocation']?['longitude']
                          ?.toString() ??
                      widget.requestData?['pickup']?['longitude']?.toString() ??
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

  Widget _buildWhatsNextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's Next?",
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF334155),
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildChecklistItem(
              icon: Icons.person_outline,
              title: 'Wait for customer',
              subtitle: 'Customer will arrive\nshortly.',
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFF3E8FF),
            ),
            _buildChecklistItem(
              icon: Icons.lock_outline,
              title: 'Verify OTP',
              subtitle: 'Verify OTP start\nthe ride',
              iconColor: const Color(0xFF00ABE4),
              iconBg: const Color(0xFFE6F7FD),
            ),
            _buildChecklistItem(
              icon: Icons.directions_car_outlined,
              title: 'Start Ride',
              subtitle: 'Start the ride after\nOTP verification.',
              iconColor: const Color(0xFF0F9F59),
              iconBg: const Color(0xFFEAF9EE),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 9.sp,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index < 3 ? 7.w : 0),
                      child: Container(
                        width: 48.w,
                        height: 58.h,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 9.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: const Color(0xFFD7D7D7),
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2EFFFFFF),
                              blurRadius: 4,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: RawKeyboardListener(
                          focusNode:
                              FocusNode(), // Dummy focus node for listener
                          onKey: (event) {
                            if (event.runtimeType == RawKeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.backspace) {
                              if (_controllers[index].text.isEmpty &&
                                  index > 0) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index - 1]);
                              }
                            }
                          },
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFCC00),
                            ),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(1),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 3) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index + 1]);
                              } else if (value.isEmpty && index > 0) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index - 1]);
                              } else if (index == 3 && value.isNotEmpty) {
                                FocusScope.of(context).unfocus();
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(width: 16.w),
              // Resend OTP Circular Countdown
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 40.w,
                        height: 40.w,
                        child: CircularProgressIndicator(
                          value: (_waitingSeconds % 60) / 60,
                          strokeWidth: 2.w,
                          backgroundColor: const Color(0xFFFFF8E1),
                          color: const Color(0xFFFFCC00),
                        ),
                      ),
                      Text(
                        '${(_waitingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_waitingSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Resend OTP',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 10.sp,
                      color: const Color(0xFFFFCC00),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartRideButton() {
    return Container(
      width: double.infinity,
      height: 40.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: const Color(0xFFFFCC00), width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxDrag = constraints.maxWidth - 40.w;
          return Stack(
            children: [
              Center(
                child: Text(
                  'Start Ride',
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
                    if (_isFinished || _isStartingRide) return;
                    setState(() {
                      _dragPosition = maxDrag;
                      _isFinished = true;
                      _isStartingRide = true;
                    });
                    final started = await _onStartRide();
                    if (!started && mounted) {
                      setState(() {
                        _dragPosition = 0;
                        _isFinished = false;
                        _isStartingRide = false;
                      });
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isFinished || _isStartingRide) return;
                    setState(() {
                      _isDraggingSlider = true;
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_isFinished || _isStartingRide) return;
                    setState(() => _isDraggingSlider = false);
                    if (_dragPosition > maxDrag * 0.7) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isFinished = true;
                        _isStartingRide = true;
                      });
                      final started = await _onStartRide();
                      if (!started && mounted) {
                        setState(() {
                          _dragPosition = 0;
                          _isFinished = false;
                          _isStartingRide = false;
                        });
                      }
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  onHorizontalDragCancel: () {
                    if (_isFinished || _isStartingRide) return;
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
                      color: Color(0xFFFFCC00),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isStartingRide
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

  Widget _buildCancelTripButton() {
    return SizedBox(
      width: double.infinity,
      height: 40.h,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          backgroundColor: const Color(0xFFFEF2F2),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
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
    );
  }

  Future<bool> _onStartRide() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 4) {
      CustomSnackbar.showWarning(
        message: 'Please enter the 4-digit OTP provided by the customer.',
      );
      return false;
    }

    final tripId =
        widget.requestData?['tripId']?.toString() ??
        widget.requestData?['bookingId']?.toString() ??
        widget.requestData?['booking']?['id']?.toString() ??
        widget.requestData?['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      _showStartError('Trip ID not found');
      return false;
    }
    final isGoods = widget.requestData?['isGoods'] ?? false;
    bool success = false;
    String errorMessage = 'Invalid pickup OTP. Please enter the correct OTP.';

    try {
      await LocationTrackingService().sendFreshLocationUpdate(tripId: tripId);
      final bookingService = BookingService();
      final res = await bookingService.startTrip(tripId, otp);
      if (res.isOk) {
        success = true;
      } else {
        final body = res.body;
        if (body is Map && body['message'] != null) {
          errorMessage = body['message'].toString();
        }
        if (res.statusCode == 409 || errorMessage.contains('DRIVER_LOCATION_STALE')) {
          errorMessage = 'GPS signal is weak or location is outdated. Please wait for a fresh location update and try again.';
        }
      }
    } catch (e) {
      debugPrint('Start trip API error: $e');
    }

    if (!success) {
      CustomSnackbar.showError(
        message: errorMessage,
      );
      return false;
    }

    if (isGoods) {
      final service = GoodsDriverService();
      service.start(tripId);
    } else {
      print(
        '--- [SOCKET_IO] Driver starting trip: $tripId, emitting ${SocketEvents.tripStart} ---',
      );
      SocketService.to.startTrip(tripId: tripId, otp: otp);
    }

    if (!mounted) return true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) =>
            RideInProgressScreen(requestData: widget.requestData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      ),
    );
    return true;
  }

  void _showStartError(String message) {
    if (!mounted) return;
    CustomSnackbar.showError(message: message);
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
}
