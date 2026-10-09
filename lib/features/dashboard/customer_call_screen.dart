import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_fonts.dart';
import '../../widgets/custom_snackbar.dart';
import 'controllers/active_booking_controller.dart';

enum CustomerCallStatus { ready, calling, ended, failed }

class CustomerCallScreen extends StatefulWidget {
  const CustomerCallScreen({super.key, required this.requestData});

  final Map<String, dynamic>? requestData;

  @override
  State<CustomerCallScreen> createState() => _CustomerCallScreenState();
}

class _CustomerCallScreenState extends State<CustomerCallScreen>
    with WidgetsBindingObserver {
  final ActiveBookingController _booking = Get.find<ActiveBookingController>();
  CustomerCallStatus _status = CustomerCallStatus.ready;
  bool _openedDialer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _booking.updateBooking(widget.requestData);
  }

  @override
  void didUpdateWidget(covariant CustomerCallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.requestData, widget.requestData)) {
      _booking.updateBooking(widget.requestData);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_openedDialer && state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _openedDialer = false;
        _status = CustomerCallStatus.ended;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String get _statusText => switch (_status) {
    CustomerCallStatus.ready => 'Ready to call',
    CustomerCallStatus.calling => 'Calling',
    CustomerCallStatus.ended => 'Call ended',
    CustomerCallStatus.failed => 'Unable to start call',
  };

  Future<void> _startCall() async {
    final phone = _booking.customer.value?.phone;
    if (phone == null) {
      setState(() => _status = CustomerCallStatus.failed);
      CustomSnackbar.showError(
        message: 'Customer phone number is unavailable.',
      );
      return;
    }
    setState(() => _status = CustomerCallStatus.calling);
    final uri = Uri(scheme: 'tel', path: phone);
    final canCall = await canLaunchUrl(uri);
    if (!mounted) return;
    if (!canCall) {
      setState(() => _status = CustomerCallStatus.failed);
      CustomSnackbar.showError(
        message: 'Calling is not supported on this device.',
      );
      return;
    }
    _openedDialer = true;
    final launched = await launchUrl(uri);
    if (!mounted) return;
    if (!launched) {
      _openedDialer = false;
      setState(() => _status = CustomerCallStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A2B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Customer call'),
      ),
      body: SafeArea(
        child: Obx(() {
          final customer = _booking.customer.value;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(customer?.bookingId),
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: EdgeInsets.all(5.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                      width: 2,
                    ),
                  ),
                  child: BookingCustomerAvatar(customer: customer, size: 112.r),
                ),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Text(
                    customer?.name ?? 'Customer',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.h2.copyWith(
                      color: Colors.white,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _statusText,
                    key: ValueKey(_status),
                    style: AppFonts.body.copyWith(
                      color: const Color(0xFFB7C7D6),
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                Semantics(
                  button: true,
                  label: _status == CustomerCallStatus.calling
                      ? 'Calling customer'
                      : 'Call customer',
                  child: FilledButton(
                    onPressed: _status == CustomerCallStatus.calling
                        ? null
                        : _startCall,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      disabledBackgroundColor: const Color(0xFF166534),
                      shape: const CircleBorder(),
                      padding: EdgeInsets.all(22.r),
                    ),
                    child: _status == CustomerCallStatus.calling
                        ? SizedBox.square(
                            dimension: 26.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 28.sp,
                          ),
                  ),
                ),
                SizedBox(height: 36.h),
              ],
            ),
          );
        }),
      ),
    );
  }
}
