import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_fonts.dart';
import '../../../widgets/profile_app_bar.dart';

class KycDocImageItem {
  final String label;
  final String? imageUrl;

  KycDocImageItem({required this.label, this.imageUrl});
}

class KycDocumentViewerScreen extends StatefulWidget {
  final String title;
  final List<KycDocImageItem> documents;

  const KycDocumentViewerScreen({
    super.key,
    required this.title,
    required this.documents,
  });

  @override
  State<KycDocumentViewerScreen> createState() => _KycDocumentViewerScreenState();
}

class _KycDocumentViewerScreenState extends State<KycDocumentViewerScreen> {
  final Map<int, int> _retryKeys = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      appBar: ProfileAppBar(title: widget.title),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < widget.documents.length; i++) ...[
                if (i > 0) SizedBox(height: 20.h),
                _buildDocumentCard(context, widget.documents[i], i),
              ],
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildDocumentCard(BuildContext context, KycDocImageItem docItem, int index) {
    final hasValidUrl = docItem.imageUrl != null &&
        docItem.imageUrl!.trim().isNotEmpty &&
        docItem.imageUrl != 'null';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          docItem.label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: hasValidUrl
                ? _buildNetworkImage(docItem.imageUrl!.trim(), index)
                : _buildNotProvidedWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImage(String url, int index) {
    final retryKey = _retryKeys[index] ?? 0;

    return Column(
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: 260.h, minHeight: 180.h),
          width: double.infinity,
          color: const Color(0xFFF8FAFC),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 3.0,
            child: Image.network(
              '$url${retryKey > 0 ? '?retry=$retryKey' : ''}',
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 180.h,
                  color: const Color(0xFFF8FAFC),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFFFB020),
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Loading document...',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: EdgeInsets.all(24.w),
                  color: const Color(0xFFFFF1F2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        size: 40.sp,
                        color: const Color(0xFFF43F5E),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Unable to load document',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF9F1239),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _retryKeys[index] = (retryKey + 1);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotProvidedWidget() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 16.w),
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54.w,
              height: 54.w,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 26.sp,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Not Provided',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF475569),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'This document image is not available',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 12.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
