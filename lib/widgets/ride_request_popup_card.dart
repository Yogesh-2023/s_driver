import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_fonts.dart';

class RideRequestPopupCard extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  final int remainingSeconds;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isSubmitting;
  final int totalRequests;
  final int currentIndex;
  final VoidCallback? onPreviousRequest;
  final VoidCallback? onNextRequest;

  const RideRequestPopupCard({
    super.key,
    required this.requestData,
    required this.remainingSeconds,
    this.onAccept,
    this.onReject,
    this.isSubmitting = false,
    this.totalRequests = 1,
    this.currentIndex = 0,
    this.onPreviousRequest,
    this.onNextRequest,
  });

  @override
  State<RideRequestPopupCard> createState() => _RideRequestPopupCardState();
}

class _RideRequestPopupCardState extends State<RideRequestPopupCard> {
  GoogleMapController? _mapController;

  late final LatLng _pickupLatLng;
  late final LatLng _dropLatLng;
  late final Set<Marker> _markers;
  late final Set<Polyline> _polylines;

  @override
  void initState() {
    super.initState();
    _initMapCoordinates();
  }

  @override
  void didUpdateWidget(covariant RideRequestPopupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestData != widget.requestData) {
      _initMapCoordinates();
    }
  }

  void _initMapCoordinates() {
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

    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: _dropLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_pickupLatLng, _dropLatLng],
        color: const Color(0xFFFFC000),
        width: 4,
      ),
    };
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    double minLat =
        _pickupLatLng.latitude < _dropLatLng.latitude
            ? _pickupLatLng.latitude
            : _dropLatLng.latitude;
    double maxLat =
        _pickupLatLng.latitude > _dropLatLng.latitude
            ? _pickupLatLng.latitude
            : _dropLatLng.latitude;
    double minLng =
        _pickupLatLng.longitude < _dropLatLng.longitude
            ? _pickupLatLng.longitude
            : _dropLatLng.longitude;
    double maxLng =
        _pickupLatLng.longitude > _dropLatLng.longitude
            ? _pickupLatLng.longitude
            : _dropLatLng.longitude;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.008, minLng - 0.008),
      northeast: LatLng(maxLat + 0.008, maxLng + 0.008),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 35));
  }

  String _formatFare() {
    final rawFare =
        widget.requestData?['fare'] ??
        widget.requestData?['totalFare'] ??
        widget.requestData?['estimatedFare'] ??
        '0';
    final parsed = double.tryParse(rawFare.toString());
    if (parsed != null) {
      // Format nicely without trailing zeros if integer, or 1 decimal place
      if (parsed == parsed.roundToDouble()) {
        return parsed.toStringAsFixed(0);
      }
      return parsed.toStringAsFixed(1);
    }
    return rawFare.toString();
  }

  String _formatDistance() {
    final rawDist =
        widget.requestData?['distance'] ??
        widget.requestData?['distanceKm'] ??
        '0';
    final distStr = rawDist.toString().replaceAll(
      RegExp(r'\s*km\s*$', caseSensitive: false),
      '',
    );
    final parsed = double.tryParse(distStr);
    if (parsed != null) {
      return parsed == parsed.roundToDouble()
          ? parsed.toStringAsFixed(0)
          : parsed.toStringAsFixed(1);
    }
    return distStr;
  }

  @override
  Widget build(BuildContext context) {
    final fareStr = _formatFare();
    final distStr = _formatDistance();
    final pickupAddress =
        widget.requestData?['pickupAddress']?.toString().trim() ??
        'Pickup Location';
    final dropAddress =
        widget.requestData?['dropAddress']?.toString().trim() ??
        widget.requestData?['destinationAddress']?.toString().trim() ??
        'Your Destination';

    final customerName =
        widget.requestData?['customerName']?.toString().trim() ??
        widget.requestData?['senderName']?.toString().trim() ??
        'Customer';

    final bool isScheduled = widget.requestData?['isScheduled'] == true ||
        widget.requestData?['isScheduled'] == 'true' ||
        widget.requestData?['bookingType'] == 'SCHEDULED' ||
        widget.requestData?['type'] == 'SCHEDULED' ||
        widget.requestData?['scheduledAt'] != null;
    final String? scheduledAtStr = widget.requestData?['scheduledAt']?.toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark navy background
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isScheduled ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          width: isScheduled ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isScheduled) ...[
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: const Color(0xFF38BDF8),
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCHEDULED RIDE REQUEST',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF38BDF8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (scheduledAtStr != null && scheduledAtStr.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            _formatScheduledDateTime(scheduledAtStr),
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.totalRequests > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC000),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'Request ${widget.currentIndex + 1} of ${widget.totalRequests}',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: widget.currentIndex > 0
                            ? const Color(0xFFFFC000)
                            : Colors.white24,
                        size: 22.sp,
                      ),
                      onPressed: widget.currentIndex > 0
                          ? widget.onPreviousRequest
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: widget.currentIndex < widget.totalRequests - 1
                            ? const Color(0xFFFFC000)
                            : Colors.white24,
                        size: 22.sp,
                      ),
                      onPressed: widget.currentIndex < widget.totalRequests - 1
                          ? widget.onNextRequest
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10.h),
          ],
          // 1. Top Header Row: Ride Fare (left) & Expiry Timer (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top-Left: Fare
              Text(
                '₹$fareStr',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFC000), // Yellow accent color
                  height: 1.1,
                ),
              ),
              // Top-Right: Expiry Timer
              Builder(
                builder: (context) {
                  final isUrgent = widget.remainingSeconds <= 10;
                  final timerBg = isUrgent ? const Color(0xFFDC3545) : const Color(0xFF1E293B);
                  final timerBorder = isUrgent ? const Color(0xFFDC3545) : const Color(0xFF334155);
                  final timerIconColor = isUrgent ? Colors.white : const Color(0xFFFFC000);

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: timerBg,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: timerBorder, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: timerIconColor,
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${widget.remainingSeconds.clamp(0, 60)}',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // 2. Pickup & Destination + Map Preview Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Pickup & Destination Timeline
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pickup Location Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 3.h),
                          width: 10.w,
                          height: 10.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFC000),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pickup Location',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFFC000),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                pickupAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Connector vertical line
                    Padding(
                      padding: EdgeInsets.only(
                        left: 4.w,
                        top: 4.h,
                        bottom: 4.h,
                      ),
                      child: Container(
                        width: 2.w,
                        height: 22.h,
                        color: const Color(0xFF334155),
                      ),
                    ),

                    // Destination Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 3.h),
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC000),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Destination',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFFC000),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                dropAddress,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Right: Google Map Preview
              Expanded(
                flex: 8,
                child: Container(
                  height: 120.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _pickupLatLng,
                        zoom: 12,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _fitMapBounds();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // 3. Distance & Fare Section with New Request Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                // Distance Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$distStr km',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 24.w),
                // Fare Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fare',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₹$fareStr',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFC000),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // New Request Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC000).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: const Color(0xFFFFC000),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    customerName.isNotEmpty ? customerName : 'New Request',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFC000),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // 4. Action Buttons Row: Reject (dark gray) & Accept Ride (yellow)
          Row(
            children: [
              // LEFT: Reject button
              Expanded(
                child: SizedBox(
                  height: 40.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF262F3D),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    onPressed: widget.isSubmitting ? null : widget.onReject,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Reject',
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
                ),
              ),
              SizedBox(width: 10.w),
              // RIGHT: Accept Ride button
              Expanded(
                child: SizedBox(
                  height: 40.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC000),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: widget.isSubmitting ? null : widget.onAccept,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: const Color(0xFF0F172A),
                            size: 20.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            widget.isSubmitting ? 'Accepting...' : 'Accept Ride',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
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
    );
  }

  String _formatScheduledDateTime(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final date = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$date • $hour:$minute $period';
    } catch (_) {
      return isoStr;
    }
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
}
