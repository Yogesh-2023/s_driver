import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../services/onboarding_step_service.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/common_save_button.dart';
import '../../widgets/custom_selection_bottom_sheet.dart';
import '../../widgets/custom_snackbar.dart';
import 'controllers/auth_controller.dart';
import 'onboarding_screen.dart';
import 'vehicle_details_screen.dart';

class RegistrationStep1Screen extends StatefulWidget {
  final bool isProviderDriver;

  const RegistrationStep1Screen({super.key, this.isProviderDriver = false});

  @override
  State<RegistrationStep1Screen> createState() =>
      _RegistrationStep1ScreenState();
}

class _RegistrationStep1ScreenState extends State<RegistrationStep1Screen> {
  // Color Palette
  static const Color _yellow = Color(0xFFFFC700);
  static const Color _headerCream = Color(0xFFFFF9E6);
  static const Color _bgCream = Color(0xFFFEFAF4);
  static const Color _darkText = Color(0xFF0D0D0D);
  static const Color _cardIconBg = Color(0xFFFEF6E7);
  static const Color _borderColor = Color(0xFFECECEC);

  // Form Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _profileAddressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isLoading = false;

  // Location States & Cities
  List<Map<String, String>> _states = [];
  List<String> _cities = [];
  String? _selectedStateIsoCode;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;
  bool _isLoadingPincode = false;

  @override
  void initState() {
    super.initState();
    OnboardingStepService.saveStep(
      OnboardingStepService.stepProfile,
      isProviderDriver: widget.isProviderDriver,
    );
    _loadProfileData();
    _loadStates();
  }

  void _loadProfileData() {
    final authController = Get.find<AuthController>();
    final profile = authController.userProfile.value;
    if (profile != null) {
      if (profile.name.isNotEmpty && profile.name != 'Driver') {
        _fullNameController.text = profile.name;
      }
      if (profile.email.isNotEmpty && profile.email != 'driver@example.com') {
        _emailController.text = profile.email;
      }
      if (profile.address.isNotEmpty) {
        _profileAddressController.text = profile.address;
      }
    }
    authController.checkProfileStatus().then((_) {
      if (!mounted) return;
      final updated = authController.userProfile.value;
      if (updated != null) {
        setState(() {
          if (_fullNameController.text.isEmpty &&
              updated.name.isNotEmpty &&
              updated.name != 'Driver') {
            _fullNameController.text = updated.name;
          }
          if (_emailController.text.isEmpty &&
              updated.email.isNotEmpty &&
              updated.email != 'driver@example.com') {
            _emailController.text = updated.email;
          }
          if (_profileAddressController.text.isEmpty &&
              updated.address.isNotEmpty) {
            _profileAddressController.text = updated.address;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _profileAddressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _onBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  bool _validateAndProceed() {
    final name = _fullNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter your full name');
      return false;
    }
    if (name.length < 4) {
      _showSnackBar('Full name must be at least 4 characters');
      return false;
    }
    if (!RegExp(r'^[A-Z]').hasMatch(name)) {
      _showSnackBar('Must start with capital letter (e.g. John)');
      return false;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email ID');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Please enter a valid email address');
      return false;
    }

    final dob = _dobController.text.trim();
    if (dob.isEmpty) {
      _showSnackBar('Please select your date of birth');
      return false;
    }
    // Check if birth year is after 2006
    final parts = dob.split('/');
    if (parts.isNotEmpty) {
      final year = int.tryParse(parts.last.trim());
      if (year != null && year > 2006) {
        _showSnackBar('Driver must be at least 18 years old');
        return false;
      }
    }

    if (_profileAddressController.text.trim().isEmpty) {
      _showSnackBar('Please enter your current address');
      return false;
    }

    if (_stateController.text.trim().isEmpty) {
      _showSnackBar('Please select your state');
      return false;
    }

    if (_cityController.text.trim().isEmpty) {
      _showSnackBar('Please select your city');
      return false;
    }

    final pincode = _pincodeController.text.trim();
    if (pincode.isEmpty) {
      _showSnackBar('Please enter your pincode');
      return false;
    }
    if (pincode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pincode)) {
      _showSnackBar('Please enter a valid 6-digit pincode');
      return false;
    }

    return true;
  }

  void _onContinue() async {
    if (_isLoading) return;
    if (_validateAndProceed()) {
      setState(() => _isLoading = true);
      try {
        final authController = Get.find<AuthController>();
        final success = await authController.saveDriverProfile(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          gender: _selectedGender,
          dateOfBirth: _dobController.text.trim(),
          address: _profileAddressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          postalCode: _pincodeController.text.trim(),
        );

        if (success && mounted) {
          await OnboardingStepService.saveStep(
            OnboardingStepService.stepVehicle,
            isProviderDriver: widget.isProviderDriver,
          );
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VehicleDetailsScreen(isProviderDriver: widget.isProviderDriver),
            ),
          );
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

  Future<void> _loadStates() async {
    setState(() => _isLoadingStates = true);
    final states = await Get.find<AuthController>().fetchStates();
    if (mounted) {
      setState(() {
        _states = states;
        _isLoadingStates = false;
      });
      if (_stateController.text.isNotEmpty) {
        _findStateCodeAndLoadCities(_stateController.text);
      }
    }
  }

  void _findStateCodeAndLoadCities(String stateName) {
    try {
      final match = _states.firstWhere(
        (s) => (s['name'] ?? '').toLowerCase() == stateName.toLowerCase(),
        orElse: () => {},
      );
      if (match.isNotEmpty &&
          match['isoCode'] != null &&
          match['isoCode']!.isNotEmpty) {
        _selectedStateIsoCode = match['isoCode'];
        _loadCities(_selectedStateIsoCode!);
      }
    } catch (_) {}
  }

  Future<void> _loadCities(String isoCode) async {
    setState(() => _isLoadingCities = true);
    final cities = await Get.find<AuthController>().fetchCitiesByState(isoCode);
    if (mounted) {
      setState(() {
        _cities = cities;
        _isLoadingCities = false;
      });
    }
  }

  Future<void> _onPincodeChanged(String val) async {
    if (val.length == 6) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _isLoadingPincode = true);
      final location =
          await Get.find<AuthController>().fetchLocationByPincode(val);
      if (mounted) {
        setState(() => _isLoadingPincode = false);
        if (location != null) {
          final stateName = location['state'] ?? '';
          final cityName = location['city'] ?? '';
          setState(() {
            if (stateName.isNotEmpty) _stateController.text = stateName;
            if (cityName.isNotEmpty) _cityController.text = cityName;
          });
          if (stateName.isNotEmpty) {
            _findStateCodeAndLoadCities(stateName);
          }
        }
      }
    }
  }

  void _onStateTap() async {
    if (_isLoadingStates) {
      CustomSnackbar.showInfo(message: 'Loading states, please wait...');
      return;
    }
    if (_states.isEmpty) {
      await _loadStates();
    }
    if (_states.isEmpty) {
      CustomSnackbar.showError(
        message: 'Unable to load states. Please try again.',
      );
      return;
    }

    final stateNames = _states
        .map((s) => s['name'] ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    if (!mounted) return;
    final selected = await CustomSelectionBottomSheet.show(
      context: context,
      title: 'State',
      items: stateNames,
      selectedItem:
          _stateController.text.isNotEmpty ? _stateController.text : null,
    );

    if (selected != null && mounted) {
      final isChanged = _stateController.text != selected;
      setState(() {
        _stateController.text = selected;
        if (isChanged) {
          _cityController.clear();
          _cities.clear();
          _selectedStateIsoCode = null;
        }
      });
      _findStateCodeAndLoadCities(selected);
    }
  }

  void _onCityTap() async {
    if (_stateController.text.trim().isEmpty) {
      CustomSnackbar.showError(message: 'Please select a state first');
      return;
    }

    if (_isLoadingCities) {
      CustomSnackbar.showInfo(message: 'Loading cities, please wait...');
      return;
    }

    if (_cities.isEmpty) {
      if (_selectedStateIsoCode != null &&
          _selectedStateIsoCode!.isNotEmpty) {
        await _loadCities(_selectedStateIsoCode!);
      } else {
        _findStateCodeAndLoadCities(_stateController.text);
      }
    }

    if (_cities.isEmpty) {
      CustomSnackbar.showInfo(message: 'No cities found for selected state');
      return;
    }

    if (!mounted) return;
    final selected = await CustomSelectionBottomSheet.show(
      context: context,
      title: 'City',
      items: _cities,
      selectedItem:
          _cityController.text.isNotEmpty ? _cityController.text : null,
    );

    if (selected != null && mounted) {
      setState(() {
        _cityController.text = selected;
      });
    }
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
                          padding: EdgeInsets.only(
                            left: 16.w,
                            top: 14.h,
                            bottom: 6.h,
                          ),
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
                                      height: 1.4,
                                      color: _darkText,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Complete\n'),
                                      TextSpan(text: 'Your '),
                                      TextSpan(
                                        text: 'Profile',
                                        style: TextStyle(color: _yellow),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                SizedBox(
                                  width: 170.w,
                                  child: Text(
                                    "Let's verify your basic\ninformation.",
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
                      right: 0,
                      top: 38.h,
                      child: Image.asset(
                        'assets/images/image 23.png',
                        width: 171.w,
                        height: 206.h,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/image10.png',
                          width: 171.w,
                          height: 206.h,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Step Progress Bar
              Padding(
                padding: EdgeInsets.only(
                  top: 10.h,
                  left: 16.w,
                  right: 16.w,
                  bottom: 14.h,
                ),
                child: _buildStepProgressBar(1),
              ),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 20.h,
                    ),
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
                    child: _buildProfileForm(),
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
                    color: activeStep > 1 ? _yellow : const Color(0xFFCCCCCC),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1.5.h,
                    color: activeStep > 2 ? _yellow : const Color(0xFFCCCCCC),
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

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomInputField(
          label: 'Full Name',
          hint: 'Enter your full name',
          iconAsset: 'assets/icons/ima1 (1).png',
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: 12.h),
        _buildCustomInputField(
          label: 'Email ID',
          hint: 'Enter your email id',
          iconAsset: 'assets/icons/ima2.png',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 12.h),
        _buildGenderSelector(),
        SizedBox(height: 12.h),
        _buildCustomInputField(
          label: 'Date of Birth',
          hint: 'DD / MM / YYYY',
          hideIconBox: true,
          controller: _dobController,
          isDatePicker: true,
        ),
        SizedBox(height: 12.h),
        _buildCustomInputField(
          label: 'Current Address',
          hint: 'Enter your current address',
          iconAsset: 'assets/icons/ima1 (5).png',
          controller: _profileAddressController,
          isTextArea: true,
        ),
        SizedBox(height: 10.h),
        _buildCustomInputField(
          label: 'State',
          hint: _isLoadingStates ? 'Loading states...' : 'Select your state',
          iconAsset: 'assets/icons/ima3.png',
          controller: _stateController,
          isDropdown: true,
          isLoading: _isLoadingStates,
          onTap: _onStateTap,
        ),
        SizedBox(height: 10.h),
        _buildCustomInputField(
          label: 'City',
          hint: _isLoadingCities ? 'Loading cities...' : 'Select your city',
          iconAsset: 'assets/icons/ima4.png',
          controller: _cityController,
          isDropdown: true,
          isLoading: _isLoadingCities,
          onTap: _onCityTap,
        ),
        SizedBox(height: 10.h),
        _buildCustomInputField(
          label: 'Pin code',
          hint: 'Enter your 6-digit pincode',
          iconAsset: 'assets/icons/ima1 (5).png',
          controller: _pincodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          isLoading: _isLoadingPincode,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: _onPincodeChanged,
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    final genders = ['Male', 'Female', 'Other'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w700,
            color: _darkText,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: genders.map((gender) {
            bool isSelected = _selectedGender == gender;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = gender),
                child: Container(
                  height: 40.h,
                  margin: EdgeInsets.only(right: gender != 'Other' ? 6.w : 0),
                  padding: EdgeInsets.fromLTRB(10.w, 7.h, 10.w, 7.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFCC00)
                          : _borderColor,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0x2EFFFFFF)
                            : Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16.r,
                        height: 16.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFFCC00)
                                : const Color(0xFFC4C4C4),
                            width: 2.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? Container(
                                width: 8.r,
                                height: 8.r,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFCC00),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          gender,
                          style: TextStyle(
                            fontFamily: 'Lufga',
                            fontSize: 11.sp,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.2,
                            letterSpacing: -0.12,
                            color: const Color(0xFF2F2F2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomInputField({
    required String label,
    required String hint,
    IconData? icon,
    String? iconAsset,
    TextEditingController? controller,
    bool isTextArea = false,
    bool isDatePicker = false,
    bool isDropdown = false,
    bool hideIconBox = false,
    bool isLoading = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w700,
            color: _darkText,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          crossAxisAlignment: isTextArea
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (!hideIconBox && (icon != null || iconAsset != null)) ...[
              Container(
                width: 40.h,
                height: 40.h,
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _cardIconBg,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0x33000000),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: iconAsset != null
                    ? Image.asset(iconAsset, width: 18, height: 18)
                    : Icon(icon, color: _darkText, size: 18.sp),
              ),
              SizedBox(width: 6.w),
            ],
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (onTap != null) {
                    onTap();
                  } else if (isDatePicker) {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000, 1, 1),
                      firstDate: DateTime(1940),
                      lastDate: DateTime(2006, 12, 31),
                    );
                    if (picked != null && controller != null) {
                      controller.text =
                          "${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}";
                    }
                  }
                },
                child: Container(
                  height: isTextArea ? 64.h : 40.h,
                  padding: isTextArea
                      ? EdgeInsets.all(10.r)
                      : EdgeInsets.symmetric(horizontal: 11.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0x33000000),
                      width: 1.0,
                    ),
                  ),
                  alignment: isTextArea ? Alignment.topLeft : Alignment.center,
                  child: Row(
                    crossAxisAlignment: isTextArea
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          textCapitalization: textCapitalization,
                          maxLength: maxLength,
                          inputFormatters: inputFormatters,
                          onChanged: onChanged,
                          textAlignVertical: isTextArea
                              ? TextAlignVertical.top
                              : TextAlignVertical.center,
                          maxLines: isTextArea ? 4 : 1,
                          readOnly: isDatePicker || isDropdown || onTap != null,
                          enabled:
                              !(isDatePicker || isDropdown || onTap != null),
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: hint,
                            hintStyle: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              color: const Color(0xFF8E8E93),
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: isTextArea
                                ? EdgeInsets.only(top: 2.h)
                                : EdgeInsets.only(top: 7.h),
                          ),
                        ),
                      ),
                      if (isLoading)
                        SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _yellow,
                          ),
                        )
                      else if (isDatePicker)
                        Image.asset(
                          'assets/icons/Vector (11).png',
                          width: 10,
                          height: 10,
                        )
                      else if (isDropdown)
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF999999),
                          size: 22.sp,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: CommonSaveButton(
        onTap: _onContinue,
        isLoading: _isLoading,
        text: 'Save and Continue',
      ),
    );
  }
}
