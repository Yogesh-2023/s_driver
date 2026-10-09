import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../services/onboarding_step_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../dashboard/driver_home_screen.dart';
import '../dashboard/profile_screen.dart';
import '../auth/repositories/history_order_screen.dart';
import '../subscriptions/subscription_plans_screen.dart';
import '../auth/controllers/auth_controller.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_constants.dart';
import '../../services/socket/socket_service.dart';
import '../../services/location_tracking_service.dart';
import '../dashboard/controllers/active_booking_controller.dart';
import '../../widgets/custom_snackbar.dart';

class DriverNavigationScreen extends StatefulWidget {
  const DriverNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialOrdersTabIndex = 0,
  });

  final int initialIndex;
  final int initialOrdersTabIndex;

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  late int _index;
  bool _isOnline = false;
  bool _isSyncingOnline = false;
  final List<int> _navigationHistory = <int>[];

  bool get _hasPendingPaymentBooking {
    if (!Get.isRegistered<ActiveBookingController>()) return false;
    final payload = Get.find<ActiveBookingController>().bookingPayload;
    if (payload == null) return false;
    final booking = payload['booking'];
    final source = booking is Map ? booking : payload;
    final status = source['status']?.toString().toUpperCase();
    final paymentStatus =
        (source['paymentStatus'] ??
                source['payment_status'] ??
                (source['payment'] is Map ? source['payment']['status'] : null))
            ?.toString()
            .toUpperCase();
    return status == 'PAYMENT_PENDING' ||
        status == 'AWAITING_PAYMENT' ||
        paymentStatus == 'PENDING' ||
        paymentStatus == 'PAYMENT_PENDING';
  }

  List<Widget> get _screens => [
    const DriverHomeScreen(),
    BookingsHistoryScreen(
      initialTabIndex: widget.initialOrdersTabIndex,
      showBackButton: false,
      onBack: _handleBack,
    ),
    SubscriptionPlansScreen(showBackButton: false, onBack: _handleBack),
    SubscriptionPlansScreen(showBackButton: false, onBack: _handleBack),
    ProfileScreen(showBackButton: false, onBack: _handleBack),
  ];

  @override
  void initState() {
    super.initState();
    OnboardingStepService.saveStep(OnboardingStepService.stepHome);
    _index = widget.initialIndex.clamp(0, _screens.length - 1).toInt();
    if (_index != 0) _navigationHistory.add(0);
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() {
      _navigationHistory.add(_index);
      _index = index;
    });
  }

  bool _goToPreviousTab() {
    if (_navigationHistory.isEmpty) return false;
    setState(() {
      _index = _navigationHistory.removeLast();
    });
    return true;
  }

  Future<void> _handleBack() async {
    if (_goToPreviousTab()) return;
    final shouldExit = await _showExitConfirmationDialog(context);
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  Future<bool> _syncOnlinePresence() async {
    try {
      await SocketService.to.ensureConnected();
      final tracker = LocationTrackingService();
      final position = await tracker.fetchBestCurrentPosition();
      if (position == null) {
        CustomSnackbar.showError(
          message: 'Unable to get current location. Please enable GPS to go online.',
        );
        print('[DRIVER_PRESENCE] action=ONLINE source=navigation location=missing');
        return false;
      }
      await tracker.startTracking(null);
      final response =
          await Get.find<ApiClient>().postData(ApiConstants.availabilityOnline, {});
      final ok = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          !(response.body is Map && response.body['success'] == false);
      if (!ok) {
        final failure = _onlineFailureMessage(response);
        print(
          '[DRIVER_PRESENCE] action=ONLINE source=navigation onlineSync=failed status=${response.statusCode} body=${response.body}',
        );
        CustomSnackbar.showError(message: failure);
        if (_isSubscriptionRequired(response)) {
          setState(() {
            if (_index != 2) _navigationHistory.add(_index);
            _index = 2;
          });
        }
        return false;
      }
      final ack = await SocketService.to.goOnline(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        sequence: 1,
      );
      await tracker.sendFreshLocationUpdate();
      await SocketService.to.sendHeartbeat();
      print(
        '[DRIVER_PRESENCE] action=ONLINE source=navigation socketConnected=${SocketService.to.isConnected} onlineSync=success available=true ack=$ack',
      );
      return true;
    } catch (e) {
      print('[DRIVER_PRESENCE] action=ONLINE source=navigation onlineSync=error error=$e');
      return false;
    }
  }

  Future<void> _syncOfflinePresence() async {
    try {
      await SocketService.to.ensureConnected();
      await SocketService.to.goOffline();
      await Get.find<ApiClient>().postData(ApiConstants.availabilityOffline, {});
    } catch (e) {
      print('[DRIVER_PRESENCE] action=OFFLINE source=navigation sync=error error=$e');
    } finally {
      await LocationTrackingService().stopTracking();
    }
  }

  bool _isSubscriptionRequired(Response response) {
    final text = '${response.body} ${response.statusText}'.toUpperCase();
    return response.statusCode == 403 &&
        text.contains('DRIVER_SUBSCRIPTION_REQUIRED');
  }

  String _onlineFailureMessage(Response response) {
    final text = '${response.body} ${response.statusText}'.toUpperCase();
    if (text.contains('DRIVER_SUBSCRIPTION_REQUIRED')) {
      return 'Please activate a driver subscription plan to go online.';
    }
    if (text.contains('DRIVER_NOT_ELIGIBLE')) {
      return 'Your driver profile or vehicle is not eligible to go online.';
    }
    final body = response.body;
    if (body is Map) {
      final message = body['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return response.statusText ?? 'Could not go online. Please try again.';
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(24.w),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: const BoxDecoration(
                color: AppColors.lightYellowBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.primaryDark,
                size: 32,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Exit Application',
              style: AppFonts.h2.copyWith(
                color: AppColors.darkText,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Are you sure you want to exit the app?',
              textAlign: TextAlign.center,
              style: AppFonts.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppFonts.body.copyWith(
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                    ),
                    child: Text(
                      'Exit',
                      style: AppFonts.body.copyWith(
                        color: AppColors.darkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: Container(
          width: double.infinity,
          height: 72.h + MediaQuery.of(context).padding.bottom,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // White Circular Arc Backdrop behind center button
              Positioned(
                top: -26.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 72.r,
                    height: 72.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1. Home Tab
                  _buildNavItem(
                    index: 0,
                    label: 'Home',
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                  ),

                  // 2. Trips Tab
                  _buildNavItem(
                    index: 1,
                    label: 'Trips',
                    assetPath: 'assets/icons/trip.png',
                    icon: Icons.layers_outlined,
                    activeIcon: Icons.layers_rounded,
                  ),

                  // 3. Center Space for Online Floating Button
                  SizedBox(width: 58.w),

                  // 4. Subscription Plans Tab
                  _buildNavItem(
                    index: 3,
                    label: 'Plans',
                    icon: Icons.workspace_premium_outlined,
                    activeIcon: Icons.workspace_premium_rounded,
                  ),

                  // 5. Profile Tab
                  _buildNavItem(
                    index: 4,
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                  ),
                ],
              ),

              // Center Floating Steering Wheel Button with Purple Glow Shadow (Ditto Figma)
              Positioned(
                top: -20.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Obx(() {
                    final authCtrl = Get.isRegistered<AuthController>()
                        ? Get.find<AuthController>()
                        : null;
                    final hasRideAccess =
                        authCtrl?.isRideAccessEnabled ?? false;
                    final isOnline =
                        hasRideAccess && (authCtrl?.isOnline.value ?? _isOnline);

                    return GestureDetector(
                      onTap: () async {
                        if (_isSyncingOnline) return;
                        if (!hasRideAccess) {
                          if (authCtrl != null) {
                            authCtrl.isOnline.value = false;
                          }
                          setState(() {
                            _isOnline = false;
                          });
                          try {
                            await SocketService.to.goOffline();
                            LocationTrackingService().stopTracking();
                          } catch (_) {}
                          return;
                        }
                        final nextState = !isOnline;
                        if (nextState && _hasPendingPaymentBooking) {
                          CustomSnackbar.showWarning(
                            message:
                                'Please complete payment confirmation before going online.',
                          );
                          return;
                        }
                        setState(() => _isSyncingOnline = true);
                        try {
                          if (nextState) {
                            final synced = await _syncOnlinePresence();
                            if (!synced) {
                              return;
                            }
                          } else {
                            await _syncOfflinePresence();
                          }
                          if (authCtrl != null) {
                            authCtrl.isOnline.value = nextState;
                          }
                          if (mounted) {
                            setState(() {
                              _isOnline = nextState;
                            });
                          }
                        } finally {
                          if (mounted) setState(() => _isSyncingOnline = false);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isOnline
                                          ? const Color(0xFF27AE60)
                                          : const Color(0xFFDC2626))
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              isOnline
                                  ? 'assets/images/Frame 46.png'
                                  : 'assets/images/Frame 47.png',
                              width: 64.r,
                              height: 64.r,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Container(
                                width: 60.r,
                                height: 60.r,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF27AE60)
                                      : const Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.sports_motorsports_rounded,
                                  color: Colors.white,
                                  size: 32.sp,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                              color: isOnline
                                  ? const Color(0xFF27AE60)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    IconData? icon,
    IconData? activeIcon,
    String? assetPath,
  }) {
    bool isSelected = _index == index;

    return GestureDetector(
      onTap: () => _selectTab(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetPath != null)
              Image.asset(
                assetPath,
                width: 24.r,
                height: 24.r,
                color: isSelected ? const Color(0xFFFFC700) : const Color(0xFF90A4AE),
                errorBuilder: (_, _, _) => Icon(
                  isSelected ? (activeIcon ?? Icons.layers_rounded) : (icon ?? Icons.layers_outlined),
                  size: 24.sp,
                  color: isSelected ? const Color(0xFFFFC700) : const Color(0xFF90A4AE),
                ),
              )
            else
              Icon(
                isSelected ? activeIcon : icon,
                size: 24.sp,
                color: isSelected ? const Color(0xFFFFC700) : const Color(0xFF90A4AE),
              ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFFFFC700) : const Color(0xFF90A4AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
