import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../services/push_notification_service.dart';
import '../../services/onboarding_step_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/sawariyaa_driver_logo.dart';
import '../../widgets/otp_verified_dialog.dart';
import 'controllers/auth_controller.dart';
import '../navigation/driver_navigation_screen.dart';
import 'registration_step1_screen.dart';
import 'selfie_verification_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isProviderDriver;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.isProviderDriver = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  bool _isResending = false;
  int _resendTimerSeconds = 180;
  Timer? _timer;

  static const Color _yellow = Color(0xFFFFC000);
  static const Color _darkButton = Color(0xFF242A37);
  static const Color _darkText = Color(0xFF0D0D0D);
  static const Color _purpleLink = Color(0xFF635BFF);

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (index) => FocusNode());
    _controllers = List.generate(4, (index) => TextEditingController());
    _startResendTimer();

    for (int i = 0; i < 4; i++) {
      final index = i;
      _focusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _controllers[index - 1].clear();
            _focusNodes[index - 1].requestFocus();
            setState(() {});
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        if (mounted) {
          setState(() {
            _resendTimerSeconds--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isResending || _resendTimerSeconds > 0) return;
    setState(() => _isResending = true);

    try {
      final AuthController authController = Get.find<AuthController>();
      bool success = await authController.sendOtp(widget.phoneNumber);
      if (success && mounted) {
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes.first.requestFocus();
        _startResendTimer();
        CustomSnackbar.showSuccess(message: 'OTP sent again successfully');
      }
    } catch (error) {
      if (mounted) {
        CustomSnackbar.showError(message: 'OTP resend failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _verifyAndContinue() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 4) {
      CustomSnackbar.showError(message: 'Please enter complete 4-digit OTP');
      return;
    }

    final AuthController authController = Get.find<AuthController>();
    bool success = await authController.verifyOtp(widget.phoneNumber, otp);

    if (success && mounted) {
      if (authController.isProfileImageMissing.value) {
        await OnboardingStepService.saveStep(
          OnboardingStepService.stepSelfie,
          isProviderDriver: widget.isProviderDriver,
        );
      } else if (!authController.isProfileCompleted.value || widget.isProviderDriver) {
        await OnboardingStepService.saveStep(
          OnboardingStepService.stepProfile,
          isProviderDriver: widget.isProviderDriver,
        );
      } else {
        await OnboardingStepService.saveStep(
          OnboardingStepService.stepHome,
          isProviderDriver: widget.isProviderDriver,
        );
      }

      PushNotificationService.instance.syncToken();
      if (!mounted) return;

      OtpVerifiedDialog.show(
        context,
        onClose: () {
          if (!mounted) return;
          if (authController.isProfileImageMissing.value) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SelfieVerificationScreen(
                  isProviderDriver: widget.isProviderDriver,
                  isProfileCompleted: authController.isProfileCompleted.value,
                ),
              ),
            );
          } else if (!authController.isProfileCompleted.value || widget.isProviderDriver) {
            Get.offAll(() => RegistrationStep1Screen(isProviderDriver: widget.isProviderDriver));
          } else {
            Get.offAll(() => const DriverNavigationScreen());
          }
        },
      );
    }
  }

  String _getFormattedPhone() {
    String p = widget.phoneNumber.trim();
    if (p.startsWith('+91') && p.length >= 13) {
      return '+91 ${p.substring(3, 5)}XXXXXX${p.substring(p.length - 2)}';
    } else if (p.length >= 10) {
      return '+91 ${p.substring(0, 2)}XXXXXX${p.substring(p.length - 2)}';
    }
    return widget.phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _getFormattedPhone();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top Header Section with solid #FFD428 background & loginpageframe
                        SizedBox(
                          width: double.infinity,
                          height: 170.h,
                          child: Stack(
                            children: [
                              // Solid Yellow Header Background (#FFD428)
                              Positioned.fill(
                                child: Container(
                                  color: const Color(0xFFFFD428),
                                ),
                              ),

                              // Logo in White Container (Centered, matching Login Screen)
                              SafeArea(
                                child: Column(
                                  children: [
                                    SizedBox(height: 26.h),
                                     const Center(
                                       child: SawariyaaDriverLogo(),
                                     ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // White OTP Card Container
                        Transform.translate(
                          offset: Offset(0, -15.h),
                          child: Container(
                            width: double.infinity,
                            constraints: BoxConstraints(minHeight: 580.h),
                            padding: EdgeInsets.fromLTRB(
                              20.w,
                              40.h,
                              20.w,
                              35.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(30.r),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title: Verify Your Number
                                Text(
                                  'Verify Your Number',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 23.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                    color: _darkButton,
                                  ),
                                ),
                                SizedBox(height: 8.h),

                                // Subtitle
                                Text(
                                  "We've sent a 6-digit verification code to",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                                SizedBox(height: 6.h),

                                // Phone Number + Change Link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      formattedPhone,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _darkText,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Text(
                                        'Change',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF635BFF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 18.h),
                                // Enter Code Parent Section
                                SizedBox(
                                  width: 320.w,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Enter Code Label
                                      Text(
                                        'Enter Code',
                                        style: TextStyle(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: _darkText,
                                        ),
                                      ),

                                      SizedBox(height: 10.h),

                                      // 4 OTP Boxes
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: List.generate(7, (index) {
                                          if (index.isOdd) {
                                            return SizedBox(width: 10.w);
                                          }
                                          final boxIndex = index ~/ 2;
                                          bool isFilledOrFocused =
                                              _controllers[boxIndex]
                                                  .text
                                                  .isNotEmpty ||
                                              _focusNodes[boxIndex].hasFocus;

                                          return Container(
                                            width: 55.w,
                                            height: 55.w,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              border: Border.all(
                                                color: isFilledOrFocused
                                                    ? _yellow
                                                    : const Color(0x33000000),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: KeyboardListener(
                                              focusNode: FocusNode(),
                                              onKeyEvent: (event) {
                                                if (event is KeyDownEvent &&
                                                    event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .backspace) {
                                                  if (_controllers[boxIndex]
                                                          .text
                                                          .isEmpty &&
                                                      boxIndex > 0) {
                                                    _controllers[boxIndex - 1]
                                                        .clear();
                                                    _focusNodes[boxIndex - 1]
                                                        .requestFocus();
                                                    setState(() {});
                                                  }
                                                }
                                              },
                                              child: Transform.translate(
                                                offset: Offset(0, 5.h),
                                                child: SizedBox(
                                                  height: 24.h,
                                                  child: TextField(
                                                    controller:
                                                        _controllers[boxIndex],
                                                    focusNode:
                                                        _focusNodes[boxIndex],
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                      LengthLimitingTextInputFormatter(
                                                        1,
                                                      ),
                                                    ],
                                                    textAlign: TextAlign.center,
                                                    textAlignVertical:
                                                        TextAlignVertical
                                                            .center,
                                                    maxLength: 1,
                                                    style: TextStyle(
                                                      fontFamily: 'Gilroy',
                                                      fontSize: 14.sp,
                                                      fontWeight: FontWeight.w700,
                                                      height: 1.2,
                                                      letterSpacing: -0.12,
                                                      color: const Color(
                                                        0xFF000000,
                                                      ),
                                                    ),
                                                    decoration: InputDecoration(
                                                      counterText: '',
                                                      hintText: '-',
                                                      hintStyle: TextStyle(
                                                        fontFamily: 'Gilroy',
                                                        fontSize: 14.sp,
                                                        fontWeight: FontWeight.w500,
                                                        height: 1.2,
                                                        letterSpacing: -0.12,
                                                        color: const Color(
                                                          0xFF000000,
                                                        ),
                                                      ),
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                    onChanged: (val) {
                                                      setState(() {});
                                                      if (val.isNotEmpty &&
                                                          boxIndex < 3) {
                                                        _focusNodes[boxIndex + 1]
                                                            .requestFocus();
                                                      } else if (val.isEmpty &&
                                                          boxIndex > 0) {
                                                        _focusNodes[boxIndex - 1]
                                                            .requestFocus();
                                                      } else if (boxIndex == 3 &&
                                                          val.isNotEmpty) {
                                                        FocusManager
                                                            .instance
                                                            .primaryFocus
                                                            ?.unfocus();
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),

                                      SizedBox(height: 12.h),

                                      // 60-second countdown or underlined Resend OTP link
                                      if (_resendTimerSeconds > 0)
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 13.sp,
                                              color: const Color(0xFF8E8E93),
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Resend OTP in ',
                                              ),
                                              TextSpan(
                                                text: '${_resendTimerSeconds}s',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF242A37),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: (_isResending || _resendTimerSeconds > 0)
                                              ? null
                                              : _resendOtp,
                                          child: Text(
                                            _isResending
                                                ? 'Sending OTP...'
                                                : 'Resend OTP',
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: _purpleLink,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: _purpleLink,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                 SizedBox(height: 35.h),

                                 // OTP Verify Button
                                 Obx(() {
                                   final AuthController authController =
                                       Get.find<AuthController>();
                                   final bool isLoading =
                                       authController.isLoading.value;
                                   return GestureDetector(
                                     onTap: isLoading || _isResending
                                         ? null
                                         : _verifyAndContinue,
                                     child: Container(
                                       width: double.infinity,
                                       height: 42.h,
                                       padding: EdgeInsets.symmetric(
                                         horizontal: 8.8.w,
                                         vertical: 12.h,
                                       ),
                                       decoration: BoxDecoration(
                                         color: _darkButton,
                                         borderRadius:
                                             BorderRadius.circular(10.48.r),
                                       ),
                                       alignment: Alignment.center,
                                       child: isLoading
                                           ? SizedBox(
                                               width: 20.w,
                                               height: 20.w,
                                               child:
                                                   const CircularProgressIndicator(
                                                 strokeWidth: 2,
                                                 color: Colors.white,
                                               ),
                                             )
                                           : Text(
                                               'OTP Verify',
                                               style: TextStyle(
                                                 fontSize: 15.5.sp,
                                                 fontWeight: FontWeight.w700,
                                                 color: Colors.white,
                                                 height: 1.0,
                                               ),
                                             ),
                                     ),
                                   );
                                 }),

                                 SizedBox(height: 35.h),

                                 // Bottom "Didn't receive the code? Resend OTP" Text
                                 Center(
                                   child: RichText(
                                     textAlign: TextAlign.center,
                                     text: TextSpan(
                                       style: TextStyle(
                                         fontFamily: 'Gilroy',
                                         fontSize: 12.22.sp,
                                         fontWeight: FontWeight.w500,
                                         height: 1.2,
                                         letterSpacing: 0,
                                         color: const Color(0xFF666666),
                                       ),
                                       children: [
                                         const TextSpan(
                                           text: "Didn't receive the code? ",
                                         ),
                                         if (_resendTimerSeconds > 0)
                                           TextSpan(
                                             text:
                                                 "Resend OTP in ${_resendTimerSeconds}s",
                                             style: TextStyle(
                                               fontFamily: 'Gilroy',
                                               fontSize: 12.22.sp,
                                               fontWeight: FontWeight.w600,
                                               color: const Color(0xFF8E8E93),
                                             ),
                                           )
                                         else
                                           TextSpan(
                                             text: _isResending
                                                 ? "Sending..."
                                                 : "Resend OTP",
                                             style: TextStyle(
                                               fontFamily: 'Gilroy',
                                               fontSize: 12.22.sp,
                                               fontWeight: FontWeight.w700,
                                               color: _isResending
                                                   ? const Color(0xFF8E8E93)
                                                   : _purpleLink,
                                               decoration:
                                                   TextDecoration.underline,
                                               decorationColor: _purpleLink,
                                             ),
                                             recognizer: TapGestureRecognizer()
                                               ..onTap = (_isResending ||
                                                       _resendTimerSeconds > 0)
                                                   ? null
                                                   : _resendOtp,
                                           ),
                                       ],
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
               );
             },
           ),
         ),
       ),
     );
   }
 }
