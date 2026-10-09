import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStepService {
  static const String _stepKey = 'current_onboarding_step';
  static const String _isProviderDriverKey = 'is_provider_driver';

  static const String stepSelfie = 'selfie';
  static const String stepProfile = 'profile';
  static const String stepVehicle = 'vehicle';
  static const String stepDocuments = 'documents';
  static const String stepPending = 'pending';
  static const String stepHome = 'home';

  static Future<void> saveStep(String step, {bool? isProviderDriver}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_stepKey, step);
      if (isProviderDriver != null) {
        await prefs.setBool(_isProviderDriverKey, isProviderDriver);
      }
      debugPrint('=== [OnboardingStepService] SAVED STEP: $step (isProvider: $isProviderDriver) ===');
    } catch (e) {
      debugPrint('=== [OnboardingStepService] ERROR SAVING STEP: $e ===');
    }
  }

  static Future<String?> getSavedStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getString(_stepKey);
      debugPrint('=== [OnboardingStepService] RETRIEVED STEP: $step ===');
      return step;
    } catch (e) {
      debugPrint('=== [OnboardingStepService] ERROR GETTING STEP: $e ===');
      return null;
    }
  }

  static Future<bool> isProviderDriver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isProviderDriverKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stepKey);
      await prefs.remove(_isProviderDriverKey);
      debugPrint('=== [OnboardingStepService] CLEARED STEP ===');
    } catch (_) {}
  }
}
