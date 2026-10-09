import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class CustomSelectionBottomSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final ValueChanged<String> onItemSelected;
  final double? width;
  final double? maxHeight;

  const CustomSelectionBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.onItemSelected,
    this.selectedItem,
    this.width,
    this.maxHeight,
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    required List<String> items,
    String? selectedItem,
    double? width,
    double? maxHeight,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => CustomSelectionBottomSheet(
        title: title,
        items: items,
        selectedItem: selectedItem,
        width: width,
        maxHeight: maxHeight,
        onItemSelected: (item) {
          Navigator.pop(context, item);
        },
      ),
    );
  }

  @override
  State<CustomSelectionBottomSheet> createState() =>
      _CustomSelectionBottomSheetState();
}

class _CustomSelectionBottomSheetState
    extends State<CustomSelectionBottomSheet> {
  late String _searchQuery;

  @override
  void initState() {
    super.initState();
    _searchQuery = '';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final defaultHeight = mediaQuery.size.height * 0.50;

    final filteredItems = widget.items
        .where(
          (item) => item.toLowerCase().contains(_searchQuery.trim().toLowerCase()),
        )
        .toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: widget.width ?? screenWidth,
        height: widget.maxHeight ?? defaultHeight,
        margin: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Header Bar
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFDF5), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28.r),
                ),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle Pill
                  Center(
                    child: Container(
                      width: 42.w,
                      height: 4.5.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // Title Row with Icon & Badge
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFFFFEF9E),
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 18.sp,
                                color: const Color(0xFFFFC000),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select ${widget.title}',
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${filteredItems.length} options available',
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 11.5.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),

                      // Close Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(7.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18.sp,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // Search Bar Input Box
                  Container(
                    height: 44.h,
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 13.5.sp,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: 'Search ${widget.title}...',
                              hintStyle: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 13.sp,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.only(top: 8.h),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchQuery = ''),
                            child: Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14.sp,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Item Cards
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search_off_rounded,
                              size: 42.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'No ${widget.title} found',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Try searching with a different keyword',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = widget.selectedItem == item;

                        return GestureDetector(
                          onTap: () => widget.onItemSelected(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(bottom: 8.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 13.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFFAE1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFFCC00)
                                    : const Color(0xFFF1F5F9),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: const Color(0xFFFFCC00)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                else
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 14.sp,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFF334155),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.all(2.r),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFCC00),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16.sp,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: const Color(0xFFCBD5E1),
                                    size: 20.sp,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
