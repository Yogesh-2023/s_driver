import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../services/onboarding_step_service.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/custom_selection_bottom_sheet.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/common_save_button.dart';
import 'controllers/auth_controller.dart';
import 'documents_upload_step_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final bool isProviderDriver;

  const VehicleDetailsScreen({super.key, this.isProviderDriver = false});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  // Color Palette
  static const Color _yellow = Color(0xFFFFC700);
  static const Color _headerCream = Color(0xFFFFF9E6);
  static const Color _bgCream = Color(0xFFFEFAF4);
  static const Color _darkText = Color(0xFF0D0D0D);
  static const Color _cardIconBg = Color(0xFFFEF6E7);

  // Form Controllers
  final _vehicleNumberController = TextEditingController();
  final _drivingLicenseController = TextEditingController();
  final _categoryController = TextEditingController();
  final _makeBrandController = TextEditingController();
  final _manufacturingYearController = TextEditingController();
  final _modelController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingOptions = false;
  bool _isOptionsError = false;
  String? _optionsErrorMessage;

  String? _selectedCategoryId;
  String? _selectedBrandId;
  String? _selectedModelId;

  List<Map<String, dynamic>> _fetchedCategories = [];
  List<Map<String, dynamic>> _fetchedBrands = [];
  List<Map<String, dynamic>> _fetchedModels = [];
  List<String> _activeYears = [];

  @override
  void initState() {
    super.initState();
    OnboardingStepService.saveStep(
      OnboardingStepService.stepVehicle,
      isProviderDriver: widget.isProviderDriver,
    );
  }

  Future<void> _loadVehicleOptions() async {
    if (!mounted || _isLoadingOptions) return;
    setState(() {
      _isLoadingOptions = true;
      _isOptionsError = false;
      _optionsErrorMessage = null;
    });

    try {
      final authController = Get.find<AuthController>();
      final options = await authController.fetchVehicleOptions();
      final categories = (options['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final brands = (options['brands'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final models = (options['models'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final mfrYears = (options['manufacturerYears'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final years = (options['years'] as List?)?.cast<String>() ?? [];

      debugPrint('\n================================================================================');
      debugPrint('📋 [VEHICLE SCREEN] LOADED OPTIONS INTO STATE');
      debugPrint('🚗 Categories Count: ${categories.length}');
      debugPrint('🏷️ Brands Count: ${brands.length}');
      debugPrint('🚙 Models Count: ${models.length}');
      debugPrint('📅 Manufacturer Years Count: ${mfrYears.length}');
      debugPrint('================================================================================\n');

      if (mounted) {
        setState(() {
          _fetchedCategories = categories;
          _fetchedBrands = brands;
          _fetchedModels = models;
          if (mfrYears.isNotEmpty) {
            _activeYears = mfrYears.map((y) => y['year'].toString()).toList();
          } else if (years.isNotEmpty) {
            _activeYears = years;
          } else {
            _activeYears = [];
          }
          final categoryStillExists = _fetchedCategories.any(
            (category) => category['id']?.toString() == _selectedCategoryId,
          );
          if (!categoryStillExists) {
            _selectedCategoryId = null;
            _categoryController.clear();
            _selectedBrandId = null;
            _makeBrandController.clear();
            _selectedModelId = null;
            _modelController.clear();
          }
          final brandStillExists = _fetchedBrands.any(
            (brand) => brand['id']?.toString() == _selectedBrandId,
          );
          if (!brandStillExists) {
            _selectedBrandId = null;
            _makeBrandController.clear();
            _selectedModelId = null;
            _modelController.clear();
          }
          final modelStillMatches = _fetchedModels.any(
            (model) =>
                model['id']?.toString() == _selectedModelId &&
                model['categoryId']?.toString() == _selectedCategoryId &&
                model['brandId']?.toString() == _selectedBrandId,
          );
          if (!modelStillMatches) {
            _selectedModelId = null;
            _modelController.clear();
          }
          if (!_activeYears.contains(_manufacturingYearController.text)) {
            _manufacturingYearController.clear();
          }
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading vehicle options: $e');
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
          _isOptionsError = true;
          _optionsErrorMessage = 'Failed to load vehicle options';
        });
      }
    }
  }

  Future<bool> _refreshOptionsForPicker() async {
    if (_isLoadingOptions) return false;
    await _loadVehicleOptions();
    return mounted && !_isOptionsError;
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _drivingLicenseController.dispose();
    _categoryController.dispose();
    _makeBrandController.dispose();
    _manufacturingYearController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _onBack() {
    Navigator.pop(context);
  }

  bool _validateAndProceed() {
    final vehicleNo =
        _vehicleNumberController.text.trim().replaceAll(' ', '').toUpperCase();
    if (vehicleNo.isEmpty) {
      _showSnackBar('Please enter vehicle registration number');
      return false;
    }
    if (vehicleNo.length < 6) {
      _showSnackBar('Enter valid vehicle number (e.g. UP16AB1234)');
      return false;
    }

    if (_categoryController.text.trim().isEmpty || _selectedCategoryId == null) {
      _showSnackBar('Please select vehicle category');
      return false;
    }

    final dlNumber = _drivingLicenseController.text.trim();
    if (dlNumber.isNotEmpty && dlNumber.length < 4) {
      _showSnackBar('Please enter a valid driving license number');
      return false;
    }

    if (_makeBrandController.text.trim().isEmpty || _selectedBrandId == null) {
      _showSnackBar('Please select vehicle brand');
      return false;
    }

    if (_manufacturingYearController.text.trim().isEmpty) {
      _showSnackBar('Please select manufacturing year');
      return false;
    }

    if (_modelController.text.trim().isEmpty || _selectedModelId == null) {
      _showSnackBar('Please select vehicle model');
      return false;
    }

    return true;
  }

  void _onContinue() async {
    if (_isLoading || _isLoadingOptions) return;
    if (_validateAndProceed()) {
      final regNo = _vehicleNumberController.text.trim().replaceAll(' ', '').toUpperCase();
      final category = _categoryController.text.trim();
      final brand = _makeBrandController.text.trim();
      final model = _modelController.text.trim();
      final year = _manufacturingYearController.text.trim();

      debugPrint('\n================================================================================');
      debugPrint('📝 [SUBMITTING VEHICLE REGISTRATION DETAILS]');
      debugPrint('🚘 Registration Number: $regNo');
      debugPrint('🚗 Category Name: $category (ID: $_selectedCategoryId)');
      debugPrint('🏷️ Brand: $brand');
      debugPrint('🚙 Model: $model');
      debugPrint('📅 Manufacturing Year: $year');
      debugPrint('📄 DL Number: ${_drivingLicenseController.text.trim()}');
      debugPrint('================================================================================\n');

      setState(() => _isLoading = true);
      try {
        final authController = Get.find<AuthController>();
        final success = await authController.saveDriverVehicle(
          registrationNumber: regNo,
          make: brand,
          model: model,
          year: year,
          categoryId: _selectedCategoryId!,
          brandId: _selectedBrandId!,
          modelId: _selectedModelId!,
          drivingLicenseNumber: _drivingLicenseController.text.trim().isNotEmpty
              ? _drivingLicenseController.text.trim().toUpperCase()
              : null,
        );

        if (success && mounted) {
          await OnboardingStepService.saveStep(
            OnboardingStepService.stepDocuments,
            isProviderDriver: widget.isProviderDriver,
          );
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentsUploadStepScreen(
                isProviderDriver: widget.isProviderDriver,
              ),
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

  Future<void> _pickManufacturingYear() async {
    if (!await _refreshOptionsForPicker()) return;
    if (!mounted) return;

    if (_activeYears.isEmpty) {
      _showSnackBar('No manufacturing years available from admin.');
      return;
    }

    final selected = await CustomSelectionBottomSheet.show(
      context: context,
      title: 'Manufacturing Year',
      items: _activeYears,
      selectedItem: _manufacturingYearController.text.isNotEmpty
          ? _manufacturingYearController.text
          : null,
    );
    if (selected != null && mounted) {
      setState(() {
        _manufacturingYearController.text = selected;
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
                                      TextSpan(text: 'Add Your '),
                                      TextSpan(
                                        text: 'Vehicle Details',
                                        style: TextStyle(color: _yellow),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                SizedBox(
                                  width: 145.w,
                                  child: Text(
                                    "Tell us about your\nvehicle to continue.",
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
                      right: -15.w,
                      top: 41.h,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: 0.95,
                          child: Image.asset(
                            'assets/images/image 22.png',
                            width: 220.w,
                            height: 158.h,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Image.asset(
                              'assets/images/image10.png',
                              width: 220.w,
                              height: 158.h,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Step Progress Bar
              Padding(
                padding: EdgeInsets.only(top: 10.h, left: 16.w, right: 16.w, bottom: 14.h),
                child: _buildStepProgressBar(2),
              ),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
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
                    child: _buildVehicleForm(),
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

  void _pickCategory() async {
    if (!await _refreshOptionsForPicker()) return;
    if (!mounted) return;

    if (_fetchedCategories.isEmpty) {
      _showSnackBar('No vehicle categories available from admin.');
      return;
    }

    List<String> categoryNames = _fetchedCategories
        .map((c) => (c['name'] ?? c['displayName'] ?? c['slug'] ?? '').toString())
        .where((s) {
          final val = s.trim().toLowerCase();
          return val.isNotEmpty && val != 'bike' && val != 'auto';
        })
        .toSet()
        .toList();

    final selected = await CustomSelectionBottomSheet.show(
      context: context,
      title: 'Vehicle Category',
      items: categoryNames,
      selectedItem: _categoryController.text.isNotEmpty ? _categoryController.text : null,
    );

    if (selected != null && mounted) {
      final found = _fetchedCategories.firstWhere(
        (c) {
          final rawCategory =
              (c['name'] ?? c['displayName'] ?? c['slug'] ?? '').toString();
          return rawCategory.toLowerCase() == selected.toLowerCase();
        },
        orElse: () => <String, dynamic>{},
      );

      setState(() {
        _categoryController.text = selected;
        _selectedCategoryId = found['id']?.toString();
        // Reset Brand and Model dependencies when Category changes
        _makeBrandController.text = '';
        _selectedBrandId = null;
        _modelController.text = '';
        _selectedModelId = null;
      });
    }
  }

  void _pickMakeBrand() async {
    if (!await _refreshOptionsForPicker()) return;
    if (!mounted) return;

    List<Map<String, dynamic>> availableBrands = _fetchedBrands;
    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      final matchingBrandIds = _fetchedModels
          .where((m) => m['categoryId']?.toString() == _selectedCategoryId)
          .map((m) => m['brandId']?.toString())
          .whereType<String>()
          .toSet();

      if (matchingBrandIds.isNotEmpty) {
        final filtered = _fetchedBrands
            .where((b) => matchingBrandIds.contains(b['id']?.toString()))
            .toList();
        if (filtered.isNotEmpty) {
          availableBrands = filtered;
        }
      }
    }

    if (availableBrands.isEmpty) {
      _showSnackBar('No vehicle brands available.');
      return;
    }

    List<String> brandNames = availableBrands
        .map((b) => (b['name'] ?? b['slug'] ?? '').toString())
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();

    final selected = await CustomSelectionBottomSheet.show(
      context: context,
      title: 'Brand',
      items: brandNames,
      selectedItem: _makeBrandController.text.isNotEmpty ? _makeBrandController.text : null,
    );

    if (selected != null && mounted) {
      final found = availableBrands.firstWhere(
        (b) => (b['name'] ?? b['slug'] ?? '').toString().toLowerCase() == selected.toLowerCase(),
        orElse: () => _fetchedBrands.firstWhere(
          (b) => (b['name'] ?? b['slug'] ?? '').toString().toLowerCase() == selected.toLowerCase(),
          orElse: () => <String, dynamic>{},
        ),
      );

      setState(() {
        _makeBrandController.text = selected;
        _selectedBrandId = found['id']?.toString();
        // Reset Model dependency when Brand changes
        _modelController.text = '';
        _selectedModelId = null;
      });
    }
  }

  void _pickModel() async {
    if (!await _refreshOptionsForPicker()) return;
    if (!mounted) return;

    List<Map<String, dynamic>> modelsToDisplay = [];

    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty &&
        _selectedBrandId != null && _selectedBrandId!.isNotEmpty) {
      modelsToDisplay = _fetchedModels.where((m) {
        final cId = m['categoryId']?.toString();
        final bId = m['brandId']?.toString();
        return cId == _selectedCategoryId && bId == _selectedBrandId;
      }).toList();
    } else if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      modelsToDisplay = _fetchedModels.where((m) {
        return m['categoryId']?.toString() == _selectedCategoryId;
      }).toList();
    } else if (_selectedBrandId != null && _selectedBrandId!.isNotEmpty) {
      modelsToDisplay = _fetchedModels.where((m) {
        return m['brandId']?.toString() == _selectedBrandId;
      }).toList();
    }

    // Fall back to all fetched models if no models match the filter or if category/brand are not picked yet
    if (modelsToDisplay.isEmpty) {
      modelsToDisplay = _fetchedModels;
    }

    if (modelsToDisplay.isEmpty) {
      _showSnackBar('No vehicle models available.');
      return;
    }

    List<String> modelNames = modelsToDisplay
        .map((m) => (m['name'] ?? m['slug'] ?? '').toString())
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();

    final selected = await CustomSelectionBottomSheet.show(
      context: context,
      title: 'Model',
      items: modelNames,
      selectedItem: _modelController.text.isNotEmpty ? _modelController.text : null,
    );

    if (selected != null && mounted) {
      final found = modelsToDisplay.firstWhere(
        (m) => (m['name'] ?? m['slug'] ?? '').toString().toLowerCase() == selected.toLowerCase(),
        orElse: () => _fetchedModels.firstWhere(
          (m) => (m['name'] ?? m['slug'] ?? '').toString().toLowerCase() == selected.toLowerCase(),
          orElse: () => <String, dynamic>{},
        ),
      );

      setState(() {
        _modelController.text = selected;
        _selectedModelId = found['id']?.toString();

        // Auto-populate Category if not selected yet
        final foundCatId = found['categoryId']?.toString();
        if ((_selectedCategoryId == null || _selectedCategoryId!.isEmpty) &&
            foundCatId != null && foundCatId.isNotEmpty) {
          final cat = _fetchedCategories.firstWhere(
            (c) => c['id']?.toString() == foundCatId,
            orElse: () => <String, dynamic>{},
          );
          if (cat.isNotEmpty) {
            _selectedCategoryId = foundCatId;
            _categoryController.text = (cat['name'] ?? cat['displayName'] ?? cat['slug'] ?? '').toString();
          }
        }

        // Auto-populate Brand if not selected yet
        final foundBrandId = found['brandId']?.toString();
        if ((_selectedBrandId == null || _selectedBrandId!.isEmpty) &&
            foundBrandId != null && foundBrandId.isNotEmpty) {
          final brand = _fetchedBrands.firstWhere(
            (b) => b['id']?.toString() == foundBrandId,
            orElse: () => <String, dynamic>{},
          );
          if (brand.isNotEmpty) {
            _selectedBrandId = foundBrandId;
            _makeBrandController.text = (brand['name'] ?? brand['slug'] ?? '').toString();
          }
        }
      });
    }
  }

  Widget _buildVehicleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingOptions) ...[
          const LinearProgressIndicator(color: _yellow),
          SizedBox(height: 12.h),
        ],
        if (_isOptionsError) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    _optionsErrorMessage ?? 'Failed to load master data',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.5.sp,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _loadVehicleOptions,
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildCustomInputField(
          label: 'Vehicle Registration Number',
          hint: 'Enter Vehicle Number',
          iconAsset: 'assets/icons/fluent_vehicle-car-20-regular.png',
          controller: _vehicleNumberController,
          textCapitalization: TextCapitalization.characters,
        ),
        SizedBox(height: 16.h),
        _buildCustomInputField(
          label: 'Vehicle Category',
          hint: _isLoadingOptions ? 'Loading categories...' : 'Select Category',
          iconAsset: 'assets/icons/fluent_vehicle-car-20-regular.png',
          controller: _categoryController,
          isDropdown: true,
          onTap: _pickCategory,
        ),
        SizedBox(height: 16.h),
        _buildCustomInputField(
          label: 'Driving License Number',
          hint: 'Enter Driving License Number (e.g. DL1420110012345)',
          iconAsset: 'assets/icons/Vector (4).png',
          controller: _drivingLicenseController,
          textCapitalization: TextCapitalization.characters,
        ),
        SizedBox(height: 16.h),
        _buildCustomInputField(
          label: 'Make / Brand',
          hint: _isLoadingOptions ? 'Loading brands...' : 'Select Brand',
          iconAsset: 'assets/icons/Vector (10).png',
          controller: _makeBrandController,
          isDropdown: true,
          onTap: _pickMakeBrand,
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCustomInputField(
                label: 'Manufacturing Year',
                hint: _isLoadingOptions ? 'Loading...' : 'YYYY',
                icon: Icons.calendar_today_outlined,
                controller: _manufacturingYearController,
                isDropdown: true,
                hideIconBox: true,
                onTap: _pickManufacturingYear,
              ),
            ),
            SizedBox(width: 8.45.w),
            Expanded(
              child: _buildCustomInputField(
                label: 'Model',
                hint: _isLoadingOptions ? 'Loading models...' : 'Select Model',
                controller: _modelController,
                isDropdown: true,
                hideIconBox: true,
                onTap: _pickModel,
              ),
            ),
          ],
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
    bool isDropdown = false,
    bool hideIconBox = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment:
              isTextArea ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (!hideIconBox && (icon != null || iconAsset != null)) ...[
              Container(
                width: 44.h,
                height: 44.h,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: _cardIconBg,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0x33000000), width: 1.0),
                ),
                alignment: Alignment.center,
                child: iconAsset != null
                    ? Image.asset(iconAsset, width: 20, height: 20)
                    : Icon(icon, color: _darkText, size: 19.sp),
              ),
              SizedBox(width: 6.w),
            ],
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (onTap != null) {
                    onTap();
                  }
                },
                child: Container(
                  height: isTextArea ? 71.h : 44.h,
                  padding: isTextArea
                      ? EdgeInsets.all(12.r)
                      : EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0x33000000), width: 1.0),
                  ),
                  alignment: isTextArea ? Alignment.topLeft : Alignment.center,
                  child: Row(
                    crossAxisAlignment:
                        isTextArea ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          textCapitalization: textCapitalization,
                          textAlignVertical:
                              isTextArea ? TextAlignVertical.top : TextAlignVertical.center,
                          maxLines: isTextArea ? 4 : 1,
                          readOnly: isDropdown || onTap != null,
                          enabled: !(isDropdown || onTap != null),
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                          decoration: InputDecoration(
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
                                ? EdgeInsets.only(top: 3.h)
                                : EdgeInsets.only(top: 9.h),
                          ),
                        ),
                      ),
                      if (isDropdown)
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
        text: 'Save',
      ),
    );
  }
}
