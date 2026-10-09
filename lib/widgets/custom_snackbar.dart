import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum SnackbarType { success, error, warning, info }

class CustomSnackbar {
  static void showSuccess({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      message,
      type: SnackbarType.success,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  static void showError({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      message,
      type: SnackbarType.error,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  static void showWarning({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      message,
      type: SnackbarType.warning,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  static void showInfo({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      message,
      type: SnackbarType.info,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  static void show(
    String message, {
    SnackbarType type = SnackbarType.info,
    Color? backgroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    bool isDismissible = true,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) return;

    final lowerMsg = normalizedMessage.toLowerCase();
    if (lowerMsg.contains('payment confirmed') ||
        lowerMsg.contains('payment completed') ||
        lowerMsg.contains('payment:confirmed') ||
        lowerMsg.contains('payment:completed') ||
        lowerMsg.contains('booking payment confirmed') ||
        lowerMsg.contains('booking payment completed') ||
        lowerMsg.contains('event: payment') ||
        lowerMsg.contains('event: booking:payment')) {
      return;
    }

    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

    final context = Get.overlayContext ?? Get.context;
    final safeTop = context == null
        ? 4.0
        : MediaQuery.viewPaddingOf(context).top + 4.0;

    final defaultColor = switch (type) {
      SnackbarType.success => const Color(0xFF15803D),
      SnackbarType.error => const Color(0xFFB91C1C),
      SnackbarType.warning => const Color(0xFFB45309),
      SnackbarType.info => const Color(0xFF0369A1),
    };

    final icon = switch (type) {
      SnackbarType.success => Icons.check_circle_outline,
      SnackbarType.error => Icons.error_outline,
      SnackbarType.warning => Icons.warning_amber_rounded,
      SnackbarType.info => Icons.info_outline,
    };

    Get.rawSnackbar(
      messageText: Row(
        children: [
          Icon(icon, color: Colors.white, size: 21.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              normalizedMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                height: 1.25,
                fontWeight: FontWeight.w600,
                fontFamily: 'Gilroy',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor ?? defaultColor,
      mainButton: actionLabel != null && onAction != null
          ? TextButton(
              onPressed: () {
                if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
                onAction();
              },
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      snackPosition: SnackPosition.TOP,
      snackStyle: SnackStyle.FLOATING,
      margin: EdgeInsets.fromLTRB(12.w, safeTop, 12.w, 0),
      borderRadius: 14.r,
      duration: duration,
      isDismissible: isDismissible,
      dismissDirection: DismissDirection.up,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      animationDuration: const Duration(milliseconds: 260),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
    );
  }
}

// Global top-level function compatibility helper
void showCustomSnackBar(
  String message, {
  bool isError = true,
  Color? backgroundColor,
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  CustomSnackbar.show(
    message,
    type: isError ? SnackbarType.error : SnackbarType.success,
    backgroundColor: backgroundColor,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}
