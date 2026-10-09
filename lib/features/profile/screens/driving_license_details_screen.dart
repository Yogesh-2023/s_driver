import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_fonts.dart';
import '../../../widgets/profile_app_bar.dart';
import '../../../widgets/status_badge.dart';
import '../../auth/models/driver_account_models.dart';
import 'kyc_document_viewer_screen.dart';

class DrivingLicenseDetailsScreen extends StatelessWidget {
  final DrivingLicenseInfo drivingLicense;

  const DrivingLicenseDetailsScreen({super.key, required this.drivingLicense});

  void _openLicenseViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycDocumentViewerScreen(
          title: 'Driving License',
          documents: [
            KycDocImageItem(
              label: 'Driving License – Front',
              imageUrl: drivingLicense.frontDocument.imageUrl,
            ),
            KycDocImageItem(
              label: 'Driving License – Back',
              imageUrl: drivingLicense.backDocument.imageUrl,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenseNo = (drivingLicense.licenseNumber.trim().isEmpty ||
            drivingLicense.licenseNumber == 'null')
        ? 'Not Provided'
        : drivingLicense.licenseNumber.trim();

    final statusVal = (drivingLicense.status.trim().isEmpty ||
            drivingLicense.status == 'null')
        ? 'Not Available'
        : drivingLicense.status.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      appBar: const ProfileAppBar(title: 'Driving License'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              _buildSectionHeader('DRIVING LICENSE DETAILS'),
                    SizedBox(height: 10.h),

                    // Card with License Number, View button & Overall Status
                    _buildCard([
                      _buildDocDetailItem(
                        context: context,
                        icon: Icons.badge_outlined,
                        iconBg: const Color(0xFFFFFBEA),
                        iconColor: const Color(0xFFFFB020),
                        label: 'License Number',
                        value: licenseNo,
                        onViewTap: () => _openLicenseViewer(context),
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildStatusRow(
                        icon: Icons.verified_user_outlined,
                        iconBg: const Color(0xFFECFDF5),
                        iconColor: const Color(0xFF10B981),
                        label: 'Overall Status',
                        status: statusVal,
                      ),
                    ]),

                    SizedBox(height: 24.h),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: AppFonts.fontFamily,
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDocDetailItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onViewTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18.sp, color: iconColor),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 11.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        InkWell(
          onTap: onViewTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              borderRadius: BorderRadius.circular(8.r),
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
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18.sp, color: iconColor),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 11.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(status: status),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
