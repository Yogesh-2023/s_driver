import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../documents/document_upload_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.isProvider = false});

  final bool isProvider;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _selectedTab = 'Today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      body: Column(
        children: [
          // Top Profile Header
          _buildProfileHeader(),

          Expanded(child: _buildActivityContent()),
        ],
      ),
    );
  }

  Widget _buildActivityContent({bool checkProviderKyc = false}) {
    return Column(
      children: [
        _buildFilterTabs(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewSection(),
                SizedBox(height: 8.h),
                _buildBreakdownChartCard(),
                SizedBox(height: 8.h),
                _buildTimelineSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingKycView(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 24.w),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF00ABE4).withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.w),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 48.sp,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Account Verification Pending',
                textAlign: TextAlign.center,
                style: AppFonts.h2.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Your Activity, Earnings, and Trip statistics will be unlocked as soon as your Provider KYC is approved.',
                textAlign: TextAlign.center,
                style: AppFonts.body.copyWith(
                  fontSize: 13.sp,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () {
                  Get.to(
                    () => const DocumentUploadScreen(isProviderDriver: true),
                  );
                },
                icon: const Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                ),
                label: Text(
                  'Check KYC Documents',
                  style: AppFonts.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final canPop = Navigator.canPop(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12.h,
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
          if (canPop) ...[
            InkWell(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Get.back();
                }
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
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Text(
              'Activity',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6E6E6), width: 1.w),
      ),
      child: Icon(icon, color: Colors.black, size: 18.sp),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = ['Today', 'Yesterday', '7 Days'];
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Container(
        height: 32.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA), // Subtle grey track
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(color: const Color(0xFFE6E6E6), width: 1.w),
        ),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = _selectedTab == tab;
            final isNextSelected =
                index < tabs.length - 1 && _selectedTab == tabs[index + 1];

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = tab;
                  });
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 26.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(100.r),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF0A8735),
                                  width: 1.w,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? const Color(0xFF0F9F59)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Subtle vertical divider if not the last tab and neither current nor next is selected
                    if (index < tabs.length - 1)
                      Container(
                        width: 1.w,
                        height: 14.h,
                        color: (isSelected || isNextSelected)
                            ? Colors.transparent
                            : const Color(0xFFE0E0E0),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Overview",
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
            Text(
              "20 June 2026",
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Container(
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
              color: const Color(0xFF00ABE4).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverviewColumn(
                'Trip',
                '4',
                Icons.directions_car_outlined,
                const Color(0xFFEAF9EE),
                const Color(0xFF0F9F59),
              ),
              _buildOverviewDivider(),
              _buildOverviewColumn(
                'Online Time',
                '6h 19m',
                Icons.access_time_outlined,
                const Color(0xFFE6F7FD),
                const Color(0xFF00ABE4),
              ),
              _buildOverviewDivider(),
              _buildOverviewColumn(
                'Earnings',
                '₹1248',
                Icons.wallet_outlined,
                const Color(0xFFFEF3C7),
                const Color(0xFFF59E0B),
              ),
              _buildOverviewDivider(),
              _buildOverviewColumn(
                'Rating',
                '90%',
                Icons.star_border,
                const Color(0xFFF3E8FF),
                const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewColumn(
    String label,
    String value,
    IconData icon,
    Color iconBg,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 16.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewDivider() {
    return Container(width: 1.w, height: 40.h, color: const Color(0xFFE6E6E6));
  }

  Widget _buildBreakdownChartCard() {
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
          color: const Color(0xFF00ABE4).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trip Earning Breakdown',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                ),
              ),
              Text(
                'How it work',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 11.sp,
                  color: const Color(0xFF00ABE4),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              // Circular progress score
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76.w,
                    height: 76.w,
                    child: CircularProgressIndicator(
                      value: 0.92,
                      strokeWidth: 7.w,
                      backgroundColor: const Color(0xFFEAF9EE),
                      color: const Color(0xFF0F9F59),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '92',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'Excellent',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F9F59),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: 20.w),

              // Breakdown lists
              Expanded(
                child: Column(
                  children: [
                    _buildBreakdownMetricItem(
                      label: 'Acceptance Rate',
                      value: '90%',
                      isUp: true,
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF0F9F59),
                      iconBg: const Color(0xFFEAF9EE),
                    ),
                    _buildBreakdownMetricItem(
                      label: 'Cancellation Rate',
                      value: '3%',
                      isUp: false,
                      icon: Icons.cancel_outlined,
                      iconColor: const Color(0xFFDC3545),
                      iconBg: const Color(0xFFFDE8E8),
                    ),
                    _buildBreakdownMetricItem(
                      label: 'On-time Rate',
                      value: '96%',
                      isUp: true,
                      icon: Icons.access_time_outlined,
                      iconColor: const Color(0xFF00ABE4),
                      iconBg: const Color(0xFFE6F7FD),
                    ),
                    _buildBreakdownMetricItem(
                      label: 'Customer Rating',
                      value: '4.9',
                      isUp: true,
                      icon: Icons.star_border,
                      iconColor: const Color(0xFF8B5CF6),
                      iconBg: const Color(0xFFF3E8FF),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownMetricItem({
    required String label,
    required String value,
    required bool isUp,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 11.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          SizedBox(width: 4.w),
          Icon(
            isUp ? Icons.arrow_upward : Icons.arrow_downward,
            color: isUp ? const Color(0xFF0F9F59) : const Color(0xFFDC3545),
            size: 10.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Timeline",
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
            Text(
              "View All Activity",
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 11.sp,
                color: const Color(0xFF00ABE4),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) {
            return _buildTimelineItem();
          },
        ),
      ],
    );
  }

  Widget _buildTimelineItem() {
    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
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
          color: const Color(0xFF0F9F59).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: Color(0xFFEAF9EE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car_filled,
              color: const Color(0xFF0F9F59),
              size: 16.sp,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '9:15 AM',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                Text(
                  'DLF Mall, Noida → DLF Mall, Noida',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          Text(
            '₹1248',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F9F59),
            ),
          ),
        ],
      ),
    );
  }
}
