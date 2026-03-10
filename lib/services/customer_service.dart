import '../models/user_model.dart';
import 'api_service.dart';

class CustomerService {
  final ApiService _apiService;

  CustomerService(this._apiService);

  /// Get customer profile
  Future<UserModel> getProfile() async {
    final response = await _apiService.get('/customer/profile');
    final data = response.data as Map<String, dynamic>;
    return UserModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update customer profile
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? avatar,
  }) async {
    final response = await _apiService.put('/customer/profile', data: {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phone != null) 'phone': phone,
      if (avatar != null) 'avatar': avatar,
    });
    final data = response.data as Map<String, dynamic>;
    return UserModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get customer addresses
  Future<List<CustomerAddress>> getAddresses() async {
    final response = await _apiService.get('/customer/addresses');
    final data = response.data as Map<String, dynamic>;
    final addressesList = data['data'] ?? [];
    return (addressesList as List<dynamic>)
        .map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Add a new address
  Future<CustomerAddress> addAddress({
    required String label,
    required String fullAddress,
    required double latitude,
    required double longitude,
    String? buildingName,
    String? unitNumber,
    String? deliveryInstructions,
    String? contactName,
    String? contactPhone,
  }) async {
    final response = await _apiService.post('/customer/addresses', data: {
      'label': label,
      'full_address': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      if (buildingName != null) 'building_name': buildingName,
      if (unitNumber != null) 'unit_number': unitNumber,
      if (deliveryInstructions != null) 'delivery_instructions': deliveryInstructions,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
    });
    final data = response.data as Map<String, dynamic>;
    return CustomerAddress.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update an address
  Future<CustomerAddress> updateAddress(String addressId, {
    String? label,
    String? fullAddress,
    double? latitude,
    double? longitude,
    String? buildingName,
    String? unitNumber,
    String? deliveryInstructions,
    String? contactName,
    String? contactPhone,
  }) async {
    final response = await _apiService.put('/customer/addresses/$addressId', data: {
      if (label != null) 'label': label,
      if (fullAddress != null) 'full_address': fullAddress,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (buildingName != null) 'building_name': buildingName,
      if (unitNumber != null) 'unit_number': unitNumber,
      if (deliveryInstructions != null) 'delivery_instructions': deliveryInstructions,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
    });
    final data = response.data as Map<String, dynamic>;
    return CustomerAddress.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Delete an address
  Future<void> deleteAddress(String addressId) async {
    await _apiService.delete('/customer/addresses/$addressId');
  }

  /// Set default address
  Future<void> setDefaultAddress(String addressId) async {
    await _apiService.post('/customer/addresses/$addressId/default');
  }

  /// Get loyalty points
  Future<LoyaltyInfo> getLoyaltyInfo() async {
    final response = await _apiService.get('/customer/loyalty');
    final data = response.data as Map<String, dynamic>;
    return LoyaltyInfo.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get loyalty history
  Future<List<LoyaltyTransaction>> getLoyaltyHistory({int page = 1}) async {
    final response = await _apiService.get('/customer/loyalty/history', queryParameters: {
      'page': page,
    });
    final data = response.data as Map<String, dynamic>;
    final historyList = data['data'] ?? [];
    return (historyList as List<dynamic>)
        .map((e) => LoyaltyTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get subscriptions
  Future<List<Subscription>> getSubscriptions() async {
    final response = await _apiService.get('/customer/subscriptions');
    final data = response.data as Map<String, dynamic>;
    final subscriptionsList = data['data'] ?? [];
    return (subscriptionsList as List<dynamic>)
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get container logs
  Future<List<ContainerLog>> getContainerLogs({int page = 1}) async {
    final response = await _apiService.get('/customer/containers', queryParameters: {
      'page': page,
    });
    final data = response.data as Map<String, dynamic>;
    final logsList = data['data'] ?? [];
    return (logsList as List<dynamic>)
        .map((e) => ContainerLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class CustomerAddress {
  final String id;
  final String label;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String? buildingName;
  final String? unitNumber;
  final String? deliveryInstructions;
  final String? contactName;
  final String? contactPhone;
  final bool isDefault;
  final String? zoneId;

  CustomerAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.buildingName,
    this.unitNumber,
    this.deliveryInstructions,
    this.contactName,
    this.contactPhone,
    this.isDefault = false,
    this.zoneId,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    // Parse latitude/longitude - can be string or num from API
    double parseCoord(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    return CustomerAddress(
      id: json['id']?.toString() ?? '',
      label: json['label'] as String? ?? json['name'] as String? ?? 'Address',
      fullAddress: json['full_address'] as String? ?? json['address'] as String? ?? '',
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      buildingName: json['building_name'] as String?,
      unitNumber: json['unit_number'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      zoneId: json['zone_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'full_address': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'building_name': buildingName,
      'unit_number': unitNumber,
      'delivery_instructions': deliveryInstructions,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'is_default': isDefault,
      'zone_id': zoneId,
    };
  }
}

class LoyaltyInfo {
  final int points;
  final int lifetimePoints;
  final String tier;
  final int pointsToNextTier;
  final double pointValue;

  LoyaltyInfo({
    required this.points,
    required this.lifetimePoints,
    required this.tier,
    required this.pointsToNextTier,
    required this.pointValue,
  });

  factory LoyaltyInfo.fromJson(Map<String, dynamic> json) {
    return LoyaltyInfo(
      points: json['points'] as int? ?? 0,
      lifetimePoints: json['lifetime_points'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'Bronze',
      pointsToNextTier: json['points_to_next_tier'] as int? ?? 0,
      pointValue: (json['point_value'] as num?)?.toDouble() ?? 0.01,
    );
  }
}

class LoyaltyTransaction {
  final String id;
  final String type;
  final int points;
  final String description;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'earn',
      points: json['points'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class Subscription {
  final String id;
  final String stationId;
  final String? stationName;
  final String productId;
  final String? productName;
  final int quantity;
  final String frequency;
  final String? preferredDay;
  final String? preferredTime;
  final String status;
  final DateTime? nextDelivery;
  final DateTime createdAt;

  Subscription({
    required this.id,
    required this.stationId,
    this.stationName,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.frequency,
    this.preferredDay,
    this.preferredTime,
    required this.status,
    this.nextDelivery,
    required this.createdAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      stationId: json['station_id']?.toString() ?? '',
      stationName: json['station']?['name'] as String? ?? json['station_name'] as String?,
      productId: json['product_id']?.toString() ?? '',
      productName: json['product']?['name'] as String? ?? json['product_name'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      frequency: json['frequency'] as String? ?? 'weekly',
      preferredDay: json['preferred_day'] as String?,
      preferredTime: json['preferred_time'] as String?,
      status: json['status'] as String? ?? 'active',
      nextDelivery: json['next_delivery'] != null
          ? DateTime.tryParse(json['next_delivery'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ContainerLog {
  final String id;
  final String type;
  final int quantity;
  final String? orderId;
  final String? notes;
  final DateTime createdAt;

  ContainerLog({
    required this.id,
    required this.type,
    required this.quantity,
    this.orderId,
    this.notes,
    required this.createdAt,
  });

  factory ContainerLog.fromJson(Map<String, dynamic> json) {
    return ContainerLog(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'borrow',
      quantity: json['quantity'] as int? ?? 0,
      orderId: json['order_id']?.toString(),
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
