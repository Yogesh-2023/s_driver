import 'package:get/get.dart';
import '../../../data/api/api_client.dart';
import '../../../data/api/api_constants.dart';

class WalletRepository {
  final ApiClient apiClient;

  WalletRepository({required this.apiClient});

  /// Fetch driver wallet balance and information
  Future<Response> getWallet() async {
    print("=== DRIVER API REQUEST ===");
    print("Method: GET");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.driverWallet}");

    final response = await apiClient.getData(ApiConstants.driverWallet);

    print("=== DRIVER API RESPONSE ===");
    print("Method: GET");
    print("URL: ${ApiConstants.driverWallet}");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Fetch driver earnings summary (today, week, month)
  Future<Response> getEarningsSummary() async {
    print("=== DRIVER API REQUEST ===");
    print("Method: GET");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.earningsSummary}");

    final response = await apiClient.getData(ApiConstants.earningsSummary);

    print("=== DRIVER API RESPONSE ===");
    print("Method: GET");
    print("URL: ${ApiConstants.earningsSummary}");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }

  /// Request payout / withdrawal from wallet
  Future<Response> requestWithdrawal(double amount) async {
    print("=== DRIVER API REQUEST ===");
    print("Method: POST");
    print("URL: ${ApiConstants.baseUrl}${ApiConstants.withdrawWallet}");
    print("Payload: { amount: $amount }");

    final response = await apiClient.postData(
      ApiConstants.withdrawWallet,
      {
        'amount': amount,
      },
    );

    print("=== DRIVER API RESPONSE ===");
    print("Method: POST");
    print("URL: ${ApiConstants.withdrawWallet}");
    print("Status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response;
  }
}
