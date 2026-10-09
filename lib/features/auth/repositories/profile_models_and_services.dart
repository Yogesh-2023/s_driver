class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String firstname;
  final String lastname;
  final String requirement;
  final String avatar;
  final String address;
  final double ratingAverage;
  final int ratingCount;
  final double walletBalance;
  final double walletBlockedBalance;
  final double walletPendingBalance;
  final double walletWithdrawableBalance;
  final double earningsToday;
  final double earningsMonthly;
  final double earningsYearly;
  final double earningsTotal;
  final int totalTrips;
  final int acceptedTrips;
  final double hoursOnline;
  final double acceptanceRate;
  final List<dynamic> recentTrips;
  final List<dynamic> assignedVehicles;
  final int todayTrips;
  final double todayDistanceMeters;
  final int todayOnlineSeconds;
  final double todayEarnings;
  final List<dynamic> incentives;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.firstname,
    required this.lastname,
    required this.requirement,
    required this.avatar,
    this.address = '',
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.walletBalance = 0,
    this.walletBlockedBalance = 0,
    this.walletPendingBalance = 0,
    this.walletWithdrawableBalance = 0,
    this.earningsToday = 0,
    this.earningsMonthly = 0,
    this.earningsYearly = 0,
    this.earningsTotal = 0,
    this.totalTrips = 0,
    this.acceptedTrips = 0,
    this.hoursOnline = 0,
    this.acceptanceRate = 0,
    this.recentTrips = const [],
    this.assignedVehicles = const [],
    this.todayTrips = 0,
    this.todayDistanceMeters = 0,
    this.todayOnlineSeconds = 0,
    this.todayEarnings = 0,
    this.incentives = const [],
  });

  Map<String, dynamic>? get assignedVehicle =>
      assignedVehicles.isNotEmpty && assignedVehicles.first is Map
          ? Map<String, dynamic>.from(assignedVehicles.first)
          : null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'firstname': firstname,
      'lastname': lastname,
      'requirement': requirement,
      'avatar': avatar,
      'address': address,
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
      'walletBalance': walletBalance,
      'walletBlockedBalance': walletBlockedBalance,
      'walletPendingBalance': walletPendingBalance,
      'walletWithdrawableBalance': walletWithdrawableBalance,
      'earningsToday': earningsToday,
      'earningsMonthly': earningsMonthly,
      'earningsYearly': earningsYearly,
      'earningsTotal': earningsTotal,
      'totalTrips': totalTrips,
      'acceptedTrips': acceptedTrips,
      'hoursOnline': hoursOnline,
      'acceptanceRate': acceptanceRate,
      'recentTrips': recentTrips,
      'assignedVehicles': assignedVehicles,
      'todayTrips': todayTrips,
      'todayDistanceMeters': todayDistanceMeters,
      'todayOnlineSeconds': todayOnlineSeconds,
      'todayEarnings': todayEarnings,
      'incentives': incentives,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      firstname: json['firstname']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      requirement: json['requirement']?.toString() ?? 'PERSONAL',
      avatar: json['avatar']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      walletBlockedBalance: (json['walletBlockedBalance'] as num?)?.toDouble() ?? 0.0,
      walletPendingBalance: (json['walletPendingBalance'] as num?)?.toDouble() ?? 0.0,
      walletWithdrawableBalance: (json['walletWithdrawableBalance'] as num?)?.toDouble() ?? 0.0,
      earningsToday: (json['earningsToday'] as num?)?.toDouble() ?? 0.0,
      earningsMonthly: (json['earningsMonthly'] as num?)?.toDouble() ?? 0.0,
      earningsYearly: (json['earningsYearly'] as num?)?.toDouble() ?? 0.0,
      earningsTotal: (json['earningsTotal'] as num?)?.toDouble() ?? 0.0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      acceptedTrips: (json['acceptedTrips'] as num?)?.toInt() ?? 0,
      hoursOnline: (json['hoursOnline'] as num?)?.toDouble() ?? 0.0,
      acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble() ?? 0.0,
      recentTrips: json['recentTrips'] is List ? List<dynamic>.from(json['recentTrips']) : const [],
      assignedVehicles: json['assignedVehicles'] is List ? List<dynamic>.from(json['assignedVehicles']) : const [],
      todayTrips: (json['todayTrips'] as num?)?.toInt() ?? 0,
      todayDistanceMeters: (json['todayDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      todayOnlineSeconds: (json['todayOnlineSeconds'] as num?)?.toInt() ?? 0,
      todayEarnings: (json['todayEarnings'] as num?)?.toDouble() ?? 0.0,
      incentives: json['incentives'] is List ? List<dynamic>.from(json['incentives']) : const [],
    );
  }
}

class ProfileService {
  Future<UserProfile> createProfile({
    required Map<String, String> fields,
    String? avatarPath,
  }) async {
    await Future.delayed(Duration(seconds: 1));
    return UserProfile(
      name: fields['name'] ?? '',
      email: fields['email'] ?? '',
      phone: fields['phone'] ?? '',
      firstname: fields['firstname'] ?? '',
      lastname: fields['lastname'] ?? '',
      requirement: fields['requirement'] ?? 'PERSONAL',
      avatar: avatarPath ?? '',
      address: fields['address'] ?? '',
    );
  }

  Future<UserProfile> updateProfile({
    required Map<String, String> fields,
    String? avatarPath,
  }) async {
    await Future.delayed(Duration(seconds: 1));
    return UserProfile(
      name: fields['name'] ?? '',
      email: fields['email'] ?? '',
      phone: fields['phone'] ?? '',
      firstname: fields['firstname'] ?? '',
      lastname: fields['lastname'] ?? '',
      requirement: fields['requirement'] ?? 'PERSONAL',
      avatar: avatarPath ?? '',
      address: fields['address'] ?? '',
    );
  }
}
