import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_fonts.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
    this.height,
  });

  final String hintText;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final Widget? suffixIcon;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? AppDimensions.controlHeight.h,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppDimensions.controlRadius.r),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        obscureText: obscureText,
        textAlignVertical: TextAlignVertical.center,
        style: AppFonts.body.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppFonts.body.copyWith(fontSize: 12.sp, color: AppColors.textSecondary),
          prefixIcon: prefixIcon,
          prefixIconConstraints: BoxConstraints(
            minWidth: 44.w,
            minHeight: height ?? AppDimensions.controlHeight.h,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppDimensions.horizontalPadding.w,
          ),
        ),
      ),
    );
  }
}
