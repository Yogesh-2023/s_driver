import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/socket/socket_service.dart';
import '../auth/phone_login_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../support/help_support_screen.dart';
import 'about_screen.dart';
import '../notifications/notifications_screen.dart';
import 'package:get/get.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_constants.dart';
import '../../services/push_notification_service.dart';
import '../../services/onboarding_step_service.dart';
import '../auth/controllers/auth_controller.dart' as driver_ctrl;
import '../../core/security/secure_session_store.dart';
import '../auth/repositories/booking_controllers.dart';
import '../auth/repositories/edit_profile_screen.dart';
import '../auth/repositories/history_order_screen.dart';
import '../auth/repositories/auth_repository.dart';
import '../auth/controllers/driver_account_controller.dart';
import '../profile/screens/personal_info_details_screen.dart';
import '../profile/screens/kyc_info_details_screen.dart';
import '../profile/screens/driving_license_details_screen.dart';
import '../profile/screens/vehicle_details_screen.dart';
import '../profile/screens/vehicle_documents_screen.dart';
import '../../widgets/status_badge.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  final bool isProvider;
  final VoidCallback? onBack;

  const ProfileScreen({
    super.key,
    this.showBackButton = false,
    this.isProvider = false,
    this.onBack,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final DriverAccountController _accountCtrl;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<DriverAccountController>()) {
      _accountCtrl = Get.put(DriverAccountController(
        authRepository: Get.find<AuthRepository>(),
      ));
    } else {
      _accountCtrl = Get.find<DriverAccountController>();
      _accountCtrl.fetchDriverInfo();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<driver_ctrl.AuthController>().checkProfileStatus();
    });
  }

  Future<void> _logout(BuildContext context) async {
    Future.microtask(() async {
      try {
        await PushNotificationService.instance.removeToken();
        await Get.find<ApiClient>().postData(ApiConstants.logout, {});
      } catch (e) {
        debugPrint('Logout API error: $e');
      }
    });

    try {} finally {
      await SecureSessionStore.clear();
      await OnboardingStepService.clearStep();
      await Get.find<driver_ctrl.AuthController>().clearCachedProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_phone');
      await prefs.remove('app_mode');
      await prefs.remove('is_profile_completed');
      SocketService.to.closeSocket();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
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
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 32,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Logout',
              style: AppFonts.h2.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Are you sure you want to log out from your ${widget.isProvider ? 'provider' : 'driver'} account?',
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
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppFonts.body.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'Logout',
                      style: AppFonts.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: () async {
                await Future.wait([
                  Get.find<driver_ctrl.AuthController>().checkProfileStatus(),
                  _accountCtrl.fetchDriverInfo(),
                ]);
              },
              child: Obx(() {
                final accountInfo = _accountCtrl.accountInfo.value;
                final vehicleInfo = _accountCtrl.vehicleInfo.value;
                final personalInfo = accountInfo?.personalInfo;
                final kycInfo = accountInfo?.kyc;
                final licenseInfo = accountInfo?.drivingLicense;
                final vDetails = vehicleInfo?.vehicleDetails;
                final vDocs = vehicleInfo?.vehicleDocuments;

                if (_accountCtrl.isLoading.value && accountInfo == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (_accountCtrl.isError.value && accountInfo == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48.sp, color: Colors.red),
                          SizedBox(height: 12.h),
                          Text(
                            _accountCtrl.errorMessage.value,
                            textAlign: TextAlign.center,
                            style: AppFonts.h2.copyWith(fontSize: 14.sp, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 16.h),
                          ElevatedButton(
                            onPressed: () => _accountCtrl.fetchDriverInfo(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                  children: [
                    // 1. User Header Card
                    _ProfileHeaderCard(isProvider: widget.isProvider),
                    SizedBox(height: 22.h),

                    // 2. Quick Actions Row (My Booking)
                    const _QuickActionsRow(),
                    SizedBox(height: 12.h),

                    // 3. Section: Account Info
                    const _SectionHeader(title: 'Account Info'),
                    SizedBox(height: 8.h),
                    _ProfileTile(
                      customIconAsset: 'assets/icons/an3.png',
                      customIconSize: Size(20.w, 24.h),
                      title: 'Personal Info',
                      subtitle: personalInfo != null
                          ? personalInfo.fullName
                          : 'Name, Email, Phone, & Address',
                      onTap: () {
                        if (personalInfo != null) {
                          Get.to(() => PersonalInfoDetailsScreen(personalInfo: personalInfo));
                        }
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.description_outlined,
                      title: 'KYC Info',
                      subtitle: 'Aadhaar, PAN',
                      statusText: kycInfo?.status,
                      onTap: () {
                        if (kycInfo != null) {
                          Get.to(() => KycInfoDetailsScreen(kyc: kycInfo));
                        }
                      },
                    ),
                    _ProfileTile(
                      customIconAsset: 'assets/icons/an4.png',
                      customIconSize: Size(24.w, 24.h),
                      title: 'Driving License',
                      subtitle: licenseInfo != null
                          ? 'License: ${licenseInfo.licenseNumber}'
                          : 'License Number & Details',
                      statusText: licenseInfo?.status,
                      onTap: () {
                        if (licenseInfo != null) {
                          Get.to(() => DrivingLicenseDetailsScreen(drivingLicense: licenseInfo));
                        }
                      },
                    ),

                    SizedBox(height: 16.h),

                    // 4. Section: Vehicle Information
                    const _SectionHeader(title: 'Vehicle Information'),
                    SizedBox(height: 8.h),
                    if (!widget.isProvider)
                      _DriverVehicleTile(
                        onTap: () {
                          Get.to(() => VehicleDetailsScreen(vehicleDetails: vDetails));
                        },
                      ),
                    _ProfileTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle Documents',
                      subtitle: vDocs != null && vDocs.isNotEmpty
                          ? '${vDocs.length} Documents Available'
                          : 'RC, Insurance, PUC & Fitness',
                      statusText: vDetails?.verificationStatus ??
                          (vDocs != null && vDocs.isNotEmpty && vDocs.every((d) => d.status.toUpperCase() == 'VERIFIED' || d.status.toUpperCase() == 'APPROVED')
                              ? 'APPROVED'
                              : null),
                      onTap: () {
                        Get.to(() => VehicleDocumentsScreen(
                          vehicleDocuments: vDocs ?? [],
                          overallStatus: vDetails?.verificationStatus,
                        ));
                      },
                    ),

                    SizedBox(height: 16.h),

                    // 5. Section: General
                    const _SectionHeader(title: 'General'),
                    SizedBox(height: 8.h),
                    _ProfileTile(
                      icon: Icons.help_outline,
                      title: 'About App',
                      subtitle: 'Read about us details & services',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.headset_mic_outlined,
                      title: 'Report & Issue',
                      subtitle: 'Get help and support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                HelpSupportScreen(isProvider: widget.isProvider),
                          ),
                        );
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      textColor: const Color(0xFF334155),
                      iconColor: const Color(0xFFFFB020),
                      onTap: () => _showLogoutDialog(context),
                    ),

                    SizedBox(height: 24.h),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authController = Get.find<driver_ctrl.AuthController>();
    void handleProfileTap() {
      print('\n=====================================================');
        print('🚀 [DEBUG] DRIVER PROFILE TOUCHED ON PROFILE SCREEN HEADER');
      print('URL: ${ApiConstants.baseUrl}${ApiConstants.driverProfile}');
      print('=====================================================\n');
      authController.debugFetchAndPrintProfile();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'My Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Manage your driver account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({this.isProvider = false});

  final bool isProvider;

  String _getInitials(String name) {
    final nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.isEmpty || nameParts[0].isEmpty) return '';
    if (nameParts.length == 1) return nameParts[0][0].toUpperCase();
    return (nameParts[0][0] + nameParts.last[0]).toUpperCase();
  }

  ImageProvider? _getImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) {
      return NetworkImage(url);
    } else if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (_) {
        return null;
      }
    } else {
      return AssetImage(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final userProfile =
          Get.find<driver_ctrl.AuthController>().userProfile.value;

      final String userName = (userProfile?.name.trim().isNotEmpty ?? false) && userProfile!.name.trim() != 'Driver'
          ? userProfile.name.trim()
          : ((userProfile?.firstname.trim().isNotEmpty ?? false) && userProfile!.firstname.trim() != 'Driver'
              ? '${userProfile.firstname} ${userProfile.lastname}'.trim()
              : 'Driver');
      final String email = (userProfile?.email.trim().isNotEmpty ?? false)
          ? userProfile!.email.trim()
          : '';
      final String driverId = (userProfile?.phone.trim().isNotEmpty ?? false)
          ? userProfile!.phone.trim()
          : '';
      final String? imageUrl =
          (userProfile?.avatar != null && userProfile!.avatar.isNotEmpty)
          ? userProfile.avatar
          : null;
      final String initials = _getInitials(userName);

      return GestureDetector(
        onTap: () {
          print('\n=====================================================');
          print('🚀 [DEBUG] DRIVER PROFILE TOUCHED ON PROFILE SCREEN');
          print('URL: ${ApiConstants.baseUrl}${ApiConstants.driverProfile}');
          print('=====================================================\n');
          Get.find<driver_ctrl.AuthController>().debugFetchAndPrintProfile();
        },
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 80.h),
          padding: EdgeInsets.symmetric(
            vertical: 8.h,
            horizontal: 14.w,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21.18.r),
            border: Border.all(color: const Color(0xFFEEEEEE), width: 1.06),
          ),
          child: Row(
            children: [
              CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFFFFFBEA),
              backgroundImage: _getImageProvider(imageUrl),
              child: imageUrl == null || imageUrl.isEmpty
                  ? Text(
                      initials.isEmpty ? 'AB' : initials,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB020),
                        fontFamily: AppFonts.fontFamily,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 8.47.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.82.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF000000),
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.71.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF272727),
                      height: 1.2,
                      letterSpacing: -0.15,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text.rich(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    TextSpan(
                      text: 'ID: ',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.71.sp,
                        fontWeight: FontWeight.w300,
                        height: 1.2,
                        letterSpacing: -0.13,
                        color: const Color(0xFF272727),
                      ),
                      children: [
                        TextSpan(
                          text: driverId,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.71.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            letterSpacing: -0.15,
                            color: const Color(0xFF272727),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.47.w),
            GestureDetector(
              onTap: () async {
                print('\n=====================================================');
                print('🚀 [DEBUG] EDIT PROFILE BUTTON CLICKED ON PROFILE SCREEN');
                print('URL: ${ApiConstants.baseUrl}${ApiConstants.driverProfile}');
                print('=====================================================\n');
                final authController = Get.isRegistered<driver_ctrl.AuthController>()
                    ? Get.find<driver_ctrl.AuthController>()
                    : null;
                if (authController != null) {
                  await authController.debugFetchAndPrintProfile();
                }
                if (context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileEditScreen(
                        profile: authController?.userProfile.value ?? userProfile,
                      ),
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4.235, sigmaY: 4.235),
                  child: Container(
                    width: 74.w,
                    height: 28.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC00),
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -0.17,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  });
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final bookingController = Get.isRegistered<BookingHistoryController>()
        ? Get.find<BookingHistoryController>()
        : Get.put(BookingHistoryController());

    return Row(
      children: [
        // My Booking Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              Get.to(() => const BookingsHistoryScreen(showBackButton: true));
            },
            child: Container(
              width: 172.w,
              height: 50.h,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.71.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF5BD4C).withOpacity(0.05),
                    blurRadius: 4.24,
                    offset: const Offset(0, 0),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF614B8B).withOpacity(0.10),
                  width: 1.06,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFDFF),
                      borderRadius: BorderRadius.circular(5.r),
                      border: Border.all(
                        color: const Color(0xFFE2EEF5),
                        width: 1.0,
                      ),
                    ),
                    child: Image.asset(
                      'assets/icons/an2.png',
                      width: 16.w,
                      height: 16.h,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'My Booking',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Obx(() {
                          final count = bookingController.allBookings.length;
                          return Text(
                            count.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF94A3B8),
                    size: 18.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppFonts.fontFamily,
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }
}

class _DriverVehicleTile extends StatelessWidget {
  const _DriverVehicleTile({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final accountCtrl = Get.isRegistered<DriverAccountController>()
          ? Get.find<DriverAccountController>()
          : null;
      final vDetails = accountCtrl?.vehicleInfo.value?.vehicleDetails;

      final subtitleText = vDetails != null
          ? '${vDetails.make} ${vDetails.model} (${vDetails.registrationNumber})'
          : 'No vehicle assigned';

      return _ProfileTile(
        icon: Icons.directions_car_outlined,
        title: 'Vehicle Details',
        subtitle: subtitleText,
        statusText: vDetails?.verificationStatus ?? vDetails?.status,
        onTap: onTap,
      );
    });
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    this.icon,
    this.customIconAsset,
    this.customIconSize,
    required this.title,
    required this.subtitle,
    this.textColor,
    this.iconColor,
    this.isVerified = false,
    this.statusText,
    this.trailingWidget,
    this.onTap,
  });

  final IconData? icon;
  final String? customIconAsset;
  final Size? customIconSize;
  final String title;
  final String subtitle;
  final Color? textColor;
  final Color? iconColor;
  final bool isVerified;
  final String? statusText;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56.h,
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.only(
            top: 6.h,
            bottom: 6.h,
            left: 8.w,
            right: 15.w,
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFDFF),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                alignment: Alignment.center,
                child: customIconAsset != null
                    ? Image.asset(
                        customIconAsset!,
                        width: customIconSize?.width,
                        height: customIconSize?.height,
                      )
                    : Icon(
                        icon,
                        color: iconColor ?? const Color(0xFFFFB020),
                        size: 22.sp,
                      ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 0,
                        color: textColor ?? const Color(0xFF272727),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        letterSpacing: -0.12,
                        color: const Color(0xFF4F4F4F),
                      ),
                    ),
                  ],
                ),
              ),
              if (statusText != null && statusText!.isNotEmpty) ...[
                StatusBadge(status: statusText!),
                SizedBox(width: 8.w),
              ] else if (isVerified) ...[
                Container(
                  width: 41.w,
                  height: 16.h,
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35AF30).withOpacity(0.20),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 7.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                      letterSpacing: 0,
                      color: const Color(0xFF35AF30),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              trailingWidget ??
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF1E293B),
                    size: 18.sp,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
