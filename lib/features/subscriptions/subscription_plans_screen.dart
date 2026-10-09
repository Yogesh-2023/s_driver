import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../notifications/notifications_screen.dart';
import 'controllers/driver_subscription_controller.dart';
import 'models/driver_subscription_models.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({
    super.key,
    this.showBackButton = false,
    this.onBack,
  });

  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  late final DriverSubscriptionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<DriverSubscriptionController>()
        ? Get.find<DriverSubscriptionController>()
        : Get.put(DriverSubscriptionController());
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
              if (_controller.isLoading.value && _controller.plans.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _controller.loadSubscriptions,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                  children: [
                    _buildActiveCard(),
                    SizedBox(height: 12.h),
                    _buildPendingCard(),
                    if (_controller.lastPurchase.value?.checkout != null) ...[
                      SizedBox(height: 12.h),
                      _buildCheckoutNotice(_controller.lastPurchase.value!),
                    ],
                    SizedBox(height: 14.h),
                    Text(
                      'Choose a plan',
                      style: AppFonts.h2.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    if (_controller.plans.isEmpty)
                      _buildEmptyPlans()
                    else
                      ..._controller.plans.map(_buildPlanCard),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = widget.showBackButton && Navigator.canPop(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10.h,
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
            InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                  return;
                }
                Navigator.pop(context);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Subscription Plans',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.h2.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Keep your driver account ready for trips',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Get.to(() => const NotificationsScreen()),
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                Icons.notifications_none_outlined,
                color: const Color(0xFF1E293B),
                size: 20.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard() {
    return Obx(() {
      final active = _controller.activeSubscription.value;
      final plan = active?.plan;
      if (active == null) {
        return _infoCard(
          icon: Icons.workspace_premium_outlined,
          title: 'No active subscription',
          subtitle: 'Buy a plan to unlock trip access after approval.',
          color: const Color(0xFFFFB020),
        );
      }

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF12251C),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC000),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: const Color(0xFF12251C),
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan?.name ?? 'Active Subscription',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.h2.copyWith(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _activeSubtitle(active),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                _activeMetric('Status', active.status),
                SizedBox(width: 10.w),
                _activeMetric('Trips', active.remainingTrips == null
                    ? 'Unlimited'
                    : active.remainingTrips.toString()),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPendingCard() {
    return Obx(() {
      final purchase = _controller.lastPurchase.value;
      final subscription = purchase?.subscription;
      if (subscription == null ||
          subscription.status.toUpperCase() != 'PENDING_PAYMENT') {
        return const SizedBox.shrink();
      }

      return _infoCard(
        icon: Icons.pending_actions_rounded,
        title: 'Payment pending',
        subtitle: 'Resume or refresh this payment before starting a new plan.',
        color: const Color(0xFF2563EB),
        trailing: TextButton(
          onPressed: () => _controller.fetchPaymentStatus(
            subscription.id,
            reconcile: true,
          ),
          child: const Text('Refresh'),
        ),
      );
    });
  }

  Widget _buildCheckoutNotice(DriverSubscriptionPurchase purchase) {
    final checkout = purchase.checkout!;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D6),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFFE58F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payments_outlined, color: const Color(0xFF8A5A00), size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checkout order created',
                  style: AppFonts.h2.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3D2A00),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Order ${checkout.orderId} is ready. Complete payment in Razorpay checkout, then the app will verify it automatically.',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    height: 1.35,
                    color: const Color(0xFF6B4E00),
                  ),
                ),
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _controller.isPurchasing.value ||
                            _controller.isVerifyingPayment.value
                        ? null
                        : _controller.resumeCheckout,
                    icon: Icon(Icons.open_in_new_rounded, size: 16.sp),
                    label: const Text('Open Razorpay'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3D2A00),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(DriverSubscriptionPlan plan) {
    final isActivePlan = _controller.activeSubscription.value?.planId == plan.id;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isActivePlan ? const Color(0xFFFFC000) : const Color(0xFFE8EEF5),
          width: isActivePlan ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5CC),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: const Color(0xFFB88400),
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.h2.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF172033),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      plan.description.isEmpty
                          ? '${plan.durationLabel} • ${plan.tripLabel}'
                          : plan.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        height: 1.35,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                plan.priceLabel,
                style: AppFonts.h2.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _chip(Icons.calendar_today_outlined, plan.durationLabel),
              _chip(Icons.route_outlined, plan.tripLabel),
              if (double.tryParse(plan.gstOrTax) != 0)
                _chip(Icons.receipt_long_outlined, 'Tax ${plan.gstOrTax}'),
            ],
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            height: 42.h,
            child: Obx(() {
              final isBusy = _controller.isPurchasing.value ||
                  _controller.isVerifyingPayment.value;
              return ElevatedButton(
                onPressed: isBusy || isActivePlan
                    ? null
                    : () {
                        debugPrint(
                          '[PLAN_DEBUG] Buy Plan clicked '
                          'planId=${plan.id} '
                          'planName=${plan.name} '
                          'price=${plan.price} '
                          'duration=${plan.durationValue} ${plan.durationType}',
                        );
                        _controller.purchasePlan(plan);
                      },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFFFC000),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: isBusy
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        _controller.isVerifyingPayment.value
                            ? 'Verifying...'
                            : (isActivePlan ? 'Current Plan' : 'Buy Plan'),
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: const Color(0xFF475569)),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeMetric(String title, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11.sp,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Widget? trailing,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.h2.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    height: 1.3,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildEmptyPlans() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 42.sp,
            color: const Color(0xFF94A3B8),
          ),
          SizedBox(height: 10.h),
          Text(
            'No plans available',
            style: AppFonts.h2.copyWith(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            'Please pull down to refresh or contact support if plans do not appear.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 12.sp,
              height: 1.35,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  String _activeSubtitle(DriverSubscription subscription) {
    final expiry = subscription.expiryDate;
    if (expiry == null || expiry.isEmpty) return 'Subscription is active';
    final date = DateTime.tryParse(expiry);
    if (date == null) return 'Valid subscription';
    return 'Valid till ${DateFormat('dd MMM yyyy').format(date.toLocal())}';
  }
}
