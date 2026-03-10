import 'package:equatable/equatable.dart';

enum PromoType {
  percentage,
  fixedAmount,
  freeDelivery,
  freeItem,
  buyOneGetOne,
}

class PromoModel extends Equatable {
  final String id;
  final String stationId;
  final String code;
  final String name;
  final String? description;
  final PromoType type;
  final double value;
  final double? minOrderAmount;
  final double? maxDiscount;
  final int? usageLimit;
  final int usedCount;
  final List<String> applicableZones;
  final List<String> applicableProducts;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromoModel({
    required this.id,
    required this.stationId,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    required this.value,
    this.minOrderAmount,
    this.maxDiscount,
    this.usageLimit,
    this.usedCount = 0,
    this.applicableZones = const [],
    this.applicableProducts = const [],
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isValid {
    final now = DateTime.now();
    return isActive && 
           now.isAfter(startDate) && 
           now.isBefore(endDate) &&
           (usageLimit == null || usedCount < usageLimit!);
  }

  String get typeDisplayName {
    switch (type) {
      case PromoType.percentage:
        return '${value.toStringAsFixed(0)}% Off';
      case PromoType.fixedAmount:
        return '₱${value.toStringAsFixed(2)} Off';
      case PromoType.freeDelivery:
        return 'Free Delivery';
      case PromoType.freeItem:
        return 'Free Item';
      case PromoType.buyOneGetOne:
        return 'Buy 1 Get 1';
    }
  }

  double calculateDiscount(double orderAmount) {
    if (!isValid) return 0;
    if (minOrderAmount != null && orderAmount < minOrderAmount!) return 0;

    double discount = 0;
    switch (type) {
      case PromoType.percentage:
        discount = orderAmount * (value / 100);
        break;
      case PromoType.fixedAmount:
        discount = value;
        break;
      case PromoType.freeDelivery:
      case PromoType.freeItem:
      case PromoType.buyOneGetOne:
        discount = 0;
        break;
    }

    if (maxDiscount != null && discount > maxDiscount!) {
      discount = maxDiscount!;
    }

    return discount;
  }

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values that might be strings
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    // Map discount_type from API to PromoType
    PromoType type = PromoType.percentage;
    final typeStr = json['type'] ?? json['discount_type'];
    if (typeStr != null) {
      final typeMap = {
        'percentage': PromoType.percentage,
        'fixed': PromoType.fixedAmount,
        'fixedAmount': PromoType.fixedAmount,
        'free_delivery': PromoType.freeDelivery,
        'freeDelivery': PromoType.freeDelivery,
        'free_item': PromoType.freeItem,
        'freeItem': PromoType.freeItem,
        'bogo': PromoType.buyOneGetOne,
        'buyOneGetOne': PromoType.buyOneGetOne,
      };
      type = typeMap[typeStr] ?? PromoType.percentage;
    }

    return PromoModel(
      id: json['id']?.toString() ?? '',
      stationId: json['station_id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? json['code'] as String? ?? '',
      description: json['description'] as String?,
      type: type,
      value: parseDouble(json['value'] ?? json['discount_value']),
      minOrderAmount: parseDoubleNullable(json['min_order_amount']),
      maxDiscount: parseDoubleNullable(json['max_discount']),
      usageLimit: json['usage_limit'] as int? ?? json['max_uses'] as int?,
      usedCount: json['used_count'] as int? ?? json['times_used'] as int? ?? 0,
      applicableZones: (json['applicable_zones'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      applicableProducts: (json['applicable_products'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? json['starts_at']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? json['ends_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'code': code,
      'name': name,
      'description': description,
      'type': type.name,
      'value': value,
      'min_order_amount': minOrderAmount,
      'max_discount': maxDiscount,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'applicable_zones': applicableZones,
      'applicable_products': applicableProducts,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        stationId,
        code,
        name,
        description,
        type,
        value,
        minOrderAmount,
        maxDiscount,
        usageLimit,
        usedCount,
        applicableZones,
        applicableProducts,
        startDate,
        endDate,
        isActive,
        createdAt,
        updatedAt,
      ];
}

class LoyaltyModel extends Equatable {
  final String id;
  final String userId;
  final int totalPoints;
  final int availablePoints;
  final int redeemedPoints;
  final String tier;
  final double pointsToNextTier;
  final List<LoyaltyTransaction> transactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoyaltyModel({
    required this.id,
    required this.userId,
    required this.totalPoints,
    required this.availablePoints,
    this.redeemedPoints = 0,
    this.tier = 'Bronze',
    this.pointsToNextTier = 0,
    this.transactions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoyaltyModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      totalPoints: json['total_points'] as int,
      availablePoints: json['available_points'] as int,
      redeemedPoints: json['redeemed_points'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'Bronze',
      pointsToNextTier: (json['points_to_next_tier'] as num?)?.toDouble() ?? 0,
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => LoyaltyTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_points': totalPoints,
      'available_points': availablePoints,
      'redeemed_points': redeemedPoints,
      'tier': tier,
      'points_to_next_tier': pointsToNextTier,
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        totalPoints,
        availablePoints,
        redeemedPoints,
        tier,
        pointsToNextTier,
        transactions,
        createdAt,
        updatedAt,
      ];
}

class LoyaltyTransaction extends Equatable {
  final String id;
  final String type;
  final int points;
  final String description;
  final String? orderId;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    this.orderId,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      points: json['points'] as int,
      description: json['description'] as String,
      orderId: json['order_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'points': points,
      'description': description,
      'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, type, points, description, orderId, createdAt];
}
