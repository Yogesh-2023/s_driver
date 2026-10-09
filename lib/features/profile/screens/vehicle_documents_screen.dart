import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_fonts.dart';
import '../../../widgets/profile_app_bar.dart';
import '../../../widgets/status_badge.dart';
import '../../auth/models/driver_account_models.dart';
import 'kyc_document_viewer_screen.dart';

class _DocCardConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final List<String> matchingTypes;

  const _DocCardConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.matchingTypes,
  });
}

class VehicleDocumentsScreen extends StatelessWidget {
  final List<VehicleDocumentItem> vehicleDocuments;
  final String? overallStatus;

  const VehicleDocumentsScreen({
    super.key,
    required this.vehicleDocuments,
    this.overallStatus,
  });

  static const List<_DocCardConfig> _standardDocs = [
    _DocCardConfig(
      title: 'Registration Certificate',
      subtitle: 'Vehicle RC',
      icon: Icons.description_outlined,
      iconBg: Color(0xFFFFFBEA),
      iconColor: Color(0xFFFFB020),
      matchingTypes: ['RC', 'REGISTRATION_CERTIFICATE', 'VEHICLE_REGISTRATION'],
    ),
    _DocCardConfig(
      title: 'Vehicle Insurance',
      subtitle: 'Insurance Document',
      icon: Icons.shield_outlined,
      iconBg: Color(0xFFECFDF5),
      iconColor: Color(0xFF10B981),
      matchingTypes: ['INSURANCE', 'VEHICLE_INSURANCE'],
    ),
    _DocCardConfig(
      title: 'Vehicle Photo',
      subtitle: 'Uploaded Vehicle Image',
      icon: Icons.directions_car_outlined,
      iconBg: Color(0xFFEFF6FF),
      iconColor: Color(0xFF3B82F6),
      matchingTypes: [
        'VEHICLE_PHOTO',
        'VEHICLEPHOTO',
        'VEHICLE_PHOTOS',
        'VEHICLE_FRONT_PHOTO',
        'VEHICLE_IMAGE',
        'VEHICLE'
      ],
    ),
  ];

  VehicleDocumentItem? _findDoc(List<String> types) {
    for (final doc in vehicleDocuments) {
      final docTypeNorm = doc.documentType.replaceAll('_', '').toUpperCase();
      for (final target in types) {
        final targetNorm = target.replaceAll('_', '').toUpperCase();
        if (docTypeNorm == targetNorm) {
          return doc;
        }
      }
    }
    return null;
  }

  void _openDocumentViewer(BuildContext context, String title, String? imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycDocumentViewerScreen(
          title: title,
          documents: [
            KycDocImageItem(
              label: title,
              imageUrl: imageUrl,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Find documents matched by standard configs
    final usedDocs = <VehicleDocumentItem>{};
    final standardItems = <Widget>[];

    for (final config in _standardDocs) {
      final doc = _findDoc(config.matchingTypes);
      if (doc != null) {
        usedDocs.add(doc);
      }

      final status = doc != null ? doc.status : 'Not Provided';
      final imageUrl = doc?.imageUrl;

      standardItems.add(
        _buildDocumentCard(
          context: context,
          icon: config.icon,
          iconBg: config.iconBg,
          iconColor: config.iconColor,
          title: config.title,
          subtitle: config.subtitle,
          status: status,
          onViewTap: () => _openDocumentViewer(context, config.title, imageUrl),
        ),
      );
    }

    // Additional documents returned by backend (e.g. PUC, Fitness, Permit)
    final additionalItems = <Widget>[];
    for (final doc in vehicleDocuments) {
      if (!usedDocs.contains(doc)) {
        final formattedType = doc.documentType.replaceAll('_', ' ').trim();
        final title = '$formattedType Document';
        additionalItems.add(
          _buildDocumentCard(
            context: context,
            icon: Icons.insert_drive_file_outlined,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF8B5CF6),
            title: title,
            subtitle: 'Uploaded Document',
            status: doc.status,
            onViewTap: () => _openDocumentViewer(context, title, doc.imageUrl),
          ),
        );
      }
    }

    final computedStatus = overallStatus ??
        (vehicleDocuments.isNotEmpty &&
                vehicleDocuments.every((d) =>
                    d.status.toUpperCase() == 'VERIFIED' ||
                    d.status.toUpperCase() == 'APPROVED')
            ? 'APPROVED'
            : 'VERIFIED');

    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      appBar: const ProfileAppBar(title: 'Vehicle Documents'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Vehicle Documents Status Banner Card
              _buildOverallStatusCard(computedStatus),

                    SizedBox(height: 18.h),

                    Text(
                      'VEHICLE DOCUMENTS',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Standard Documents (RC, Insurance, Vehicle Photo)
                    for (int i = 0; i < standardItems.length; i++) ...[
                      if (i > 0) SizedBox(height: 14.h),
                      standardItems[i],
                    ],

                    // Additional Documents (if any)
                    if (additionalItems.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      Text(
                        'ADDITIONAL DOCUMENTS',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      for (int i = 0; i < additionalItems.length; i++) ...[
                        if (i > 0) SizedBox(height: 14.h),
                        additionalItems[i],
                      ],
                    ],

                    SizedBox(height: 24.h),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOverallStatusCard(String status) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Overall Vehicle Status',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          StatusBadge(status: status),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onViewTap,
  }) {
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
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 22.sp, color: iconColor),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 4.h),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: [
                    StatusBadge(status: status),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.5.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          InkWell(
            onTap: onViewTap,
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEA),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFFFEF9E), width: 1.w),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16.sp,
                    color: const Color(0xFFD97706),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'View',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
