import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Reusable Sawariyaa Driver Logo widget matching Figma Frame 2147226770 specs:
/// - Layout: Horizontal
/// - Width: 135.52px (Hug)
/// - Height: 50px (Hug)
/// - Corner Radius: 14px
/// - Padding: Top 8px, Bottom 8px, Left 10px, Right 10px
/// - Background Color: #FFFFFF (White)
class SawariyaaDriverLogo extends StatelessWidget {
  final double? width;
  final double? height;

  const SawariyaaDriverLogo({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (width ?? 135.52).w,
      height: (height ?? 50).h,
      padding: EdgeInsets.only(
        top: 8.h,
        right: 10.w,
        bottom: 8.h,
        left: 10.w,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Image.asset(
        'assets/images/sanwari_driver_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
