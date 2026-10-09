import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/api/api_client.dart';
import '../../../data/api/api_constants.dart';

class DriverSubscriptionRepository {
  DriverSubscriptionRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<Response> getPlans() {
    return apiClient.getData(ApiConstants.subscriptionPlans);
  }

  Future<Response> getActiveSubscription() {
    return apiClient.getData(ApiConstants.activeSubscription);
  }

  Future<Response> getHistory({int page = 1, int limit = 20, String? status}) {
    return apiClient.getData(
      ApiConstants.subscriptionHistory,
      query: {
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<Response> getPaymentStatus(String subscriptionId, {bool reconcile = false}) {
    return apiClient.getData(
      ApiConstants.subscriptionPaymentStatus(subscriptionId),
      query: {'reconcile': reconcile.toString()},
    );
  }

  Future<Response> purchase({
    required String planId,
    required String idempotencyKey,
  }) async {
    final endpoint = ApiConstants.purchaseSubscription;
    final body = {'planId': planId};
    final headers = {'X-Idempotency-Key': idempotencyKey};

    debugPrint('[PLAN_DEBUG] endpoint = ${ApiConstants.baseUrl}$endpoint');
    debugPrint('[PLAN_DEBUG] method = POST');
    debugPrint('[PLAN_DEBUG] request = $body');
    debugPrint(
      '[PLAN_DEBUG] headers = '
      '{X-Idempotency-Key: ${_maskValue(idempotencyKey)}}',
    );

    final response = await apiClient.postData(
      endpoint,
      body,
      headers: headers,
    );

    debugPrint('[PLAN_DEBUG] statusCode = ${response.statusCode}');
    debugPrint('[PLAN_DEBUG] response = ${response.body}');
    return response;
  }

  String _maskValue(String value) {
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  Future<Response> verifyPayment({
    required String paymentId,
    required String providerPaymentId,
    required String signature,
  }) {
    return apiClient.postData(
      ApiConstants.verifyPayment,
      {
        'paymentId': paymentId,
        'providerPaymentId': providerPaymentId,
        'signature': signature,
      },
    );
  }

  String createPurchaseKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final chars = bytes.map(hex).join();
    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }
}
