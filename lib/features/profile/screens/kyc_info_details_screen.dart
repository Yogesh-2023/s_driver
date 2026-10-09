import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_fonts.dart';
import '../../../widgets/profile_app_bar.dart';
import '../../../widgets/status_badge.dart';
import '../../auth/models/driver_account_models.dart';
import 'kyc_document_viewer_screen.dart';

class KycInfoDetailsScreen extends StatelessWidget {
  final KycInfo kyc;

  const KycInfoDetailsScreen({super.key, required this.kyc});

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty || rawDate == 'null') {
      return 'Not available';
    }
    try {
      final dt = DateTime.parse(rawDate.trim());
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  void _openAadhaarViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycDocumentViewerScreen(
          title: 'Aadhaar Card',
          documents: [
            KycDocImageItem(
              label: 'Aadhaar Card – Front',
              imageUrl: kyc.aadhaar.frontImageUrl ?? kyc.aadhaar.imageUrl,
            ),
            KycDocImageItem(
              label: 'Aadhaar Card – Back',
              imageUrl: kyc.aadhaar.backImageUrl,
            ),
          ],
        ),
      ),
    );
  }

  void _openPanViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycDocumentViewerScreen(
          title: 'PAN Card',
          documents: [
            KycDocImageItem(
              label: 'PAN Card',
              imageUrl: kyc.pan.imageUrl,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      appBar: const ProfileAppBar(title: 'KYC Info'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Overall KYC Status Banner Card
              _buildOverallKycCard(),

                    SizedBox(height: 20.h),

                    // 2. KYC Documents Section Header
                    Text(
                      'KYC DOCUMENTS',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // 3. Aadhaar Card Item Card
                    _buildDocumentCard(
                      context: context,
                      icon: Icons.badge_outlined,
                      iconBg: const Color(0xFFFFFBEA),
                      iconColor: const Color(0xFFFFB020),
                      title: 'Aadhaar Card',
                      subtitle: 'Front & Back',
                      status: kyc.aadhaar.status,
                      onViewTap: () => _openAadhaarViewer(context),
                    ),

                    SizedBox(height: 14.h),

                    // 4. PAN Card Item Card
                    _buildDocumentCard(
                      context: context,
                      icon: Icons.credit_card_outlined,
                      iconBg: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'PAN Card',
                      subtitle: 'Uploaded Document',
                      status: kyc.pan.status,
                      onViewTap: () => _openPanViewer(context),
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallKycCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall KYC Status',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              StatusBadge(status: kyc.status),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Onboarding Status',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              StatusBadge(status: kyc.onboardingStatus),
            ],
          ),
          if (kyc.verifiedAt != null && kyc.verifiedAt!.isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verified At',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(kyc.verifiedAt),
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onViewTap,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 22.sp, color: iconColor),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    StatusBadge(status: status),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          InkWell(
            onTap: onViewTap,
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEA),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFFFEF9E), width: 1.w),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16.sp,
                    color: const Color(0xFFD97706),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'View',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
