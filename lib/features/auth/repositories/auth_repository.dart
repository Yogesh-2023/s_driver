import 'dart:io';

import 'package:get/get.dart';
import '../../../data/api/api_client.dart';
import '../../../data/api/api_constants.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  String _phoneIdentifier(String phone) {
    return phone.trim();
  }

  Future<Response> requestOtp(String phone) async {
    return await apiClient.postData(ApiConstants.requestOtp, {
      'mobile': _phoneIdentifier(phone),
    });
  }

  Future<Response> sendOtp(String phone) async {
    return await apiClient.postData(ApiConstants.sendOtp, {
      'mobile': _phoneIdentifier(phone),
    });
  }

  Future<Response> resendOtp(String phone) async {
    return await apiClient.postData(ApiConstants.resendOtp, {
      'mobile': _phoneIdentifier(phone),
    });
  }

  // Call API to verify OTP
  Future<Response> verifyOtp(String phone, String otp) async {
    return await apiClient.postData(ApiConstants.verifyOtp, {
      'mobile': _phoneIdentifier(phone),
      'otp': otp,
      'deviceId': 'device_${Platform.operatingSystem}',
    });
  }

  // Session & Auth Management Endpoints
  Future<Response> getAuthMe() async {
    return await apiClient.getData(ApiConstants.authMe);
  }

  Future<Response> getAuthSession() async {
    return await apiClient.getData(ApiConstants.authSession);
  }

  Future<Response> getAuthSessions() async {
    return await apiClient.getData(ApiConstants.authSessions);
  }

  Future<Response> revokeSession(String sessionId) async {
    return await apiClient.deleteData(ApiConstants.revokeSession(sessionId));
  }

  Future<Response> logout() async {
    return await apiClient.postData(ApiConstants.logout, {});
  }

  Future<Response> logoutAll() async {
    return await apiClient.postData(ApiConstants.logoutAll, {});
  }

  Future<Response> deleteAccount() async {
    return await apiClient.deleteData(ApiConstants.deleteAccount);
  }

  Future<Response> verifyDriverCode(String code) async {
    return await apiClient.postData(ApiConstants.verifyDriverCode, {
      'code': code,
    });
  }

  // Call API to register a new driver
  Future<Response> registerDriver(Map<String, dynamic> driverData) async {
    return await apiClient.postData(ApiConstants.registerDriver, driverData);
  }

  // Call API to save personal information
  Future<Response> savePersonalInformation(dynamic data) async {
    return await apiClient.postData(ApiConstants.savePersonalInformation, data);
  }

  // Fetch driver account info
  Future<Response> getDriverAccountInfo() async {
    final response = await apiClient.getData(ApiConstants.driverAccountInfo);
    print('=== GET DRIVER ACCOUNT INFO API RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    return response;
  }

  // Fetch driver vehicle info
  Future<Response> getDriverVehicleInfo() async {
    final response = await apiClient.getData(ApiConstants.driverVehicleInfo);
    print('=== GET DRIVER VEHICLE INFO API RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    return response;
  }

  // Fetch driver profile
  Future<Response> getProfile() async {
    final response = await apiClient.getData(ApiConstants.driverProfile);
    print('=== GET PROFILE API RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
    return response;
  }

  // Fetch driver dashboard stats
  Future<Response> getDashboard() async {
    final response = await apiClient.getData(ApiConstants.driverDashboard);
    print('=== GET DASHBOARD API RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
    return response;
  }

  // Canonical Create/Complete Driver Profile (Step 1)
  Future<Response> createDriverProfile(Map<String, dynamic> profileData) async {
    return await apiClient.postData(
      ApiConstants.createDriverProfile,
      profileData,
    );
  }

  // Update Driver Profile
  Future<Response> updateProfile(Map<String, dynamic> profileData) async {
    return await apiClient.patchData(
      ApiConstants.updateDriverProfile,
      profileData,
    );
  }

  // Profile Image Upload URL Request
  Future<Response> getProfileImageUploadUrl() async {
    return await apiClient.postData(
      ApiConstants.profileImageUploadUrl,
      {},
    );
  }

  // Canonical Upload Profile Image / Selfie
  Future<Response> uploadProfileImage(FormData formData) async {
    return await apiClient.postData(
      ApiConstants.uploadProfileImage,
      formData,
    );
  }

  // Delete Profile Image
  Future<Response> deleteProfileImage() async {
    return await apiClient.deleteData(ApiConstants.deleteProfileImage);
  }

  // Onboarding & Account Status
  Future<Response> getOnboardingStatus() async {
    return await apiClient.getData(ApiConstants.onboardingStatus);
  }

  Future<Response> getCanonicalOnboardingStatus() async {
    return await apiClient.getData(ApiConstants.onboardingStatusCanonical);
  }

  Future<Response> getAccountStatus() async {
    return await apiClient.getData(ApiConstants.accountStatus);
  }

  // Canonical Add Driver Vehicle (Step 2)
  Future<Response> createVehicle(Map<String, dynamic> vehicleData) async {
    return await apiClient.postData(
      ApiConstants.createDriverVehicle,
      vehicleData,
    );
  }

  // Canonical Submit KYC / Documents (Step 3) - Single document upload
  Future<Response> uploadKycDocument(String documentKey, FormData formData) async {
    return await apiClient.postData(
      '${ApiConstants.uploadDriverKyc}?type=$documentKey&documentType=$documentKey&key=$documentKey',
      formData,
    );
  }

  Future<Response> uploadKycDocuments(FormData formData) async {
    return await apiClient.postData(
      ApiConstants.uploadDriverKyc,
      formData,
    );
  }

  // Submit Driver KYC Application
  Future<Response> submitKyc(dynamic kycData) async {
    return await apiClient.postData(
      ApiConstants.submitDriverKyc,
      kycData,
    );
  }

  // Fetch submitted KYC documents status
  Future<Response> getKycStatus() async {
    return await apiClient.getData(ApiConstants.driverKycStatus);
  }

  // Fetch detailed KYC info
  Future<Response> getKycDetails() async {
    return await apiClient.getData(ApiConstants.driverKycDetails);
  }

  // Location Endpoints
  Future<Response> getStates() async {
    return await apiClient.getData(ApiConstants.locationsStates);
  }

  Future<Response> getCitiesByState(String stateCode) async {
    return await apiClient.getData(ApiConstants.locationsCities(stateCode));
  }

  Future<Response> getLocationByPincode(String pincode) async {
    return await apiClient.getData(ApiConstants.locationsPincode(pincode));
  }

  Future<Response> getVehicleOptions() async {
    return await apiClient.getData(ApiConstants.vehicleOptions);
  }
}

