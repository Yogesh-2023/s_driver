// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/api/api_constants.dart';
import '../../../services/socket/socket_service.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/security/secure_session_store.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_models_and_services.dart';

class AuthController extends GetxController {
  final AuthRepository authRepository;

  AuthController({required this.authRepository});

  // State observable variables
  final RxBool isLoading = false.obs;
  final RxBool isProfileCompleted = false.obs;
  final RxBool isProfileImageMissing = true.obs;
  final RxString verificationStatus = ''.obs;
  final RxString onboardingStatus = ''.obs;
  final RxBool isOnline = false.obs;
  final Rxn<UserProfile> userProfile = Rxn<UserProfile>();

  static String _normalizeApprovalStatus(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
  }

  static bool _isApprovedStatus(String value) {
    final normalized = _normalizeApprovalStatus(value);
    return normalized == 'APPROVED' ||
        normalized == 'VERIFIED' ||
        normalized == 'KYCAPPROVED' ||
        normalized == 'KYCVERIFIED';
  }

  bool get isRideAccessEnabled =>
      _isApprovedStatus(verificationStatus.value) ||
      _isApprovedStatus(onboardingStatus.value);

  void enforceKycRideAccess() {
    if (!isRideAccessEnabled && isOnline.value) {
      isOnline.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadCachedProfile();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedJson = prefs.getString('cached_driver_profile');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(cachedJson);
        final profile = UserProfile.fromJson(data);
        userProfile.value = profile;
        if (profile.avatar.trim().isNotEmpty) {
          isProfileImageMissing.value = false;
        }
        if (data['verificationStatus'] != null) {
          verificationStatus.value = data['verificationStatus'].toString();
        }
        if (data['onboardingStatus'] != null) {
          onboardingStatus.value = data['onboardingStatus'].toString();
        }
        enforceKycRideAccess();
        print('[AUTH][CACHE] Loaded instant cached profile for: ${profile.name}');
      } else {
        final name = prefs.getString('driver_name') ?? prefs.getString('driver_firstname') ?? '';
        final phone = prefs.getString('user_phone') ?? '';
        final avatar = prefs.getString('driver_avatar') ?? '';
        if (name.isNotEmpty) {
          userProfile.value = UserProfile(
            name: name,
            email: '',
            phone: phone,
            firstname: prefs.getString('driver_firstname') ?? name.split(' ').first,
            lastname: '',
            requirement: 'PERSONAL',
            avatar: avatar,
          );
          if (avatar.isNotEmpty) isProfileImageMissing.value = false;
          enforceKycRideAccess();
          print('[AUTH][CACHE] Loaded fallback cached profile for: $name');
        }
      }
    } catch (e) {
      print('[AUTH][CACHE] Error loading cached driver profile: $e');
    }
  }

  Future<void> _saveCachedProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = profile.toJson();
      jsonMap['verificationStatus'] = verificationStatus.value;
      jsonMap['onboardingStatus'] = onboardingStatus.value;
      await prefs.setString('cached_driver_profile', jsonEncode(jsonMap));
      await prefs.setString('driver_name', profile.name);
      await prefs.setString('driver_firstname', profile.firstname);
      await prefs.setString('user_phone', profile.phone);
      await prefs.setString('driver_avatar', profile.avatar);
      print('[AUTH][CACHE] Profile cached locally for: ${profile.name}');
    } catch (e) {
      print('[AUTH][CACHE] Error saving cached driver profile: $e');
    }
  }

  Future<void> clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_driver_profile');
      await prefs.remove('driver_name');
      await prefs.remove('driver_firstname');
      await prefs.remove('user_phone');
      await prefs.remove('driver_avatar');
      await prefs.remove('user_id');
      userProfile.value = null;
      isOnline.value = false;
      print('[AUTH][CACHE] Cleared cached driver profile');
    } catch (e) {
      print('[AUTH][CACHE] Error clearing cached driver profile: $e');
    }
  }

  // Dashboard state observables
  final RxBool isDashboardLoading = false.obs;
  final RxBool isDashboardError = false.obs;
  final RxString dashboardErrorMessage = ''.obs;
  final Rxn<Map<String, dynamic>> dashboardData = Rxn<Map<String, dynamic>>();

  Future<void> fetchDashboardData({bool isRefresh = false}) async {
    try {
      if (dashboardData.value == null || isRefresh) {
        isDashboardLoading.value = true;
      }
      isDashboardError.value = false;
      dashboardErrorMessage.value = '';

      final dashResponse = await authRepository.getDashboard();
      if (dashResponse.isOk && dashResponse.body != null) {
        final body = dashResponse.body;
        if (body is Map) {
          var dashRaw = body['data'] ?? body;
          if (dashRaw is Map) {
            dashboardData.value = Map<String, dynamic>.from(dashRaw);
            isDashboardError.value = false;
            return;
          }
        }
      }

      if (dashboardData.value == null) {
        isDashboardError.value = true;
        dashboardErrorMessage.value =
            dashResponse.statusText ?? 'Failed to load dashboard data';
      }
    } catch (e) {
      if (dashboardData.value == null) {
        isDashboardError.value = true;
        dashboardErrorMessage.value = e.toString();
      }
    } finally {
      isDashboardLoading.value = false;
    }
  }

  // Fetch and check profile completion status
  Future<bool> checkProfileStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionCookie = await SecureSessionStore.readCookie();
      if (sessionCookie == null || sessionCookie.isEmpty) {
        print("=== DRIVER GET PROFILE SKIPPED ===");
        print("Reason: No session cookie found");
        return false;
      }

      print("=== DRIVER GET PROFILE REQUEST ===");
      print("URI: /driver/details/profile");

      Response response = await authRepository.getProfile();
      Response dashResponse = await authRepository.getDashboard();
      print("=== DRIVER GET PROFILE RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Status Text: ${response.statusText}");

      Map<String, dynamic> dashboard = {};
      if (dashResponse.isOk && dashResponse.body != null) {
        var dashRaw = dashResponse.body['data'] ?? dashResponse.body;
        if (dashRaw is Map) {
          dashboard = Map<String, dynamic>.from(dashRaw);
          dashboardData.value = dashboard;
          isDashboardError.value = false;
        }
      } else if (dashboardData.value == null) {
        isDashboardError.value = true;
        dashboardErrorMessage.value =
            dashResponse.statusText ?? 'Failed to load dashboard';
      }

      if (response.isOk) {
        var rawData =
            response.body['data'] ?? response.body['driver'] ?? response.body;
        var data = rawData is Map && rawData['personalInfo'] is Map
            ? rawData['personalInfo']
            : rawData;
        if (dashboard.isEmpty && rawData is Map && rawData['dashboard'] is Map) {
          dashboard = Map<String, dynamic>.from(rawData['dashboard']);
        }
        final rating = dashboard['rating'] is Map
            ? dashboard['rating']
            : <String, dynamic>{};
        final wallet = dashboard['wallet'] is Map
            ? dashboard['wallet']
            : <String, dynamic>{};
        final earnings = dashboard['earnings'] is Map
            ? dashboard['earnings']
            : <String, dynamic>{};
        print("Parsed Profile Data: $data");
        print("Parsed Dashboard Data: $dashboard");
        if (data != null) {
          String? userId =
              _safeGet(data, 'userId') ??
              _safeGet(data, 'driverId') ??
              _safeGet(data, 'id');
          String? vStatus = _safeGet(data, 'verificationStatus') ?? _safeGet(data, 'kycStatus');
          if (vStatus != null) {
            verificationStatus.value = vStatus;
          }
          String? oStatus = _safeGet(data, 'onboardingStatus');
          if (oStatus != null) {
            onboardingStatus.value = oStatus;
          }
          enforceKycRideAccess();
          if (userId != null) {
            await prefs.setString('user_id', userId);
            await SocketService.to.reconnectFromStoredSession();
          }

          final userMap = data is Map
              ? (data['driver'] is Map
                  ? data['driver'] as Map
                  : (data['user'] is Map
                      ? data['user'] as Map
                      : (data['profile'] is Map
                          ? data['profile'] as Map
                          : null)))
              : null;

          String? rawName =
              _safeGet(userMap, 'displayName') ??
              _safeGet(userMap, 'name') ??
              _safeGet(data, 'displayName') ??
              _safeGet(data, 'name') ??
              _safeGet(data, 'fullName') ??
              _safeGet(data, 'fullname') ??
              _safeGet(data, 'driverName');

          String? rawFirst =
              _safeGet(userMap, 'firstName') ??
              _safeGet(userMap, 'firstname') ??
              _safeGet(data, 'firstName') ??
              _safeGet(data, 'firstname');

          String? rawLast =
              _safeGet(userMap, 'lastName') ??
              _safeGet(userMap, 'lastname') ??
              _safeGet(data, 'lastName') ??
              _safeGet(data, 'lastname');

          String? firstNameToUse = rawFirst;
          if (firstNameToUse == null || firstNameToUse.trim().isEmpty) {
            if (rawName != null && rawName.trim().isNotEmpty) {
              firstNameToUse = rawName.trim().split(' ').first;
            } else {
              firstNameToUse = 'Driver';
            }
          }

          String name = (rawName != null && rawName.trim().isNotEmpty)
              ? rawName.trim()
              : '$firstNameToUse ${rawLast ?? ''}'.trim();
          if (name.isEmpty) name = firstNameToUse;

          await prefs.setString('driver_name', name);
          await prefs.setString('driver_firstname', firstNameToUse);

          print("=== PROFILE API DEBUG ===");
          final safeDataToPrint = Map.from(data as Map);
          safeDataToPrint.remove('avatar');
          safeDataToPrint.remove('profileImage');
          safeDataToPrint.remove('profileImageUrl');

          final profileImage =
              _safeGet(data, 'profileImageUrl') ??
              _safeGet(data, 'avatar') ??
              _safeGet(data, 'profileImage') ??
              _safeGet(userMap, 'avatar') ??
              _safeGet(userMap, 'profileImageUrl') ??
              '';
          isProfileImageMissing.value = profileImage.trim().isEmpty;

          final ratingAverage = _safeDouble(data, 'averageRating') != 0
              ? _safeDouble(data, 'averageRating')
              : (_safeDouble(rating, 'average') != 0
                  ? _safeDouble(rating, 'average')
                  : _safeDouble(data, 'rating'));

          final ratingCount = rating is Map && rating.containsKey('count')
              ? _safeInt(rating, 'count')
              : _safeInt(data, 'totalReviews');

          final totalTrips = _safeInt(data, 'totalTrips');
          final acceptedTrips = _safeInt(data, 'acceptedTrips');
          final dashboardAcceptanceRate = _safeDouble(
            dashboard,
            'acceptanceRate',
          );
          final acceptanceRate = dashboardAcceptanceRate > 0
              ? dashboardAcceptanceRate
              : (totalTrips > 0 ? (acceptedTrips / totalTrips) * 100 : 0.0);

          String savedPhone = prefs.getString('user_phone') ?? '';
          String apiPhone =
              _safeGet(userMap, 'phone') ??
              _safeGet(data, 'phone') ??
              _safeGet(dashboard, 'phone') ??
              _safeGet(data, 'alternatePhone') ??
              '';

          String finalPhone = apiPhone.trim().isNotEmpty ? apiPhone.trim() : savedPhone;
          if (finalPhone.isNotEmpty) {
            await prefs.setString('user_phone', finalPhone);
          }

          String apiEmail =
              _safeGet(userMap, 'email') ??
              _safeGet(data, 'email') ??
              '';

          String addr1 = _safeGet(data, 'addressLine1') ?? '';
          String addr2 = _safeGet(data, 'addressLine2') ?? '';
          String city = _safeGet(data, 'city') ?? '';
          String state = _safeGet(data, 'state') ?? '';
          String pcode = _safeGet(data, 'postalCode') ?? '';
          List<String> parts = [addr1, addr2, city, state, pcode]
              .where((s) => s.trim().isNotEmpty)
              .toList();
          String address = parts.isNotEmpty
              ? parts.join(', ')
              : (_safeGet(data, 'address') ?? '');

          userProfile.value = UserProfile(
            name: name,
            email: apiEmail,
            phone: finalPhone,
            firstname: firstNameToUse,
            lastname: rawLast ?? '',
            requirement: _safeGet(data, 'requirement') ?? 'PERSONAL',
            avatar: profileImage,
            address: address,
            ratingAverage: ratingAverage,
            ratingCount: ratingCount,
            walletBalance: _safeDouble(wallet, 'balance'),
            walletBlockedBalance: _safeDouble(wallet, 'blockedBalance'),
            walletPendingBalance: _safeDouble(wallet, 'pendingBalance'),
            walletWithdrawableBalance: _safeDouble(
              wallet,
              'withdrawableBalance',
            ),
            earningsToday: _safeDouble(dashboard, 'todayEarnings') != 0
                ? _safeDouble(dashboard, 'todayEarnings')
                : _safeDouble(earnings, 'today'),
            earningsMonthly: _safeDouble(earnings, 'monthly'),
            earningsYearly: _safeDouble(earnings, 'yearly'),
            earningsTotal: _safeDouble(earnings, 'total') != 0
                ? _safeDouble(earnings, 'total')
                : _safeDouble(data, 'totalEarnings'),
            totalTrips: totalTrips,
            acceptedTrips: acceptedTrips,
            hoursOnline: _safeDouble(dashboard, 'hoursOnline') != 0
                ? _safeDouble(dashboard, 'hoursOnline')
                : _safeDouble(data, 'totalOnlineHours'),
            acceptanceRate: acceptanceRate.clamp(0, 100).toDouble(),
            recentTrips: _safeGetList(dashboard, 'recentTrips'),
            todayTrips: _safeInt(dashboard, 'todayTrips'),
            todayDistanceMeters: _safeDouble(dashboard, 'todayDistanceMeters'),
            todayOnlineSeconds: _safeInt(dashboard, 'todayOnlineSeconds'),
            todayEarnings: _safeDouble(dashboard, 'todayEarnings'),
            incentives: _safeGetList(dashboard, 'incentives'),
            assignedVehicles: () {
              if (dashboard['assignedVehicle'] != null &&
                  dashboard['assignedVehicle'] is Map &&
                  (dashboard['assignedVehicle'] as Map).isNotEmpty) {
                return [dashboard['assignedVehicle']];
              }
              final dashList = _safeGetList(dashboard, 'assignedVehicles');
              if (dashList.isNotEmpty) return dashList;
              if (data['assignedVehicle'] != null &&
                  data['assignedVehicle'] is Map &&
                  (data['assignedVehicle'] as Map).isNotEmpty) {
                return [data['assignedVehicle']];
              }
              if (rawData['assignedVehicle'] != null &&
                  rawData['assignedVehicle'] is Map &&
                  (rawData['assignedVehicle'] as Map).isNotEmpty) {
                return [rawData['assignedVehicle']];
              }
              final vehicleAssignments =
                  _safeGetList(rawData, 'vehicleAssignments').isNotEmpty
                      ? _safeGetList(rawData, 'vehicleAssignments')
                      : _safeGetList(data, 'vehicleAssignments');
              if (vehicleAssignments.isNotEmpty) {
                final firstAssigned = vehicleAssignments.first;
                final firstVehicle = firstAssigned is Map
                    ? (firstAssigned['vehicle'] ?? firstAssigned)
                    : null;
                if (firstVehicle != null &&
                    firstVehicle is Map &&
                    firstVehicle.isNotEmpty) {
                  return [firstVehicle];
                }
              }
              return _safeGetList(data, 'assignedVehicles');
            }(),
          );

          print("=== DRIVER PROFILE UI DATA ===");
          print("name: ${userProfile.value?.name}");
          print("email: ${userProfile.value?.email}");
          print("phone: ${userProfile.value?.phone}");
          print("firstname: ${userProfile.value?.firstname}");
          print("lastname: ${userProfile.value?.lastname}");
          print("avatar length: ${userProfile.value?.avatar.length}");
          print("address: ${userProfile.value?.address}");
          print("ratingAverage: ${userProfile.value?.ratingAverage}");
          print("ratingCount: ${userProfile.value?.ratingCount}");
          print("walletBalance: ${userProfile.value?.walletBalance}");
          print(
            "walletBlockedBalance: ${userProfile.value?.walletBlockedBalance}",
          );
          print(
            "walletPendingBalance: ${userProfile.value?.walletPendingBalance}",
          );
          print(
            "walletWithdrawableBalance: ${userProfile.value?.walletWithdrawableBalance}",
          );
          print("earningsToday: ${userProfile.value?.earningsToday}");
          print("earningsMonthly: ${userProfile.value?.earningsMonthly}");
          print("earningsYearly: ${userProfile.value?.earningsYearly}");
          print("earningsTotal: ${userProfile.value?.earningsTotal}");
          print("totalTrips: ${userProfile.value?.totalTrips}");
          print("acceptedTrips: ${userProfile.value?.acceptedTrips}");
          print("acceptanceRate: ${userProfile.value?.acceptanceRate}");
          print("recentTrips: ${userProfile.value?.recentTrips}");
          print("assignedVehicles: ${userProfile.value?.assignedVehicles}");

          if (userProfile.value != null) {
            await _saveCachedProfile(userProfile.value!);
          }

          isProfileCompleted.value = true;
          await prefs.setBool('is_profile_completed', true);
          return true;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print("=== DRIVER GET PROFILE UNAUTHORIZED -> CLEARING SESSION ===");
        await SecureSessionStore.clear();
        await clearCachedProfile();
        await prefs.remove('user_id');
      }
    } catch (e) {
      print("=== PROFILE STATUS CHECK ERROR ===");
      print(e.toString());
    }
    isProfileCompleted.value = false;
    isProfileImageMissing.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_profile_completed', false);
    return false;
  }

  /// Debug method invoked when driver profile avatar or header is touched
  Future<void> debugFetchAndPrintProfile() async {
    final profileUrl = '${ApiConstants.baseUrl}${ApiConstants.driverProfile}';
    print('\n=====================================================');
    print('🚀 [DEBUG PROFILE TOUCH] DRIVER PROFILE TAP DETECTED');
    print('URL: $profileUrl');
    print('Method: GET');
    print('-----------------------------------------------------');
    try {
      Response response = await authRepository.getProfile();
      print('Status Code: ${response.statusCode}');
      print('Status Text: ${response.statusText}');
      print('Headers: ${response.headers}');
      print('-----------------------------------------------------');
      print('Response Body:');
      print(response.body);
      print('=====================================================\n');
      await checkProfileStatus();
    } catch (e) {
      print('Error fetching profile in debug mode: $e');
      print('=====================================================\n');
    }
  }

  // Helper method to safely access keys from dynamic body
  String? _safeGet(dynamic body, String key) {
    if (body is Map) {
      return body[key]?.toString();
    }
    return null;
  }

  dynamic _extractDriverProfile(dynamic body) {
    if (body is! Map) return null;
    final data = body['data'];
    if (data is Map) {
      return data['driverProfile'] ??
          data['driver'] ??
          data['profile'] ??
          data['personalInfo'] ??
          data;
    }
    return body['driverProfile'] ??
        body['driver'] ??
        body['profile'] ??
        body['personalInfo'];
  }

  bool _hasProfileImage(dynamic profile) {
    final image =
        _safeGet(profile, 'profileImage') ??
        _safeGet(profile, 'profilePhoto') ??
        _safeGet(profile, 'avatar');
    return image != null && image.trim().isNotEmpty && image != 'null';
  }

  double _safeDouble(dynamic body, String key) {
    if (body is! Map) return 0;
    final value = body[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _safeInt(dynamic body, String key) {
    if (body is! Map) return 0;
    final value = body[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<dynamic> _safeGetList(dynamic body, String key) {
    if (body is! Map || body[key] is! List) return const [];
    return List<dynamic>.from(body[key]);
  }

  String _apiMessage(dynamic body, String fallback) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        final issues = error['issues'];
        if (issues is List && issues.isNotEmpty) {
          final issue = issues.first;
          if (issue is Map) {
            final message = issue['message']?.toString().trim();
            if (message != null && message.isNotEmpty) return message;
          }
        }
        final errorMessage = error['message']?.toString().trim();
        if (errorMessage != null && errorMessage.isNotEmpty) {
          return errorMessage;
        }
      } else if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }

      final message = body['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }

  Future<String?> _saveSessionCookie(Response response) async {
    final setCookie =
        response.headers?['set-cookie'] ?? response.headers?['Set-Cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;

    await authRepository.apiClient.updateSessionCookieFromSetCookie(setCookie);
    return await SecureSessionStore.readCookie();
  }

  String? _extractDriverUserId(dynamic body) {
    if (body is! Map) return null;
    final driverProfile = body['driverProfile'];
    return _safeGet(driverProfile, 'userId') ??
        _safeGet(driverProfile, 'driverId') ??
        _safeGet(driverProfile, 'id') ??
        _safeGet(body['data'], 'userId') ??
        _safeGet(body['data'], 'driverId') ??
        _safeGet(body['driver'], 'userId') ??
        _safeGet(body['driver'], 'driverId') ??
        _safeGet(body, 'userId') ??
        _safeGet(body, 'driverId') ??
        _safeGet(body, 'id');
  }

  bool _safeBool(dynamic body, String key) {
    if (body is! Map) return false;
    final value = body[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value == 1;
    return false;
  }

  Future<bool> loginWithDriverCode(String code, {String? phone}) async {
    isLoading.value = true;

    try {
      final response = await authRepository.verifyOtp(phone ?? '', code);

      if (response.isOk) {
        final prefs = await SharedPreferences.getInstance();
        var sessionCookie = await _saveSessionCookie(response);

        if ((sessionCookie == null || sessionCookie.isEmpty) &&
            response.body is Map &&
            response.body['token'] != null) {
          final token = response.body['token'];
          sessionCookie = 'session=$token; better-auth.session_token=$token';
          await authRepository.apiClient.updateSessionCookie(sessionCookie);
        }

        final userId = _extractDriverUserId(response.body);
        if (userId != null && userId.isNotEmpty) {
          await prefs.setString('user_id', userId);
          if (sessionCookie != null && sessionCookie.isNotEmpty) {
            await SocketService.to.reconnectFromStoredSession();
          }
        } else {
          await checkProfileStatus();
          await SocketService.to.reconnectFromStoredSession();
        }

        if (phone != null && phone.isNotEmpty) {
          await prefs.setString('user_phone', phone);
        }

        final driverProfile = _extractDriverProfile(response.body);
        final isProfileComplete =
            _safeBool(response.body, 'isProfileComplete') ||
            _safeBool(driverProfile, 'isProfileComplete') ||
            _safeBool(driverProfile, 'isProfileCompleted');
        final hasProfilePhoto = _hasProfileImage(driverProfile);
        isProfileImageMissing.value = !hasProfilePhoto;
        final hasProfileDetails =
            (_safeGet(driverProfile, 'firstName') ??
                    _safeGet(driverProfile, 'name') ??
                    _safeGet(driverProfile, 'fullName') ??
                    _safeGet(driverProfile, 'email'))
                ?.trim()
                .isNotEmpty ??
            false;
        final shouldOpenDriverApp =
            hasProfilePhoto && (isProfileComplete || hasProfileDetails);

        await prefs.setString('app_mode', 'driver');
        await prefs.setBool('is_profile_completed', shouldOpenDriverApp);
        isProfileCompleted.value = shouldOpenDriverApp;

        CustomSnackbar.showSuccess(message: 'Login successful');
        return true;
      }

      final errorMessage = _apiMessage(response.body, 'Driver login failed');
      CustomSnackbar.showError(message: errorMessage);
      return false;
    } catch (e) {
      print("=== DRIVER CODE LOGIN EXCEPTION ===");
      print("Exception: ${e.toString()}");
      CustomSnackbar.showError(
        message: 'Something went wrong: ${e.toString()}',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Send OTP method
  Future<bool> sendOtp(String phone) async {
    isLoading.value = true;

    // Print request details to terminal
    print("=== SEND OTP REQUEST ===");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.sendOtp}");
    print("Body: {'mobile': '$phone'}");

    try {
      Response response = await authRepository.sendOtp(phone);

      // Print response details to terminal
      print("=== SEND OTP RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.isOk) {
        // Success response
        CustomSnackbar.showSuccess(message: 'OTP sent successfully');
        return true;
      } else {
        // Error response from API
        String errorMessage = _apiMessage(response.body, 'Failed to send OTP');
        CustomSnackbar.showError(message: errorMessage);
        return false;
      }
    } catch (e) {
      print("=== SEND OTP EXCEPTION ===");
      print("Exception: ${e.toString()}");
      CustomSnackbar.showError(
        message: 'Something went wrong: ${e.toString()}',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> resendOtp(String phone) async {
    isLoading.value = true;
    try {
      final response = await authRepository.resendOtp(phone);
      if (response.isOk) {
        CustomSnackbar.showSuccess(message: 'OTP resent successfully');
        return true;
      }
      CustomSnackbar.showError(
        message: _apiMessage(response.body, 'Failed to resend OTP'),
      );
      return false;
    } catch (e) {
      CustomSnackbar.showError(message: 'Something went wrong: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Verify OTP method
  Future<bool> verifyOtp(String phone, String otp) async {
    isLoading.value = true;

    // Print request details to terminal
    print("=== VERIFY OTP REQUEST ===");
    print(
      "URL: ${ApiConstants.baseUrl}${ApiConstants.verifyOtp}",
    );
    print("Body: {'mobile': '$phone', 'otp': '$otp', 'deviceId': '<device>'}");

    try {
      Response response = await authRepository.verifyOtp(phone, otp);

      // Print response details to terminal
      print(
        "================= LOGIN / VERIFY OTP API RESPONSE =================",
      );
      print("Status Code: ${response.statusCode}");
      print("Headers: ${response.headers}");
      print("Response Body: ${response.body}");
      print(
        "===================================================================",
      );

      if (response.isOk) {
        var sessionCookie = await _saveSessionCookie(response);
        if ((sessionCookie == null || sessionCookie.isEmpty) &&
            response.body is Map &&
            response.body['token'] != null) {
          final token = response.body['token'];
          sessionCookie = 'session=$token; better-auth.session_token=$token';
          await authRepository.apiClient.updateSessionCookie(sessionCookie);
        }

        // Save userId and initialize Socket
        var verifyData = _extractDriverProfile(response.body);
        String? userId;
        if (verifyData != null) {
          userId =
              _safeGet(verifyData, 'id') ??
              _safeGet(verifyData, 'userId') ??
              _safeGet(verifyData, 'driverId');
        }
        userId ??=
            _safeGet(response.body, 'id') ??
            _safeGet(response.body, 'userId') ??
            _safeGet(response.body, 'driverId');

        if (userId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
        }
        if (sessionCookie != null && sessionCookie.isNotEmpty) {
          await SocketService.to.reconnectFromStoredSession();
        }

        // Also check if the driver details are already inside the verify response
        isProfileImageMissing.value = !_hasProfileImage(verifyData);

        bool detailsFilled = false;
        if (verifyData != null) {
          String? firstName =
              _safeGet(verifyData, 'firstName') ?? _safeGet(verifyData, 'name');
          if (firstName != null && firstName.trim().isNotEmpty) {
            detailsFilled = true;
            isProfileCompleted.value = true;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_profile_completed', true);
          }
        }

        // If not found in verifyOtp response, fetch the profile via GET API
        if (!detailsFilled) {
          await checkProfileStatus();
        }
        await SocketService.to.reconnectFromStoredSession();

        CustomSnackbar.showSuccess(message: 'Verification successful');
        return true;
      } else {
        String errorMessage = _apiMessage(
          response.body,
          'OTP verification failed',
        );
        CustomSnackbar.showError(message: errorMessage);
        return false;
      }
    } catch (e) {
      print("=== VERIFY OTP EXCEPTION ===");
      print("Exception: ${e.toString()}");
      CustomSnackbar.showError(
        message: 'Something went wrong: ${e.toString()}',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Save personal information method
  Future<bool> savePersonalInformation({
    required String firstName,
    required String lastName,
    required String email,
    required String alternatePhone,
    required File? profileImage,
    String address = '',
  }) async {
    isLoading.value = true;

    final Map<String, dynamic> fields = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'alternatePhone': alternatePhone,
      if (address.trim().isNotEmpty) 'address': address.trim(),
    };

    if (profileImage != null) {
      final String pathStr = profileImage.path.toLowerCase();
      String contentType = 'image/jpeg';
      String extension = 'jpg';
      if (pathStr.endsWith('.png')) {
        contentType = 'image/png';
        extension = 'png';
      } else if (pathStr.endsWith('.pdf')) {
        contentType = 'application/pdf';
        extension = 'pdf';
      }

      fields['profileImage'] = MultipartFile(
        profileImage.readAsBytesSync(),
        filename: 'profile_image.$extension',
        contentType: contentType,
      );
    }

    final formData = FormData(fields);

    // Print request details to terminal
    print("=== SAVE PERSONAL INFORMATION REQUEST ===");
    print(
      "URL: https://truck-api.technogigz.co.in/api/driver/details/personal-information",
    );
    print(
      "Fields: {firstName: $firstName, lastName: $lastName, email: $email, alternatePhone: $alternatePhone, address: $address, hasProfileImage: ${profileImage != null}}",
    );

    try {
      Response response = await authRepository.savePersonalInformation(
        formData,
      );

      // Print response details to terminal
      print("=== SAVE PERSONAL INFORMATION RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.isOk) {
        isProfileCompleted.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_profile_completed', true);
        await checkProfileStatus();
        CustomSnackbar.showSuccess(
          message: 'Personal information saved successfully',
        );
        return true;
      } else {
        String errorMessage = _apiMessage(
          response.body,
          'Failed to save personal information',
        );
        CustomSnackbar.showError(message: errorMessage);
        return false;
      }
    } catch (e) {
      print("=== SAVE PERSONAL INFORMATION EXCEPTION ===");
      print("Exception: ${e.toString()}");
      CustomSnackbar.showError(
        message: 'Something went wrong: ${e.toString()}',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> uploadProfileImage(File profileImage) async {
    isLoading.value = true;

    final String pathStr = profileImage.path.toLowerCase();
    String contentType = 'image/jpeg';
    String extension = 'jpg';
    if (pathStr.endsWith('.png')) {
      contentType = 'image/png';
      extension = 'png';
    }

    final formData = FormData({
      'profileImage': MultipartFile(
        profileImage.readAsBytesSync(),
        filename: 'profile_image.$extension',
        contentType: contentType,
      ),
    });

    print("=== UPLOAD PROFILE IMAGE REQUEST ===");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.uploadProfileImage}");
    print("Fields: {profileImage: profile_image.$extension}");

    try {
      final response = await authRepository.uploadProfileImage(formData);

      print("=== UPLOAD PROFILE IMAGE RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.isOk) {
        isProfileImageMissing.value = false;
        CustomSnackbar.showSuccess(
          message: 'Profile image uploaded successfully',
        );
        return true;
      }

      final errorMessage = _apiMessage(
        response.body,
        'Failed to upload profile image',
      );
      CustomSnackbar.showError(message: errorMessage);
      return false;
    } catch (e) {
      print("=== UPLOAD PROFILE IMAGE EXCEPTION ===");
      print("Exception: ${e.toString()}");
      CustomSnackbar.showError(
        message: 'Something went wrong: ${e.toString()}',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Step 1: Save / Complete Driver Profile
  Future<bool> saveDriverProfile({
    required String fullName,
    required String email,
    required String gender,
    String dateOfBirth = '',
    String address = '',
    String city = '',
    String state = '',
    String postalCode = '',
    String? currentNumber,
    String? alternateNumber,
  }) async {
    isLoading.value = true;

    String formatToIso(String d) {
      final t = d.trim();
      if (t.isEmpty) return t;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return t;
      if (t.contains('/')) {
        final parts = t.split('/').map((s) => s.trim()).toList();
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final y = parts[2];
          return '$y-$month-$day';
        }
      }
      return t;
    }

    final body = <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'gender': gender.toUpperCase(),
      if (dateOfBirth.trim().isNotEmpty)
        'dateOfBirth': formatToIso(dateOfBirth),
      if (address.trim().isNotEmpty) 'addressLine1': address,
      if (city.trim().isNotEmpty) 'city': city,
      if (state.trim().isNotEmpty) 'state': state,
      if (postalCode.trim().isNotEmpty) 'postalCode': postalCode,
      'country': 'India',
      if (currentNumber != null && currentNumber.isNotEmpty)
        'currentNumber': currentNumber,
      if (alternateNumber != null && alternateNumber.isNotEmpty)
        'alternateNumber': alternateNumber,
    };

    print("=== SAVE DRIVER PROFILE REQUEST ===");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.createDriverProfile}");
    print("Body: $body");

    try {
      final response = await authRepository.createDriverProfile(body);
      print("=== SAVE DRIVER PROFILE RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.isOk) {
        await checkProfileStatus();
        CustomSnackbar.showSuccess(message: 'Profile saved successfully');
        return true;
      }
      final errorMessage = _apiMessage(response.body, 'Failed to save profile');
      CustomSnackbar.showError(message: errorMessage);
      return false;
    } catch (e) {
      print("=== SAVE DRIVER PROFILE EXCEPTION ===");
      print("Exception: $e");
      CustomSnackbar.showError(message: 'Something went wrong: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Step 2: Save Driver Vehicle
  Future<bool> saveDriverVehicle({
    required String registrationNumber,
    required String make,
    required String model,
    required String year,
    String? currentAddress,
    required String categoryId,
    required String brandId,
    required String modelId,
    String? drivingLicenseNumber,
  }) async {
    isLoading.value = true;

    int? parsedYear = int.tryParse(year.trim());
    if (parsedYear == null && year.contains('/')) {
      final parts = year.split('/');
      if (parts.isNotEmpty) {
        parsedYear = int.tryParse(parts.last.trim());
      }
    }

    final body = <String, dynamic>{
      'registrationNo': registrationNumber,
      'registrationNumber': registrationNumber, // fallback
      'make': make,
      'model': model,
      ...?parsedYear == null ? null : {'year': parsedYear},
      if (drivingLicenseNumber?.trim().isNotEmpty == true)
        'drivingLicenseNumber': drivingLicenseNumber!.trim().toUpperCase(),
      if (currentAddress != null && currentAddress.isNotEmpty) ...{
        'currentAddress': currentAddress,
        'address': currentAddress, // fallback
      },
      'categoryId': categoryId,
      'brandId': brandId,
      'modelId': modelId,
    };

    print("=== SAVE DRIVER VEHICLE REQUEST ===");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.createDriverVehicle}");
    print("Body: $body");

    try {
      final response = await authRepository.createVehicle(body);
      print("=== SAVE DRIVER VEHICLE RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.isOk) {
        CustomSnackbar.showSuccess(message: 'Vehicle details saved successfully');
        return true;
      }
      final errorMessage = _apiMessage(response.body, 'Failed to save vehicle');
      CustomSnackbar.showError(message: errorMessage);
      return false;
    } catch (e) {
      print("=== SAVE DRIVER VEHICLE EXCEPTION ===");
      print("Exception: $e");
      CustomSnackbar.showError(message: 'Something went wrong: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Step 3: Submit KYC Documents
  Future<bool> submitDriverKycDocuments(Map<String, File> files) async {
    isLoading.value = true;
    final submitUrl = "${ApiConstants.baseUrl}${ApiConstants.submitDriverKyc}";

    try {
      // Exact standardized backend document identifiers in sequence
      final requiredKeys = [
        'AADHAR_FRONT',
        'AADHAR_BACK',
        'PAN_CARD',
        'DL_FRONT',
        'DL_BACK',
        'RC',
        'INSURANCE',
      ];

      // Map local file keys to exact required Backend document keys
      final documentFiles = <String, File>{};
      for (final entry in files.entries) {
        final key = entry.key;
        final file = entry.value;
        String targetKey;
        switch (key.toLowerCase().trim()) {
          case 'aadhar_front':
          case 'aadhar':
          case 'aadhaar_front':
          case 'aadhaar':
            targetKey = 'AADHAR_FRONT';
            break;
          case 'aadhar_back':
          case 'aadhaar_back':
            targetKey = 'AADHAR_BACK';
            break;
          case 'pan_card':
          case 'pan':
            targetKey = 'PAN_CARD';
            break;
          case 'dl_front':
          case 'dl':
          case 'driving_license_front':
          case 'driving_licence_front':
            targetKey = 'DL_FRONT';
            break;
          case 'dl_back':
          case 'driving_license_back':
          case 'driving_licence_back':
            targetKey = 'DL_BACK';
            break;
          case 'rc':
          case 'vehicle_rc':
          case 'vehicle_registration':
            targetKey = 'RC';
            break;
          case 'insurance':
          case 'vehicle_insurance':
            targetKey = 'INSURANCE';
            break;
          case 'profile_photo':
          case 'profile_image':
            targetKey = 'PROFILE_PHOTO';
            break;
          case 'passbook':
          case 'passbook_image':
          case 'bank_passbook':
            targetKey = 'PASSBOOK_IMAGE';
            break;
          case 'vehicle_photo':
          case 'vehicle_photos':
          case 'vehicle_image':
            targetKey = 'VEHICLE_PHOTO';
            break;
          case 'permit':
          case 'commercial_permit':
            targetKey = 'COMMERCIAL_PERMIT';
            break;
          default:
            targetKey = key.toUpperCase().trim();
            break;
        }
        documentFiles[targetKey] = file;
      }

      // Check if any required document files are missing before starting upload loop
      final missingKeys = requiredKeys.where((k) => !documentFiles.containsKey(k)).toList();
      if (missingKeys.isNotEmpty) {
        print("=== KYC UPLOAD ERROR: Missing required document files: $missingKeys ===");
        CustomSnackbar.showError(
          message: 'Missing required documents: ${missingKeys.join(", ")}',
        );
        return false;
      }

      // Collect all keys to upload: required ones first, then any extra optional documents
      final keysToUpload = <String>[...requiredKeys];
      for (final k in documentFiles.keys) {
        if (!keysToUpload.contains(k)) {
          keysToUpload.add(k);
        }
      }

      // Upload EACH selected document individually in sequential flow
      for (final docKey in keysToUpload) {
        final file = documentFiles[docKey]!;
        final bool fileExists = file.existsSync();
        final int fileSize = fileExists ? file.lengthSync() : 0;

        final pathStr = file.path.toLowerCase();
        String contentType = 'image/jpeg';
        String extension = 'jpg';
        if (pathStr.endsWith('.png')) {
          contentType = 'image/png';
          extension = 'png';
        } else if (pathStr.endsWith('.pdf')) {
          contentType = 'application/pdf';
          extension = 'pdf';
        }

        final filename = '${docKey}_${DateTime.now().millisecondsSinceEpoch}.$extension';

        // Debug log: Upload Started
        print("=== KYC DOCUMENT UPLOAD ===");
        print("Document Type: $docKey");
        print("File Name: $filename");
        print("File Exists: $fileExists");
        print("File Size: $fileSize");
        print("Upload Started");

        if (!fileExists || fileSize == 0) {
          print("=== KYC DOCUMENT UPLOAD RESULT ===");
          print("Document Type: $docKey");
          print("Status: 400");
          print("Success: false");
          print("Response: File is missing or empty (0 bytes)");
          CustomSnackbar.showError(message: 'File for $docKey is missing or empty');
          return false;
        }

        // Construct single document Multipart FormData with file attached
        final singleFormDataMap = <String, dynamic>{
          'documentType': docKey,
          'type': docKey,
          'documentKey': docKey,
          'key': docKey,
          'file': MultipartFile(
            file.path,
            filename: filename,
            contentType: contentType,
          ),
          'document': MultipartFile(
            file.path,
            filename: filename,
            contentType: contentType,
          ),
          docKey: MultipartFile(
            file.path,
            filename: filename,
            contentType: contentType,
          ),
        };

        final formData = FormData(singleFormDataMap);
        final uploadResponse = await authRepository.uploadKycDocument(docKey, formData);

        final bool isSuccess = uploadResponse.isOk &&
            (uploadResponse.body == null ||
                (uploadResponse.body is Map && uploadResponse.body['success'] != false));

        // Debug log: Upload Result
        print("=== KYC DOCUMENT UPLOAD RESULT ===");
        print("Document Type: $docKey");
        print("Status: ${uploadResponse.statusCode}");
        print("Success: $isSuccess");
        print("Response: ${uploadResponse.body}");

        if (!isSuccess) {
          final errorMessage = _apiMessage(
            uploadResponse.body,
            uploadResponse.statusText ?? 'Failed to upload $docKey',
          );
          CustomSnackbar.showError(message: 'Upload failed for $docKey: $errorMessage');
          // DO NOT call /kyc/submit if any upload fails
          return false;
        }
      }

      // Call submit API ONLY after ALL 7 required documents have uploaded successfully
      print("=== SUBMIT KYC APPLICATION REQUEST ===");
      print("URL: $submitUrl");
      print("HTTP Method: POST");
      print("Body: {}");

      final submitResponse = await authRepository.submitKyc({});

      print("=== SUBMIT KYC APPLICATION RESPONSE ===");
      print("Status Code: ${submitResponse.statusCode}");
      print("Status Text: ${submitResponse.statusText}");
      print("Response Body: ${submitResponse.body}");

      if (submitResponse.isOk ||
          (submitResponse.body is Map && submitResponse.body['success'] == true)) {
        await checkProfileStatus();
        return true;
      } else {
        final errorMessage = _apiMessage(
          submitResponse.body,
          submitResponse.statusText ?? 'Failed to submit KYC application',
        );
        CustomSnackbar.showError(message: errorMessage);
        return false;
      }
    } catch (e, stackTrace) {
      print("=== SUBMIT KYC DOCUMENTS EXCEPTION ===");
      print("Exception Type: ${e.runtimeType}");
      print("Error Message: ${e.toString()}");
      print("Stack Trace: $stackTrace");

      CustomSnackbar.showError(message: 'Something went wrong: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Vehicle Options & Categories API
  Future<Map<String, dynamic>> fetchVehicleOptions() async {
    final String apiUrl = '${ApiConstants.baseUrl}${ApiConstants.vehicleOptions}';
    debugPrint('\n================================================================================');
    debugPrint('🚀 [API REQUEST] CALLING VEHICLE OPTIONS ENDPOINT');
    debugPrint('🌐 URL: $apiUrl');
    debugPrint('================================================================================');

    try {
      final response = await authRepository.getVehicleOptions();
      debugPrint('\n================================================================================');
      debugPrint('📥 [API RESPONSE RECEIVED]');
      debugPrint('🌐 URL: $apiUrl');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📄 Raw Body: ${response.body}');
      debugPrint('================================================================================');

      if (response.isOk && response.body is Map && response.body['success'] != false) {
        final dataRaw = response.body['data'] ?? response.body;
        if (dataRaw is Map) {
          final categoriesRaw = dataRaw['categories'] ?? [];
          final categories = (categoriesRaw is List)
              ? categoriesRaw.map<Map<String, dynamic>>((item) {
                  if (item is Map) {
                    return {
                      'id': (item['id'] ?? item['_id'] ?? '').toString(),
                      'name': (item['name'] ?? item['title'] ?? item['displayName'] ?? item['slug'] ?? '').toString(),
                      'slug': (item['slug'] ?? item['name'] ?? '').toString(),
                      'iconUrl': (item['iconUrl'] ?? item['icon'] ?? '').toString(),
                      'capacity': item['capacity'],
                      'baseFare': item['baseFare'],
                      'perKmRate': item['perKmRate'],
                      'perMinuteRate': item['perMinuteRate'],
                    };
                  }
                  return <String, dynamic>{};
                }).where((c) {
                    final name = c['name']?.toString().trim().toLowerCase() ?? '';
                    final slug = c['slug']?.toString().trim().toLowerCase() ?? '';
                    final isValid = c['id']?.toString().trim().isNotEmpty == true && name.isNotEmpty;
                    return isValid && name != 'bike' && name != 'auto' && slug != 'bike' && slug != 'auto';
                }).toList()
              : <Map<String, dynamic>>[];

          final brandsRaw = dataRaw['brands'];
          final brands = (brandsRaw is List)
              ? brandsRaw.map<Map<String, dynamic>>((b) {
                  if (b is Map) {
                    return {
                      'id': (b['id'] ?? b['_id'] ?? '').toString(),
                      'name': (b['name'] ?? b['title'] ?? '').toString(),
                      'slug': (b['slug'] ?? b['name'] ?? '').toString(),
                    };
                  }
                  return <String, dynamic>{};
                }).where((b) =>
                    b['id']?.toString().trim().isNotEmpty == true &&
                    b['name']?.toString().trim().isNotEmpty == true).toList()
              : <Map<String, dynamic>>[];

          final modelsRaw = dataRaw['models'];
          final models = (modelsRaw is List)
              ? modelsRaw.map<Map<String, dynamic>>((m) {
                  if (m is Map) {
                    return {
                      'id': (m['id'] ?? m['_id'] ?? '').toString(),
                      'name': (m['name'] ?? m['title'] ?? '').toString(),
                      'slug': (m['slug'] ?? m['name'] ?? '').toString(),
                      'brandId': (m['brandId'] ?? '').toString(),
                      'categoryId': (m['categoryId'] ?? '').toString(),
                    };
                  }
                  return <String, dynamic>{};
                }).where((m) =>
                    m['id']?.toString().trim().isNotEmpty == true &&
                    m['name']?.toString().trim().isNotEmpty == true &&
                    m['brandId']?.toString().trim().isNotEmpty == true &&
                    m['categoryId']?.toString().trim().isNotEmpty == true).toList()
              : <Map<String, dynamic>>[];

          final mfrYearsRaw = dataRaw['manufacturerYears'];
          final manufacturerYears = (mfrYearsRaw is List)
              ? mfrYearsRaw.map<Map<String, dynamic>>((y) {
                  if (y is Map) {
                    return {
                      'id': (y['id'] ?? '').toString(),
                      'year': y['year'] is int ? y['year'] : int.tryParse(y['year'].toString()),
                    };
                  }
                  return <String, dynamic>{};
                }).where((y) => y['year'] != null).toList()
              : <Map<String, dynamic>>[];

          final years = manufacturerYears
              .map((item) => item['year'].toString())
              .toSet()
              .toList();

          debugPrint('\n================================================================================');
          debugPrint('🎯 [TERMINAL PRINT: VEHICLE OPTIONS API DATA]');
          debugPrint('🌐 API URL: $apiUrl');
          debugPrint('📊 HTTP Status: ${response.statusCode}');
          debugPrint('--------------------------------------------------------------------------------');
          debugPrint('🚗 VEHICLE CATEGORIES (${categories.length} items):');
          for (var i = 0; i < categories.length; i++) {
            final cat = categories[i];
            debugPrint('   [$i] ID: ${cat['id']} | Name: ${cat['name']} | Slug: ${cat['slug']} | Capacity: ${cat['capacity']} | BaseFare: ₹${cat['baseFare']} | PerKm: ₹${cat['perKmRate']} | Icon: ${cat['iconUrl']}');
          }
          debugPrint('--------------------------------------------------------------------------------');
          debugPrint('🏷️ BRANDS (${brands.length} items):');
          for (var i = 0; i < brands.length; i++) {
            final b = brands[i];
            debugPrint('   [$i] ID: ${b['id']} | Name: ${b['name']} | Slug: ${b['slug']}');
          }
          debugPrint('--------------------------------------------------------------------------------');
          debugPrint('🚙 MODELS (${models.length} items):');
          for (var i = 0; i < models.length; i++) {
            final m = models[i];
            debugPrint('   [$i] ID: ${m['id']} | Name: ${m['name']} | BrandId: ${m['brandId']} | CategoryId: ${m['categoryId']}');
          }
          debugPrint('--------------------------------------------------------------------------------');
          debugPrint('📅 MANUFACTURER YEARS (${manufacturerYears.length} items):');
          for (var i = 0; i < manufacturerYears.length; i++) {
            final my = manufacturerYears[i];
            debugPrint('   [$i] ID: ${my['id']} | Year: ${my['year']}');
          }
          debugPrint('================================================================================\n');

          return {
            'categories': categories,
            'brands': brands,
            'models': models,
            'manufacturerYears': manufacturerYears,
            'years': years,
          };
        }
      }
    } catch (e, stack) {
      debugPrint('\n================================================================================');
      debugPrint('❌ [API ERROR] EXCEPTION IN fetchVehicleOptions: $e');
      debugPrint('📌 Stack Trace: $stack');
      debugPrint('================================================================================\n');
    }
    throw StateError('Failed to load vehicle options');
  }

  // Location APIs
  Future<List<Map<String, String>>> fetchStates() async {
    try {
      final response = await authRepository.getStates();
      print("=== FETCH STATES RESPONSE: ${response.statusCode} ===");
      if (response.isOk && response.body != null) {
        final data = response.body['data'];
        if (data is List) {
          return data.map<Map<String, String>>((item) {
            return {
              'name': (item['name'] ?? '').toString().trim(),
              'isoCode': (item['isoCode'] ?? '').toString().trim(),
            };
          }).where((m) => m['name']!.isNotEmpty).toList();
        }
      }
    } catch (e) {
      print("=== FETCH STATES EXCEPTION: $e ===");
    }
    return [];
  }

  Future<List<String>> fetchCitiesByState(String stateCode) async {
    try {
      final response = await authRepository.getCitiesByState(stateCode);
      print("=== FETCH CITIES RESPONSE ($stateCode): ${response.statusCode} ===");
      if (response.isOk && response.body != null) {
        final data = response.body['data'];
        if (data is List) {
          return data
              .map<String>((item) => (item['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      print("=== FETCH CITIES EXCEPTION: $e ===");
    }
    return [];
  }

  Future<Map<String, String>?> fetchLocationByPincode(String pincode) async {
    try {
      final response = await authRepository.getLocationByPincode(pincode);
      print("=== FETCH PINCODE RESPONSE ($pincode): ${response.statusCode} ===");
      print("Response Body: ${response.body}");
      if (response.isOk && response.body != null) {
        final data = response.body['data'];
        if (data is Map) {
          return {
            'state': (data['state'] ?? '').toString().trim(),
            'city': (data['city'] ?? '').toString().trim(),
          };
        }
      } else {
        String msg = 'Invalid Pincode';
        if (response.body is Map) {
          if (response.body['message'] != null) {
            msg = response.body['message'].toString();
          } else if (response.body['error'] is Map &&
              response.body['error']['message'] != null) {
            msg = response.body['error']['message'].toString();
          }
        }
        CustomSnackbar.showError(message: msg);
      }
    } catch (e) {
      print("=== FETCH PINCODE EXCEPTION: $e ===");
      CustomSnackbar.showError(message: 'Invalid Pincode');
    }
    return null;
  }

  // Additional Postman Driver API Methods
  Future<Response> getAuthSession() async {
    return await authRepository.getAuthSession();
  }

  Future<Response> getAuthSessions() async {
    return await authRepository.getAuthSessions();
  }

  Future<bool> revokeSession(String sessionId) async {
    isLoading.value = true;
    try {
      final response = await authRepository.revokeSession(sessionId);
      if (response.isOk) {
        CustomSnackbar.showSuccess(message: 'Session revoked successfully');
        return true;
      }
      CustomSnackbar.showError(
        message: _apiMessage(response.body, 'Failed to revoke session'),
      );
      return false;
    } catch (e) {
      CustomSnackbar.showError(message: 'Error revoking session: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteDriverAccount() async {
    isLoading.value = true;
    try {
      final response = await authRepository.deleteAccount();
      if (response.isOk) {
        await SecureSessionStore.clear();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        CustomSnackbar.showSuccess(message: 'Account deleted successfully');
        return true;
      }
      CustomSnackbar.showError(
        message: _apiMessage(response.body, 'Failed to delete account'),
      );
      return false;
    } catch (e) {
      CustomSnackbar.showError(message: 'Error deleting account: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> logoutDriver() async {
    isLoading.value = true;
    try {
      final response = await authRepository.logout();
      await SecureSessionStore.clear();
      await clearCachedProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('is_profile_completed');
      if (response.isOk) {
        CustomSnackbar.showSuccess(message: 'Logged out successfully');
        return true;
      }
      return true;
    } catch (e) {
      await SecureSessionStore.clear();
      await clearCachedProfile();
      return true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> logoutAllSessions() async {
    isLoading.value = true;
    try {
      final response = await authRepository.logoutAll();
      await SecureSessionStore.clear();
      await clearCachedProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('is_profile_completed');
      if (response.isOk) {
        CustomSnackbar.showSuccess(message: 'Logged out from all sessions');
        return true;
      }
      return true;
    } catch (e) {
      await SecureSessionStore.clear();
      await clearCachedProfile();
      return true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateDriverProfileData(Map<String, dynamic> data) async {
    isLoading.value = true;
    try {
      final response = await authRepository.updateProfile(data);
      if (response.isOk) {
        await checkProfileStatus();
        CustomSnackbar.showSuccess(message: 'Profile updated successfully');
        return true;
      }
      CustomSnackbar.showError(
        message: _apiMessage(response.body, 'Failed to update profile'),
      );
      return false;
    } catch (e) {
      CustomSnackbar.showError(message: 'Error updating profile: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Response> fetchCanonicalOnboardingStatus() async {
    return await authRepository.getCanonicalOnboardingStatus();
  }

  Future<Response> fetchAccountStatus() async {
    return await authRepository.getAccountStatus();
  }

  Future<Response> fetchProfileImageUploadUrl() async {
    return await authRepository.getProfileImageUploadUrl();
  }

  Future<bool> removeProfileImage() async {
    isLoading.value = true;
    try {
      final response = await authRepository.deleteProfileImage();
      if (response.isOk) {
        isProfileImageMissing.value = true;
        await checkProfileStatus();
        CustomSnackbar.showSuccess(message: 'Profile image removed');
        return true;
      }
      CustomSnackbar.showError(
        message: _apiMessage(response.body, 'Failed to remove image'),
      );
      return false;
    } catch (e) {
      CustomSnackbar.showError(message: 'Error removing image: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
