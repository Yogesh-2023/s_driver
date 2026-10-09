import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import 'controllers/notification_preferences_controller.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({Key? key}) : super(key: key);

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final NotificationPreferencesController _controller = Get.put(NotificationPreferencesController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(fontFamily: AppFonts.family, fontSize: 20.sp, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSwitchTile(
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: _controller.emailNotifications.value,
              onChanged: (val) {
                _controller.emailNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Receive push notifications on this device',
              value: _controller.pushNotifications.value,
              onChanged: (val) {
                _controller.pushNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'SMS Notifications',
              subtitle: 'Receive text messages for important updates',
              value: _controller.smsNotifications.value,
              onChanged: (val) {
                _controller.smsNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'Promotional Notifications',
              subtitle: 'Receive offers and promotional messages',
              value: _controller.promotionalNotifications.value,
              onChanged: (val) {
                _controller.promotionalNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'System Notifications',
              subtitle: 'Critical system updates (cannot be disabled)',
              value: _controller.systemNotifications.value,
              onChanged: null, // Disabled
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(fontFamily: AppFonts.family, fontSize: 16.sp, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontFamily: AppFonts.family, fontSize: 14.sp, fontWeight: FontWeight.w400, color: Colors.grey[600]!)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
