import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../services/ticket_service.dart';
import '../widgets/custom_snackbar.dart';

class RaiseIssueScreen extends StatefulWidget {
  const RaiseIssueScreen({super.key, this.isProvider = false});

  final bool isProvider;

  @override
  State<RaiseIssueScreen> createState() => _RaiseIssueScreenState();
}

class _RaiseIssueScreenState extends State<RaiseIssueScreen> {
  late final TicketService _ticketService = TicketService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _bookingIdController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _loadingCategories = true;

  final List<File> _attachmentFiles = [];
  final List<Map<String, dynamic>> _uploadedAttachments = [];
  bool _isUploadingAttachment = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final cats = await _ticketService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loadingCategories = false;
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first['id']?.toString() ?? _categories.first['code']?.toString();
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descController.dispose();
    _bookingIdController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    CustomSnackbar.showError(message: message);
  }

  Future<void> _pickAttachment(ImageSource source) async {
    if (_attachmentFiles.length >= 5) {
      _showError('Maximum 5 attachments allowed.');
      return;
    }
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;

      final ioFile = File(file.path);
      final size = await ioFile.length();
      if (size > 10 * 1024 * 1024) {
        _showError('File size exceeds max 10 MB limit.');
        return;
      }

      setState(() => _isUploadingAttachment = true);

      final uploaded = await _ticketService.uploadAttachment(file.path);
      if (!mounted) return;

      setState(() => _isUploadingAttachment = false);

      if (uploaded != null && (uploaded['url'] != null || uploaded['path'] != null)) {
        setState(() {
          _attachmentFiles.add(ioFile);
          _uploadedAttachments.add({
            'url': uploaded['url'] ?? uploaded['path'],
            'filename': uploaded['filename'] ?? uploaded['name'] ?? file.name,
            'mimeType': uploaded['mimeType'] ?? uploaded['type'],
            'size': uploaded['size'] ?? size,
          });
        });
      } else {
        _showError(_ticketService.lastErrorMessage ?? 'Attachment upload failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        _showError('Error picking image: $e');
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentFiles.removeAt(index);
      _uploadedAttachments.removeAt(index);
    });
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final description = _descController.text.trim();
    final bookingId = _bookingIdController.text.trim();

    if (subject.length < 2) {
      _showError('Ticket title must be at least 2 characters.');
      return;
    }

    if (description.length < 10) {
      _showError('Please describe your issue in more detail (at least 10 characters).');
      return;
    }

    setState(() => _isSubmitting = true);

    final created = await _ticketService.raiseTicket(
      subject: subject,
      description: description,
      categoryId: _selectedCategoryId,
      bookingId: bookingId.isNotEmpty ? bookingId : null,
      attachments: _uploadedAttachments.isNotEmpty ? _uploadedAttachments : null,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (created != null) {
      CustomSnackbar.showSuccess(message: 'Support ticket raised successfully!');
      Navigator.pop(context, true);
    } else {
      _showError(
        _ticketService.lastErrorMessage ?? 'Failed to submit ticket. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFAF4),
        body: Column(
          children: [
            _buildHeaderSection(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Selection Chips
                    Text(
                      'Select Category',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    if (_loadingCategories)
                      const LinearProgressIndicator(color: Color(0xFFFFCC00))
                    else if (_categories.isEmpty)
                      Text(
                        'General Driver Support',
                        style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 13.sp, color: Colors.grey),
                      )
                    else
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: _categories.map((cat) {
                          final id = (cat['id'] ?? cat['code'] ?? '').toString();
                          final name = (cat['name'] ?? cat['code'] ?? 'Category').toString();
                          final isSelected = _selectedCategoryId == id;
                          return ChoiceChip(
                            label: Text(name),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFCC00),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? const Color(0xFFFFCC00) : const Color(0xFFE2E8F0),
                            ),
                            labelStyle: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF475569),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategoryId = id);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    SizedBox(height: 16.h),

                    // Ticket Subject
                    Text(
                      'Ticket Title',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _subjectController,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Payment payout delayed, Trip issue',
                          hintStyle: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Describe Issue
                    Text(
                      'Describe your issue',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _descController,
                        maxLines: 5,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Describe your issue in detail here...',
                          hintStyle: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Optional Booking ID
                    Text(
                      'Trip / Booking ID (Optional)',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _bookingIdController,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Booking UUID or Ride ID',
                          hintStyle: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Attachments Label
                    Text(
                      'Attachments (${_attachmentFiles.length}/5, max 10MB each)',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8.h),

                    if (_attachmentFiles.isNotEmpty) ...[
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: List.generate(_attachmentFiles.length, (index) {
                          final file = _attachmentFiles[index];
                          return Stack(
                            children: [
                              Container(
                                width: 70.w,
                                height: 70.w,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.r),
                                  image: DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeAttachment(index),
                                  child: Container(
                                    padding: EdgeInsets.all(4.r),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      SizedBox(height: 10.h),
                    ],

                    if (_isUploadingAttachment)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFCC00),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Uploading attachment...',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 12.sp,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_attachmentFiles.length < 5)
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickAttachment(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF1E293B)),
                            label: Text(
                              'Gallery',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          OutlinedButton.icon(
                            onPressed: () => _pickAttachment(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E293B)),
                            label: Text(
                              'Camera',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: const BoxDecoration(color: Color(0xFFE9EDF1)),
            child: SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitTicket,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Color(0xFF1E293B))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Submit Ticket',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: const Color(0xFF1E293B),
                            size: 18.sp,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
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
            InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
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
              'Raise Support Ticket',
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
