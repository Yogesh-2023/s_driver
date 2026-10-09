import 'package:get/get.dart';
import '../../../data/api/api_client.dart';
import '../../../data/api/api_constants.dart';

class DocumentRepository {
  final ApiClient apiClient;

  DocumentRepository({required this.apiClient});

  // Get driver KYC status from backend
  Future<Response> getKycStatus() async {
    final response = await apiClient.getData(ApiConstants.driverKycStatus);
    print("=== DOCUMENT DRIVER GET RESPONSE ===");
    print("URI: ${ApiConstants.driverKycStatus}");
    print("Status Code: ${response.statusCode}");
    print("Response Body: ${response.body}");
    return response;
  }

  // Get detailed KYC information
  Future<Response> getKycDetails() async {
    return await apiClient.getData(ApiConstants.driverKycDetails);
  }

  // Submit Driver KYC application
  Future<Response> submitKyc(dynamic kycData) async {
    return await apiClient.postData(ApiConstants.submitDriverKyc, kycData);
  }

  // Upload individual KYC document
  Future<Response> uploadDocument(String type, FormData formData) async {
    return await apiClient.postData(
      '${ApiConstants.uploadDriverKyc}/?type=$type',
      formData,
    );
  }

  // Reupload driver KYC document
  Future<Response> reuploadDocument(String kycId, FormData formData) async {
    return await apiClient.postData(
      '${ApiConstants.uploadDriverKyc}/$kycId/reupload',
      formData,
    );
  }

  Future<Response> getProviderKycStatus() {
    return apiClient.getData(ApiConstants.providerKycStatus);
  }

  Future<Response> uploadProviderKycDocument(String type, FormData formData) {
    return apiClient.postData(
      '${ApiConstants.uploadProviderKyc}/?type=$type',
      formData,
    );
  }

  Future<Response> reuploadProviderKycDocument(FormData formData) {
    return apiClient.postData(
      '${ApiConstants.uploadProviderKyc}/reupload',
      formData,
    );
  }
}
