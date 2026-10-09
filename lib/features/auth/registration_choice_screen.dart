import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../services/onboarding_step_service.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/otp_verified_dialog.dart';
import 'controllers/auth_controller.dart';
import 'selfie_verification_screen.dart';
import '../auth/terms_screen.dart';
import '../dashboard/privacy_policy_screen.dart';
import 'personal_information_screen.dart';

class RegistrationChoiceScreen extends StatefulWidget {
  const RegistrationChoiceScreen({super.key});

  @override
  State<RegistrationChoiceScreen> createState() =>
      _RegistrationChoiceScreenState();
}

class _RegistrationChoiceScreenState extends State<RegistrationChoiceScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(4, (_) => FocusNode());

  bool _showOtpStep = false;
  int _resendTimerSeconds = 30;
  Timer? _timer;

  static const Color _yellow = Color(0xFFFFC700);
  static const Color _darkButton = Color(0xFF1E232A);
  static const Color _darkText = Color(0xFF0D0D0D);
  static const Color _purpleLink = Color(0xFF635BFF);

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
    for (int i = 0; i < 4; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_otpControllers[index].text.isEmpty && index > 0) {
            _otpControllers[index - 1].clear();
            _otpFocusNodes[index - 1].requestFocus();
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
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimerSeconds = 30;
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

  void _onGetOtp() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    final phoneRegExp = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegExp.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a Valid Number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final AuthController authController = Get.find<AuthController>();
    bool success = await authController.sendOtp(phone);
    if (success && mounted) {
      setState(() {
        _showOtpStep = true;
      });
      _startResendTimer();
    }
  }

  void _onVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid 4-digit code')),
      );
      return;
    }

    final AuthController authController = Get.find<AuthController>();
    bool success = await authController.verifyOtp(phone, otp);
    if (success && mounted) {
      if (authController.isProfileImageMissing.value) {
        await OnboardingStepService.saveStep(
          OnboardingStepService.stepSelfie,
          isProviderDriver: false,
        );
      } else if (!authController.isProfileCompleted.value) {
        await OnboardingStepService.saveStep(
          OnboardingStepService.stepProfile,
          isProviderDriver: false,
        );
      } else {
        await OnboardingStepService.saveStep(
          OnboardingStepService.stepVehicle,
          isProviderDriver: false,
        );
      }
      PushNotificationService.instance.syncToken();
      _showOtpVerifiedDialog();
    }
  }

  void _showOtpVerifiedDialog() {
    OtpVerifiedDialog.show(
      context,
      onClose: () {
        if (!mounted) return;
        final AuthController authController = Get.find<AuthController>();
        if (authController.isProfileImageMissing.value) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SelfieVerificationScreen(
                isProviderDriver: false,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const PersonalInformationScreen(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedPhone = _phoneController.text.trim();
    if (formattedPhone.length >= 10) {
      formattedPhone =
          '+91 ${formattedPhone.substring(0, 2)}XXXXXX${formattedPhone.substring(formattedPhone.length - 2)}';
    } else {
      formattedPhone = '+91 98XXXXXX45';
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top Header Section with loginpageframe.png & driver logo
                      SizedBox(
                        width: double.infinity,
                        height: _showOtpStep ? 240.h : 382.h,
                        child: Stack(
                          children: [
                            // Solid Yellow Header Background (#FFD428)
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFFFFD428),
                              ),
                            ),
                            SafeArea(
                              bottom: false,
                              child: Column(
                                children: [
                                  SizedBox(height: 16.h),

                                  // Centered Logo (Direct Image, No Container)
                                  Center(
                                    child: Image.asset(
                                      'assets/images/sanwari_driver_logo.png',
                                      width: 140.w,
                                      height: 54.h,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  if (!_showOtpStep) ...[
                                    SizedBox(height: 35.h),
                                    Text(
                                      'Welcome Back',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 23.sp,
                                        fontWeight: FontWeight.w700,
                                        height: 1.0,
                                        letterSpacing: 0,
                                        color: const Color(0xFF242A37),
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      "We're so excited to have you here.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14.5.sp,
                                        fontWeight: FontWeight.w400,
                                        height: 1.0,
                                        letterSpacing: 0,
                                        color: const Color(0xFF242A37),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form Card / OTP Card Container
                      if (_showOtpStep)
                        Transform.translate(
                          offset: Offset(0, -65.h),
                          child: _buildOtpCardView(formattedPhone),
                        )
                      else
                        Transform.translate(
                          offset: Offset(0, -95.h),
                          child: Center(
                            child: Container(
                              width: 350.w,
                              height: 350.h,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 20.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: const Color(0xFFF0F0F0),
                                  width: 1.05,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _buildPhoneCardView(),
                            ),
                          ),
                        ),

                      if (!_showOtpStep) const Spacer(),

                      // Footer Links for Login Screen
                      if (!_showOtpStep)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 24.w,
                              right: 24.w,
                              bottom: 24.h,
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: const Color(0xFF1C1C1E),
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'By Clicking Sign in you Agree to the\n',
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PrivacyPolicyScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Terms of Use',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const TermsScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 12.h),
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

  Widget _buildPhoneCardView() {
    return Column(
      key: const ValueKey('phoneView'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in with your',
              style: TextStyle(
                fontSize: 25.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0D0D0D),
                height: 1.0,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Phone number',
              style: TextStyle(
                fontSize: 25.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFC000),
                height: 1.0,
                letterSpacing: 0,
              ),
            ),
          ],
        ),

        SizedBox(height: 14.h),

        // Country/Region Box
        Container(
          width: double.infinity,
          height: 57.5.h,
          padding: EdgeInsets.symmetric(
            horizontal: 15.w,
            vertical: 6.5.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.6.r),
            border: Border.all(
              color: const Color(0xFFECECEC),
              width: 1.1,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Country/Region',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: const Color(0xFF8E8E93),
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Text(
                        '🇮🇳',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'India(+91)',
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D0D0D),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 0,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: const Color(0xFF0D0D0D),
                  size: 26.sp,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 6.h),

        // Enter Phone Number Box
        Container(
          width: double.infinity,
          height: 57.5.h,
          padding: EdgeInsets.symmetric(
            horizontal: 15.w,
            vertical: 6.5.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.6.r),
            border: Border.all(
              color: const Color(0xFFECECEC),
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Enter Phone Number',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 3.h),
              SizedBox(
                height: 18.h,
                child: TextField(
                  controller: _phoneController,
                  keyboardType: const TextInputType.numberWithOptions(),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  maxLength: 10,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D0D0D),
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '9876543210',
                    hintStyle: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // Sign In Button
        GestureDetector(
          onTap: _onGetOtp,
          child: Container(
            width: double.infinity,
            height: 42.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1E232A),
              borderRadius: BorderRadius.circular(10.48.r),
            ),
            alignment: Alignment.center,
            child: Text(
              'Sign In',
              style: TextStyle(
                fontSize: 15.5.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpCardView(String formattedPhone) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 657.h),
      padding: EdgeInsets.fromLTRB(20.w, 35.h, 20.w, 35.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
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
          Text(
            'Verify Your Number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23.sp,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: const Color(0xFF242A37),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "We've sent a 4-digit code to",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF242A37),
            ),
          ),
          SizedBox(height: 6.h),
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
                onTap: () {
                  setState(() {
                    _showOtpStep = false;
                  });
                },
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _purpleLink,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 35.h),

          // Enter Code Section
          SizedBox(
            width: 320.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(7, (index) {
                    if (index.isOdd) return SizedBox(width: 10.w);
                    final boxIndex = index ~/ 2;

                    bool isFilledOrFocused =
                        _otpControllers[boxIndex].text.isNotEmpty ||
                        _otpFocusNodes[boxIndex].hasFocus;

                    return Container(
                      width: 55.w,
                      height: 55.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
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
                                  LogicalKeyboardKey.backspace) {
                            if (_otpControllers[boxIndex].text.isEmpty &&
                                boxIndex > 0) {
                              _otpControllers[boxIndex - 1].clear();
                              _otpFocusNodes[boxIndex - 1].requestFocus();
                              setState(() {});
                            }
                          }
                        },
                        child: SizedBox(
                          height: 24.h,
                          child: TextField(
                            controller: _otpControllers[boxIndex],
                            focusNode: _otpFocusNodes[boxIndex],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            textAlignVertical: TextAlignVertical.center,
                            maxLength: 1,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              color: const Color(0xFF000000),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '-',
                              hintStyle: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                                color: const Color(0xFFC7C7CC),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && boxIndex < 3) {
                                _otpFocusNodes[boxIndex + 1].requestFocus();
                              } else if (value.isEmpty && boxIndex > 0) {
                                _otpControllers[boxIndex - 1].clear();
                                _otpFocusNodes[boxIndex - 1].requestFocus();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                SizedBox(height: 10.h),

                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                    children: [
                      if (_resendTimerSeconds > 0) ...[
                        const TextSpan(text: 'Resend in '),
                        TextSpan(
                          text: '${_resendTimerSeconds ~/ 60}:${(_resendTimerSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF242A37),
                          ),
                        ),
                      ] else ...[
                        const TextSpan(text: "Didn't receive code? "),
                        TextSpan(
                          text: 'Resend again',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF635BFF),
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = _onGetOtp,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 35.h),

          // OTP Verify Button
          GestureDetector(
            onTap: _onVerifyOtp,
            child: Container(
              width: double.infinity,
              height: 42.h,
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.8.w),
              decoration: BoxDecoration(
                color: const Color(0xFF242A37),
                borderRadius: BorderRadius.circular(10.48.r),
              ),
              alignment: Alignment.center,
              child: Text(
                'OTP Verify',
                style: TextStyle(
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FourPointStarWidget extends StatelessWidget {
  final double size;
  final Color color;

  const FourPointStarWidget({
    Key? key,
    required this.size,
    this.color = const Color(0xFFFFB800),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FourPointStarPainter(color: color),
      ),
    );
  }
}

class _FourPointStarPainter extends CustomPainter {
  final Color color;
  _FourPointStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    double w = size.width;
    double h = size.height;
    double cx = w / 2;
    double cy = h / 2;

    path.moveTo(cx, 0);
    path.quadraticBezierTo(cx, cy, w, cy);
    path.quadraticBezierTo(cx, cy, cx, h);
    path.quadraticBezierTo(cx, cy, 0, cy);
    path.quadraticBezierTo(cx, cy, cx, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
