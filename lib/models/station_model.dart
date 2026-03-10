import 'package:equatable/equatable.dart';

class StationModel extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final String? ownerName;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? email;
  final String? description;
  final String? imageUrl;
  final List<String> zones;
  final bool isActive;
  final bool isVerified;
  final double rating;
  final int totalReviews;
  final String? openTime;
  final String? closeTime;
  final List<String> operatingDays;
  final double? deliveryRadius;
  final double? minimumOrder;
  final double? deliveryFee;
  final double? distance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StationModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.ownerName,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.email,
    this.description,
    this.imageUrl,
    this.zones = const [],
    this.isActive = true,
    this.isVerified = false,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.openTime,
    this.closeTime,
    this.operatingDays = const [],
    this.deliveryRadius,
    this.minimumOrder,
    this.deliveryFee,
    this.distance,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen {
    if (openTime == null || closeTime == null) return true;
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday).toLowerCase();
    
    // Check if today is an operating day (case-insensitive)
    final isOperatingDay = operatingDays.isEmpty || 
        operatingDays.any((day) => day.toLowerCase() == currentDay);
    if (!isOperatingDay) return false;
    
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return currentTime.compareTo(openTime!) >= 0 && 
           currentTime.compareTo(closeTime!) <= 0;
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  factory StationModel.fromJson(Map<String, dynamic> json) {
    // Handle latitude/longitude as either num or string
    double parseCoordinate(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Parse operating_hours to extract open/close times
    String? openTime;
    String? closeTime;
    List<String> operatingDays = [];
    if (json['operating_hours'] != null && json['operating_hours'] is Map) {
      final hours = json['operating_hours'] as Map<String, dynamic>;
      operatingDays = hours.keys.map((k) => k.toString()).toList();
      // Get Monday hours as default, or first available
      final firstDay = hours.values.first as Map<String, dynamic>?;
      if (firstDay != null) {
        openTime = firstDay['open'] as String?;
        closeTime = firstDay['close'] as String?;
      }
    } else {
      openTime = json['open_time'] as String?;
      closeTime = json['close_time'] as String?;
      operatingDays = (json['operating_days'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
    }

    // Parse zones - could be list or zone_id
    List<String> zones = [];
    if (json['zones'] != null && json['zones'] is List) {
      zones = (json['zones'] as List<dynamic>).map((e) => e.toString()).toList();
    } else if (json['zone_id'] != null) {
      zones = [json['zone_id'].toString()];
    }

    return StationModel(
      id: json['uuid']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? json['business_name'] as String? ?? '',
      ownerId: json['owner_id']?.toString() ?? json['user_id']?.toString() ?? '',
      ownerName: json['owner_name'] as String?,
      address: json['address'] as String? ?? '',
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String? ?? json['logo'] as String? ?? json['banner'] as String?,
      zones: zones,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['verification_status'] == 'verified' || (json['is_verified'] as bool? ?? false),
      rating: (json['rating'] is String) 
          ? double.tryParse(json['rating']) ?? 0.0 
          : (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      openTime: openTime,
      closeTime: closeTime,
      operatingDays: operatingDays,
      deliveryRadius: (json['delivery_radius'] as num?)?.toDouble(),
      minimumOrder: (json['minimum_order'] is String)
          ? double.tryParse(json['minimum_order']) ?? 0.0
          : (json['minimum_order'] as num?)?.toDouble(),
      deliveryFee: (json['delivery_fee'] is String)
          ? double.tryParse(json['delivery_fee']) ?? 0.0
          : (json['delivery_fee'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'description': description,
      'image_url': imageUrl,
      'zones': zones,
      'is_active': isActive,
      'is_verified': isVerified,
      'rating': rating,
      'total_reviews': totalReviews,
      'open_time': openTime,
      'close_time': closeTime,
      'operating_days': operatingDays,
      'delivery_radius': deliveryRadius,
      'minimum_order': minimumOrder,
      'delivery_fee': deliveryFee,
      'distance': distance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StationModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? ownerName,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    String? description,
    String? imageUrl,
    List<String>? zones,
    bool? isActive,
    bool? isVerified,
    double? rating,
    int? totalReviews,
    String? openTime,
    String? closeTime,
    List<String>? operatingDays,
    double? deliveryRadius,
    double? minimumOrder,
    double? deliveryFee,
    double? distance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      zones: zones ?? this.zones,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      operatingDays: operatingDays ?? this.operatingDays,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      minimumOrder: minimumOrder ?? this.minimumOrder,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      distance: distance ?? this.distance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        ownerId,
        ownerName,
        address,
        latitude,
        longitude,
        phone,
        email,
        description,
        imageUrl,
        zones,
        isActive,
        isVerified,
        rating,
        totalReviews,
        openTime,
        closeTime,
        operatingDays,
        deliveryRadius,
        minimumOrder,
        deliveryFee,
        distance,
        createdAt,
        updatedAt,
      ];
}
