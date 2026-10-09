import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../navigation/driver_navigation_screen.dart';
import '../../services/socket/socket_service.dart';
import '../../services/socket/socket_events.dart';
import '../../services/ride_service.dart';
import '../../services/location_tracking_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'controllers/active_booking_controller.dart';
import '../../services/booking_service.dart';

class TripCompletedScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  const TripCompletedScreen({super.key, this.requestData});

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  int _rating = 5;
  bool _isPaymentCompleted = false;
  bool _isCollectingCash = false;
  bool _isRefreshingPayment = false;
  late final Map<String, Function(dynamic)> _paymentEventHandlers;

  static const _paymentConfirmedStatuses = {
    'PAID',
    'PAID_FULL',
    'CAPTURED',
    'SUCCESS',
    'SUCCEEDED',
    'COMPLETED',
    'PAYMENT_COMPLETED',
    'CONFIRMED',
    'PAYMENT_CONFIRMED',
  };

  static const _bookingClosedStatuses = {
    'COMPLETED',
    'PAYMENT_COMPLETED',
    'BOOKING_COMPLETED',
    'FINISHED',
    'CLOSED',
  };

  Future<void> _collectCash() async {
    final bookingId = _bookingId ?? _tripId;
    if (bookingId == null || bookingId.isEmpty || _isCollectingCash) return;
    if (!_isCashPayment) {
      await _refreshPaymentStatus(showSuccess: true);
      return;
    }
    setState(() => _isCollectingCash = true);
    try {
      final idempotencyKey =
          'pay_${bookingId}_${DateTime.now().millisecondsSinceEpoch}';
      final response = await BookingService.to.confirmCashPayment(
        bookingId,
        idempotencyKey: idempotencyKey,
      );

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        setState(() => _isPaymentCompleted = true);
        _clearActiveBookingIfClosed();
        CustomSnackbar.showSuccess(message: 'Cash collected successfully!');
      } else {
        final body = response.body;
        final msg = body is Map ? (body['message'] ?? body['error']?['message'])?.toString() : null;
        CustomSnackbar.showError(message: msg ?? 'Failed to confirm cash collection');
      }
    } catch (e) {
      CustomSnackbar.showError(message: e.toString());
    } finally {
      if (mounted) setState(() => _isCollectingCash = false);
    }
  }

  Map<String, dynamic> get _booking {
    final nested = widget.requestData?['booking'];
    return nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(widget.requestData ?? const {});
  }

  Map<String, dynamic>? get _rideParticipant {
    for (final value in [
      widget.requestData?['customer'],
      widget.requestData?['user'],
      widget.requestData?['rider'],
      _booking['customer'],
      _booking['user'],
      _booking['rider'],
    ]) {
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  String? get _participantName => _firstText([
    Get.find<ActiveBookingController>().customer.value?.name,
    widget.requestData?['customerName'],
    _rideParticipant?['name'],
    _rideParticipant?['fullName'],
    _rideParticipant?['firstName'],
  ]);

  String? get _participantImage {
    final activeImage =
        Get.find<ActiveBookingController>().customer.value?.imageUrl;
    final profile = _rideParticipant?['profile'];
    return _firstText([
      activeImage,
      _rideParticipant?['profileImage'],
      _rideParticipant?['profileImageUrl'],
      _rideParticipant?['profilePhoto'],
      _rideParticipant?['profilePicture'],
      _rideParticipant?['avatar'],
      _rideParticipant?['image'],
      profile is Map ? profile['profileImage'] : null,
      profile is Map ? profile['image'] : null,
    ]);
  }

  double? get _participantRating {
    final raw =
        _rideParticipant?['ratingAverage'] ??
        _rideParticipant?['averageRating'] ??
        _rideParticipant?['rating'];
    return raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  }

  String? get _vehicleDetails {
    final vehicle = _booking['vehicle'] ?? widget.requestData?['vehicle'];
    if (vehicle is Map) {
      return _firstText([
        vehicle['displayName'],
        [
          vehicle['make'],
          vehicle['model'],
          vehicle['registrationNumber'] ?? vehicle['vehicleNumber'],
        ].where((value) => _firstText([value]) != null).join(' • '),
        vehicle['name'],
        vehicle['type'],
      ]);
    }
    return _firstText([
      _booking['vehicleDetails'],
      _booking['vehicleType'],
      widget.requestData?['vehicleDetails'],
      widget.requestData?['vehicleType'],
    ]);
  }

  String? get _tripId => _firstText([
    widget.requestData?['tripId'],
    widget.requestData?['bookingId'],
    _booking['tripId'],
    _booking['bookingId'],
    _booking['id'],
    widget.requestData?['id'],
  ]);

  String? get _bookingId => _firstText([
    widget.requestData?['bookingId'],
    _booking['bookingId'],
    _booking['id'],
    widget.requestData?['id'],
    widget.requestData?['tripId'],
    _booking['tripId'],
  ]);

  String get _paymentMethod =>
      _firstText([
        widget.requestData?['paymentMethod'],
        widget.requestData?['paymentType'],
        widget.requestData?['payment'] is Map
            ? widget.requestData!['payment']['method']
            : null,
        widget.requestData?['latestPayment'] is Map
            ? widget.requestData!['latestPayment']['method']
            : null,
        widget.requestData?['payments'] is List &&
                (widget.requestData!['payments'] as List).isNotEmpty &&
                (widget.requestData!['payments'] as List).first is Map
            ? (widget.requestData!['payments'] as List).first['method']
            : null,
        _booking['paymentMethod'],
        _booking['paymentType'],
        _booking['payment'] is Map ? _booking['payment']['method'] : null,
        _booking['latestPayment'] is Map
            ? _booking['latestPayment']['method']
            : null,
        _booking['payments'] is List &&
                (_booking['payments'] as List).isNotEmpty &&
                (_booking['payments'] as List).first is Map
            ? (_booking['payments'] as List).first['method']
            : null,
      ])?.toUpperCase() ??
      'CASH';

  bool get _isCashPayment =>
      _paymentMethod == 'CASH' || _paymentMethod == 'COD';

  bool get _isOnlinePayment => !_isCashPayment;

  bool get _canLeaveCompletionScreen => _isPaymentCompleted;

  @override
  void initState() {
    super.initState();
    Get.find<ActiveBookingController>().updateBooking(widget.requestData);
    _isPaymentCompleted = _hasConfirmedPayment(widget.requestData);
    _paymentEventHandlers = {
      SocketEvents.paymentCompleted: _handlePaymentConfirmedEvent,
      'payment:completed': _handlePaymentConfirmedEvent,
      'booking:payment:confirmed': _handlePaymentConfirmedEvent,
      'booking:completed': _handlePaymentConfirmedEvent,
      'booking:session:closed': _handlePaymentConfirmedEvent,
      'payment:confirmed': _handlePaymentConfirmedEvent,
      'PAYMENT_CONFIRMED': _handlePaymentConfirmedEvent,
    };
    for (final entry in _paymentEventHandlers.entries) {
      SocketService.to.listenTo(entry.key, entry.value);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOnlinePayment && !_isPaymentCompleted) {
        _refreshPaymentStatus();
      }
    });
  }

  @override
  void dispose() {
    for (final entry in _paymentEventHandlers.entries) {
      SocketService.to.stopListening(entry.key, entry.value);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasConfirmedPayment(widget.requestData)) {
      _isPaymentCompleted = true;
    }
  }

  bool _hasConfirmedPayment(dynamic payload) {
    if (payload is! Map) return false;
    final envelope = Map<String, dynamic>.from(payload);
    final root = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : envelope;
    final nested = root['booking'];
    final booking = nested is Map ? Map<String, dynamic>.from(nested) : root;

    final paymentStatus = _firstText([
      root['paymentStatus'],
      root['payment_status'],
      root['payment'] is Map ? root['payment']['status'] : null,
      root['latestPayment'] is Map ? root['latestPayment']['status'] : null,
      root['payments'] is List &&
              (root['payments'] as List).isNotEmpty &&
              (root['payments'] as List).first is Map
          ? (root['payments'] as List).first['status']
          : null,
      booking['paymentStatus'],
      booking['payment_status'],
      booking['payment'] is Map ? booking['payment']['status'] : null,
      booking['latestPayment'] is Map ? booking['latestPayment']['status'] : null,
      booking['payments'] is List &&
              (booking['payments'] as List).isNotEmpty &&
              (booking['payments'] as List).first is Map
          ? (booking['payments'] as List).first['status']
          : null,
    ])?.toUpperCase();

    final bookingStatus = _firstText([
      root['status'],
      root['bookingStatus'],
      booking['status'],
      booking['bookingStatus'],
    ])?.toUpperCase();

    if (bookingStatus == 'PAYMENT_PENDING' ||
        bookingStatus == 'TRIP_COMPLETED' ||
        paymentStatus == 'PENDING' ||
        paymentStatus == 'PAYMENT_PENDING' ||
        paymentStatus == 'CREATED') {
      return false;
    }

    final isPaid = root['isPaid'] == true || booking['isPaid'] == true;
    final amountDue = double.tryParse(
      _firstText([
            root['remainingFareAmount'],
            root['amountDue'],
            booking['remainingFareAmount'],
            booking['amountDue'],
          ]) ??
          '',
    );

    return isPaid ||
        (paymentStatus != null &&
            _paymentConfirmedStatuses.contains(paymentStatus)) ||
        (bookingStatus != null && _bookingClosedStatuses.contains(bookingStatus)) ||
        amountDue == 0;
  }

  void _handlePaymentConfirmedEvent(dynamic data) {
    if (!mounted || !_eventMatchesCurrentTrip(data)) return;
    setState(() => _isPaymentCompleted = true);
    _clearActiveBookingIfClosed();
  }

  bool _eventMatchesCurrentTrip(dynamic data) {
    final currentId = _bookingId ?? _tripId;
    if (currentId == null || currentId.isEmpty) return true;
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return true;
    final envelope = Map<String, dynamic>.from(payload);
    final eventData = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : envelope;
    final meta = envelope['meta'] is Map
        ? Map<String, dynamic>.from(envelope['meta'] as Map)
        : const <String, dynamic>{};
    final booking = eventData['booking'];
    final eventId = _firstText([
      eventData['bookingId'],
      eventData['tripId'],
      eventData['id'],
      meta['bookingId'],
      meta['tripId'],
      booking is Map ? booking['id'] : null,
      booking is Map ? booking['bookingId'] : null,
      booking is Map ? booking['tripId'] : null,
    ]);
    return eventId == null || eventId == currentId;
  }

  Future<void> _refreshPaymentStatus({bool showSuccess = false}) async {
    final tripId = _bookingId ?? _tripId;
    if (tripId == null || tripId.isEmpty || _isRefreshingPayment) return;
    setState(() => _isRefreshingPayment = true);
    try {
      final response = await BookingService.to.getBookingDetails(tripId);
      final data = response.body is Map
          ? (response.body['data'] ?? response.body)
          : null;
      if (response.isOk && _hasConfirmedPayment(data)) {
        if (!mounted) return;
        setState(() => _isPaymentCompleted = true);
        _clearActiveBookingIfClosed();
        return;
      }
      if (showSuccess) {
        CustomSnackbar.showWarning(
          message:
              'Payment is still pending. Please wait for confirmation before going online.',
        );
      }
    } catch (e) {
      if (showSuccess) {
        CustomSnackbar.showError(message: 'Unable to refresh payment status');
      }
    } finally {
      if (mounted) setState(() => _isRefreshingPayment = false);
    }
  }

  void _clearActiveBookingIfClosed() {
    final tripId = _bookingId ?? _tripId;
    if (tripId != null && tripId.isNotEmpty) {
      Get.find<ActiveBookingController>().clear(bookingId: tripId);
    }
    unawaited(LocationTrackingService().stopTracking());
  }

  String _formatTime(dynamic timeValue, {bool isDrop = false}) {
    final strVal = timeValue?.toString().trim() ?? '';
    if (strVal.isNotEmpty && strVal != '--:--') {
      try {
        final dt = DateTime.tryParse(strVal);
        if (dt != null) {
          final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final minute = dt.minute.toString().padLeft(2, '0');
          final period = dt.hour >= 12 ? 'PM' : 'AM';
          return '$hour:$minute $period';
        }
        return strVal;
      } catch (_) {
        return strVal;
      }
    }

    final rawDate = isDrop
        ? (widget.requestData?['completedAt'] ??
              widget.requestData?['updatedAt'] ??
              widget.requestData?['dropTime'])
        : (widget.requestData?['startedAt'] ??
              widget.requestData?['createdAt'] ??
              widget.requestData?['pickupTime']);

    final rawStr = rawDate?.toString().trim() ?? '';
    if (rawStr.isNotEmpty && rawStr != '--:--') {
      try {
        final dt = DateTime.tryParse(rawStr);
        if (dt != null) {
          final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final minute = dt.minute.toString().padLeft(2, '0');
          final period = dt.hour >= 12 ? 'PM' : 'AM';
          return '$hour:$minute $period';
        }
      } catch (_) {}
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      body: Column(
        children: [
          // Custom Header
          _buildHeader(),

          // Scrollable Content
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Column(
                  children: [
                    // Trip Completed Status Card
                    _buildTripCompletedCard(),
                    SizedBox(height: 12.h),

                    // Customer Details Card
                    _buildCustomerCard(),
                    SizedBox(height: 12.h),

                    // Addresses Timeline Card
                    _buildAddressCard(),
                    SizedBox(height: 12.h),

                    if (_isPaymentCompleted) ...[
                      _buildCashSuccessBanner(),
                      SizedBox(height: 12.h),
                    ],

                    // Trip Earning Details Section
                    _buildTripEarningDetails(),
                    SizedBox(height: 12.h),

                    // Motivation Banner
                    _buildMotivationBanner(),
                    SizedBox(height: 12.h),

                    // Rating Card
                    _buildRatingCard(),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ),

          // Single completion action
          _buildBottomButtons(),
        ],
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
            onTap: () => Get.back(),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
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
                  'Trip Completed',
                  style: AppFonts.h2.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Great job! You've completed the trip.",
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
          // Safety First tag
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9EE),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: const Color(0xFF0F9F59).withOpacity(0.3),
                width: 1.w,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: const Color(0xFF0F9F59),
                  size: 10.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  'Safety First',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F9F59),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCompletedCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
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
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Color(0xFFEAF9EE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: const Color(0xFF0F9F59),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Completed',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Thank you for completing the trip',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 10.sp,
                    color: const Color(0xFF0F9F59),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Earnings',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              Text(
                '₹${widget.requestData?['fare'] ?? widget.requestData?['totalFare'] ?? widget.requestData?['booking']?['totalFare'] ?? widget.requestData?['booking']?['fare'] ?? '0'}',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00ABE4),
                ),
              ),
              Text(
                _isPaymentCompleted
                    ? 'Payment Received'
                    : (_isCashPayment ? 'Cash to Collect' : 'Payment Pending'),
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 11.sp,
                  color: const Color(0xFF0F9F59),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
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
        children: [
          Stack(
            children: [
              _ParticipantAvatar(imageUrl: _participantImage, radius: 20.r),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F9F59),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5.w),
                  ),
                ),
              ),
            ],
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
                      child: Text(
                        _participantName ?? 'Ride details unavailable',
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
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF9EE),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: const Color(0xFF0F9F59),
                            size: 10.sp,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            _participantRating?.toStringAsFixed(1) ?? 'New',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F9F59),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                if (_vehicleDetails != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7FD),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      _vehicleDetails!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        color: const Color(0xFF00ABE4),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                  _isPaymentCompleted ? 'Paid' : 'Cash to Collect',
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

  Widget _buildAddressCard() {
    return Container(
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
      child: Stack(
        children: [
          // Timeline connector line
          Positioned(
            left: 6.w,
            top: 16.h,
            bottom: 16.h,
            child: Container(width: 1.5.w, color: const Color(0xFFE6E6E6)),
          ),
          Column(
            children: [
              // Pickup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    margin: EdgeInsets.only(top: 2.h),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F9F59),
                        width: 3.w,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pick-up Location',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          () {
                            final p = widget.requestData?['booking']?['pickup'];
                            if (p is Map && p['address'] != null)
                              return p['address'].toString();
                            return (widget.requestData?['pickupAddress'] ??
                                    widget
                                        .requestData?['booking']?['pickupAddress'] ??
                                    'Pickup Location')
                                .toString();
                          }(),
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
                  Text(
                    _formatTime(
                      widget.requestData?['pickupTime'],
                      isDrop: false,
                    ),
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              // Drop
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    margin: EdgeInsets.only(top: 2.h),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFDC3545),
                        width: 3.w,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drop Location',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          () {
                            final d = widget.requestData?['booking']?['drop'];
                            if (d is Map && d['address'] != null)
                              return d['address'].toString();
                            return (widget.requestData?['dropAddress'] ??
                                    widget
                                        .requestData?['booking']?['dropAddress'] ??
                                    'Drop Location')
                                .toString();
                          }(),
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
                  Text(
                    _formatTime(widget.requestData?['dropTime'], isDrop: true),
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
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

  Widget _buildCashSuccessBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF9EE),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF0F9F59), size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: _isCashPayment ? 'Cash of ' : 'Payment of ',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF334155),
                    ),
                    children: [
                      TextSpan(
                        text:
                            '₹${widget.requestData?['fare'] ?? widget.requestData?['totalFare'] ?? widget.requestData?['booking']?['totalFare'] ?? widget.requestData?['booking']?['fare'] ?? '0'}',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F9F59),
                        ),
                      ),
                      TextSpan(
                        text: _isCashPayment
                            ? ' collected successfully'
                            : ' confirmed successfully',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F9F59),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _isCashPayment
                      ? 'Thank you for collecting the payment'
                      : 'Online payment has been confirmed',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripEarningDetails() {
    return Container(
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
            'Trip Earning Details',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(height: 12.h),
          _buildEarningRow(
            'Total Fare',
            '₹${widget.requestData?['fare'] ?? widget.requestData?['totalFare'] ?? widget.requestData?['booking']?['totalFare'] ?? widget.requestData?['booking']?['fare'] ?? '0'}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: isTotal ? 13.sp : 11.sp,
            fontWeight: FontWeight.w800,
            color: isTotal ? const Color(0xFF0F9F59) : const Color(0xFF94A3B8),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: isTotal ? 13.sp : 11.sp,
            fontWeight: FontWeight.w800,
            color: isTotal ? const Color(0xFF0F9F59) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF9EE),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF0F9F59), size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're doing great today!",
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F9F59),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
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
            _participantName == null
                ? 'How was your trip?'
                : 'How was your trip with $_participantName?',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            'Your rating helps us improve',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFB020),
                    size: 28.sp,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 17,
            offset: const Offset(0, -13),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isPaymentCompleted) ...[
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9F59),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),
                onPressed: _isCollectingCash || _isRefreshingPayment
                    ? null
                    : (_isCashPayment
                        ? _collectCash
                        : () => _refreshPaymentStatus(showSuccess: true)),
                child: _isCollectingCash || _isRefreshingPayment
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_outlined, color: Colors.white, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            _isCashPayment
                                ? 'Cash Collected'
                                : 'Refresh Payment Status',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 8.h),
          ],
          // Go Online Button
          SizedBox(
            width: double.infinity,
            height: 40.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canLeaveCompletionScreen
                    ? const Color(0xFF35AF30)
                    : const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
              onPressed: _canLeaveCompletionScreen ? _goToHome : _showPaymentPendingMessage,
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
                    'Go Online',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),

          // Back to Home Button
          SizedBox(
            width: double.infinity,
            height: 40.h,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0x1AFFC000),
                side: const BorderSide(color: Color(0x80FFC000), width: 1.0),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
              onPressed: _canLeaveCompletionScreen ? _goToHome : _showPaymentPendingMessage,
              child: Center(
                child: Text(
                  'Back to Home',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF9F00),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToHome() {
    if (!_canLeaveCompletionScreen) {
      _showPaymentPendingMessage();
      return;
    }
    final tripId = _tripId;
    if (tripId != null) {
      // The ride service can be removed when the completed trip route is
      // disposed. Review submission must never block navigation back home.
      try {
        final rideService = Get.isRegistered<RideService>()
            ? Get.find<RideService>()
            : RideService();
        unawaited(rideService.submitReview(tripId, _rating, null));
      } catch (error) {
        debugPrint('Unable to submit trip review: $error');
      }
    }
    Get.offAll(() => const DriverNavigationScreen(initialIndex: 0));
  }

  void _showPaymentPendingMessage() {
    CustomSnackbar.showWarning(
      message: _isCashPayment
          ? 'Please confirm cash collection before going online.'
          : 'Payment confirmation is pending. Please refresh after the customer pays.',
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.imageUrl, required this.radius});

  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: const Color(0xFFE2E8F0),
        child: url == null
            ? Icon(
                Icons.person_outline,
                size: radius,
                color: const Color(0xFF64748B),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_outline,
                  size: radius,
                  color: const Color(0xFF64748B),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Center(
                        child: SizedBox(
                          width: radius * .7,
                          height: radius * .7,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}
