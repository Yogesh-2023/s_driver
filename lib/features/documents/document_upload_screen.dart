import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_snackbar.dart';
import '../dashboard/profile_screen.dart';
import 'approval_pending_screen.dart';
import 'document_detail_screen.dart';
import 'repositories/document_repository.dart';
import 'controllers/document_controller.dart';
import '../auth/controllers/auth_controller.dart';
import '../navigation/driver_navigation_screen.dart';

enum DocumentStatus { pending, underVerification, approved, rejected }

class DocumentUploadScreen extends StatefulWidget {
  final bool isFromAuth;
  final bool isProviderDriver;
  final bool isEmbedded;

  const DocumentUploadScreen({
    super.key,
    this.isFromAuth = false,
    this.isProviderDriver = false,
    this.isEmbedded = false,
  });

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  late final DocumentController _documentController;
  late final List<_DriverDocument> _documents;
  Worker? _statusWorker;
  bool _hasSubmittedLocally = false;

  @override
  void initState() {
    super.initState();
    _documentController = Get.isRegistered<DocumentController>()
        ? Get.find<DocumentController>()
        : Get.put(DocumentController(documentRepository: Get.find<DocumentRepository>()));

    // Fetch latest status on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _documentController.fetchKycStatus(isProviderKyc: widget.isProviderDriver);
    });

    if (widget.isFromAuth) {
      _statusWorker = ever(_documentController.kycStatus, (status) {
        if (status.toLowerCase() == 'approved') {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => DriverNavigationScreen()),
              (_) => false,
            );
          }
        }
      });
    }

    _documents = [
      _DriverDocument(
        'Aadhaar Card',
        'Front and back photo',
        Icons.badge_outlined,
      ),
      _DriverDocument(
        'Driving Licence',
        'Valid commercial licence',
        Icons.credit_card,
      ),
      _DriverDocument(
        'Vehicle RC',
        'Truck registration certificate',
        Icons.article_outlined,
      ),
      _DriverDocument(
        'Vehicle Insurance',
        'Active insurance copy',
        Icons.verified_user_outlined,
      ),
      _DriverDocument(
        'PAN Card',
        'For payouts and tax record',
        Icons.account_box_outlined,
      ),
      _DriverDocument(
        'Bank Details',
        'Account number and IFSC',
        Icons.account_balance_outlined,
      ),
    ];
  }

  @override
  void dispose() {
    _statusWorker?.dispose();
    super.dispose();
  }

  void _onDocumentTap(String title) {
    final status =
        _documentController.documentStatuses[title] ?? DocumentStatus.pending;
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final authStatus = authController?.verificationStatus.value.toUpperCase() ?? '';
    final isPendingOrUnderReview =
        authStatus == 'PENDING' || authStatus == 'UNDER_REVIEW';

    final isReadOnly = widget.isEmbedded ||
        isPendingOrUnderReview ||
        status == DocumentStatus.approved ||
        status == DocumentStatus.underVerification;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          title: title,
          isReadOnly: isReadOnly,
          readOnlyText: status == DocumentStatus.approved
              ? 'Approved'
              : (status == DocumentStatus.underVerification || isPendingOrUnderReview
                    ? 'Under Verification'
                    : 'Uploaded'),
          onUploadComplete: () {
            _documentController.fetchKycStatus(isProviderKyc: widget.isProviderDriver);
          },
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.all(24.w),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: AppColors.primary,
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Exit KYC Verification?',
                textAlign: TextAlign.center,
                style: AppFonts.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Are you sure you want to exit? Your progress is saved, but you need to complete KYC to start accepting orders.',
                textAlign: TextAlign.center,
                style: AppFonts.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text(
                        'Yes, Exit',
                        style: AppFonts.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return shouldExit ?? false;
  }

  Future<void> _handleBackNavigation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final status = _documentController.kycStatus.value.toLowerCase().trim();
    final isApproved = status == 'approved' || status == 'verified';

    if (isApproved) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Get.back();
      }
      return;
    }

    final confirm = await _showExitConfirmationDialog(context);
    if (confirm && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Get.back();
      }
    }
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
            onTap: _handleBackNavigation,
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
              widget.isProviderDriver ? 'Provider KYC' : 'Driver Verification',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(isProvider: widget.isProviderDriver),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.person_outline,
                size: 20.sp,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return Obx(() {
        if (_documentController.isLoading.value &&
            _documentController.documentStatuses.values.every(
              (s) => s == DocumentStatus.pending,
            )) {
          return const Center(child: CircularProgressIndicator());
        }

        final requiredDocuments = widget.isProviderDriver
            ? _documents
                  .where((doc) => doc.title != 'Bank Details')
                  .toList()
            : _documents;
        int completedCount = requiredDocuments
            .where(
              (doc) =>
                  _documentController.documentStatuses[doc.title] ==
                      DocumentStatus.approved ||
                  _documentController.documentStatuses[doc.title] ==
                      DocumentStatus.underVerification ||
                  (widget.isProviderDriver &&
                      _hasUploadedDocument(doc.title)),
            )
            .length;
        final progress = _documents.isEmpty
            ? 0.0
            : completedCount / requiredDocuments.length;
        final status = _documentController.kycStatus.value.toLowerCase();
        final isApproved =
            status.contains('approve') || status.contains('verified');
        final isRejected = status.contains('reject');
        final isDraftPending = status == 'pending';
        final isUnderVerification =
            status.contains('under') ||
            status.contains('verify') ||
            status.contains('submitted') ||
            status.contains('review');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 18.w,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploaded Documents',
                    style: AppFonts.h1.copyWith(fontSize: 20.sp),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Tap on any document card below to view details.',
                    style: AppFonts.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: progress,
                      backgroundColor: AppColors.border,
                      color: isRejected
                          ? Colors.red
                          : ((isUnderVerification || isDraftPending)
                                ? Colors.orange
                                : AppColors.secondary),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    widget.isProviderDriver
                        ? '$completedCount/${requiredDocuments.length} required completed'
                        : '$completedCount/${_documents.length} completed',
                    style: AppFonts.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            for (final document in _documents) ...[
              Builder(
                builder: (context) {
                  final docStatus =
                      _documentController.documentStatuses[document.title] ??
                      DocumentStatus.pending;
                  final hasUploaded =
                      widget.isProviderDriver &&
                      _hasUploadedDocument(document.title);

                  return _DocumentCard(
                    document: document,
                    status: docStatus,
                    hasUploadedFile: hasUploaded,
                    rejectionReason:
                        _documentController.documentRejectionReasons[document.title] ??
                        (docStatus == DocumentStatus.rejected
                            ? _documentController.rejectionReason.value
                            : null),
                    onTap: () {
                      _onDocumentTap(document.title);
                    },
                  );
                },
              ),
              SizedBox(height: 10.h),
            ],
          ],
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFAF4),
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Obx(() {
                if (_documentController.isLoading.value &&
                    _documentController.documentStatuses.values.every(
                      (s) => s == DocumentStatus.pending,
                    )) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requiredDocuments = widget.isProviderDriver
                    ? _documents
                          .where((doc) => doc.title != 'Bank Details')
                          .toList()
                    : _documents;
                int completedCount = requiredDocuments
                    .where(
                      (doc) =>
                          _documentController.documentStatuses[doc.title] ==
                              DocumentStatus.approved ||
                          _documentController.documentStatuses[doc.title] ==
                              DocumentStatus.underVerification ||
                          (widget.isProviderDriver &&
                              _hasUploadedDocument(doc.title)),
                    )
                    .length;
                final progress = _documents.isEmpty
                    ? 0.0
                    : completedCount / requiredDocuments.length;
                final status = _documentController.kycStatus.value
                    .toLowerCase();
                final isApproved =
                    status.contains('approve') || status.contains('verified');
                final isRejected = status.contains('reject');
                final isNotSubmitted =
                    status.isEmpty || status == 'not_submitted';
                final isDraftPending = status == 'pending';
                final isUnderVerification =
                    status.contains('under') ||
                    status.contains('verify') ||
                    status.contains('submitted') ||
                    status.contains('review');

                final isKycCompleted =
                    _documentController.aadharNumber.value &&
                    _documentController.aadharCardFront.value &&
                    _documentController.aadharCardBack.value &&
                    _documentController.panNumber.value &&
                    _documentController.panCardFront.value &&
                    _documentController.panCardBack.value;

                final hasAnyRejectedDoc = _documents.any(
                  (doc) =>
                      _documentController.documentStatuses[doc.title] ==
                      DocumentStatus.rejected,
                );

                final canSubmitProviderKyc =
                    widget.isProviderDriver &&
                    isKycCompleted &&
                    !hasAnyRejectedDoc &&
                    (status == 'pending' ||
                        status == 'not_submitted' ||
                        status.isEmpty) &&
                    !_documentController.isSubmitting.value;

                return SafeArea(
                  top: false,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _documentController.fetchKycStatus(
                        isProviderKyc: widget.isProviderDriver,
                      );
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 18.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Documents',
                                style: AppFonts.h1.copyWith(fontSize: 24.sp),
                              ),
                              if (!isApproved) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  widget.isProviderDriver
                                      ? 'Please upload required documents for provider account approval.'
                                      : 'Please upload documents for driver partner approval.',
                                  style: AppFonts.body,
                                ),
                                if (widget.isProviderDriver) ...[
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Pull down to refresh latest KYC status.',
                                    style: AppFonts.body.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                              SizedBox(height: 18.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20.r),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: progress,
                                  backgroundColor: AppColors.border,
                                  color: isRejected
                                      ? Colors.red
                                      : ((isUnderVerification || isDraftPending)
                                            ? Colors.orange
                                            : AppColors.secondary),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                widget.isProviderDriver
                                    ? '$completedCount/${requiredDocuments.length} required completed'
                                    : '$completedCount/${_documents.length} completed',
                                style: AppFonts.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        for (final document in _documents) ...[
                          Builder(
                            builder: (context) {
                              final docStatus =
                                  _documentController.documentStatuses[document
                                      .title] ??
                                  DocumentStatus.pending;
                              final hasUploaded =
                                  widget.isProviderDriver &&
                                  _hasUploadedDocument(document.title);
                              final isLocked =
                                  widget.isProviderDriver &&
                                  (docStatus == DocumentStatus.approved ||
                                      docStatus ==
                                          DocumentStatus.underVerification ||
                                      (docStatus == DocumentStatus.pending &&
                                          hasUploaded));

                              return _DocumentCard(
                                document: document,
                                status: docStatus,
                                hasUploadedFile: hasUploaded,
                                rejectionReason:
                                    _documentController
                                        .documentRejectionReasons[document
                                        .title] ??
                                    (docStatus == DocumentStatus.rejected
                                        ? _documentController
                                              .rejectionReason
                                              .value
                                        : null),
                                onTap: () {
                                  _onDocumentTap(document.title);
                                },
                              );
                            },
                          ),
                          SizedBox(height: 10.h),
                        ],
                        SizedBox(height: 10.h),
                        PrimaryButton(
                          text: isApproved
                              ? 'Approved'
                              : isNotSubmitted
                              ? 'Start KYC'
                              : (isUnderVerification
                                    ? 'Under Verification'
                                    : (_documentController.isSubmitting.value
                                          ? 'Submitting...'
                                          : 'Submit for Approval')),
                          onPressed:
                              ((widget.isProviderDriver &&
                                      canSubmitProviderKyc) ||
                                  (!widget.isProviderDriver &&
                                      (completedCount >= _documents.length ||
                                          isRejected) &&
                                      !isApproved &&
                                      !_hasSubmittedLocally &&
                                      !_documentController.isSubmitting.value))
                              ? () async {
                                  setState(() {
                                    _hasSubmittedLocally = true;
                                  });
                                  if (widget.isProviderDriver) {
                                    bool success = await _documentController
                                        .submitForApproval(isProviderKyc: true);
                                    if (success && !widget.isFromAuth) {
                                      if (context.mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ApprovalPendingScreen(
                                                  isProviderKyc: true,
                                                ),
                                          ),
                                        );
                                      }
                                    } else if (!success) {
                                      setState(() {
                                        _hasSubmittedLocally = false;
                                      });
                                    }
                                  } else {
                                    if (!widget.isFromAuth) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ApprovalPendingScreen(),
                                        ),
                                      );
                                    }
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasUploadedDocument(String title) {
    if (widget.isProviderDriver) {
      if (title == 'Aadhaar Card') {
        return _documentController.aadharCardFront.value ||
            _documentController.aadharCardBack.value;
      }
      if (title == 'PAN Card') {
        return _documentController.panCardFront.value ||
            _documentController.panCardBack.value;
      }
      if (title == 'Bank Details') {
        return _documentController.bankProof.value ||
            _documentController.bankName.value;
      }
    }
    final urls = _documentController.documentFileUrls;
    return (urls[title]?.isNotEmpty ?? false) ||
        (urls['$title Front']?.isNotEmpty ?? false) ||
        (urls['$title Back']?.isNotEmpty ?? false);
  }
}

class _ProviderKycStatusCard extends StatelessWidget {
  const _ProviderKycStatusCard({
    required this.status,
    required this.name,
    required this.email,
    required this.phone,
  });

  final String status;
  final String name;
  final String email;
  final String phone;

  Color get _statusColor {
    final normalized = status.toLowerCase();
    if (normalized.contains('approve')) return AppColors.secondary;
    if (normalized.contains('reject')) return Colors.red;
    return Colors.orange;
  }

  String get _statusText {
    final normalized = status.toLowerCase();
    if (normalized.contains('approve')) return 'Approved';
    if (normalized.contains('reject')) return 'Rejected';
    if (normalized.contains('under') ||
        normalized.contains('review') ||
        normalized.contains('verify') ||
        normalized.contains('submitted'))
      return 'Under Verification';
    if (normalized.isEmpty || normalized == 'not_submitted')
      return 'Not Submitted';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.w),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _statusColor.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _statusColor.withOpacity(0.16),
            child: Icon(Icons.verified_user_outlined, color: _statusColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Provider KYC' : name,
                  style: AppFonts.h2.copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 3.h),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: AppFonts.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppFonts.body.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              _statusText,
              style: AppFonts.body.copyWith(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.status,
    required this.onTap,
    this.hasUploadedFile = false,
    this.rejectionReason,
  });

  final _DriverDocument document;
  final DocumentStatus status;
  final VoidCallback? onTap;
  final bool hasUploadedFile;
  final String? rejectionReason;

  Color _getStatusColor() {
    switch (status) {
      case DocumentStatus.approved:
        return AppColors.secondary;
      case DocumentStatus.rejected:
        return Colors.red;
      case DocumentStatus.underVerification:
        return Colors.orange;
      case DocumentStatus.pending:
        return hasUploadedFile ? Colors.orange : AppColors.textSecondary;
    }
  }

  String _getStatusText() {
    switch (status) {
      case DocumentStatus.approved:
        return 'Approved';
      case DocumentStatus.rejected:
        return 'Rejected - Reupload';
      case DocumentStatus.underVerification:
        return 'Under Verification';
      case DocumentStatus.pending:
        return hasUploadedFile ? 'Pending' : 'Upload';
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case DocumentStatus.approved:
        return Icons.check_circle;
      case DocumentStatus.rejected:
        return Icons.error_outline;
      case DocumentStatus.underVerification:
        return Icons.hourglass_empty;
      case DocumentStatus.pending:
        return hasUploadedFile ? Icons.hourglass_empty : document.icon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isPending = status == DocumentStatus.pending;
    final isUploadPending = isPending && hasUploadedFile;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isPending && !isUploadPending
                ? AppColors.border
                : statusColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isPending
                    ? (isUploadPending
                          ? statusColor.withOpacity(.12)
                          : AppColors.primary.withOpacity(.1))
                    : statusColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                _getStatusIcon(),
                color: isPending && !isUploadPending
                    ? AppColors.primary
                    : statusColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: AppFonts.h2.copyWith(fontSize: 16.sp),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    status == DocumentStatus.rejected
                        ? (rejectionReason != null &&
                                  rejectionReason!.isNotEmpty
                              ? 'Reason: $rejectionReason'
                              : 'Verification failed. Please upload again.')
                        : document.subtitle,
                    style: AppFonts.body.copyWith(
                      color: status == DocumentStatus.rejected
                          ? Colors.red
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  isPending && !isUploadPending
                      ? Icons.file_upload_outlined
                      : Icons.chevron_right,
                  color: statusColor,
                ),
                SizedBox(height: 4.h),
                Text(
                  _getStatusText(),
                  style: AppFonts.body.copyWith(
                    fontSize: 10.sp,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverDocument {
  _DriverDocument(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}
