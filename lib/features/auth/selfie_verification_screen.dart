import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../services/onboarding_step_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_snackbar.dart';
import 'controllers/auth_controller.dart';
import '../navigation/driver_navigation_screen.dart';
import 'registration_step1_screen.dart';

class SelfieVerificationScreen extends StatefulWidget {
  final bool isProfileCompleted;
  final bool isProviderDriver;

  const SelfieVerificationScreen({
    super.key,
    this.isProfileCompleted = false,
    this.isProviderDriver = false,
  });

  @override
  State<SelfieVerificationScreen> createState() =>
      _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  File? _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    OnboardingStepService.saveStep(
      OnboardingStepService.stepSelfie,
      isProviderDriver: widget.isProviderDriver,
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverNavigationScreen()),
      (_) => false,
    );
  }

  Future<void> _takeSelfie() async {
    final image = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(builder: (_) => const _FrontSelfieCameraScreen()),
    );

    if (image != null && mounted) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _onContinue() async {
    final imageFile = _imageFile;
    if (imageFile == null) {
      CustomSnackbar.showError(message: 'Please capture a selfie to continue');
      return;
    }

    setState(() => _isUploading = true);
    final success = await Get.find<AuthController>().uploadProfileImage(
      imageFile,
    );
    if (!mounted) return;
    setState(() => _isUploading = false);

    if (!success) return;

    await OnboardingStepService.saveStep(
      OnboardingStepService.stepProfile,
      isProviderDriver: widget.isProviderDriver,
    );

    if (!mounted) return;

    // Navigate to next screen based on profile completion status
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationStep1Screen(isProviderDriver: widget.isProviderDriver),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: EdgeInsets.only(left: 16.w),
            child: Center(
              child: InkWell(
                onTap: _handleBack,
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20.h),
                Text(
                  'Take a Selfie',
                  style: AppFonts.h1,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Please take a clear selfie for your driver profile to ensure smooth verification.',
                  style: AppFonts.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40.h),

                // Camera / Preview Area
                GestureDetector(
                  onTap: _takeSelfie,
                  child: Container(
                    width: 250.w,
                    height: 250.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.field,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: _imageFile != null
                        ? ClipOval(
                            child: Transform.scale(
                              scaleX: -1,
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                                width: 250.w,
                                height: 250.w,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 60.w,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Tap to Capture',
                                style: AppFonts.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: 40.h),

                // Guidance Cards
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 14.w,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Make sure your face is straight, well-lit, and clearly visible. Keep your eyes open and blink naturally without sunglasses or hats.',
                          style: AppFonts.body.copyWith(
                            fontSize: 12.sp,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                if (_imageFile != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _takeSelfie,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            side: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'Retake',
                            style: AppFonts.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: PrimaryButton(
                          text: _isUploading ? 'Uploading...' : 'Continue',
                          onPressed: _isUploading ? null : _onContinue,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  PrimaryButton(
                    text: 'Open Camera',
                    onPressed: _isUploading ? null : _takeSelfie,
                  ),
                ],

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FrontSelfieCameraScreen extends StatefulWidget {
  const _FrontSelfieCameraScreen();

  @override
  State<_FrontSelfieCameraScreen> createState() =>
      _FrontSelfieCameraScreenState();
}

class _FrontSelfieCameraScreenState extends State<_FrontSelfieCameraScreen> {
  CameraController? _controller;
  String? _errorMessage;
  bool _isInitializing = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeFrontCamera();
  }

  Future<void> _initializeFrontCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      CameraDescription? selectedCamera;
      try {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (_) {
        selectedCamera = cameras.first;
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Front camera is not available.';
        _isInitializing = false;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(context, image);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to capture selfie. Please try again.';
        _isCapturing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isInitializing)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 24.w,
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppFonts.body.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (controller != null && controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: 1 / controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
            Positioned(
              top: 12.h,
              left: 12.w,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28.h,
              child: Center(
                child: GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 54.w,
                        height: 54.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white,
                        ),
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
  }
}
