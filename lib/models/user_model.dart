import 'package:equatable/equatable.dart';

enum UserRole { customer, driver, owner }

class UserModel extends Equatable {
  final String id;
  final String email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final UserRole role;
  final String? profileImage;
  final bool isVerified;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Customer-specific fields
  final int? loyaltyPoints;
  final double? containerDeposit;
  final String? referralCode;
  
  // Driver-specific fields
  final String? driverId;  // The ID from the drivers table (for WebSocket channels)
  final String? vehicleType;
  final String? vehiclePlate;
  final String? licenseNumber;
  final bool? isOnline;
  final double? currentLatitude;
  final double? currentLongitude;
  
  // Owner-specific fields
  final String? stationId;

  const UserModel({
    required this.id,
    required this.email,
    this.phone,
    this.firstName,
    this.lastName,
    required this.role,
    this.profileImage,
    this.isVerified = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.loyaltyPoints,
    this.containerDeposit,
    this.referralCode,
    this.driverId,
    this.vehicleType,
    this.vehiclePlate,
    this.licenseNumber,
    this.isOnline,
    this.currentLatitude,
    this.currentLongitude,
    this.stationId,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  
  String get roleDisplayName {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.driver:
        return 'Driver';
      case UserRole.owner:
        return 'Owner';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle id as either int or string, with fallback
    final idValue = json['id'] ?? json['uuid'];
    final id = idValue != null 
        ? (idValue is int ? idValue.toString() : idValue.toString())
        : '';
    
    // Handle role from 'role' or 'user_type' field
    final roleStr = (json['role'] ?? json['user_type'] ?? 'customer')?.toString() ?? 'customer';
    
    // Map API user_type values to our UserRole enum
    UserRole role;
    switch (roleStr) {
      case 'station_staff':
      case 'station_owner':
      case 'owner':
        role = UserRole.owner;
        break;
      case 'driver':
      case 'delivery_driver':
        role = UserRole.driver;
        break;
      case 'customer':
      default:
        role = UserRole.customer;
    }
    
    // Extract driver ID from nested driver object (for WebSocket channel subscriptions)
    String? driverId;
    final driverData = json['driver'];
    if (driverData != null && driverData is Map<String, dynamic>) {
      final driverIdValue = driverData['id'];
      driverId = driverIdValue != null ? driverIdValue.toString() : null;
    }
    
    return UserModel(
      id: id,
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: role,
      profileImage: (json['profile_image'] ?? json['avatar']) as String?,
      isVerified: json['email_verified_at'] != null || (json['is_verified'] as bool? ?? false),
      isActive: json['status'] == 'active' || (json['is_active'] as bool? ?? true),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      loyaltyPoints: json['loyalty_points'] as int?,
      containerDeposit: (json['container_deposit'] as num?)?.toDouble(),
      referralCode: json['referral_code'] as String?,
      driverId: driverId,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      licenseNumber: json['license_number'] as String?,
      isOnline: json['is_online'] as bool?,
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      stationId: json['station_id'] != null ? json['station_id'].toString() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'role': role.name,
      'profile_image': profileImage,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'loyalty_points': loyaltyPoints,
      'container_deposit': containerDeposit,
      'referral_code': referralCode,
      'driver': driverId != null ? {'id': driverId} : null,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'license_number': licenseNumber,
      'is_online': isOnline,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'station_id': stationId,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    UserRole? role,
    String? profileImage,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? loyaltyPoints,
    double? containerDeposit,
    String? referralCode,
    String? driverId,
    String? vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
    bool? isOnline,
    double? currentLatitude,
    double? currentLongitude,
    String? stationId,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      containerDeposit: containerDeposit ?? this.containerDeposit,
      referralCode: referralCode ?? this.referralCode,
      driverId: driverId ?? this.driverId,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isOnline: isOnline ?? this.isOnline,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      stationId: stationId ?? this.stationId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        phone,
        firstName,
        lastName,
        role,
        profileImage,
        isVerified,
        isActive,
        createdAt,
        updatedAt,
        loyaltyPoints,
        containerDeposit,
        referralCode,
        driverId,
        vehicleType,
        vehiclePlate,
        licenseNumber,
        isOnline,
        currentLatitude,
        currentLongitude,
        stationId,
      ];
}

// Guest User Model for local-only usage
class GuestUser {
  final String localId;
  final List<AddressModel> addresses;
  final List<String> cartItems;
  final DateTime createdAt;

  GuestUser({
    required this.localId,
    this.addresses = const [],
    this.cartItems = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GuestUser.fromJson(Map<String, dynamic> json) {
    return GuestUser(
      localId: json['local_id'] as String,
      addresses: (json['addresses'] as List<dynamic>?)
              ?.map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cartItems: (json['cart_items'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'addresses': addresses.map((e) => e.toJson()).toList(),
      'cart_items': cartItems,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AddressModel extends Equatable {
  final String id;
  final String label;
  final String fullAddress;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  final String? zipCode;
  final double latitude;
  final double longitude;
  final String? notes;
  final String? landmark;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.zipCode,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.landmark,
    this.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      label: json['label'] as String,
      fullAddress: json['full_address'] as String,
      street: json['street'] as String?,
      barangay: json['barangay'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      zipCode: json['zip_code'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      notes: json['notes'] as String?,
      landmark: json['landmark'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'full_address': fullAddress,
      'street': street,
      'barangay': barangay,
      'city': city,
      'province': province,
      'zip_code': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'landmark': landmark,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? zipCode,
    double? latitude,
    double? longitude,
    String? notes,
    String? landmark,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      landmark: landmark ?? this.landmark,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        fullAddress,
        street,
        barangay,
        city,
        province,
        zipCode,
        latitude,
        longitude,
        notes,
        landmark,
        isDefault,
      ];
}
