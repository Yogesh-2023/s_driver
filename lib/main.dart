import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'di/dependency_injection.dart';
import 'features/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'core/network/network_controller.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Platform.isAndroid) {
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      // Use Hybrid Composition to fix "Image is already closed" crash on some Android 10 devices
      mapsImplementation.useAndroidViewSurface = true;
    }
  }

  await initDependencies();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const DriverApp());

  // Push setup must never hold the first Flutter frame hostage. Firebase and
  // Google Play services can be unavailable or slow on some devices, but the
  // rest of the app should still open normally.
  // We wait for the first frame so the Activity context is fully attached,
  // preventing NullPointerException in flutter_local_notifications.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializePushNotifications());
  });
}

Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Push notification initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: GetMaterialApp(
            title: 'Doblego Driver',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            initialBinding: NetworkBinding(),
            home: SplashScreen(),
            builder: (context, widget) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: widget ?? const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }
}
