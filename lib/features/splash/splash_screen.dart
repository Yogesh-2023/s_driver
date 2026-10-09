import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/secure_session_store.dart';
import '../../services/onboarding_step_service.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/documents_upload_step_screen.dart';
import '../auth/onboarding_screen.dart';
import '../auth/registration_step1_screen.dart';
import '../auth/selfie_verification_screen.dart';
import '../auth/vehicle_details_screen.dart';
import '../navigation/driver_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(
      begin: .65,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      final sessionCookie = await SecureSessionStore.readCookie();
      final authToken = await SecureSessionStore.readToken();
      final savedStep = await OnboardingStepService.getSavedStep();
      final isProviderDriver = await OnboardingStepService.isProviderDriver();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      debugPrint(
        '=== [SplashScreen] CHECK LOGIN: cookie=${sessionCookie != null && sessionCookie.isNotEmpty}, token=${authToken != null && authToken.isNotEmpty}, userId=$userId, savedStep=$savedStep ===',
      );

      final isLoggedIn = (sessionCookie != null && sessionCookie.isNotEmpty) ||
          (authToken != null && authToken.isNotEmpty) ||
          (userId != null && userId.isNotEmpty) ||
          (savedStep != null && savedStep.isNotEmpty);

      if (isLoggedIn) {
        if (!mounted) return;

        // ── STEP 1: Resolve target screen from savedStep FIRST ──────────────
        // This ensures that even if checkProfileStatus() clears the session
        // (401/403 for pending drivers), we still land on the correct screen.
        Widget? earlyTarget;
        if (savedStep == OnboardingStepService.stepHome) {
          earlyTarget = const DriverNavigationScreen();
        } else if (savedStep == OnboardingStepService.stepPending) {
          // Will re-evaluate after profile check below — leave null for now.
        } else if (savedStep == OnboardingStepService.stepDocuments) {
          earlyTarget = DocumentsUploadStepScreen(isProviderDriver: isProviderDriver);
        } else if (savedStep == OnboardingStepService.stepVehicle) {
          earlyTarget = VehicleDetailsScreen(isProviderDriver: isProviderDriver);
        } else if (savedStep == OnboardingStepService.stepProfile) {
          earlyTarget = RegistrationStep1Screen(isProviderDriver: isProviderDriver);
        } else if (savedStep == OnboardingStepService.stepSelfie) {
          earlyTarget = SelfieVerificationScreen(
            isProviderDriver: isProviderDriver,
            isProfileCompleted: false,
          );
        }

        // If we already have a definitive screen, navigate immediately
        // (skip profile API – avoids 401 clearing the session for pending drivers)
        if (earlyTarget != null) {
          debugPrint('=== [SplashScreen] ROUTING TO (early): ${earlyTarget.runtimeType} ===');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => earlyTarget!),
          );
          return;
        }

        // ── STEP 2: stepPending or no step → fetch profile first ────────────
        final authController = Get.isRegistered<AuthController>()
            ? Get.find<AuthController>()
            : null;

        if (authController != null) {
          try {
            await authController.checkProfileStatus();
          } catch (e) {
            debugPrint('=== [SplashScreen] checkProfileStatus error: $e ===');
          }
        }

        if (!mounted) return;

        Widget targetScreen;

        if (savedStep == OnboardingStepService.stepPending) {
          final vStatus =
              authController?.verificationStatus.value.toUpperCase() ?? '';
          if (vStatus == 'APPROVED' || vStatus == 'VERIFIED') {
            targetScreen = const DriverNavigationScreen();
          } else {
            // Still pending — go to home, which shows the pending banner
            targetScreen = const DriverNavigationScreen();
          }
        } else if (authController != null &&
            authController.isProfileImageMissing.value) {
          targetScreen = SelfieVerificationScreen(
            isProviderDriver: isProviderDriver,
            isProfileCompleted: authController.isProfileCompleted.value,
          );
        } else if (authController != null &&
            !authController.isProfileCompleted.value) {
          targetScreen = RegistrationStep1Screen(
            isProviderDriver: isProviderDriver,
          );
        } else {
          final profile = authController?.userProfile.value;
          final hasVehicle =
              profile != null && profile.assignedVehicles.isNotEmpty;
          if (!hasVehicle) {
            targetScreen = VehicleDetailsScreen(
              isProviderDriver: isProviderDriver,
            );
          } else {
            targetScreen = const DriverNavigationScreen();
          }
        }

        debugPrint(
          '=== [SplashScreen] ROUTING TO: ${targetScreen.runtimeType} ===',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
        );
        return;
      }
    } catch (e) {
      debugPrint('SplashScreen check login error: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                'assets/images/image3.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/image2.png',
                      width: 107.w,
                      height: 107.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 16.h),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Sawariyaa',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: 30.sp,
                            height: 1.0,
                            color: const Color(0xFF000000),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w400,
                            fontSize: 16.sp,
                            height: 1.0,
                            color: const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: FadeTransition(
              opacity: _fade,
              child: const Center(
                child: Text(
                  'Book Easy, Feel Happy',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: 10,
                    height: 1.0,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
