import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_colors.dart';
import '../../auth/models/driver_account_models.dart';

import '../../../widgets/profile_app_bar.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final VehicleDetailsInfo? vehicleDetails;

  const VehicleDetailsScreen({super.key, this.vehicleDetails});

  String _getValue(String? value) {
    if (value == null || value.trim().isEmpty || value.trim().toLowerCase() == 'null') {
      return 'Not Available';
    }
    return value.trim();
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty || rawDate.trim().toLowerCase() == 'null') {
      return 'Not Available';
    }
    try {
      final dt = DateTime.parse(rawDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      return '$day $month ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  Widget _buildStatusBadge(String status, {String? customPrefix}) {
    final s = status.toUpperCase().trim();
    Color bgColor;
    Color textColor;
    String displayStatus = status.replaceAll('_', ' ').trim();

    if (s == 'VERIFIED' || s == 'APPROVED' || s == 'ACTIVE' || s == 'AVAILABLE' || s == 'YES') {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
      if (customPrefix != null) {
        displayStatus = '$customPrefix $displayStatus';
      } else if (s == 'APPROVED' || s == 'ACTIVE') {
        displayStatus = '✓ $displayStatus';
      }
    } else if (s == 'PENDING' || s == 'PROFILE_PENDING' || s == 'UNDER_REVIEW' || s.contains('REVIEW')) {
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
    } else if (s == 'REJECTED' || s == 'FAILED' || s == 'INACTIVE' || s == 'UNAVAILABLE' || s == 'NO') {
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
        displayStatus,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      appBar: const ProfileAppBar(title: 'Vehicle Details'),
      body: vehicleDetails == null
          ? _buildEmptyState()
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Vehicle Card
                    _buildVehicleHeaderCard(),

                    SizedBox(height: 16.h),

                    // Section: Vehicle Specifications
                    _buildSectionHeader('SPECIFICATIONS'),
                    SizedBox(height: 8.h),
                    _buildCard([
                      _buildInfoRow('Make / Brand', _getValue(vehicleDetails!.make)),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildInfoRow('Model', _getValue(vehicleDetails!.model)),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildInfoRow('Registration Number', _getValue(vehicleDetails!.registrationNumber)),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        'Manufacturer Year',
                        vehicleDetails!.year != null ? vehicleDetails!.year.toString() : 'Not Available',
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        'Category',
                        _getValue(vehicleDetails!.category.name),
                      ),
                    ]),

                    SizedBox(height: 16.h),

                    // Status Information: Verification Status ABOVE Availability
                    _buildSectionHeader('STATUS DETAILS'),
                    SizedBox(height: 8.h),
                    _buildCard([
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Verification Status',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _buildStatusBadge(
                            _getValue(vehicleDetails!.verificationStatus),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Availability',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _buildStatusBadge(
                            vehicleDetails!.isAvailable ? 'Available' : 'Unavailable',
                            customPrefix: vehicleDetails!.isAvailable ? '✓' : null,
                          ),
                        ],
                      ),
                    ]),

                    SizedBox(height: 16.h),

                    // Section: Assignment Information Card
                    _buildSectionHeader('ASSIGNMENT INFORMATION'),
                    SizedBox(height: 8.h),
                    _buildCard([
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Assignment Status',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _buildStatusBadge(
                            vehicleDetails!.assignment.isActive ? 'Active' : 'Inactive',
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        'Assigned On',
                        _formatDate(vehicleDetails!.assignment.assignedAt),
                      ),
                    ]),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVehicleHeaderCard() {
    final makeStr = _getValue(vehicleDetails!.make);
    final modelStr = _getValue(vehicleDetails!.model);

    String vehicleTitle = '';
    if (makeStr != 'Not Available' && modelStr != 'Not Available') {
      vehicleTitle = '$makeStr $modelStr';
    } else if (makeStr != 'Not Available') {
      vehicleTitle = makeStr;
    } else if (modelStr != 'Not Available') {
      vehicleTitle = modelStr;
    } else {
      vehicleTitle = 'Vehicle Details';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFEF9E), width: 1.w),
            ),
            child: Icon(
              Icons.directions_car_rounded,
              size: 26.sp,
              color: const Color(0xFFFFB020),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vehicleTitle,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  _getValue(vehicleDetails!.registrationNumber),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _buildStatusBadge(_getValue(vehicleDetails!.status)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 56.sp,
                color: const Color(0xFFFFB020),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Vehicle Assigned',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You currently do not have any vehicle assigned to your driver account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF64748B),
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
            color: Colors.black.withValues(alpha: 0.02),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
