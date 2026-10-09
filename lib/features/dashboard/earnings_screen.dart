import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_colors.dart';
import 'package:get/get.dart';
import '../navigation/driver_navigation_screen.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/profile_models_and_services.dart';
import '../notifications/notifications_screen.dart';
import 'profile_screen.dart';
import '../wallet/repositories/wallet_repository.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_constants.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key, this.showBackButton = false, this.onBack});

  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  String _selectedTab = 'Today';

  UserProfile? get _profile => Get.find<AuthController>().userProfile.value;

  String _money(num value) => '₹${value.toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    _fetchWalletAndEarningsData();
  }

  Future<void> _fetchWalletAndEarningsData() async {
    try {
      final repo = WalletRepository(apiClient: Get.find<ApiClient>());
      await repo.getWallet();
      await repo.getEarningsSummary();
    } catch (e) {
      print("=== FETCH WALLET / EARNINGS ERROR: $e ===");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      body: Column(
        children: [
          // Top Profile Header
          _buildProfileHeaderSection(),

          // Filter Tabs Row
          _buildFilterTabs(),

          Expanded(
            child: Obx(
              () => SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Green Total Earnings Card
                    _buildEarningsCard(),
                    SizedBox(height: 10.h),

                    // Stats Row
                    _buildStatsOverview(),
                    SizedBox(height: 10.h),

                    // Trip Earning Breakdown Card
                    _buildBreakdownCard(),
                    SizedBox(height: 10.h),

                    // Recent Transaction Card
                    _buildRecentTransactionsSection(),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderSection() {
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
        print('🚀 [DEBUG] DRIVER PROFILE TOUCHED ON EARNINGS SCREEN HEADER');
        print('URL: ${ApiConstants.baseUrl}${ApiConstants.driverProfile}');
        print('=====================================================\n');
        authController?.debugFetchAndPrintProfile();
        Get.to(() => ProfileScreen(showBackButton: true));
      }

      final canPop = widget.showBackButton && Navigator.canPop(context);

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
            if (canPop) ...[
              InkWell(
                onTap: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                    return;
                  }
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Get.offAll(() => const DriverNavigationScreen());
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
                  onTap: () => Get.to(() => const EarningsScreen()),
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
                      Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF1E293B),
                      size: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
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

  Widget _buildFilterTabs() {
    final tabs = ['Today', 'This Week', 'This Month', 'Custom'];
    return Container(
      color: const Color(0xFFFEFAF4),
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: SizedBox(
        height: 30.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final tab = tabs[index];
            final isSelected = _selectedTab == tab;
            return Padding(
              padding: EdgeInsets.only(
                right: index == tabs.length - 1 ? 0 : 8.w,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedTab = tab;
                  });
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
                    tab,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.gilroyFontFamily,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF000000)
                          : const Color(0xFF666666),
                      height: 1.0,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    final profile = _profile;
    final total = profile?.earningsTotal ?? 0;
    final today = profile?.earningsToday ?? 0;
    final wallet = profile?.walletBalance ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF35AF30),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFE6E6E6), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT SIDE
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Earning',
                  style: TextStyle(
                    fontFamily: AppFonts.gilroyFontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _money(total),
                  style: TextStyle(
                    fontFamily: AppFonts.gilroyFontFamily,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF027319),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '+12% higher than last week',
                    style: TextStyle(
                      fontFamily: AppFonts.gilroyFontFamily,
                      fontSize: 8.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // VERTICAL DIVIDER
          Container(
            width: 1.w,
            height: 54.h,
            color: Colors.white,
            margin: EdgeInsets.symmetric(horizontal: 12.w),
          ),

          // RIGHT SIDE
          Expanded(
            flex: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cash Collected
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash Collected',
                          style: TextStyle(
                            fontFamily: AppFonts.gilroyFontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _money(today),
                          style: TextStyle(
                            fontFamily: AppFonts.gilroyFontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 30.w,
                      height: 30.w,
                      decoration: BoxDecoration(
                        color: const Color(0x80FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 6.h),
                // HORIZONTAL DIVIDER
                Container(height: 1.h, color: Colors.white),
                SizedBox(height: 6.h),
                
                // Online Payments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Online Payments',
                          style: TextStyle(
                            fontFamily: AppFonts.gilroyFontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _money(wallet),
                          style: TextStyle(
                            fontFamily: AppFonts.gilroyFontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 30.w,
                      height: 30.w,
                      decoration: BoxDecoration(
                        color: const Color(0x80FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.credit_card_outlined,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final profile = _profile;

    return Container(
      width: double.infinity,
      height: 82.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFAF4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE6E6E6),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatColumn(
            'Total Trip',
            '${profile?.totalTrips ?? 0}',
            Icons.directions_car_outlined,
            const Color(0xFFEAF9EE),
            const Color(0xFF0F9F59),
          ),
          _buildStatDivider(),
          _buildStatColumn(
            'Online Hours',
            '6.5',
            Icons.access_time_outlined,
            const Color(0xFFE6F7FD),
            const Color(0xFF00ABE4),
          ),
          _buildStatDivider(),
          _buildStatColumn(
            'Monthly',
            _money(profile?.earningsMonthly ?? 0),
            Icons.currency_rupee,
            const Color(0xFFFEF3C7),
            const Color(0xFFF59E0B),
          ),
          _buildStatDivider(),
          _buildStatColumn(
            'Rating',
            (profile?.ratingAverage ?? 0).toStringAsFixed(1),
            Icons.star_border,
            const Color(0xFFF3E8FF),
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color iconBg,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 14.sp),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 10.sp,
              color: const Color(0xFF000000),
              fontWeight: FontWeight.w500,
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF000000),
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1.w, height: 32.h, color: const Color(0xFFE6E6E6));
  }

  Widget _buildBreakdownCard() {
    final profile = _profile;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFAF4),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Earning Breakdown',
            style: TextStyle(
              fontFamily: AppFonts.gilroyFontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          SizedBox(height: 12.h),
          _buildBreakdownRow('Today', _money(profile?.earningsToday ?? 0)),
          _buildBreakdownRow('Monthly', _money(profile?.earningsMonthly ?? 0)),
          _buildBreakdownRow('Yearly', _money(profile?.earningsYearly ?? 0)),
          _buildBreakdownRow(
            'Wallet Balance',
            _money(profile?.walletBalance ?? 0),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Earning',
                style: TextStyle(
                  fontFamily: AppFonts.gilroyFontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F9F59),
                ),
              ),
              Text(
                _money(profile?.earningsTotal ?? 0),
                style: TextStyle(
                  fontFamily: AppFonts.gilroyFontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F9F59),
                ),
              ),
            ],
          ),
        ],
      ),
    );
      }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF474747),
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF474747),
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsCard() {
    final profile = _profile;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFAF4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE6E6E6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payouts',
            style: TextStyle(
              fontFamily: AppFonts.gilroyFontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            'Your earnings will be transferred to your bank account',
            style: TextStyle(
              fontFamily: AppFonts.gilroyFontFamily,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 12.h),

          // Bank Row
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.black,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HDFC Bank',
                      style: TextStyle(
                        fontFamily: AppFonts.gilroyFontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    Text(
                      '**** **** **** 1205',
                      style: TextStyle(
                        fontFamily: AppFonts.gilroyFontFamily,
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
          SizedBox(height: 12.h),

          // Green Promo box
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.w),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9EE),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Payout',
                      style: TextStyle(
                        fontFamily: AppFonts.gilroyFontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F9F59),
                      ),
                    ),
                    Text(
                      '22 June 2026 09:20 AM',
                      style: TextStyle(
                        fontFamily: AppFonts.gilroyFontFamily,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F9F59).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(profile?.walletWithdrawableBalance ?? 0),
                      style: TextStyle(
                        fontFamily: AppFonts.gilroyFontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F9F59),
                      ),
                    ),
                    Text(
                      'Earning collected',
                      style: TextStyle(
                        fontFamily: AppFonts.gilroyFontFamily,
                        fontSize: 8.sp,
                        color: const Color(0xFF0F9F59),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    final recentTrips = _profile?.recentTrips ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 14.w),
          child: Text(
            'Recent Transactions',
            style: TextStyle(
              fontFamily: AppFonts.gilroyFontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        if (recentTrips.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFAF4),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              'No recent trips found',
              style: TextStyle(
                fontFamily: AppFonts.gilroyFontFamily,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
          )
        else
          ...recentTrips.map((trip) {
            final item = trip is Map ? trip : <String, dynamic>{};
            final amount =
                item['fare'] ?? item['amount'] ?? item['totalFare'] ?? 0;
            final date =
                item['createdAt'] ?? item['date'] ?? item['completedAt'] ?? '';
            final paymentMode =
                item['paymentMode'] ?? item['paymentType'] ?? 'Trip';
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFAF4),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF9EE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_car_filled,
                      color: const Color(0xFF0F9F59),
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride Payment',
                          style: TextStyle(
                            fontFamily: AppFonts.gilroyFontFamily,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        Text(
                          date.toString(),
                          style: TextStyle(
                            fontFamily: AppFonts.gilroyFontFamily,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(double.tryParse(amount.toString()) ?? 0),
                        style: TextStyle(
                          fontFamily: AppFonts.gilroyFontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F9F59),
                        ),
                      ),
                      Text(
                        paymentMode.toString(),
                        style: TextStyle(
                          fontFamily: AppFonts.gilroyFontFamily,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
