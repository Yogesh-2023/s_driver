class DriverSubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final int durationValue;
  final String durationType;
  final String price;
  final String tripType;
  final int? numberOfTrips;
  final String gstOrTax;

  const DriverSubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.durationValue,
    required this.durationType,
    required this.price,
    required this.tripType,
    required this.numberOfTrips,
    required this.gstOrTax,
  });

  factory DriverSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return DriverSubscriptionPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Subscription Plan',
      description: json['description']?.toString() ?? '',
      durationValue: _asInt(json['durationValue']),
      durationType: json['durationType']?.toString() ?? 'DAYS',
      price: json['price']?.toString() ?? '0',
      tripType: json['tripType']?.toString() ?? 'UNLIMITED',
      numberOfTrips: json['numberOfTrips'] == null
          ? null
          : _asInt(json['numberOfTrips']),
      gstOrTax: json['gstOrTax']?.toString() ?? '0',
    );
  }

  bool get isFree => double.tryParse(price) == 0;

  String get priceLabel {
    final amount = double.tryParse(price) ?? 0;
    if (amount == amount.roundToDouble()) return 'Rs ${amount.toStringAsFixed(0)}';
    return 'Rs ${amount.toStringAsFixed(2)}';
  }

  String get durationLabel {
    final label = durationValue == 1 ? 'day' : 'days';
    return '$durationValue $label';
  }

  String get tripLabel {
    if (tripType.toUpperCase() == 'LIMITED') {
      final trips = numberOfTrips ?? 0;
      return '$trips ${trips == 1 ? 'trip' : 'trips'}';
    }
    return 'Unlimited trips';
  }
}

class DriverSubscription {
  final String id;
  final String planId;
  final String status;
  final String? startDate;
  final String? expiryDate;
  final String priceAtPurchase;
  final int? remainingTrips;
  final DriverSubscriptionPlan? plan;

  const DriverSubscription({
    required this.id,
    required this.planId,
    required this.status,
    required this.startDate,
    required this.expiryDate,
    required this.priceAtPurchase,
    required this.remainingTrips,
    required this.plan,
  });

  factory DriverSubscription.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'];
    return DriverSubscription(
      id: json['id']?.toString() ?? '',
      planId: json['planId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startDate: json['startDate']?.toString(),
      expiryDate: json['expiryDate']?.toString(),
      priceAtPurchase: json['priceAtPurchase']?.toString() ?? '0',
      remainingTrips: json['remainingTrips'] == null
          ? null
          : _asInt(json['remainingTrips']),
      plan: planJson is Map
          ? DriverSubscriptionPlan.fromJson(Map<String, dynamic>.from(planJson))
          : null,
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

class DriverSubscriptionPayment {
  final String id;
  final String status;
  final String amount;
  final String currency;
  final String provider;
  final String? providerOrderId;

  const DriverSubscriptionPayment({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.providerOrderId,
  });

  factory DriverSubscriptionPayment.fromJson(Map<String, dynamic> json) {
    return DriverSubscriptionPayment(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'INR',
      provider: json['provider']?.toString() ?? '',
      providerOrderId: json['providerOrderId']?.toString(),
    );
  }
}

class DriverSubscriptionCheckout {
  final String provider;
  final String keyId;
  final String orderId;
  final int amountMinor;
  final String currency;

  const DriverSubscriptionCheckout({
    required this.provider,
    required this.keyId,
    required this.orderId,
    required this.amountMinor,
    required this.currency,
  });

  factory DriverSubscriptionCheckout.fromJson(Map<String, dynamic> json) {
    return DriverSubscriptionCheckout(
      provider: json['provider']?.toString() ?? '',
      keyId: json['keyId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      amountMinor: _asInt(json['amountMinor']),
      currency: json['currency']?.toString() ?? 'INR',
    );
  }
}

class DriverSubscriptionPurchase {
  final DriverSubscription? subscription;
  final String? paymentId;
  final DriverSubscriptionPayment? payment;
  final DriverSubscriptionCheckout? checkout;

  const DriverSubscriptionPurchase({
    required this.subscription,
    required this.paymentId,
    required this.payment,
    required this.checkout,
  });

  factory DriverSubscriptionPurchase.fromJson(Map<String, dynamic> json) {
    final subscriptionJson = json['subscription'];
    final paymentJson = json['payment'];
    final checkoutJson = json['checkout'];
    return DriverSubscriptionPurchase(
      subscription: subscriptionJson is Map
          ? DriverSubscription.fromJson(Map<String, dynamic>.from(subscriptionJson))
          : null,
      paymentId: json['paymentId']?.toString(),
      payment: paymentJson is Map
          ? DriverSubscriptionPayment.fromJson(Map<String, dynamic>.from(paymentJson))
          : null,
      checkout: checkoutJson is Map
          ? DriverSubscriptionCheckout.fromJson(Map<String, dynamic>.from(checkoutJson))
          : null,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
