import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/api/api_client.dart';
import '../../../widgets/custom_snackbar.dart';
import '../models/driver_subscription_models.dart';
import '../repositories/driver_subscription_repository.dart';

class DriverSubscriptionController extends GetxController {
  DriverSubscriptionController({
    DriverSubscriptionRepository? repository,
  }) : _repository = repository ??
            DriverSubscriptionRepository(apiClient: Get.find<ApiClient>());

  final DriverSubscriptionRepository _repository;

  final isLoading = false.obs;
  final isPurchasing = false.obs;
  final isVerifyingPayment = false.obs;
  final plans = <DriverSubscriptionPlan>[].obs;
  final activeSubscription = Rxn<DriverSubscription>();
  final lastPurchase = Rxn<DriverSubscriptionPurchase>();
  final errorMessage = ''.obs;
  late final Razorpay _razorpay;
  String? _lastPurchasePlanId;
  final _paymentPlanIds = <String, String>{};

  static const _purchaseKeyPrefix = 'driver_subscription_purchase_key_';

  @override
  void onInit() {
    super.onInit();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    loadSubscriptions();
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }

  Future<void> loadSubscriptions() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await Future.wait([
        fetchActiveSubscription(showErrors: false),
        fetchPlans(showErrors: false),
        recoverPendingPurchase(showErrors: false),
      ]);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlans({bool showErrors = true}) async {
    final response = await _repository.getPlans();
    if (!response.isOk) {
      if (showErrors) _showError(response.statusText ?? 'Unable to load plans');
      return;
    }

    final data = _unwrapData(response.body);
    final list = data is List ? data : const [];
    plans.assignAll(
      list
          .whereType<Map>()
          .map((item) => DriverSubscriptionPlan.fromJson(Map<String, dynamic>.from(item)))
          .where((plan) => plan.id.isNotEmpty)
          .toList(),
    );
  }

  Future<void> fetchActiveSubscription({bool showErrors = true}) async {
    final response = await _repository.getActiveSubscription();
    if (!response.isOk) {
      if (showErrors) _showError(response.statusText ?? 'Unable to load subscription');
      return;
    }

    final data = _unwrapData(response.body);
    if (data is Map) {
      activeSubscription.value =
          DriverSubscription.fromJson(Map<String, dynamic>.from(data));
    } else {
      activeSubscription.value = null;
    }
  }

  Future<void> recoverPendingPurchase({bool showErrors = true}) async {
    final response = await _repository.getHistory(
      page: 1,
      limit: 1,
      status: 'PENDING_PAYMENT',
    );
    if (!response.isOk) {
      if (showErrors) _showError(response.statusText ?? 'Unable to load history');
      return;
    }

    final data = _unwrapData(response.body);
    if (data is! Map) return;
    final items = data['items'];
    if (items is! List || items.isEmpty || items.first is! Map) return;

    final subscription = DriverSubscription.fromJson(
      Map<String, dynamic>.from(items.first as Map),
    );
    if (subscription.id.isEmpty) return;
    await fetchPaymentStatus(subscription.id, reconcile: true, showErrors: false);
  }

  Future<void> fetchPaymentStatus(
    String subscriptionId, {
    bool reconcile = false,
    bool showErrors = true,
  }) async {
    final response = await _repository.getPaymentStatus(
      subscriptionId,
      reconcile: reconcile,
    );
    if (!response.isOk) {
      if (showErrors) _showError(response.statusText ?? 'Unable to load payment');
      return;
    }

    final data = _unwrapData(response.body);
    if (data is Map) {
      lastPurchase.value =
          DriverSubscriptionPurchase.fromJson(Map<String, dynamic>.from(data));
      final subscription = lastPurchase.value?.subscription;
      if (subscription?.isActive == true) {
        activeSubscription.value = subscription;
      }
    }
  }

  Future<void> purchasePlan(DriverSubscriptionPlan plan) async {
    if (isPurchasing.value) return;
    isPurchasing.value = true;
    errorMessage.value = '';
    try {
      final key = await _purchaseKeyForPlan(plan.id);
      debugPrint(
        '[PLAN_DEBUG] purchasePlan() '
        'planId=${plan.id} '
        'planName=${plan.name} '
        'idempotencyKey=${_maskValue(key)}',
      );
      final response = await _repository.purchase(
        planId: plan.id,
        idempotencyKey: key,
      );
      debugPrint(
        '[PLAN_DEBUG] purchasePlan response '
        'statusCode=${response.statusCode} '
        'isOk=${response.isOk} '
        'statusText=${response.statusText ?? ''}',
      );
      debugPrint('[PLAN_DEBUG] purchasePlan responseBody=${response.body}');

      if (!response.isOk) {
        await _clearPurchaseKey(plan.id);
        _showError(response.statusText ?? 'Unable to start subscription purchase');
        return;
      }

      final data = _unwrapData(response.body);
      if (data is! Map) {
        await _clearPurchaseKey(plan.id);
        _showError('Unexpected subscription response');
        return;
      }

      final purchase = DriverSubscriptionPurchase.fromJson(
        Map<String, dynamic>.from(data),
      );
      lastPurchase.value = purchase;
      _lastPurchasePlanId = plan.id;
      final paymentId = purchase.paymentId;
      if (paymentId != null && paymentId.isNotEmpty) {
        _paymentPlanIds[paymentId] = plan.id;
      }

      if (purchase.subscription?.isActive == true) {
        activeSubscription.value = purchase.subscription;
        await _clearPurchaseKey(plan.id);
        CustomSnackbar.showSuccess(message: 'Subscription activated');
        return;
      }

      if (purchase.checkout != null) {
        _openRazorpayCheckout(purchase);
        return;
      }

      await _clearPurchaseKey(plan.id);
      if (purchase.subscription?.status.toUpperCase() == 'PENDING_PAYMENT') {
        _showError('Payment order expired. Please try again.');
        return;
      }
      CustomSnackbar.showSuccess(message: 'Subscription request created');
    } catch (e) {
      await _clearPurchaseKey(plan.id);
      debugPrint('Subscription purchase error: $e');
      _showError('Unable to start subscription purchase');
    } finally {
      isPurchasing.value = false;
    }
  }

  void resumeCheckout() {
    final purchase = lastPurchase.value;
    if (purchase == null) {
      _showError('No pending checkout found');
      return;
    }
    _openRazorpayCheckout(purchase);
  }

  void _openRazorpayCheckout(DriverSubscriptionPurchase purchase) {
    final checkout = purchase.checkout;
    final paymentId = purchase.paymentId;
    if (checkout == null || paymentId == null || paymentId.isEmpty) {
      _showError('Payment checkout details are missing');
      return;
    }
    final subscription = purchase.subscription;
    final planId =
        subscription?.planId ?? _paymentPlanIds[paymentId] ?? _lastPurchasePlanId;
    if (checkout.keyId.isEmpty ||
        checkout.orderId.isEmpty ||
        checkout.amountMinor <= 0 ||
        checkout.currency.isEmpty) {
      if (planId != null && planId.isNotEmpty) {
        _clearPurchaseKey(planId);
      }
      _showError('Payment checkout details are incomplete');
      return;
    }
    if (!checkout.orderId.startsWith('order_')) {
      debugPrint(
        '[RAZORPAY][SUBSCRIPTION][INVALID_ORDER] '
        'orderId=${checkout.orderId} paymentId=$paymentId planId=${planId ?? ''}',
      );
      if (planId != null && planId.isNotEmpty) {
        _clearPurchaseKey(planId);
      }
      _showError('Payment order is invalid. Please try again.');
      return;
    }
    if (!checkout.keyId.startsWith('rzp_test_') &&
        !checkout.keyId.startsWith('rzp_live_')) {
      debugPrint(
        '[RAZORPAY][SUBSCRIPTION][INVALID_KEY] '
        'key=${_maskKey(checkout.keyId)} paymentId=$paymentId planId=${planId ?? ''}',
      );
      if (planId != null && planId.isNotEmpty) {
        _clearPurchaseKey(planId);
      }
      _showError('Payment key is invalid. Please try again.');
      return;
    }

    final plan = purchase.subscription?.plan;
    debugPrint(
      '[RAZORPAY][SUBSCRIPTION][OPEN] '
      'key=${_maskKey(checkout.keyId)} '
      'orderId=${checkout.orderId} '
      'amount=${checkout.amountMinor} '
      'currency=${checkout.currency} '
      'planId=${planId ?? ''} '
      'subscriptionId=${subscription?.id ?? ''} '
      'paymentId=$paymentId',
    );
    final options = {
      'key': checkout.keyId,
      'amount': checkout.amountMinor,
      'currency': checkout.currency,
      'order_id': checkout.orderId,
      'name': 'FleetGo Driver',
      'description': plan?.name ?? 'Driver subscription plan',
      'timeout': 300,
      'retry': {'enabled': true, 'max_count': 1},
      'theme': {'color': '#FFC000'},
      'notes': {
        'backendPaymentId': paymentId,
        if (purchase.subscription?.id.isNotEmpty == true)
          'subscriptionId': purchase.subscription!.id,
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      _showError('Unable to open Razorpay checkout');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final purchase = lastPurchase.value;
    final backendPaymentId = purchase?.paymentId;
    final providerPaymentId = response.paymentId;
    final signature = response.signature;

    if (backendPaymentId == null ||
        backendPaymentId.isEmpty ||
        providerPaymentId == null ||
        providerPaymentId.isEmpty ||
        signature == null ||
        signature.isEmpty) {
      _showError('Payment completed, but verification details are missing');
      return;
    }

    isVerifyingPayment.value = true;
    try {
      final verifyResponse = await _repository.verifyPayment(
        paymentId: backendPaymentId,
        providerPaymentId: providerPaymentId,
        signature: signature,
      );

      if (!verifyResponse.isOk) {
        _showError(verifyResponse.statusText ?? 'Payment verification failed');
        return;
      }

      await fetchActiveSubscription(showErrors: false);
      final planId = purchase?.subscription?.planId ??
          _paymentPlanIds[backendPaymentId] ??
          _lastPurchasePlanId;
      if (planId != null && planId.isNotEmpty) {
        await _clearPurchaseKey(planId);
      }
      _paymentPlanIds.remove(backendPaymentId);
      _lastPurchasePlanId = null;
      lastPurchase.value = null;
      CustomSnackbar.showSuccess(message: 'Payment verified successfully');
    } catch (e) {
      debugPrint('Payment verification error: $e');
      _showError('Payment verification failed. Please refresh status.');
    } finally {
      isVerifyingPayment.value = false;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final message = response.message?.trim();
    final purchase = lastPurchase.value;
    final backendPaymentId = purchase?.paymentId;
    final planId = purchase?.subscription?.planId ??
        (backendPaymentId == null ? null : _paymentPlanIds[backendPaymentId]) ??
        _lastPurchasePlanId;
    if (planId != null && planId.isNotEmpty) {
      _clearPurchaseKey(planId);
    }
    debugPrint(
      '[RAZORPAY][SUBSCRIPTION][ERROR] '
      'code=${response.code} '
      'message=${_sanitizeRazorpayMessage(message)} '
      'planId=${planId ?? ''} '
      'paymentId=${backendPaymentId ?? ''}',
    );
    _showError(
      message != null && message.isNotEmpty
          ? message
          : 'Payment was not completed',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    CustomSnackbar.showSuccess(
      message: 'External wallet selected: ${response.walletName ?? 'wallet'}',
    );
  }

  dynamic _unwrapData(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<String> _purchaseKeyForPlan(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_purchaseKeyPrefix$planId';
    final existing = prefs.getString(storageKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final key = _repository.createPurchaseKey();
    await prefs.setString(storageKey, key);
    return key;
  }

  Future<void> _clearPurchaseKey(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_purchaseKeyPrefix$planId');
  }

  void _showError(String message) {
    errorMessage.value = message;
    CustomSnackbar.showError(message: message);
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  String _maskValue(String value) {
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  String _sanitizeRazorpayMessage(String? message) {
    if (message == null || message.isEmpty) return '';
    return message
        .replaceAll(RegExp(r'rzp_(test|live)_[A-Za-z0-9]+'), 'rzp_****')
        .replaceAll(
          RegExp(r'key_secret["=: ]+[A-Za-z0-9]+'),
          'key_secret=****',
        );
  }
}
