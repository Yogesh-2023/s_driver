import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/onboarding_step_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/primary_button.dart';
import '../auth/documents_upload_step_screen.dart';

class ApprovalPendingScreen extends StatefulWidget {
  final bool isProviderKyc;

  const ApprovalPendingScreen({super.key, this.isProviderKyc = false});

  @override
  State<ApprovalPendingScreen> createState() => _ApprovalPendingScreenState();
}

class _ApprovalPendingScreenState extends State<ApprovalPendingScreen> {
  @override
  void initState() {
    super.initState();
    OnboardingStepService.saveStep(
      OnboardingStepService.stepPending,
      isProviderDriver: widget.isProviderKyc,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 24.w),
          child: Column(
            children: [
              Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.warning.withOpacity(0.05),
                    ),
                  ),
                  Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.warning.withOpacity(0.1),
                    ),
                  ),
                  Container(
                    width: 70.w,
                    height: 70.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                      size: 36.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 28.h),
              Text(
                'Approval Pending',
                style: AppFonts.h1,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                'Your documents are under review. You will be able to receive rides after approval.',
                style: AppFonts.body.copyWith(
                  height: 1.5,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              _StatusTile(
                icon: Icons.task_alt,
                title: 'Documents Submitted',
                subtitle: 'The verification team has received your details.',
                color: AppColors.secondary,
              ),
              SizedBox(height: 10.h),
              _StatusTile(
                icon: Icons.support_agent,
                title: 'Manual Review',
                subtitle: 'Approval usually takes 24-48 hours.',
                color: AppColors.warning,
              ),
              Spacer(),
              PrimaryButton(
                text: 'View Uploaded Documents',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentsUploadStepScreen(
                        isProviderDriver: widget.isProviderKyc,
                        isReadOnly: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.h2.copyWith(
                    fontSize: 15.sp,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: AppFonts.body.copyWith(
                    fontSize: 13.sp,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
