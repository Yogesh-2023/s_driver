import 'booking_controllers.dart';
import 'booking_history_model.dart';
import 'my_order_screen.dart';
import '../../dashboard/profile_screen.dart';
import '../../notifications/notifications_screen.dart';
import '../controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_fonts.dart';
import '../../../data/api/api_constants.dart';

class BookingsHistoryScreen extends StatefulWidget {
  const BookingsHistoryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.showBackButton = false,
    this.onBack,
  });

  final int initialTabIndex;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  State<BookingsHistoryScreen> createState() => _BookingsHistoryScreenState();
}

class _BookingsHistoryScreenState extends State<BookingsHistoryScreen>
    with SingleTickerProviderStateMixin {
  final BookingHistoryController _controller = Get.put(
    BookingHistoryController(),
  );

  late TabController _tabController;
  final List<String> _tabs = const [
    "All",
    "Completed",
    "Cancelled",
    "Upcoming",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1).toInt(),
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Obx(() {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final profile = authController?.userProfile.value;

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

      final avatarRaw = profile?.avatar ?? '';
      String? avatarUrl;
      if (avatarRaw.trim().isNotEmpty) {
        final trimmed = avatarRaw.trim();
        if (trimmed.startsWith('http')) {
          avatarUrl = trimmed;
        } else if (trimmed.startsWith('/')) {
          avatarUrl = '${ApiConstants.fileBaseUrl}$trimmed';
        } else if (!trimmed.startsWith('assets/')) {
          avatarUrl = '${ApiConstants.fileBaseUrl}/$trimmed';
        }
      }

      void handleProfileTap() {
        print('\n=====================================================');
        print('🚀 [DEBUG] DRIVER PROFILE TOUCHED ON HISTORY SCREEN HEADER');
        print('URL: ${ApiConstants.baseUrl}${ApiConstants.driverProfile}');
        print('=====================================================\n');
        authController?.debugFetchAndPrintProfile();
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
            if (widget.showBackButton && Navigator.canPop(context)) ...[
              InkWell(
                onTap: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                    return;
                  }
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 20.sp,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
            ],
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
                        child: avatarUrl != null && avatarUrl.isNotEmpty
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
                            authController?.isRideAccessEnabled == true &&
                                    authController?.isOnline.value == true
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
            Row(
              children: [
                InkWell(
                  onTap: () => Get.to(() => const NotificationsScreen()),
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_none_outlined,
                      color: const Color(0xFF1E293B),
                      size: 20.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      extendBody: true,
      body: Column(
        children: [
          _buildHeader(context),

          SizedBox(height: 12.h),

          /// 📑 INDIVIDUAL TAB PILLS (Matching screenshot design)
          SizedBox(
            height: 30.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final isSelected = _tabController.index == index;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _tabs.length - 1 ? 0 : 8.w,
                  ),
                  child: InkWell(
                    onTap: () {
                      _tabController.animateTo(index);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(8.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 81.w,
                      height: 30.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFF2B2)
                            : const Color(0xFFFEFCFA),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFCC00)
                              : const Color(0xFFE9E9E9),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        _tabs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF000000),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 8.h),

          /// 📜 TAB BAR VIEW
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList("All"),
                _buildBookingList("Completed"),
                _buildBookingList("Cancelled"),
                _buildBookingList("Upcoming"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(String filter) {
    return Obx(() {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      if (authController == null || !authController.isRideAccessEnabled) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (authController != null) {
              await authController.checkProfileStatus();
              if (authController.isRideAccessEnabled) {
                await _controller.fetchBookings();
              }
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.verified_user_outlined,
                            size: 40.sp,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "KYC approval required",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          "Rides will be available after your KYC is approved.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (_controller.isLoading.value && _controller.allBookings.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      List<BookingHistoryModel> list;
      if (filter == "All") {
        list = _controller.allBookings;
      } else {
        final normalizedFilter = filter.toUpperCase();
        list = _controller.allBookings.where((booking) {
          final status = booking.status?.toUpperCase() ?? '';
          if (normalizedFilter == "COMPLETED") {
            return status == "COMPLETED";
          }
          if (normalizedFilter == "CANCELLED") {
            return status == "DECLINED" ||
                status == "REJECTED" ||
                status == "CANCELLED" ||
                status == "EXPIRED";
          }
          if (normalizedFilter == "UPCOMING") {
            return status == "UPCOMING" ||
                status == "RESCHEDULE" ||
                status == "PENDING" ||
                status == "ACCEPTED" ||
                status == "ONGOING";
          }
          return status == normalizedFilter;
        }).toList();
      }

      if (list.isEmpty) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _controller.fetchBookings,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.route_rounded,
                            size: 40.sp,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "No trips yet",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          filter == 'All'
                              ? "Your accepted and completed rides will appear here once you start taking trips."
                              : "No $filter trips available right now.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _controller.fetchBookings,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 24.h),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return _buildBookingCard(list[index]);
          },
        ),
      );
    });
  }

  Widget _buildBookingCard(BookingHistoryModel booking) {
    Color badgeBgColor;
    Color badgeTextColor;
    String badgeText;

    final statusUpper = (booking.status ?? "COMPLETED").toUpperCase();
    if (statusUpper == "COMPLETED") {
      badgeBgColor = const Color(0xFFD1F4D9);
      badgeTextColor = const Color(0xFF35AF30);
      badgeText = "Completed";
    } else if (statusUpper == "RESCHEDULE" ||
        statusUpper == "UPCOMING" ||
        statusUpper == "PENDING") {
      badgeBgColor = const Color(0xFFD6E4FF);
      badgeTextColor = const Color(0xFF2563EB);
      badgeText = statusUpper == "RESCHEDULE" ? "Reschedule" : "Upcoming";
    } else if (statusUpper == "CANCELLED" ||
        statusUpper == "DECLINED" ||
        statusUpper == "EXPIRED" ||
        statusUpper == "REJECTED") {
      badgeBgColor = const Color(0xFFFFD6D6);
      badgeTextColor = const Color(0xFFDC3545);
      badgeText = "Cancelled";
    } else {
      badgeBgColor = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF475569);
      badgeText = statusUpper;
    }

    String formattedTime = booking.createdAt ?? "10:20 AM";
    if (formattedTime.contains("T")) {
      try {
        DateTime dt = DateTime.parse(formattedTime).toLocal();
        formattedTime = DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    return Container(
      width: 360.w,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    color: badgeTextColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                ),
              ),
              Text(
                formattedTime,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF565656),
                  height: 1.0,
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Locations with new Group2.png asset
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
                child: Image.asset(
                  'assets/icons/Group2.png',
                  width: 18.w,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pick-up Location",
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF858585),
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      booking.pickup?.address ?? "Pick-up address",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF000000),
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Drop Location",
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF858585),
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      booking.drop?.address ?? "Drop location address",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF000000),
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          SizedBox(height: 12.h),

          // Stats & Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn(
                "Distance",
                "${booking.distanceKm ?? 12.5} km",
                isEarnings: false,
              ),
              _buildMetricColumn(
                "Time",
                "${booking.durationMin ?? 28}m",
                isEarnings: false,
              ),
              _buildMetricColumn(
                "Earnings",
                "₹${booking.totalFare?.toInt() ?? 1254}",
                isEarnings: true,
              ),
              InkWell(
                onTap: () {
                  if (booking.id != null) {
                    Get.to(() => BookingDetailsScreen(bookingId: booking.id!));
                  }
                },
                borderRadius: BorderRadius.circular(6.r),
                child: Container(
                  padding: EdgeInsets.only(
                    top: 5.h,
                    right: 15.w,
                    bottom: 5.h,
                    left: 15.w,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3DA),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: const Color(0xFFFD8802),
                    size: 16.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, {required bool isEarnings}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF565656),
            height: 1.0,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: isEarnings ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
