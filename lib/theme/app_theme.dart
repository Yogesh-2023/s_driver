import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_fonts.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.family,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.background,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.headerBackground,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: TextTheme(
        headlineLarge: AppFonts.h1,
        headlineMedium: AppFonts.h2,
        titleLarge: AppFonts.screenTitle,
        titleMedium: AppFonts.sectionTitle,
        titleSmall: AppFonts.cardTitle,
        bodyLarge: AppFonts.bodyText,
        bodyMedium: AppFonts.body,
        labelLarge: AppFonts.button,
        labelMedium: AppFonts.label,
      ),
      inputDecorationTheme: InputDecorationTheme(
        constraints: BoxConstraints(minHeight: AppDimensions.controlHeight.h),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          minimumSize: Size(0, AppDimensions.controlHeight.h),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, AppDimensions.controlHeight.h),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

