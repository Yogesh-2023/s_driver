import 'dart:io';
import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/primary_button.dart';
import 'controllers/document_controller.dart';
import '../../widgets/custom_snackbar.dart';

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.title,
    required this.onUploadComplete,
    this.isReadOnly = false,
    this.isRejected = false,
    this.readOnlyText,
  });

  final String title;
  final VoidCallback onUploadComplete;
  final bool isReadOnly;
  final bool isRejected;
  final String? readOnlyText;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final DocumentController _documentController = Get.find<DocumentController>();

  final _controller = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();

  final FocusNode _panFocusNode = FocusNode();
  TextInputType _panKeyboardType = TextInputType.text;

  File? _frontFile;
  File? _backFile;
  File? _bankProofFile;

  @override
  void initState() {
    super.initState();
    final prefill = _documentController.documentPrefillValues;
    if (widget.title == 'Bank Details') {
      _bankNameController.text = prefill['Bank Name'] ?? '';
      _accountController.text = prefill['Bank Account Number'] ?? '';
      _confirmAccountController.text = prefill['Bank Account Number'] ?? '';
      _ifscController.text = prefill['Bank IFSC'] ?? '';
    } else {
      _controller.text = prefill[widget.title] ?? '';
      if (widget.title == 'PAN Card') {
        _controller.addListener(_onPanTextChanged);
      }
    }
  }

  void _onPanTextChanged() {
    TextInputType newKeyboardType;
    int len = _controller.text.length;
    if (len >= 5 && len < 9) {
      newKeyboardType = TextInputType.number;
    } else {
      newKeyboardType = TextInputType.text;
    }

    if (newKeyboardType != _panKeyboardType) {
      _panKeyboardType = newKeyboardType;
      setState(() {});
      if (_panFocusNode.hasFocus) {
        _panFocusNode.unfocus();
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            FocusScope.of(context).requestFocus(_panFocusNode);
          }
        });
      }
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.title == 'PAN Card') {
      _controller.removeListener(_onPanTextChanged);
    }
    _panFocusNode.dispose();
    _controller.dispose();
    _bankNameController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller, [
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
  ]) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: !widget.isReadOnly,
      readOnly: widget.isReadOnly,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontFamily: AppFonts.fontFamily,
        color: const Color(0xFF1E293B),
        fontWeight: FontWeight.w700,
        fontSize: 15.sp,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: AppFonts.fontFamily,
          color: const Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
          fontSize: 14.sp,
        ),
        filled: true,
        fillColor: AppColors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          InkWell(
            onTap: () => Navigator.pop(context),
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
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Upload ${widget.title}',
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

  Future<void> _submitDocument() async {
    final Map<String, File> files = {};
    final Map<String, String> textFields = {};

    if (widget.title == 'Bank Details') {
      if (_bankNameController.text.trim().isEmpty) {
        CustomSnackbar.showError(message: 'Bank Name is required');
        return;
      }
      if (_accountController.text.trim().isEmpty) {
        CustomSnackbar.showError(message: 'Account Number is required');
        return;
      }
      if (_accountController.text != _confirmAccountController.text) {
        CustomSnackbar.showError(
          message: 'Account number and confirm account number do not match.',
        );
        return;
      }
      if (_ifscController.text.trim().isEmpty) {
        CustomSnackbar.showError(message: 'IFSC Code is required');
        return;
      }
      if (_bankProofFile == null) {
        CustomSnackbar.showError(
          message: 'Passbook / Cancelled Cheque image is required',
        );
        return;
      }

      files['bankFront'] = _bankProofFile!;
      files['bankProof'] = _bankProofFile!;
      textFields['bankName'] = _bankNameController.text.trim();
      textFields['bankAccountNumber'] = _accountController.text.trim();
      textFields['bankIfscCode'] = _ifscController.text.trim();
      textFields['bankAccountHolderName'] = 'Self';
    } else {
      if (_controller.text.trim().isEmpty) {
        CustomSnackbar.showError(message: '${widget.title} number is required');
        return;
      }
      if (_frontFile == null) {
        CustomSnackbar.showError(message: 'Front image is required');
        return;
      }

      if (widget.title == 'Aadhaar Card') {
        if (_backFile == null) {
          CustomSnackbar.showError(
            message: 'Back image is required for Aadhaar Card',
          );
          return;
        }
        files['aadhaarFront'] = _frontFile!;
        files['aadhaarBack'] = _backFile!;
        textFields['aadhaarNumber'] = _controller.text.trim();
      } else if (widget.title == 'Driving Licence') {
        if (_backFile == null) {
          CustomSnackbar.showError(
            message: 'Back image is required for Driving Licence',
          );
          return;
        }
        files['dlFront'] = _frontFile!;
        files['dlBack'] = _backFile!;
        textFields['dlNumber'] = _controller.text.trim();
      } else if (widget.title == 'Vehicle RC') {
        files['rcFront'] = _frontFile!;
        files['vehicleRcFront'] = _frontFile!;
        if (_backFile != null) {
          files['rcBack'] = _backFile!;
          files['vehicleRcBack'] = _backFile!;
        }
        textFields['rcNumber'] = _controller.text.trim();
      } else if (widget.title == 'Vehicle Insurance') {
        files['insuranceFront'] = _frontFile!;
        files['vehicleInsurance'] = _frontFile!;
        if (_backFile != null) {
          files['insuranceBack'] = _backFile!;
        }
        textFields['insuranceNumber'] = _controller.text.trim();
      } else if (widget.title == 'PAN Card') {
        if (_controller.text.trim().length != 10) {
          CustomSnackbar.showError(
            message: 'PAN Card number must be 10 characters',
          );
          return;
        }
        files['panFront'] = _frontFile!;
        files['panCard'] = _frontFile!;
        if (_backFile != null) {
          files['panBack'] = _backFile!;
        }
        textFields['panNumber'] = _controller.text.trim();
      }
    }

    final success = await _documentController.uploadKycDocument(
      title: widget.title,
      files: files,
      textFields: textFields,
      isProviderKyc: false,
    );

    if (success) {
      widget.onUploadComplete();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFAF4),
        body: Obx(() {
          return Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 24.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Please provide clear images and details for your ${widget.title}.',
                                      style: AppFonts.body,
                                    ),
                                    SizedBox(height: 24.h),
                                    if (widget.title == 'Bank Details') ...[
                                      Text(
                                        'Bank Name',
                                        style: AppFonts.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      _buildTextField(
                                        'Enter bank name',
                                        _bankNameController,
                                        TextCapitalization.words,
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'Account Number',
                                        style: AppFonts.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      _buildTextField(
                                        'Enter account number',
                                        _accountController,
                                        TextCapitalization.none,
                                        18,
                                        TextInputType.number,
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'Confirm Account Number',
                                        style: AppFonts.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      _buildTextField(
                                        'Re-enter account number',
                                        _confirmAccountController,
                                        TextCapitalization.none,
                                        18,
                                        TextInputType.number,
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'IFSC Code',
                                        style: AppFonts.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      _buildTextField(
                                        'Enter IFSC code',
                                        _ifscController,
                                        TextCapitalization.characters,
                                        11,
                                      ),
                                      SizedBox(height: 24.h),
                                      _UploadBox(
                                        label: 'Passbook / Cancelled Cheque',
                                        networkUrl: _documentController.documentFileUrls['Bank Details Front'],
                                        isRejected: widget.isRejected,
                                        isReadOnly: widget.isReadOnly,
                                        onFileSelected: (file) {
                                          setState(() {
                                            _bankProofFile = file;
                                          });
                                        },
                                      ),
                                    ] else ...[
                                      Text(
                                        '${widget.title} Number',
                                        style: AppFonts.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      _buildTextField(
                                        'Enter your ${widget.title} number',
                                        _controller,
                                        widget.title == 'PAN Card'
                                            ? TextCapitalization.characters
                                            : TextCapitalization.none,
                                        widget.title == 'PAN Card'
                                            ? 10
                                            : (widget.title == 'Aadhaar Card'
                                                ? 12
                                                : null),
                                        widget.title == 'Aadhaar Card'
                                            ? TextInputType.number
                                            : (widget.title == 'PAN Card'
                                                ? _panKeyboardType
                                                : null),
                                        widget.title == 'PAN Card'
                                            ? [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r'[a-zA-Z0-9]'),
                                                ),
                                              ]
                                            : (widget.title == 'Aadhaar Card'
                                                ? [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ]
                                                : null),
                                        widget.title == 'PAN Card'
                                            ? _panFocusNode
                                            : null,
                                      ),
                                      SizedBox(height: 24.h),
                                      _UploadBox(
                                        label: 'Front Image',
                                        networkUrl: _documentController.documentFileUrls['${widget.title} Front'],
                                        isRejected: widget.isRejected,
                                        isReadOnly: widget.isReadOnly,
                                        onFileSelected: (file) {
                                          setState(() {
                                            _frontFile = file;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 16.h),
                                      _UploadBox(
                                        label: 'Back Image',
                                        networkUrl: _documentController.documentFileUrls['${widget.title} Back'],
                                        isRejected: widget.isRejected,
                                        isReadOnly: widget.isReadOnly,
                                        onFileSelected: (file) {
                                          setState(() {
                                            _backFile = file;
                                          });
                                        },
                                      ),
                                    ],
                                    SizedBox(height: 24.h),
                                  ],
                                ),
                              ),
                            ),
                            PrimaryButton(
                              text: widget.isReadOnly
                                  ? (widget.readOnlyText ?? 'Submitted')
                                  : 'Submit Document',
                              onPressed:
                                  _documentController.isLoading.value ||
                                      widget.isReadOnly
                                  ? null
                                  : _submitDocument,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_documentController.isLoading.value)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _UploadBox extends StatefulWidget {
  const _UploadBox({
    required this.label,
    required this.onFileSelected,
    this.networkUrl,
    this.isRejected = false,
    this.isReadOnly = false,
  });

  final String label;
  final ValueChanged<File?> onFileSelected;
  final String? networkUrl;
  final bool isRejected;
  final bool isReadOnly;

  @override
  State<_UploadBox> createState() => _UploadBoxState();
}

class _UploadBoxState extends State<_UploadBox> {
  File? _selectedImage;
  bool _hideNetworkImage = false;
  final ImagePicker _picker = ImagePicker();

  Widget _buildLoading(BuildContext context, Widget child, ImageChunkEvent? progress) {
    if (progress == null) return child;
    return Center(
      child: SizedBox(
        width: 24.w,
        height: 24.w,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
          value: progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error, StackTrace? stackTrace) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
        SizedBox(height: 8.h),
        Text('Failed to load image', style: AppFonts.captionDark),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        widget.onFileSelected(_selectedImage);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context); // Close bottom sheet
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
        widget.onFileSelected(_selectedImage);
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Upload Document',
                style: AppFonts.h2.copyWith(fontSize: 18.sp),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  _SourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _SourceOption(
                    icon: Icons.folder_rounded,
                    label: 'Files',
                    onTap: () => _pickDocument(),
                  ),
                ],
              ),
              SizedBox(height: 30.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppFonts.body.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: widget.isReadOnly ? null : () => _showImageSourceSheet(context),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.05),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _selectedImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await OpenFilex.open(_selectedImage!.path);
                        },
                        child:
                            _selectedImage!.path.toLowerCase().endsWith(
                                  '.pdf',
                                ) ||
                                _selectedImage!.path.toLowerCase().endsWith(
                                  '.doc',
                                ) ||
                                _selectedImage!.path.toLowerCase().endsWith(
                                  '.docx',
                                )
                            ? Container(
                                color: Colors.grey.shade100,
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file,
                                      size: 40,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      _selectedImage!.path
                                          .split('/')
                                          .last
                                          .split('\\')
                                          .last,
                                      style: AppFonts.captionDark,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Tap to view',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                            });
                            widget.onFileSelected(null);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.w),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : widget.networkUrl != null && widget.networkUrl!.isNotEmpty && !_hideNetworkImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.isRejected
                              ? ImageFiltered(
                                  imageFilter: dart_ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                                  child: Image.network(
                                    widget.networkUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: _buildLoading,
                                    errorBuilder: _buildError,
                                  ),
                                )
                              : Image.network(
                                  widget.networkUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: _buildLoading,
                                  errorBuilder: _buildError,
                                ),
                          if (!widget.isReadOnly)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _hideNetworkImage = true;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.w),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Tap to upload',
                            style: AppFonts.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            SizedBox(height: 8.h),
            Text(
              label,
              style: AppFonts.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
