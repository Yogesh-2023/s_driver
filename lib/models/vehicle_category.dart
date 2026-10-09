class VehicleCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final String? imageUrl;
  final int capacity;
  final double baseFare;
  final double perKmRate;
  final double perMinuteRate;

  const VehicleCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.imageUrl,
    this.capacity = 4,
    this.baseFare = 0.0,
    this.perKmRate = 0.0,
    this.perMinuteRate = 0.0,
  });

  factory VehicleCategory.fromJson(Map<String, dynamic> json) {
    final rawCap = json['capacity'] ?? json['maxPassengers'] ?? json['seatingCapacity'] ?? 4;
    final rawBase = json['baseFare'] ?? json['base_fare'] ?? 0;
    final rawKm = json['perKmRate'] ?? json['perKilometer'] ?? json['per_km_rate'] ?? 0;
    final rawMin = json['perMinuteRate'] ?? json['perMinute'] ?? json['per_minute_rate'] ?? 0;

    final String nameStr = (json['name'] ?? json['title'] ?? json['displayName'] ?? json['slug'] ?? '').toString();
    final String slugStr = (json['slug'] ?? nameStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')).toString();

    return VehicleCategory(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: nameStr,
      slug: slugStr,
      description: json['description']?.toString(),
      iconUrl: (json['iconUrl'] ?? json['icon'] ?? json['imageUrl'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['image'] ?? json['iconUrl'] ?? '').toString(),
      capacity: rawCap is num ? rawCap.toInt() : int.tryParse(rawCap.toString()) ?? 4,
      baseFare: rawBase is num ? rawBase.toDouble() : double.tryParse(rawBase.toString()) ?? 0.0,
      perKmRate: rawKm is num ? rawKm.toDouble() : double.tryParse(rawKm.toString()) ?? 0.0,
      perMinuteRate: rawMin is num ? rawMin.toDouble() : double.tryParse(rawMin.toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'iconUrl': iconUrl,
      'imageUrl': imageUrl,
      'capacity': capacity,
      'baseFare': baseFare,
      'perKmRate': perKmRate,
      'perMinuteRate': perMinuteRate,
    };
  }

  String get value => id.isNotEmpty ? id : name;
  String get displayName => name.isNotEmpty ? name : slug;

  String get assetPath {
    if (iconUrl != null && iconUrl!.trim().isNotEmpty) return iconUrl!.trim();
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return imageUrl!.trim();
    return 'assets/images/ridenew.png';
  }

  static VehicleCategory? fromString(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final clean = input.trim();
    return VehicleCategory(
      id: clean,
      name: clean,
      slug: clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
    );
  }

  static List<VehicleCategory> get values => const [];
  static List<VehicleCategory> get all => const [];
  static List<VehicleCategory> get registrationAllowed => const [];

  static bool isRegistrationAllowed(String? input) {
    return input != null && input.trim().isNotEmpty;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleCategory &&
          runtimeType == other.runtimeType &&
          (id == other.id || slug == other.slug || name.toUpperCase() == other.name.toUpperCase());

  @override
  int get hashCode => id.hashCode ^ slug.hashCode ^ name.toUpperCase().hashCode;
}

class VehicleOptions {
  final List<VehicleCategory> categories;
  final List<String> brands;
  final List<String> models;
  final List<dynamic> years;

  const VehicleOptions({
    required this.categories,
    required this.brands,
    required this.models,
    required this.years,
  });

  factory VehicleOptions.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] : json;
    final categoriesRaw = data['categories'] ?? data['items'] ?? [];
    final catList = (categoriesRaw is List)
        ? categoriesRaw
            .whereType<Map>()
            .map((c) => VehicleCategory.fromJson(Map<String, dynamic>.from(c)))
            .toList()
        : <VehicleCategory>[];

    final brandList = (data['brands'] is List)
        ? (data['brands'] as List).map((b) => b.toString()).toList()
        : <String>[];

    final modelList = (data['models'] is List)
        ? (data['models'] as List).map((m) => m.toString()).toList()
        : <String>[];

    final yearList = (data['years'] is List)
        ? (data['years'] as List)
        : <dynamic>[];

    return VehicleOptions(
      categories: catList,
      brands: brandList,
      models: modelList,
      years: yearList,
    );
  }
}
