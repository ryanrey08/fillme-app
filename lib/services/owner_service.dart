import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import 'api_service.dart';

class OwnerService {
  final ApiService _apiService;

  OwnerService(this._apiService);

  /// Get station dashboard
  Future<StationDashboard> getDashboard() async {
    debugPrint('[OwnerService] getDashboard() called');
    final response = await _apiService.get('/station/dashboard');
    debugPrint('[OwnerService] API response: ${response.data}');
    final data = response.data as Map<String, dynamic>;
    final dashboardData = data['data'] as Map<String, dynamic>;
    debugPrint('[OwnerService] Dashboard data: $dashboardData');
    final dashboard = StationDashboard.fromJson(dashboardData);
    debugPrint('[OwnerService] Parsed dashboard: todayRevenue=${dashboard.todayRevenue}, pendingOrders=${dashboard.pendingOrders}');
    return dashboard;
  }

  /// Get station analytics
  Future<StationAnalytics> getAnalytics({String period = 'week'}) async {
    final response = await _apiService.get('/station/analytics', queryParameters: {
      'period': period,
    });
    final data = response.data as Map<String, dynamic>;
    return StationAnalytics.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get station orders
  Future<List<OrderModel>> getOrders({
    int page = 1,
    int limit = 20,
    String? status,
    String? date,
    String? driverId,
  }) async {
    final response = await _apiService.get('/orders/station', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
      if (date != null) 'date': date,
      if (driverId != null) 'driver_id': driverId,
    });
    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? [];
    return (ordersList as List<dynamic>)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Approve an order (sets status to 'confirmed')
  Future<void> approveOrder(String orderId) async {
    await _apiService.put('/orders/$orderId/status', data: {
      'status': 'confirmed',
    });
  }

  /// Reject an order (sets status to 'cancelled')
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    await _apiService.put('/orders/$orderId/status', data: {
      'status': 'cancelled',
      if (reason != null && reason.isNotEmpty) 'notes': reason,
    });
  }

  /// Assign driver to order (also sets status to out_for_delivery)
  Future<void> assignDriver(String orderId, String driverId) async {
    await _apiService.post('/orders/$orderId/assign-driver', data: {
      'driver_id': driverId,
    });
    // Update status to out_for_delivery after assigning driver
    await _apiService.put('/orders/$orderId/status', data: {
      'status': 'out_for_delivery',
    });
  }

  /// Get station inventory
  Future<List<InventoryItem>> getInventory() async {
    final response = await _apiService.get('/station/inventory');
    final data = response.data as Map<String, dynamic>;
    final inventoryList = data['data'] ?? [];
    return (inventoryList as List<dynamic>)
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update inventory
  Future<void> updateInventory(String productId, int quantity) async {
    await _apiService.put('/station/inventory/$productId', data: {
      'stock_quantity': quantity,
    });
  }

  /// Get station drivers
  Future<List<StationDriver>> getDrivers() async {
    final response = await _apiService.get('/station/drivers');
    final data = response.data as Map<String, dynamic>;
    final driversList = data['data'] ?? [];
    return (driversList as List<dynamic>)
        .map((e) => StationDriver.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get station promos
  Future<List<StationPromo>> getPromos({String? status}) async {
    final response = await _apiService.get('/station/promotions', queryParameters: {
      if (status != null) 'status': status,
    });
    final data = response.data as Map<String, dynamic>;
    final promosList = data['data'] ?? [];
    return (promosList as List<dynamic>)
        .map((e) => StationPromo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create promo
  Future<StationPromo> createPromo({
    required String name,
    required String code,
    required String type,
    required double value,
    String? description,
    double? minOrder,
    double? maxDiscount,
    int? usageLimit,
    required DateTime startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    final response = await _apiService.post('/station/promotions', data: {
      'name': name,
      'code': code,
      'type': type,
      'value': value,
      if (description != null) 'description': description,
      if (minOrder != null) 'minimum_order': minOrder,
      if (maxDiscount != null) 'maximum_discount': maxDiscount,
      if (usageLimit != null) 'usage_limit': usageLimit,
      'start_date': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T').first,
      'is_active': isActive,
    });
    final data = response.data as Map<String, dynamic>;
    return StationPromo.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update promo
  Future<StationPromo> updatePromo(String promoId, {
    String? name,
    String? code,
    String? description,
    String? type,
    double? value,
    double? minOrder,
    double? maxDiscount,
    int? usageLimit,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async {
    final response = await _apiService.put('/station/promotions/$promoId', data: {
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (minOrder != null) 'minimum_order': minOrder,
      if (maxDiscount != null) 'maximum_discount': maxDiscount,
      if (usageLimit != null) 'usage_limit': usageLimit,
      if (startDate != null) 'start_date': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T').first,
      if (isActive != null) 'is_active': isActive,
    });
    final data = response.data as Map<String, dynamic>;
    return StationPromo.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Delete promo
  Future<void> deletePromo(String promoId) async {
    await _apiService.delete('/station/promotions/$promoId');
  }

  /// Update station profile
  Future<StationSettings> updateProfile({
    String? name,
    String? description,
    String? phone,
    String? email,
    double? minimumOrder,
    double? deliveryFee,
  }) async {
    final response = await _apiService.put('/station/profile', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (minimumOrder != null) 'minimum_order': minimumOrder,
      if (deliveryFee != null) 'delivery_fee': deliveryFee,
    });
    final data = response.data as Map<String, dynamic>;
    return StationSettings.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get station settings
  Future<StationSettings> getStationSettings() async {
    final response = await _apiService.get('/station/settings');
    final data = response.data as Map<String, dynamic>;
    return StationSettings.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update operating hours
  Future<StationSettings> updateOperatingHours(Map<String, OperatingHours> hours) async {
    // Convert map format to array format expected by backend
    // Backend expects: [{ "day": 0-6, "open": "HH:mm", "close": "HH:mm", "is_closed": bool }]
    const dayMap = {
      'sunday': 0,
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
    };
    
    final hoursArray = hours.entries.map((entry) {
      final dayIndex = dayMap[entry.key.toLowerCase()] ?? 0;
      return {
        'day': dayIndex,
        'open': entry.value.openTime,
        'close': entry.value.closeTime,
        'is_closed': !entry.value.isOpen,
      };
    }).toList();
    
    // Sort by day index
    hoursArray.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
    
    final response = await _apiService.put('/station/operating-hours', data: {
      'operating_hours': hoursArray,
    });
    final data = response.data as Map<String, dynamic>;
    return StationSettings.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update delivery settings
  Future<StationSettings> updateDeliverySettings({
    double? baseDeliveryFee,
    double? minimumOrderAmount,
    double? freeDeliveryMinimum,
    bool? enableFreeDelivery,
    double? deliveryRadius,
    int? estimatedDeliveryMinutes,
  }) async {
    // Build the request data
    final Map<String, dynamic> requestData = {};
    
    // Backend expects: delivery_fee, minimum_order, delivery_radius_km, estimated_delivery_minutes
    if (baseDeliveryFee != null) requestData['delivery_fee'] = baseDeliveryFee;
    if (minimumOrderAmount != null) requestData['minimum_order'] = minimumOrderAmount;
    if (deliveryRadius != null) requestData['delivery_radius_km'] = deliveryRadius;
    if (estimatedDeliveryMinutes != null) requestData['estimated_delivery_minutes'] = estimatedDeliveryMinutes;
    
    // Store free delivery settings in delivery_settings JSON field
    if (freeDeliveryMinimum != null || enableFreeDelivery != null) {
      final Map<String, dynamic> deliverySettings = {};
      if (freeDeliveryMinimum != null) deliverySettings['free_delivery_minimum'] = freeDeliveryMinimum;
      if (enableFreeDelivery != null) deliverySettings['enable_free_delivery'] = enableFreeDelivery;
      requestData['delivery_settings'] = deliverySettings;
    }
    
    final response = await _apiService.put('/station/delivery-settings', data: requestData);
    final data = response.data as Map<String, dynamic>;
    return StationSettings.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get payment methods
  Future<PaymentSettings> getPaymentMethods() async {
    final response = await _apiService.get('/station/payment-methods');
    final data = response.data as Map<String, dynamic>;
    final paymentData = data['data'];
    
    // Handle empty array from backend
    if (paymentData is List && paymentData.isEmpty) {
      return PaymentSettings(
        codEnabled: true,
        gcashEnabled: false,
        mayaEnabled: false,
        cardEnabled: false,
      );
    }
    
    return PaymentSettings.fromJson(paymentData as Map<String, dynamic>);
  }

  /// Update payment methods
  Future<PaymentSettings> updatePaymentMethods({
    bool? codEnabled,
    bool? gcashEnabled,
    bool? mayaEnabled,
    bool? cardEnabled,
    String? gcashNumber,
    String? mayaNumber,
  }) async {
    final response = await _apiService.put('/station/payment-methods', data: {
      if (codEnabled != null) 'cash': codEnabled,
      if (gcashEnabled != null) 'gcash': gcashEnabled,
      if (mayaEnabled != null) 'maya': mayaEnabled,
      if (cardEnabled != null) 'card': cardEnabled,
    });
    final data = response.data as Map<String, dynamic>;
    final paymentData = data['data'];
    
    // Handle empty array from backend
    if (paymentData is List && paymentData.isEmpty) {
      return PaymentSettings(
        codEnabled: codEnabled ?? true,
        gcashEnabled: gcashEnabled ?? false,
        mayaEnabled: mayaEnabled ?? false,
        cardEnabled: cardEnabled ?? false,
      );
    }
    
    return PaymentSettings.fromJson(paymentData as Map<String, dynamic>);
  }

  /// Get station products
  Future<List<StationProduct>> getProducts() async {
    final response = await _apiService.get('/station/products');
    final data = response.data as Map<String, dynamic>;
    final productsList = data['data'] ?? [];
    return (productsList as List<dynamic>)
        .map((e) => StationProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get product categories
  Future<List<ProductCategory>> getCategories() async {
    final response = await _apiService.get('/station/products/categories');
    final data = response.data as Map<String, dynamic>;
    final categoriesList = data['data'] ?? [];
    return (categoriesList as List<dynamic>)
        .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create product
  Future<StationProduct> createProduct({
    required int categoryId,
    required String name,
    required double price,
    String? description,
    String? unit,
    int? stockQuantity,
    bool? isActive,
  }) async {
    final response = await _apiService.post('/station/products', data: {
      'category_id': categoryId,
      'name': name,
      'price': price,
      'unit': unit ?? 'gallon',
      if (description != null) 'description': description,
      if (stockQuantity != null) 'stock_quantity': stockQuantity,
      if (isActive != null) 'is_active': isActive,
    });
    final data = response.data as Map<String, dynamic>;
    return StationProduct.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update product
  Future<StationProduct> updateProduct(String productId, {
    int? categoryId,
    String? name,
    double? price,
    String? description,
    String? unit,
    int? stockQuantity,
    bool? isActive,
  }) async {
    final response = await _apiService.put('/station/products/$productId', data: {
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (description != null) 'description': description,
      if (unit != null) 'unit': unit,
      if (stockQuantity != null) 'stock_quantity': stockQuantity,
      if (isActive != null) 'is_active': isActive,
    });
    final data = response.data as Map<String, dynamic>;
    return StationProduct.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    await _apiService.delete('/station/products/$productId');
  }
}

class StationDashboard {
  final double todayRevenue;
  final int todayOrders;
  final int pendingOrders;
  final int activeOrders;
  final int availableDrivers;
  final int lowStockItems;
  final int openIssues;
  final double weekRevenue;
  final int weekOrders;
  final double rating;
  final int totalReviews;

  StationDashboard({
    required this.todayRevenue,
    required this.todayOrders,
    required this.pendingOrders,
    required this.activeOrders,
    required this.availableDrivers,
    required this.lowStockItems,
    required this.openIssues,
    required this.weekRevenue,
    required this.weekOrders,
    required this.rating,
    required this.totalReviews,
  });

  factory StationDashboard.fromJson(Map<String, dynamic> json) {
    final analytics = json['analytics'] as Map<String, dynamic>? ?? {};
    return StationDashboard(
      // API returns 'today_sales', map to todayRevenue
      todayRevenue: (json['today_sales'] ?? analytics['today_revenue'] ?? json['today_revenue'] as num?)?.toDouble() ?? 0,
      todayOrders: json['today_orders'] as int? ?? analytics['today_orders'] as int? ?? 0,
      // API returns 'orders_to_approve', map to pendingOrders
      pendingOrders: json['orders_to_approve'] as int? ?? json['pending_orders'] as int? ?? 0,
      activeOrders: json['active_orders'] as int? ?? 0,
      // API returns 'active_drivers', map to availableDrivers
      availableDrivers: json['active_drivers'] as int? ?? json['available_drivers'] as int? ?? 0,
      lowStockItems: json['low_stock_items'] as int? ?? 0,
      openIssues: json['open_issues'] as int? ?? 0,
      weekRevenue: (analytics['week_revenue'] ?? json['week_revenue'] as num?)?.toDouble() ?? 0,
      weekOrders: analytics['week_orders'] as int? ?? json['week_orders'] as int? ?? 0,
      rating: (json['station']?['rating'] ?? json['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['station']?['total_reviews'] as int? ?? json['total_reviews'] as int? ?? 0,
    );
  }

  StationDashboard copyWith({
    double? todayRevenue,
    int? todayOrders,
    int? pendingOrders,
    int? activeOrders,
    int? availableDrivers,
    int? lowStockItems,
    int? openIssues,
    double? weekRevenue,
    int? weekOrders,
    double? rating,
    int? totalReviews,
  }) {
    return StationDashboard(
      todayRevenue: todayRevenue ?? this.todayRevenue,
      todayOrders: todayOrders ?? this.todayOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      activeOrders: activeOrders ?? this.activeOrders,
      availableDrivers: availableDrivers ?? this.availableDrivers,
      lowStockItems: lowStockItems ?? this.lowStockItems,
      openIssues: openIssues ?? this.openIssues,
      weekRevenue: weekRevenue ?? this.weekRevenue,
      weekOrders: weekOrders ?? this.weekOrders,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }
}

class StationAnalytics {
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final int newCustomers;
  final int returningCustomers;
  final List<RevenuePeriod> revenueByPeriod;
  final List<TopProduct> topProducts;

  StationAnalytics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.newCustomers,
    required this.returningCustomers,
    required this.revenueByPeriod,
    required this.topProducts,
  });

  factory StationAnalytics.fromJson(Map<String, dynamic> json) {
    return StationAnalytics(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      averageOrderValue: (json['average_order_value'] as num?)?.toDouble() ?? 0,
      newCustomers: json['new_customers'] as int? ?? 0,
      returningCustomers: json['returning_customers'] as int? ?? 0,
      revenueByPeriod: (json['revenue_by_period'] as List<dynamic>?)
              ?.map((e) => RevenuePeriod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topProducts: (json['top_products'] as List<dynamic>?)
              ?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RevenuePeriod {
  final String period;
  final double revenue;
  final int orders;

  RevenuePeriod({
    required this.period,
    required this.revenue,
    required this.orders,
  });

  factory RevenuePeriod.fromJson(Map<String, dynamic> json) {
    return RevenuePeriod(
      period: json['period'] as String? ?? json['date'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      orders: json['orders'] as int? ?? 0,
    );
  }
}

class TopProduct {
  final String id;
  final String name;
  final int quantity;
  final double revenue;

  TopProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String? imageUrl;
  final int stockQuantity;
  final int lowStockThreshold;
  final String unit;
  final double price;
  final bool isLowStock;

  InventoryItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.unit,
    required this.price,
    required this.isLowStock,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final stockQty = json['stock_quantity'] as int? ?? 0;
    final threshold = json['low_stock_threshold'] as int? ?? 10;
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      stockQuantity: stockQty,
      lowStockThreshold: threshold,
      unit: json['unit'] as String? ?? 'gallon',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isLowStock: stockQty <= threshold,
    );
  }
}

class StationDriver {
  final String id;
  final String name;
  final String? phone;
  final String? avatar;
  final bool isOnline;
  final bool isAvailable;
  final int activeDeliveries;
  final int completedToday;
  final double rating;
  final double? currentLat;
  final double? currentLng;

  StationDriver({
    required this.id,
    required this.name,
    this.phone,
    this.avatar,
    required this.isOnline,
    required this.isAvailable,
    required this.activeDeliveries,
    required this.completedToday,
    required this.rating,
    this.currentLat,
    this.currentLng,
  });

  factory StationDriver.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    
    // Parse status to determine online/available
    final status = json['status'] as String? ?? '';
    final isOnline = status == 'available' || status == 'busy';
    final isAvailable = status == 'available';
    
    // Parse rating (can be string or num)
    double rating = 0;
    if (json['rating'] != null) {
      rating = double.tryParse(json['rating'].toString()) ?? 0;
    }
    
    // Parse lat/lng (can be string or num)
    double? currentLat;
    double? currentLng;
    if (json['current_lat'] != null) {
      currentLat = double.tryParse(json['current_lat'].toString());
    }
    if (json['current_lng'] != null) {
      currentLng = double.tryParse(json['current_lng'].toString());
    }
    
    return StationDriver(
      id: json['id']?.toString() ?? '',
      name: user != null
          ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
          : json['name'] as String? ?? '',
      phone: user?['phone'] as String? ?? json['phone'] as String?,
      avatar: user?['avatar'] as String? ?? json['avatar'] as String?,
      isOnline: json['is_online'] as bool? ?? isOnline,
      isAvailable: json['is_available'] as bool? ?? json['is_active'] as bool? ?? isAvailable,
      activeDeliveries: json['active_deliveries'] as int? ?? 0,
      completedToday: json['completed_today'] as int? ?? 0,
      rating: rating,
      currentLat: currentLat,
      currentLng: currentLng,
    );
  }
}

class StationPromo {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String type;
  final double value;
  final double? minOrder;
  final double? maxDiscount;
  final int? usageLimit;
  final int usageCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  StationPromo({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.type,
    required this.value,
    this.minOrder,
    this.maxDiscount,
    this.usageLimit,
    required this.usageCount,
    this.startDate,
    this.endDate,
    required this.isActive,
  });

  factory StationPromo.fromJson(Map<String, dynamic> json) {
    return StationPromo(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'percentage',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      minOrder: (json['minimum_order'] as num?)?.toDouble(),
      maxDiscount: (json['maximum_discount'] as num?)?.toDouble(),
      usageLimit: json['usage_limit'] as int?,
      usageCount: json['usage_count'] as int? ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get status {
    if (!isActive) return 'inactive';
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return 'scheduled';
    if (endDate != null && now.isAfter(endDate!)) return 'expired';
    if (usageLimit != null && usageCount >= usageLimit!) return 'exhausted';
    return 'active';
  }
}

/// Station Settings model
class StationSettings {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? zoneId;
  final String? zoneName;
  final String? zoneCity;
  final String? zoneBarangay;
  final double minimumOrderAmount;
  final double baseDeliveryFee;
  final double? freeDeliveryMinimum;
  final bool enableFreeDelivery;
  final double deliveryRadius;
  final Map<String, OperatingHours> operatingHours;
  final bool isActive;
  final DateTime? createdAt;

  StationSettings({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.phone,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
    this.zoneId,
    this.zoneName,
    this.zoneCity,
    this.zoneBarangay,
    required this.minimumOrderAmount,
    required this.baseDeliveryFee,
    this.freeDeliveryMinimum,
    required this.enableFreeDelivery,
    required this.deliveryRadius,
    required this.operatingHours,
    required this.isActive,
    this.createdAt,
  });

  factory StationSettings.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Day index to name mapping
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

    // Parse operating hours - handle both array and map formats
    Map<String, OperatingHours> hours = {};
    final hoursData = json['operating_hours'];
    
    if (hoursData is List) {
      // API returns array format: [{ "day": 0-6, "open": "HH:mm", "close": "HH:mm", "is_closed": bool }]
      for (final item in hoursData) {
        if (item is Map<String, dynamic>) {
          final dayIndex = item['day'] as int? ?? 0;
          final dayName = dayNames[dayIndex.clamp(0, 6)];
          hours[dayName] = OperatingHours(
            isOpen: !(item['is_closed'] as bool? ?? false),
            openTime: item['open'] as String? ?? '06:00',
            closeTime: item['close'] as String? ?? '21:00',
          );
        }
      }
    } else if (hoursData is Map<String, dynamic>) {
      // Legacy map format: { "monday": { "is_open": true, "open_time": "HH:mm", ... } }
      hoursData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          hours[key] = OperatingHours.fromJson(value);
        }
      });
    }

    // If no hours from API, create default hours
    if (hours.isEmpty) {
      for (final day in dayNames) {
        hours[day] = OperatingHours(isOpen: true, openTime: '06:00', closeTime: '21:00');
      }
    }

    // Parse delivery_settings JSON for free delivery options
    // Handle both Map and empty array [] from API
    Map<String, dynamic> deliverySettings = {};
    if (json['delivery_settings'] is Map<String, dynamic>) {
      deliverySettings = json['delivery_settings'] as Map<String, dynamic>;
    }

    return StationSettings(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String? ?? json['logo'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      zoneId: json['zone_id'] as int?,
      zoneName: json['zone_name'] as String?,
      zoneCity: json['zone_city'] as String?,
      zoneBarangay: json['zone_barangay'] as String?,
      minimumOrderAmount: parseDouble(json['minimum_order_amount'] ?? json['minimum_order']),
      baseDeliveryFee: parseDouble(json['base_delivery_fee'] ?? json['delivery_fee']),
      freeDeliveryMinimum: deliverySettings['free_delivery_minimum'] != null 
          ? parseDouble(deliverySettings['free_delivery_minimum']) 
          : (json['free_delivery_minimum'] != null ? parseDouble(json['free_delivery_minimum']) : null),
      enableFreeDelivery: deliverySettings['enable_free_delivery'] as bool? 
          ?? json['enable_free_delivery'] as bool? 
          ?? false,
      deliveryRadius: parseDouble(json['delivery_radius'] ?? json['delivery_radius_km']),
      operatingHours: hours,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Operating hours for a single day
class OperatingHours {
  final bool isOpen;
  final String openTime;
  final String closeTime;

  OperatingHours({
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  factory OperatingHours.fromJson(Map<String, dynamic> json) {
    return OperatingHours(
      isOpen: json['is_open'] as bool? ?? true,
      openTime: json['open_time'] as String? ?? '06:00',
      closeTime: json['close_time'] as String? ?? '21:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_open': isOpen,
      'open_time': openTime,
      'close_time': closeTime,
    };
  }

  OperatingHours copyWith({
    bool? isOpen,
    String? openTime,
    String? closeTime,
  }) {
    return OperatingHours(
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}

/// Payment settings model
class PaymentSettings {
  final bool codEnabled;
  final bool gcashEnabled;
  final bool mayaEnabled;
  final bool cardEnabled;
  final String? gcashNumber;
  final String? mayaNumber;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;

  PaymentSettings({
    required this.codEnabled,
    required this.gcashEnabled,
    required this.mayaEnabled,
    required this.cardEnabled,
    this.gcashNumber,
    this.mayaNumber,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
  });

  factory PaymentSettings.fromJson(Map<String, dynamic> json) {
    return PaymentSettings(
      codEnabled: json['cod_enabled'] as bool? ?? json['cash'] as bool? ?? true,
      gcashEnabled: json['gcash_enabled'] as bool? ?? json['gcash'] as bool? ?? false,
      mayaEnabled: json['maya_enabled'] as bool? ?? json['maya'] as bool? ?? false,
      cardEnabled: json['card_enabled'] as bool? ?? json['card'] as bool? ?? false,
      gcashNumber: json['gcash_number'] as String?,
      mayaNumber: json['maya_number'] as String?,
      bankName: json['bank_name'] as String?,
      bankAccountName: json['bank_account_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
    );
  }

  PaymentSettings copyWith({
    bool? codEnabled,
    bool? gcashEnabled,
    bool? mayaEnabled,
    bool? cardEnabled,
    String? gcashNumber,
    String? mayaNumber,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
  }) {
    return PaymentSettings(
      codEnabled: codEnabled ?? this.codEnabled,
      gcashEnabled: gcashEnabled ?? this.gcashEnabled,
      mayaEnabled: mayaEnabled ?? this.mayaEnabled,
      cardEnabled: cardEnabled ?? this.cardEnabled,
      gcashNumber: gcashNumber ?? this.gcashNumber,
      mayaNumber: mayaNumber ?? this.mayaNumber,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }
}

/// Station product model
class StationProduct {
  final String id;
  final int? categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double price;
  final String unit;
  final String? imageUrl;
  final int stockQuantity;
  final bool isActive;
  final DateTime? createdAt;

  StationProduct({
    required this.id,
    this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.price,
    required this.unit,
    this.imageUrl,
    required this.stockQuantity,
    required this.isActive,
    this.createdAt,
  });

  factory StationProduct.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    // Parse category data
    final category = json['category'] as Map<String, dynamic>?;

    return StationProduct(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id'] as int?,
      categoryName: category?['name'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parseDouble(json['price']),
      unit: json['unit'] as String? ?? 'gallon',
      imageUrl: json['image_url'] as String? ?? json['image'] as String?,
      stockQuantity: parseInt(json['stock_quantity']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  StationProduct copyWith({
    String? id,
    int? categoryId,
    String? categoryName,
    String? name,
    String? description,
    double? price,
    String? unit,
    String? imageUrl,
    int? stockQuantity,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return StationProduct(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Product Category model
class ProductCategory {
  final int id;
  final String name;

  ProductCategory({
    required this.id,
    required this.name,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
    );
  }
}
