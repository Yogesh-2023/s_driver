import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'phone_login_screen.dart';
import '../navigation/driver_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  static const Color _yellow = Color(0xFFFFC700);
  static const Color _darkText = Color(0xFF0D0D0D);

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _onboardingPages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _onboardingPages = [
    {
      'image': 'assets/images/image 16.png',
      'fallbackImage': 'assets/images/Image.png',
      'badge': 'Welcome Driver',
      'titleSpans': [
        {'text': 'Start Driving With ', 'isYellow': false},
        {'text': 'Sawariyaa', 'isYellow': true},
      ],
      'description':
          'Accept rides, earn daily, and manage your trips with ease.',
    },
    {
      'image': 'assets/images/image 17.png',
      'fallbackImage': 'assets/images/Image1.png',
      'badge': 'Accept Ride Requests',
      'titleSpans': [
        {'text': 'Accept Trips ', 'isYellow': false},
        {'text': 'Instantly', 'isYellow': true},
      ],
      'description':
          'Receive nearby ride requests and start earning in just one tap.',
    },
    {
      'image': 'assets/images/image 18.png',
      'fallbackImage': 'assets/images/Image1.png',
      'badge': 'Navigate & Earn',
      'titleSpans': [
        {'text': 'Navigate, Complete ', 'isYellow': false},
        {'text': '& Earn', 'isYellow': true},
      ],
      'description':
          'Use live navigation, complete trips, and track your earnings in real time.',
    },
  ];

  void _nextPage() {
    if (_currentPage < _onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToNextScreen();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToNextScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhoneLoginScreen(),
      ),
    );
  }

  void _navigateToHomeScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverNavigationScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row (Logo + Skip)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/sanwari_driver_logo.png',
                    width: 112.w,
                    height: 54.h,
                    fit: BoxFit.contain,
                  ),
                  // Skip Button (Figma Properties)
                  GestureDetector(
                    onTap: _navigateToHomeScreen,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(200.r),
                      ),
                      child: Text(
                        'Skip',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF000000),
                          height: 1.0,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingPages.length,
                itemBuilder: (context, index) {
                  final page = _onboardingPages[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Illustration Image
                        Expanded(
                          child: Center(
                            child: Image.asset(
                              page['image'] as String,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                page['fallbackImage'] as String,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.directions_car,
                                  size: 120.sp,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12.h),

                        // Badge Tag (Figma Properties)
                        Container(
                          height: 30.96.h,
                          padding: EdgeInsets.only(
                            top: 5.16.h,
                            bottom: 5.16.h,
                            left: 5.16.w,
                            right: 12.38.w,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(35.08.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 20.64.r,
                                height: 20.64.r,
                                decoration: const BoxDecoration(
                                  color: _yellow,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11.sp,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 5.16.w),
                              Text(
                                page['badge'] as String,
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 12.38.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF000000),
                                  height: 1.0,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // Headline Title
                        RichText(
                          text: TextSpan(
                            children: (page['titleSpans'] as List<Map<String, dynamic>>)
                                .map(
                                  (span) => TextSpan(
                                    text: span['text'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 32.sp,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                      color: (span['isYellow'] as bool) ? _yellow : _darkText,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // Subtitle / Description (Figma Properties)
                        Text(
                          page['description'] as String,
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),

                        SizedBox(height: 16.h),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Buttons Bar
            Padding(
              padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 16.h, top: 10.h),
              child: _buildBottomButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required Color backgroundColor,
    Color? borderColor,
    Color textColor = const Color(0xFF0D0D0D),
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentPage == 0) {
      // Slide 1: Single full-width light button "Continue"
      return _buildActionButton(
        label: 'Continue',
        onTap: _nextPage,
        backgroundColor: const Color(0xFFF7F7F7),
        borderColor: const Color(0xFFE5E5E5),
      );
    } else if (_currentPage == 1) {
      // Slide 2: Two buttons - "Back" (light) + "Continue" (yellow)
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: 'Back',
              onTap: _previousPage,
              backgroundColor: const Color(0xFFF7F7F7),
              borderColor: const Color(0xFFE5E5E5),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: _buildActionButton(
              label: 'Continue',
              onTap: _nextPage,
              backgroundColor: _yellow,
            ),
          ),
        ],
      );
    } else {
      // Slide 3: Single full-width yellow button "Get Started"
      return _buildActionButton(
        label: 'Get Started',
        onTap: _navigateToNextScreen,
        backgroundColor: _yellow,
      );
    }
  }
}
