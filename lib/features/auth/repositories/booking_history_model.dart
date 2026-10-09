class BookingLocation {
  final String? address;
  final String? receiverName;
  final String? receiverMobile;
  final String? landmark;
  final String? additionalDirection;
  final String? category;
  final String? senderName;
  final String? senderMobile;

  BookingLocation({
    this.address,
    this.receiverName,
    this.receiverMobile,
    this.landmark,
    this.additionalDirection,
    this.category,
    this.senderName,
    this.senderMobile,
  });

  factory BookingLocation.fromJson(dynamic json) {
    if (json is! Map) return BookingLocation();
    return BookingLocation(
      address: _readString(json, const [
        'address',
        'fullAddress',
        'pickupAddress',
        'dropAddress',
        'location',
        'formattedAddress',
      ]),
      receiverName: _readString(json, const ['receiverName', 'receiver_name']),
      receiverMobile: _readString(json, const [
        'receiverMobile',
        'receiverPhone',
        'receiver_mobile',
      ]),
      landmark: _readString(json, const ['landmark']),
      additionalDirection: _readString(json, const [
        'additionalDirection',
        'additional_direction',
      ]),
      category: _readString(json, const ['category', 'type']),
      senderName: _readString(json, const ['senderName', 'sender_name']),
      senderMobile: _readString(json, const [
        'senderMobile',
        'senderPhone',
        'sender_mobile',
      ]),
    );
  }
}

class BookingUser {
  final String? name;
  final String? mobile;

  BookingUser({this.name, this.mobile});

  factory BookingUser.fromJson(dynamic json) {
    if (json is! Map) return BookingUser();
    return BookingUser(
      name: _readString(json, const [
        'name',
        'fullName',
        'firstName',
        'customerName',
      ]),
      mobile: _readString(json, const [
        'mobile',
        'phone',
        'phoneNumber',
        'customerPhone',
      ]),
    );
  }
}

class BookingDriver {
  final String? name;
  final String? mobile;

  BookingDriver({this.name, this.mobile});

  factory BookingDriver.fromJson(dynamic json) {
    if (json is! Map) return BookingDriver();
    return BookingDriver(
      name: _readString(json, const ['name', 'fullName', 'firstName']),
      mobile: _readString(json, const ['mobile', 'phone', 'phoneNumber']),
    );
  }
}

class BookingHistoryModel {
  final String? id;
  final String? bookingId;
  final String? status;
  final String? createdAt;
  final double? totalFare;
  final double? baseFare;
  final double? distanceFare;
  final double? waitingFare;
  final double? couponDiscount;
  final double? distanceKm;
  final int? durationMin;
  final String? paymentMethod;
  final BookingLocation? pickup;
  final BookingLocation? drop;
  final BookingUser? user;
  final BookingDriver? driver;
  final String? vehicleType;
  final int? rating;
  final String? paymentStatus;

  BookingHistoryModel({
    this.id,
    this.bookingId,
    this.status,
    this.createdAt,
    this.totalFare,
    this.baseFare,
    this.distanceFare,
    this.waitingFare,
    this.couponDiscount,
    this.distanceKm,
    this.durationMin,
    this.paymentMethod,
    this.pickup,
    this.drop,
    this.user,
    this.driver,
    this.vehicleType,
    this.rating,
    this.paymentStatus,
  });

  factory BookingHistoryModel.fromJson(dynamic json) {
    if (json is! Map) return BookingHistoryModel();

    final pickupMap =
        _readMap(json, const ['pickup', 'pickupLocation', 'source']) ?? json;
    final dropMap =
        _readMap(json, const ['drop', 'dropLocation', 'destination']) ?? json;
    final fareMap = _readMap(json, const ['fare', 'pricing', 'payment']);
    final customerMap = _readMap(json, const ['user', 'customer', 'rider']);
    final driverMap = _readMap(json, const ['driver']);

    final pickup = BookingLocation.fromJson(pickupMap).copyWith(
      address:
          _readString(json, const [
            'pickupAddress',
            'pickup_address',
            'sourceAddress',
          ]) ??
          BookingLocation.fromJson(pickupMap).address,
      category:
          _readString(json, const ['category', 'vehicleCategory']) ??
          BookingLocation.fromJson(pickupMap).category,
      senderName:
          _readString(json, const ['senderName', 'customerName']) ??
          BookingLocation.fromJson(pickupMap).senderName,
      senderMobile:
          _readString(json, const ['senderMobile', 'customerMobile']) ??
          BookingLocation.fromJson(pickupMap).senderMobile,
    );

    final drop = BookingLocation.fromJson(dropMap).copyWith(
      address:
          _readString(json, const [
            'dropAddress',
            'drop_address',
            'destinationAddress',
          ]) ??
          BookingLocation.fromJson(dropMap).address,
    );

    return BookingHistoryModel(
      id: _readString(json, const ['id', '_id', 'tripId', 'rideId']),
      bookingId: _readString(json, const [
        'bookingId',
        'booking_id',
        'crn',
        'orderId',
      ]),
      status: _readString(json, const ['status', 'tripStatus', 'rideStatus']),
      createdAt: _readString(json, const [
        'createdAt',
        'created_at',
        'date',
        'bookingTime',
        'startedAt',
      ]),
      totalFare:
          _readDouble(json, const [
            'totalFare',
            'fare',
            'amount',
            'totalAmount',
            'price',
          ]) ??
          _readDouble(fareMap, const ['totalFare', 'total', 'amount']),
      baseFare:
          _readDouble(json, const ['baseFare']) ??
          _readDouble(fareMap, const ['baseFare', 'base']),
      distanceFare:
          _readDouble(json, const ['distanceFare']) ??
          _readDouble(fareMap, const ['distanceFare']),
      waitingFare:
          _readDouble(json, const ['waitingFare']) ??
          _readDouble(fareMap, const ['waitingFare']),
      couponDiscount:
          _readDouble(json, const ['couponDiscount', 'discount']) ??
          _readDouble(fareMap, const ['couponDiscount', 'discount']),
      distanceKm: _readDouble(json, const ['distanceKm', 'distance']),
      durationMin: _readInt(json, const ['durationMin', 'duration']),
      paymentMethod: _readString(json, const [
        'paymentMethod',
        'paymentMode',
        'paymentType',
      ]),
      pickup: pickup,
      drop: drop,
      user: BookingUser.fromJson(customerMap ?? json),
      driver: BookingDriver.fromJson(driverMap),
      vehicleType: _readString(json, const [
        'vehicleType',
        'carType',
        'vehicleName',
        'category',
      ]),
      rating: _readInt(json, const ['rating']),
      paymentStatus: _readString(json, const ['paymentStatus']),
    );
  }
}

extension on BookingLocation {
  BookingLocation copyWith({
    String? address,
    String? receiverName,
    String? receiverMobile,
    String? landmark,
    String? additionalDirection,
    String? category,
    String? senderName,
    String? senderMobile,
  }) {
    return BookingLocation(
      address: address ?? this.address,
      receiverName: receiverName ?? this.receiverName,
      receiverMobile: receiverMobile ?? this.receiverMobile,
      landmark: landmark ?? this.landmark,
      additionalDirection: additionalDirection ?? this.additionalDirection,
      category: category ?? this.category,
      senderName: senderName ?? this.senderName,
      senderMobile: senderMobile ?? this.senderMobile,
    );
  }
}

Map? _readMap(dynamic source, List<String> keys) {
  if (source is! Map) return null;
  for (final key in keys) {
    final value = source[key];
    if (value is Map) return value;
  }
  return null;
}

String? _readString(dynamic source, List<String> keys) {
  if (source is! Map) return null;
  for (final key in keys) {
    final value = source[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return null;
}

double? _readDouble(dynamic source, List<String> keys) {
  final text = _readString(source, keys);
  if (text == null) return null;
  return double.tryParse(text);
}

int? _readInt(dynamic source, List<String> keys) {
  final text = _readString(source, keys);
  if (text == null) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.round();
}
