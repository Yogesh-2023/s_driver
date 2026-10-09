import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/onboarding_step_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/common_save_button.dart';
import 'controllers/auth_controller.dart';
import '../navigation/driver_navigation_screen.dart';

class DocumentsUploadStepScreen extends StatefulWidget {
  final bool isProviderDriver;
  final bool isReadOnly;

  const DocumentsUploadStepScreen({
    super.key,
    this.isProviderDriver = false,
    this.isReadOnly = false,
  });

  @override
  State<DocumentsUploadStepScreen> createState() =>
      _DocumentsUploadStepScreenState();
}

class _DocumentsUploadStepScreenState extends State<DocumentsUploadStepScreen> {
  // Color Palette
  static const Color _yellow = Color(0xFFFFC700);
  static const Color _headerCream = Color(0xFFFFF9E6);
  static const Color _bgCream = Color(0xFFFEFAF4);
  static const Color _darkText = Color(0xFF0D0D0D);

  // Document Upload Statuses
  final Map<String, File?> _uploadedDocs = {};
  // Tracks documents already submitted to server (URL → key mapping)
  final Map<String, String> _submittedDocUrls = {};
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isReadOnly) {
      OnboardingStepService.saveStep(
        OnboardingStepService.stepDocuments,
        isProviderDriver: widget.isProviderDriver,
      );
    }
    _fetchKycStatus();
  }

  /// Fetches already-submitted KYC documents from the server and marks them
  /// with a "Pending" badge so the driver can see what's been uploaded.
  Future<void> _fetchKycStatus() async {
    try {
      final authController = Get.find<AuthController>();
      final response =
          await authController.authRepository.getKycStatus();
      if (response.isOk && response.body != null) {
        final body = response.body;
        // API may return { data: { documents: [...] } } or similar shapes
        dynamic docs =
            (body['data']?['documents']) ??
            body['documents'] ??
            body['data'] ??
            [];

        // Map of server docType key → local docKey
        const docTypeMap = {
          'AADHAR_FRONT': 'aadhar_front',
          'AADHAR_BACK': 'aadhar_back',
          'PAN_CARD': 'pan_card',
          'DL_FRONT': 'dl_front',
          'DL_BACK': 'dl_back',
          'RC': 'rc',
          'INSURANCE': 'insurance',
          'PROFILE_PHOTO': 'profile_photo',
          'PASSBOOK_IMAGE': 'passbook',
          'PASSBOOK': 'passbook',
          'BANK_PASSBOOK': 'passbook',
          'VEHICLE_PHOTO': 'vehicle_photo',
          'VEHICLE_PHOTOS': 'vehicle_photo',
          'VEHICLE_FRONT_PHOTO': 'vehicle_photo',
          'RESIDENCE_PROOF': 'aadhar_front',
          'RESIDENCE_PROOF_BACK': 'aadhar_back',
          'DRIVING_LICENSE': 'dl_front',
          'DRIVING_LICENSE_BACK': 'dl_back',
          'VEHICLE_REGISTRATION': 'rc',
          'VEHICLE_INSURANCE': 'insurance',
          'COMMERCIAL_PERMIT': 'permit',
          'PERMIT': 'permit',
        };

        if (docs is List) {
          for (final doc in docs) {
            if (doc is! Map) continue;
            final type = (doc['documentType'] ??
                    doc['type'] ??
                    doc['docType'] ??
                    '')
                .toString()
                .toUpperCase();
            final url = (doc['documentUrl'] ??
                    doc['url'] ??
                    doc['fileUrl'] ??
                    '')
                .toString();
            final localKey = docTypeMap[type];
            if (localKey != null && url.isNotEmpty) {
              _submittedDocUrls[localKey] = url;
            }
          }
        } else if (docs is Map) {
          // Some APIs return { RESIDENCE_PROOF: 'url', ... }
          docs.forEach((k, v) {
            final localKey = docTypeMap[k.toString().toUpperCase()];
            if (localKey != null && v != null && v.toString().isNotEmpty) {
              _submittedDocUrls[localKey] = v.toString();
            }
          });
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('=== [KYC Status] fetch error: $e ===');
    }
  }

  void _onBack() {
    Navigator.pop(context);
  }

  void _pickDocument(String docKey) {
    if (widget.isReadOnly) {
      CustomSnackbar.showError(
        message: 'Documents are under verification and cannot be edited right now.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38.w,
                  height: 4.5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Upload Photo',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 16.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? file =
                              await _picker.pickImage(source: ImageSource.camera);
                          if (file != null) {
                            setState(() {
                              _uploadedDocs[docKey] = File(file.path);
                            });
                          }
                        },
                        child: Container(
                          height: 104.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: const Color(0xFFEEEEEE),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFF9E6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: const Color(0xFFFFC000),
                                  size: 24.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Camera',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _darkText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? file =
                              await _picker.pickImage(source: ImageSource.gallery);
                          if (file != null) {
                            setState(() {
                              _uploadedDocs[docKey] = File(file.path);
                            });
                          }
                        },
                        child: Container(
                          height: 104.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: const Color(0xFFEEEEEE),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFF9E6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.photo_library_rounded,
                                  color: const Color(0xFFFFC000),
                                  size: 24.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _darkText,
                                ),
                              ),
                            ],
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
      },
    );
  }

  bool _validateStep3() {
    final requiredDocs = [
      ('aadhar_front', 'Aadhar Card (Front)'),
      ('aadhar_back', 'Aadhar Card (Back)'),
      ('pan_card', 'PAN Card'),
      ('dl_front', 'Driving License (Front)'),
      ('dl_back', 'Driving License (Back)'),
      ('rc', 'Vehicle Registration (RC)'),
      ('insurance', 'Insurance Certificate'),
    ];

    for (final doc in requiredDocs) {
      final bool hasDoc =
          _uploadedDocs[doc.$1] != null || _submittedDocUrls.containsKey(doc.$1);
      if (!hasDoc) {
        _showSnackBar('Please upload ${doc.$2} before submitting');
        return false;
      }
    }
    return true;
  }

  void _onSubmit() async {
    if (_isLoading) return;
    if (_validateStep3()) {
      setState(() => _isLoading = true);
      try {
        final authController = Get.find<AuthController>();
        final filesToUpload = <String, File>{};
        _uploadedDocs.forEach((key, file) {
          if (file != null) {
            filesToUpload[key] = file;
          }
        });

        final success =
            await authController.submitDriverKycDocuments(filesToUpload);

        if (success && mounted) {
          await OnboardingStepService.saveStep(
            OnboardingStepService.stepHome,
            isProviderDriver: widget.isProviderDriver,
          );
          if (!mounted) return;
          _showSuccessDialog();
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Something went wrong: $e');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    CustomSnackbar.showError(message: message);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.r,
                height: 64.r,
                decoration: const BoxDecoration(
                  color: _yellow,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 36.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                'Registration Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Your application has been submitted successfully and is currently under verification.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.sp,
                  color: const Color(0xFF666666),
                ),
              ),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  Get.offAll(
                    () => const DriverNavigationScreen(),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242A37),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Go to Dashboard',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: _bgCream,
          body: Column(
            children: [
              // Top Header Section
              SizedBox(
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 78.h,
                          color: _headerCream,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 6.h,
                            left: 16.w,
                          ),
                          alignment: Alignment.topLeft,
                          child: GestureDetector(
                            onTap: _onBack,
                            child: Container(
                              width: 34.r,
                              height: 34.r,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_back,
                                size: 18.sp,
                                color: _darkText,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 16.w, top: 14.h, bottom: 6.h),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      color: _darkText,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Upload Your '),
                                      TextSpan(
                                        text: 'Documents',
                                        style: TextStyle(color: _yellow),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                SizedBox(
                                  width: 170.w,
                                  child: Text(
                                    "Please upload clear & valid\ndocuments to verify your\naccount.",
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF666666),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: -10.w,
                      top: 68.h,
                      child: Image.asset(
                        'assets/images/image 21.png',
                        width: 180.w,
                        height: 168.h,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/images/image10.png',
                          width: 180.w,
                          height: 168.h,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Step Progress Bar
              Padding(
                padding: EdgeInsets.only(top: 10.h, left: 16.w, right: 16.w, bottom: 14.h),
                child: _buildStepProgressBar(3),
              ),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      _buildSecurityBanner(),
                      SizedBox(height: 12.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 18.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildDocumentsForm(),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgressBar(int activeStep) {
    return Container(
      height: 65.h,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 10.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1.5.h,
                    color: _yellow,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1.5.h,
                    color: _yellow,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepCircle(1, 'Profile', activeStep),
              _buildStepCircle(2, 'Vehicle', activeStep),
              _buildStepCircle(3, 'Documents', activeStep),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, int activeStep) {
    bool isCompleted = activeStep > step;
    bool isCurrent = activeStep == step;
    bool isActive = isCurrent || isCompleted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24.r,
          height: 24.r,
          decoration: BoxDecoration(
            color: isActive ? _yellow : const Color(0xFFAFAFAF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isActive ? const Color(0xFFFFC000) : const Color(0xFFAFAFAF),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF4E1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFFFE3AE), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your documents are 100% secure',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF414141),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'We never share your data with anyone.',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF676767),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Personal Identity Proofs
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0x33000000), width: 1.0),
          ),
          child: Column(
            children: [
              _buildDocumentUploadItem(
                docKey: 'aadhar_front',
                title: 'Aadhar Card (Front)',
                subtitle: 'Upload front side of Aadhar Card',
                iconAsset: 'assets/icons/Vector (9).png',
                iconBg: const Color(0xFFFEF6E7),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ),
              _buildDocumentUploadItem(
                docKey: 'aadhar_back',
                title: 'Aadhar Card (Back)',
                subtitle: 'Upload Back side of Aadhar Card',
                iconAsset: 'assets/icons/Vector (7).png',
                iconBg: const Color(0xFFE9F3E1),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ),
              _buildDocumentUploadItem(
                docKey: 'pan_card',
                title: 'PAN Card',
                subtitle: 'Upload clear PAN card image',
                iconAsset: 'assets/icons/Group.png',
                iconBg: const Color(0xFFF9F3EA),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 2. Driving License
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0x33000000), width: 1.0),
          ),
          child: Column(
            children: [
              _buildDocumentUploadItem(
                docKey: 'dl_front',
                title: 'Driving License (Front)',
                subtitle: 'Upload front side of DL',
                iconAsset: 'assets/icons/lecense.png',
                iconBg: const Color(0xFFFEF6E7),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ),
              _buildDocumentUploadItem(
                docKey: 'dl_back',
                title: 'Driving License (Back)',
                subtitle: 'Upload Back side of DL',
                iconAsset: 'assets/icons/lecense.png',
                iconBg: const Color(0xFFE6F1DD),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 3. Vehicle Registration, Insurance & Photos
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0x33000000), width: 1.0),
          ),
          child: Column(
            children: [
              _buildDocumentUploadItem(
                docKey: 'rc',
                title: 'Vehicle Registration (RC)',
                subtitle: 'Upload RC certificate of your vehicle',
                iconAsset: 'assets/icons/Vector (8).png',
                iconBg: const Color(0xFFF1E8FA),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ),
              _buildDocumentUploadItem(
                docKey: 'insurance',
                title: 'Vehicle Insurance',
                subtitle: 'Upload valid vehicle insurance policy',
                iconAsset: 'assets/icons/Vector (9).png',
                iconBg: const Color(0xFFE1F2FC),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ),
              _buildDocumentUploadItem(
                docKey: 'vehicle_photo',
                title: 'Vehicle Photo',
                subtitle: 'Upload clear photo of vehicle with number plate',
                iconAsset: 'assets/icons/fluent_vehicle-car-20-regular.png',
                iconBg: const Color(0xFFFFF4DF),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // 4. Bank & Commercial Documents
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0x33000000), width: 1.0),
          ),
          child: Column(
            children: [
              _buildDocumentUploadItem(
                docKey: 'passbook',
                title: 'Bank Passbook / Cancelled Cheque',
                subtitle: 'Upload passbook page with A/C details',
                iconAsset: 'assets/icons/Vector (4).png',
                iconBg: const Color(0xFFE8F8F5),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ),
              _buildDocumentUploadItem(
                docKey: 'permit',
                title: 'Commercial Permit / Taxi Badge (If Applicable)',
                subtitle: 'Upload commercial permit or taxi badge',
                iconAsset: 'assets/icons/Vector (10).png',
                iconBg: const Color(0xFFFEE8E5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPreviewModal(String docKey, String title) {
    final file = _uploadedDocs[docKey];
    if (file == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 5.0,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 40.h,
                right: 16.w,
                child: SafeArea(
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 18.r,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded, color: Colors.white, size: 22.sp),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentUploadItem({
    required String docKey,
    required String title,
    required String subtitle,
    IconData? icon,
    String? iconAsset,
    required Color iconBg,
  }) {
    final bool isUploaded = _uploadedDocs[docKey] != null;
    final bool isSubmitted = _submittedDocUrls.containsKey(docKey);

    return Row(
      children: [
        Container(
          width: 44.h,
          height: 44.h,
          padding: EdgeInsets.fromLTRB(8.w, 9.h, 8.w, 9.h),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: const Color(0x33000000),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: iconAsset != null
              ? Image.asset(iconAsset, width: 20, height: 20)
              : Icon(icon, color: const Color(0xFF333333), size: 16.sp),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: -0.156.sp,
                  color: AppColors.darkText,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                  letterSpacing: -0.12.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        // Priority: submitted from server → show Pending badge
        // Then: locally picked → show View button
        // Else: show Upload button
        if (isSubmitted)
          Container(
            height: 28.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: const Color(0xFFFFB700),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  size: 12.sp,
                  color: const Color(0xFF9A6700),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Pending',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A6700),
                  ),
                ),
              ],
            ),
          )
        else if (isUploaded)
          GestureDetector(
            onTap: () => _showPreviewModal(docKey, title),
            child: Container(
              height: 28.h,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                  color: const Color(0xFFFFCC00),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 13.sp,
                    color: const Color(0xFF1E293B),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'View',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () => _pickDocument(docKey),
            child: Container(
              width: 69.w,
              height: 28.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(color: const Color(0xFFFFCC00), width: 1.0),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/uploadicons.png',
                    width: 16.w,
                    height: 16.h,
                    color: const Color(0xFF444444),
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.cloud_upload_outlined,
                        size: 16.w,
                        color: const Color(0xFF444444),
                      );
                    },
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Upload',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF444444),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    if (widget.isReadOnly) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF9E6),
          border: Border(
            top: BorderSide(color: Color(0xFFFFC700), width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: const Color(0xFFB48500),
              size: 22.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Verification Pending (Under Review)',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D0D0D),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Details locked until admin review completes.',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () async {
                await Get.find<AuthController>().checkProfileStatus();
                CustomSnackbar.showSuccess(message: 'Status refreshed');
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC000),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Refresh 🔄',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: CommonSaveButton(
        onTap: _onSubmit,
        isLoading: _isLoading,
        text: 'Submit Request',
      ),
    );
  }
}
