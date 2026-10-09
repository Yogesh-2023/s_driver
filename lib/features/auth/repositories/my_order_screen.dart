import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_fonts.dart';
import '../../../widgets/custom_snackbar.dart';
import 'booking_controllers.dart';
import 'booking_history_model.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final BookingDetailsController _controller = Get.put(
    BookingDetailsController(),
  );

  @override
  void initState() {
    super.initState();
    _controller.fetchBookingDetails(widget.bookingId);
  }

  String _formatLabel(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    return value
        .trim()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return '₹ 0.0';
    try {
      if (amount == amount.roundToDouble()) {
        return '₹ ${amount.toStringAsFixed(0)}';
      }
      return '₹ ${amount.toStringAsFixed(1)}';
    } catch (_) {
      return '₹ ${amount.toStringAsFixed(1)}';
    }
  }

  Color _getStatusColor(String? status) {
    final s = status?.toUpperCase() ?? '';
    if (s == 'COMPLETED') return const Color(0xFF10B981);
    if (s == 'CANCELLED' || s == 'REJECTED' || s == 'DECLINED' || s == 'EXPIRED') {
      return const Color(0xFFEF4444);
    }
    if (s == 'ONGOING' || s == 'IN_PROGRESS' || s == 'ACCEPTED') {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            /// 1. TOP APP BAR
            _buildCustomHeader(context),

            /// MAIN SCROLLABLE BODY
            Expanded(
              child: Obx(() {
                if (_controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final booking = _controller.bookingDetails.value;
                if (booking == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_late_outlined,
                            size: 48.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            "Booking details unavailable",
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                              fontSize: 15.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// 2. RIDE SUMMARY CARD
                          _buildTripSummaryCard(booking),
                          SizedBox(height: 12.h),

                          /// 3. CUSTOMER CARD (SEPARATE CARD)
                          _buildCustomerCard(booking),
                          SizedBox(height: 12.h),

                          /// 4. TRIP ROUTE CARD (COMBINED PICKUP + DROP)
                          _buildTripRouteCard(booking),
                          SizedBox(height: 12.h),

                          /// 5. FARE BREAKDOWN CARD
                          _buildFareBreakdownCard(booking),
                          SizedBox(height: 12.h),

                          /// 6. RIDE INFORMATION CARD
                          _buildRideInformationCard(booking),
                          SizedBox(height: 16.h),

                          /// 7. BOTTOM ACTIONS
                          _buildBottomActions(context),
                          SizedBox(height: 14.h),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. TOP APP BAR
  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: const Color(0xFF0F172A),
                size: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Ride Details',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// 2. RIDE SUMMARY CARD (Time, CRN, Total Fare, Status Pill)
  Widget _buildTripSummaryCard(BookingHistoryModel booking) {
    String formattedTime = "10:20 AM";
    if (booking.createdAt != null && booking.createdAt!.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(booking.createdAt!).toLocal();
        formattedTime = DateFormat('hh:mm a').format(dt);
      } catch (_) {
        formattedTime = booking.createdAt!;
      }
    }

    final displayCrn = (booking.bookingId != null && booking.bookingId!.isNotEmpty)
        ? booking.bookingId!
        : (booking.id != null
            ? (booking.id!.length >= 10
                ? booking.id!.substring(0, 10).toUpperCase()
                : booking.id!.toUpperCase())
            : 'FLT-1001');

    final double totalFare = booking.totalFare ?? 1254.0;
    final String statusStr = booking.status ?? 'COMPLETED';
    final Color statusColor = _getStatusColor(statusStr);

    return _buildContainerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 14.sp,
                          color: const Color(0xFF64748B),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "CRN: $displayCrn",
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),

              /// HIGHLIGHTED FARE BADGE
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.w),
                ),
                child: Text(
                  _formatCurrency(totalFare),
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          /// STATUS BADGE PILL
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(
                  _formatLabel(statusStr),
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. CUSTOMER SECTION (SEPARATE CARD)
  Widget _buildCustomerCard(BookingHistoryModel booking) {
    final userName = booking.user?.name;
    final senderName = booking.pickup?.senderName;
    final String customerName = (userName != null && userName.trim().isNotEmpty)
        ? userName
        : ((senderName != null && senderName.trim().isNotEmpty)
            ? senderName
            : "Customer");

    final String vehicleName = _formatLabel(booking.vehicleType ?? '');
    final String serviceName = _formatLabel(booking.pickup?.category ?? 'Delivery');

    final String categoryBadge = vehicleName.isNotEmpty && serviceName.isNotEmpty
        ? "$vehicleName • $serviceName"
        : (vehicleName.isNotEmpty ? vehicleName : (serviceName.isNotEmpty ? serviceName : 'Delivery'));

    final userPhone = booking.user?.mobile ?? booking.pickup?.senderMobile;

    return _buildContainerCard(
      child: Row(
        children: [
          /// CIRCULAR AVATAR
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (userPhone != null && userPhone.trim().isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    userPhone,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
                SizedBox(height: 5.h),

                /// SERVICE TYPE BADGE
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.w),
                  ),
                  child: Text(
                    categoryBadge,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. TRIP ROUTE CARD (COMBINED PICKUP + DROP)
  Widget _buildTripRouteCard(BookingHistoryModel booking) {
    final pickupAddress = (booking.pickup?.address != null &&
            booking.pickup!.address!.isNotEmpty)
        ? booking.pickup!.address!
        : "Pickup location not available";

    final dropAddress = (booking.drop?.address != null && booking.drop!.address!.isNotEmpty)
        ? booking.drop!.address!
        : "Drop location not available";

    final pickupLandmark = booking.pickup?.landmark;
    final pickupContact = booking.pickup?.senderMobile;
    final dropLandmark = booking.drop?.landmark;
    final dropContact = booking.drop?.receiverMobile;

    return _buildContainerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// SECTION HEADER
          _buildSectionHeader(
            title: "Trip Route",
            icon: Icons.alt_route_rounded,
            iconColor: const Color(0xFF2563EB),
            badgeColor: const Color(0xFFEFF6FF),
          ),
          SizedBox(height: 12.h),

          /// VERTICAL ROUTE TIMELINE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// LEFT TIMELINE GRAPHIC (DOT - LINE - DOT)
              Column(
                children: [
                  SizedBox(height: 3.h),
                  // Pickup Dot
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 2.5.w),
                    ),
                  ),
                  // Connecting Vertical Line
                  Container(
                    width: 2.w,
                    height: 56.h,
                    color: const Color(0xFFCBD5E1),
                  ),
                  // Drop Dot
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFEE2E2), width: 2.5.w),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 10.w),

              /// RIGHT ADDRESS DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// PICKUP BLOCK
                    Text(
                      "PICKUP",
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      pickupAddress,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                    if (pickupLandmark != null && pickupLandmark.trim().isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        "Landmark: $pickupLandmark",
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (pickupContact != null && pickupContact.trim().isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        "Contact: $pickupContact",
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],

                    SizedBox(height: 16.h),

                    /// DROP BLOCK
                    Text(
                      "DROP",
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      dropAddress,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                    if (dropLandmark != null && dropLandmark.trim().isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        "Landmark: $dropLandmark",
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (dropContact != null && dropContact.trim().isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        "Contact: $dropContact",
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. FARE BREAKDOWN CARD (PREMIUM BILLING STYLE)
  Widget _buildFareBreakdownCard(BookingHistoryModel booking) {
    final double totalFare = booking.totalFare ?? 1254.0;
    final double tripFare = booking.baseFare ?? 501.60;
    final double distanceFare = booking.distanceFare ?? 627.00;
    final double waitingFare = booking.waitingFare ?? 125.40;
    final double? couponDiscount = booking.couponDiscount;

    return _buildContainerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// SECTION HEADER
          _buildSectionHeader(
            title: "Fare Breakdown",
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF16A34A),
            badgeColor: const Color(0xFFEAF5EA),
          ),
          SizedBox(height: 12.h),

          _buildFareItemRow("Trip Fare", _formatCurrency(tripFare)),
          _buildFareItemRow("Distance Fare", _formatCurrency(distanceFare)),
          if (waitingFare > 0)
            _buildFareItemRow("Waiting Charge", _formatCurrency(waitingFare)),
          if (couponDiscount != null && couponDiscount > 0)
            _buildFareItemRow("Discount", "- ${_formatCurrency(couponDiscount)}", isDiscount: true),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Row(
              children: List.generate(
                32,
                (index) => Expanded(
                  child: Container(
                    height: 1.2.h,
                    color: index % 2 == 0 ? const Color(0xFFE2E8F0) : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          /// TOTAL EARNINGS HIGHLIGHT CONTAINER
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.w),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TOTAL EARNINGS",
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  _formatCurrency(totalFare),
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 6. RIDE INFORMATION CARD (2-COLUMN GRID)
  Widget _buildRideInformationCard(BookingHistoryModel booking) {
    final vehicleType = _formatLabel(booking.vehicleType ?? '');
    final serviceType = _formatLabel(booking.pickup?.category ?? 'Delivery');
    final crn = (booking.bookingId != null && booking.bookingId!.isNotEmpty)
        ? booking.bookingId!
        : (booking.id != null
            ? (booking.id!.length >= 10
                ? booking.id!.substring(0, 10).toUpperCase()
                : booking.id!.toUpperCase())
            : 'FLT-1001');

    final distance = booking.distanceKm != null ? "${booking.distanceKm!.toStringAsFixed(1)} km" : null;
    final duration = booking.durationMin != null ? "${booking.durationMin} mins" : null;
    final paymentMethod = booking.paymentMethod != null ? _formatLabel(booking.paymentMethod) : 'Cash';
    final status = _formatLabel(booking.status ?? 'Completed');

    final infoItems = <Map<String, String>>[
      if (vehicleType.isNotEmpty) {'label': 'Vehicle Type', 'value': vehicleType},
      if (serviceType.isNotEmpty) {'label': 'Ride Type', 'value': serviceType},
      {'label': 'Booking ID', 'value': crn},
      if (distance != null) {'label': 'Distance', 'value': distance},
      if (duration != null) {'label': 'Duration', 'value': duration},
      {'label': 'Payment', 'value': paymentMethod},
      {'label': 'Status', 'value': status},
    ];

    return _buildContainerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// SECTION HEADER
          _buildSectionHeader(
            title: "Ride Information",
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF6366F1),
            badgeColor: const Color(0xFFEEF2FF),
          ),
          SizedBox(height: 12.h),

          /// 2-COLUMN RESPONSIVE LAYOUT
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12.w) / 2;
              return Wrap(
                spacing: 12.w,
                runSpacing: 10.h,
                children: infoItems.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['label']!,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          item['value']!,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 7. BOTTOM ACTION BUTTONS
  Widget _buildBottomActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38.h,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: const Color(0xFFCBD5E1), width: 1.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                backgroundColor: Colors.white,
              ),
              onPressed: () {
                CustomSnackbar.showSuccess(
                  message: 'Invoice sent to registered email!',
                );
              },
              child: Text(
                "Mail Invoice",
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: SizedBox(
            height: 38.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFF59E0B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Back",
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// REUSABLE SECTION HEADER WITH ICON BADGE
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18.sp,
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  /// REUSABLE CARD CONTAINER WITH SOFT MODERN SHADOW
  Widget _buildContainerCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  /// REUSABLE FARE ITEM ROW
  Widget _buildFareItemRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: const Color(0xFF64748B),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: isDiscount ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
