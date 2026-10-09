import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_fonts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  children: [
                    _buildTermsCard(
                      numberId: 'SEC 01',
                      title: '1. Acceptance of Terms',
                      content:
                          'By registering, accessing, or operating as a driver partner on the FleetGo platform, you agree to comply with and be bound by these Terms & Conditions, our safety guidelines, and all applicable operational policies.',
                      bulletPoints: [
                        'Applies to all ride bookings, delivery assignments, and interactions on the platform.',
                        'Continued use of the driver application constitutes ongoing acceptance of updated terms.',
                      ],
                    ),
                    _buildTermsCard(
                      numberId: 'SEC 02',
                      title: '2. Driver Eligibility & Verification',
                      content:
                          'All driver partners must possess a valid commercial driving license, active vehicle registration certificate (RC), valid motor insurance, and transport permits as mandated by regional authorities.',
                      bulletPoints: [
                        'Drivers must be at least 18 years of age with verified background checks.',
                        'Mandatory documentation and vehicle fitness must be kept up to date at all times.',
                      ],
                    ),
                    _buildTermsCard(
                      numberId: 'SEC 03',
                      title: '3. Ride Fulfillment & Code of Conduct',
                      content:
                          'Driver partners agree to provide safe, professional, and reliable transportation services. Drivers must adhere strictly to traffic rules and maintain zero tolerance for reckless behavior or harassment.',
                      bulletPoints: [
                        'Strict adherence to speed limits, traffic signals, and passenger safety standards.',
                        'Zero tolerance for substance abuse, intoxication, or inappropriate conduct during trips.',
                      ],
                    ),
                    _buildTermsCard(
                      numberId: 'SEC 04',
                      title: '4. Fares, Earnings & Payouts',
                      content:
                          'Trip fares and driver earnings are calculated based on base fare, distance traveled, trip duration, and active surge/incentive structures. Platform commissions are deducted transparently.',
                      bulletPoints: [
                        'Net earnings are credited directly to your registered bank account or wallet.',
                        'Fare disputes and cancellation adjustments are resolved under platform fare policies.',
                      ],
                    ),
                    _buildTermsCard(
                      numberId: 'SEC 05',
                      title: '5. Account Suspension & Termination',
                      content:
                          'FleetGo reserves the right to temporarily suspend or permanently deactivate driver partner accounts in cases of policy violations, safety complaints, fraudulent actions, or expired documentation.',
                      bulletPoints: [
                        'Temporary holding for document verification updates or pending investigations.',
                        'Permanent account deactivation for critical safety breaches or fraudulent activity.',
                      ],
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Container(
      color: const Color(0xFFFFFAE1),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12.h,
        bottom: 14.h,
        left: 16.w,
        right: 16.w,
      ),
      child: Row(
        children: [
          if (canPop) ...[
            InkWell(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: 20.sp,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Expanded(
            child: Text(
              'Terms & Conditions',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCard({
    required String numberId,
    required String title,
    required String content,
    required List<String> bulletPoints,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAE1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: const Color(0xFFFFC000).withValues(alpha: 0.4),
                    width: 1.w,
                  ),
                ),
                child: Text(
                  numberId,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: 0.0,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            content,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 12.sp,
              fontWeight: FontWeight.w300,
              height: 1.2,
              letterSpacing: -0.144,
              color: const Color(0xFF475569),
            ),
          ),
          if (bulletPoints.isNotEmpty) ...[
            SizedBox(height: 10.h),
            ...bulletPoints.map(
              (point) => Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 5.h),
                      child: Container(
                        width: 5.w,
                        height: 5.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC000),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                          letterSpacing: -0.144,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
