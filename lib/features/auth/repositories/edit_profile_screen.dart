import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_fonts.dart';
import '../controllers/auth_controller.dart';
import 'profile_models_and_services.dart';
import '../../../widgets/custom_snackbar.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserProfile? profile;
  const ProfileEditScreen({super.key, this.profile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ProfileService _service = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  String _requirement = 'PERSONAL';
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authCtrl = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final p = widget.profile ?? authCtrl?.userProfile.value;
    final fullName = p?.name.isNotEmpty == true
        ? p!.name
        : [p?.firstname ?? '', p?.lastname ?? ''].join(' ').trim();
    _nameCtrl = TextEditingController(text: fullName);
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _firstCtrl = TextEditingController(text: p?.firstname ?? '');
    _lastCtrl = TextEditingController(text: p?.lastname ?? '');
    if (p != null && p.requirement.isNotEmpty) {
      _requirement = p.requirement.toUpperCase();
    }

    _phoneCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProfileAndPopulateFields();
    });
  }

  Future<void> _fetchProfileAndPopulateFields() async {
    if (Get.isRegistered<AuthController>()) {
      final authCtrl = Get.find<AuthController>();
      print('\n=====================================================');
      print('🚀 [EDIT PROFILE OPENED] EXECUTING GET DRIVER PROFILE API');
      print('=====================================================\n');
      await authCtrl.debugFetchAndPrintProfile();
      final latest = authCtrl.userProfile.value;
      if (latest != null && mounted) {
        setState(() {
          final fullName = latest.name.isNotEmpty
              ? latest.name
              : [latest.firstname, latest.lastname].join(' ').trim();
          if (fullName.isNotEmpty) _nameCtrl.text = fullName;
          if (latest.email.isNotEmpty) _emailCtrl.text = latest.email;
          if (latest.phone.isNotEmpty) _phoneCtrl.text = latest.phone;
          if (latest.firstname.isNotEmpty) _firstCtrl.text = latest.firstname;
          if (latest.lastname.isNotEmpty) _lastCtrl.text = latest.lastname;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.only(
          top: 14.h,
          left: 20.w,
          right: 20.w,
          bottom: 24.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Select Profile Picture',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.primary,
                            size: 32.sp,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Camera',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library_rounded,
                            color: AppColors.primary,
                            size: 32.sp,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(source: source, imageQuality: 80);
    if (img != null) {
      setState(() {
        _selectedImage = img;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final fullName = _nameCtrl.text.trim();
    final parts = fullName.split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final newPhone = _phoneCtrl.text.trim();

    final Map<String, String> fields = {
      'name': fullName,
      'email': _emailCtrl.text.trim(),
      'phone': newPhone,
      'firstname': first,
      'lastname': last,
      'requirement': _requirement,
    };

    if (Get.isRegistered<AuthController>()) {
      final authCtrl = Get.find<AuthController>();
      final success = await authCtrl.updateDriverProfileData({
        'displayName': fullName,
        'email': _emailCtrl.text.trim(),
        'phone': newPhone,
        'firstName': first,
        'lastName': last,
      });
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (success) {
          Navigator.pop(context, authCtrl.userProfile.value);
          return;
        }
      }
    }

    _performSave(fields);
  }

  Future<void> _performSave(Map<String, String> fields) async {
    UserProfile? result;
    try {
      if (widget.profile == null) {
        result = await _service.createProfile(
          fields: fields,
          avatarPath: _selectedImage?.path ?? '',
        );
      } else {
        result = await _service.updateProfile(
          fields: fields,
          avatarPath: _selectedImage?.path,
        );
      }
    } catch (e) {
      CustomSnackbar.showError(message: 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (result != null) {
          Navigator.pop(context, result);
        } else {
          CustomSnackbar.showError(
            message: 'Failed to save profile. Please try again.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.profile != null;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFAF4),
        body: Column(
          children: [
            _buildHeader(context, isEditMode),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 16.h,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar Picker
                        GestureDetector(
                          onTap: _showImageSourceBottomSheet,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFCC00),
                                    width: 2.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50.r,
                                  backgroundColor: const Color(0xFFFFFBEA),
                                  backgroundImage: _selectedImage != null
                                      ? FileImage(File(_selectedImage!.path))
                                      : (widget.profile?.avatar.isNotEmpty ??
                                            false)
                                      ? NetworkImage(widget.profile!.avatar)
                                            as ImageProvider
                                      : null,
                                  child: _selectedImage == null &&
                                          (widget.profile?.avatar.isEmpty ?? true)
                                      ? Icon(
                                          Icons.person_outline_rounded,
                                          size: 46.sp,
                                          color: const Color(0xFF94A3B8),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: EdgeInsets.all(7.r),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFCC00),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    color: const Color(0xFFFFCC00),
                                    size: 16.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),

                        _buildField(
                          label: 'Full Name',
                          controller: _nameCtrl,
                          hintText: 'Enter full name',
                          readOnly: true,
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: const Color(0xFF94A3B8),
                            size: 20.sp,
                          ),
                        ),
                        _buildField(
                          label: 'Email Address',
                          controller: _emailCtrl,
                          hintText: 'abidoya@gmail.com',
                          readOnly: false,
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: const Color(0xFF94A3B8),
                            size: 20.sp,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your email address';
                            }
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(v.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        _buildField(
                          label: 'Phone Number',
                          controller: _phoneCtrl,
                          hintText: '+91 9876543210',
                          readOnly: true,
                          prefixIcon: Icon(
                            Icons.smartphone_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20.sp,
                          ),
                          keyboardType: TextInputType.phone,
                        ),

                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Save Changes Button
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 40.h,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC000),
                        foregroundColor: const Color(0xFF1E293B),
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 10.w,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1E293B),
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    final effectiveSuffixIcon = suffixIcon ??
        (readOnly
            ? Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 18.sp,
                ),
              )
            : null);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 6.h),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            enabled: !readOnly,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: readOnly ? const Color(0xFF475569) : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 13.sp,
                color: Colors.grey.shade400,
              ),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(left: 12.w, right: 9.w),
                      child: prefixIcon,
                    )
                  : null,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: effectiveSuffixIcon,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: true,
              fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
              contentPadding: EdgeInsets.only(
                top: 12.h,
                bottom: 12.h,
                left: 12.w,
                right: 18.w,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: readOnly ? const Color(0xFFE2E8F0) : const Color(0x1A614B8B),
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: readOnly ? const Color(0xFFE2E8F0) : const Color(0x1A614B8B),
                  width: 1.0,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: readOnly ? const Color(0xFFE2E8F0) : const Color(0xFFFFCC00),
                  width: 1.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.0,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isEditMode) {
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
            GestureDetector(
              onTap: () => Navigator.pop(context),
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
              'Edit Profile',
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
}

class NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final textWithoutSpecials = newValue.text.replaceAll(
      RegExp(r'[^a-zA-Z\s]'),
      '',
    );
    final formattedText = _capitalizeEachWord(textWithoutSpecials);

    int newSelectionIndex = newValue.selection.end;
    if (formattedText.length < newValue.text.length) {
      newSelectionIndex =
          newSelectionIndex - (newValue.text.length - formattedText.length);
    }
    newSelectionIndex = newSelectionIndex.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }

  String _capitalizeEachWord(String text) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ') {
        buffer.write(char);
        capitalizeNext = true;
      } else {
        if (capitalizeNext) {
          buffer.write(char.toUpperCase());
          capitalizeNext = false;
        } else {
          buffer.write(char.toLowerCase());
        }
      }
    }
    return buffer.toString();
  }
}
