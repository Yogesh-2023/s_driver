import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase().trim();
    Color bgColor;
    Color textColor;

    if (s == 'VERIFIED' || s == 'APPROVED' || s == 'ACTIVE' || s == 'YES' || s == 'ONLINE') {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
    } else if (s == 'PENDING' || s == 'PROFILE_PENDING' || s == 'NO') {
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
    } else if (s.contains('REVIEW') || s == 'UNDER_REVIEW') {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    } else if (s == 'REJECTED' || s == 'FAILED' || s == 'INACTIVE' || s == 'OFFLINE') {
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFB91C1C);
    } else {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF475569);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
