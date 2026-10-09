import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_fonts.dart';
import '../../../widgets/profile_app_bar.dart';
import '../../auth/models/driver_account_models.dart';

class PersonalInfoDetailsScreen extends StatelessWidget {
  final PersonalInfo personalInfo;

  const PersonalInfoDetailsScreen({super.key, required this.personalInfo});

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty || rawDate == 'null') {
      return 'Not provided';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      appBar: const ProfileAppBar(title: 'Personal Info'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 4.h, bottom: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              _buildProfileHeaderCard(),

              SizedBox(height: 12.h),

              // Section: Personal Details
              _buildSectionHeader('PERSONAL DETAILS'),
              SizedBox(height: 8.h),
              _buildCard([
                _buildDetailItem(
                  icon: Icons.person_outline_rounded,
                  iconBg: const Color(0xFFFFFBEA),
                  iconColor: const Color(0xFFFFB020),
                  label: 'Full Name',
                  value: personalInfo.fullName,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.mail_outline_rounded,
                  iconBg: const Color(0xFFF0F9FF),
                  iconColor: const Color(0xFF0284C7),
                  label: 'Email Address',
                  value: personalInfo.email,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.smartphone_outlined,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF10B981),
                  label: 'Phone Number',
                  value: personalInfo.phone,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.wc_rounded,
                  iconBg: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'Gender',
                  value: personalInfo.gender,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.cake_outlined,
                  iconBg: const Color(0xFFFFF1F2),
                  iconColor: const Color(0xFFF43F5E),
                  label: 'Date of Birth',
                  value: _formatDate(personalInfo.dateOfBirth),
                ),
              ]),

              SizedBox(height: 20.h),

              // Section: Address
              _buildSectionHeader('ADDRESS'),
              SizedBox(height: 8.h),
              _buildCard([
                _buildDetailItem(
                  icon: Icons.home_outlined,
                  iconBg: const Color(0xFFFFFBEA),
                  iconColor: const Color(0xFFFFB020),
                  label: 'Address Line 1',
                  value: personalInfo.address.addressLine1,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.location_city_outlined,
                  iconBg: const Color(0xFFF8FAFC),
                  iconColor: const Color(0xFF64748B),
                  label: 'Address Line 2',
                  value: personalInfo.address.addressLine2 ?? 'Not provided',
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.near_me_outlined,
                  iconBg: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                  label: 'Landmark',
                  value: personalInfo.address.landmark ?? 'Not provided',
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.apartment_outlined,
                  iconBg: const Color(0xFFF0F9FF),
                  iconColor: const Color(0xFF0284C7),
                  label: 'City',
                  value: personalInfo.address.city,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.map_outlined,
                  iconBg: const Color(0xFFFDF4FF),
                  iconColor: const Color(0xFFC084FC),
                  label: 'State',
                  value: personalInfo.address.state,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.pin_drop_outlined,
                  iconBg: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFEF4444),
                  label: 'Postal Code',
                  value: personalInfo.address.postalCode,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildDetailItem(
                  icon: Icons.public_outlined,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF059669),
                  label: 'Country',
                  value: personalInfo.address.country,
                ),
              ]),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final hasImage = personalInfo.profileImageUrl != null &&
        personalInfo.profileImageUrl!.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 92.w,
              height: 92.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFCC00),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasImage
                    ? Image.network(
                        personalInfo.profileImageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 50.sp,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 50.sp,
                      ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              personalInfo.fullName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 4.h),
            _buildActiveStatus(personalInfo.accountStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStatus(String status) {
    final s = status.toUpperCase().trim();
    Color dotColor;
    Color bgColor;
    Color textColor;
    String displayStatus = status.replaceAll('_', ' ').trim();

    if (s == 'VERIFIED' || s == 'APPROVED' || s == 'ACTIVE' || s == 'YES' || s == 'ONLINE') {
      dotColor = const Color(0xFF10B981);
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
    } else if (s == 'PENDING' || s == 'PROFILE_PENDING' || s == 'NO') {
      dotColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
    } else if (s.contains('REVIEW') || s == 'UNDER_REVIEW') {
      dotColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    } else if (s == 'REJECTED' || s == 'FAILED' || s == 'INACTIVE' || s == 'OFFLINE') {
      dotColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFB91C1C);
    } else {
      dotColor = const Color(0xFF64748B);
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF475569);
    }

    return Padding(
      padding: EdgeInsets.only(left: 14.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: dotColor.withValues(alpha: 0.25), width: 0.8.w),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              displayStatus,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
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

  Widget _buildDetailItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final displayValue = (value.trim().isEmpty || value == 'null') ? 'Not provided' : value;

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
                displayValue,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.5.sp,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
