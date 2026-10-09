import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_fonts.dart';

class CommonSaveButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final String text;

  const CommonSaveButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
    this.text = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5), width: 1.0),
        ),
      ),
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 40.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC000),
            borderRadius: BorderRadius.circular(59.r),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  height: 18.h,
                  width: 18.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
        ),
      ),
    );
  }
}
