import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

class AppFonts {
  static const String family = 'Gilroy';
  static const String fontFamily = 'Gilroy';
  static const String gilroyFontFamily = 'Gilroy';

  static TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 28.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 20.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.25,
  );

  static TextStyle bodyText = TextStyle(
    fontFamily: family,
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static TextStyle captionDark = TextStyle(
    fontFamily: family,
    fontSize: 12.sp,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle buttonText = TextStyle(
    fontFamily: family,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle get screenTitle => TextStyle(
    fontFamily: family,
    fontSize: 16.sp,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get sectionTitle => TextStyle(
    fontFamily: family,
    fontSize: 15.sp,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardTitle => TextStyle(
    fontFamily: family,
    fontSize: 14.sp,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get label => TextStyle(
    fontFamily: family,
    fontSize: 12.sp,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static TextStyle get value => TextStyle(
    fontFamily: family,
    fontSize: 14.sp,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get listItem => TextStyle(
    fontFamily: family,
    fontSize: 13.sp,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
