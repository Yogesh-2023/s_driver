import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import 'controllers/notification_controller.dart';
import '../dashboard/driver_home_screen.dart';
import '../dashboard/navigate_to_pickup_screen.dart';
import '../auth/repositories/history_order_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationController _controller = Get.put(NotificationController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.refreshList();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.fetchNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 64.w,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16.h),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    "You don't have any notifications at the moment. We'll let you know when something arrives.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.refreshList,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                _controller.notifications.length +
                (_controller.hasMore.value ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == _controller.notifications.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final item = _controller.notifications[index];
              final isRead = item['isRead'] ?? false;

              return Dismissible(
                key: Key(item['id'] ?? item['_id'] ?? index.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  _controller.deleteNotification(
                    item['id'] ?? item['_id'],
                    index,
                  );
                },
                child: InkWell(
                  onTap: () {
                    final notificationId = item['id'] ?? item['_id'];
                    if (notificationId != null) {
                      _controller.markAsRead(notificationId.toString(), index);
                    }
                    final data = item['metadata'] is Map
                        ? Map<String, dynamic>.from(item['metadata'] as Map)
                        : item['data'] is Map
                        ? Map<String, dynamic>.from(item['data'] as Map)
                        : null;
                    if (data != null) {
                      final type = (data['type'] ?? data['event'] ?? data['module'])?.toString().toUpperCase();
                      final bookingId = (data['rideId'] ?? data['bookingId'] ?? data['tripId'])?.toString();
                      if (type == 'RIDE_REQUEST' || type == 'DISPATCH_OFFER' || type == 'GOODS_REQUEST') {
                        Get.offAll(() => const DriverHomeScreen());
                      } else if (bookingId != null && bookingId.isNotEmpty) {
                        if (type == 'DRIVER_ARRIVED' || type == 'RIDE_STARTED' || type == 'TRIP_STARTED') {
                          Get.to(() => NavigateToPickupScreen(requestData: {'bookingId': bookingId, ...data}));
                        } else if (type == 'RIDE_COMPLETED' || type == 'RIDE_CANCELLED') {
                          Get.to(() => const BookingsHistoryScreen());
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    color: isRead
                        ? Colors.white
                        : AppColors.primary.withValues(alpha: 0.05),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isRead
                              ? Colors.grey[200]
                              : AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.notifications,
                            color: isRead ? Colors.grey : AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isRead ? Colors.black87 : Colors.black,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                item['body'] ?? item['message'] ?? '',
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[600]!,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                _formatDate(
                                  item['createdAt'] ?? item['created_at'],
                                ),
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[400]!,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12.h,
        bottom: 12.h,
        left: 16.w,
        right: 16.w,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAE1),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFEF9E), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
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
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          Obx(() {
            if (_controller.unreadCount.value > 0) {
              return TextButton(
                onPressed: _controller.markAllAsRead,
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFCC00),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }
}
