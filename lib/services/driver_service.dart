import '../models/order_model.dart';
import 'api_service.dart';

class DriverService {
  final ApiService _apiService;

  DriverService(this._apiService);

  /// Get driver dashboard data
  Future<DriverDashboard> getDashboard() async {
    final response = await _apiService.get('/driver/dashboard');
    final data = response.data as Map<String, dynamic>;
    print('=== DRIVER DASHBOARD API RESPONSE ===');
    print('Raw data: $data');
    final dashboardData = data['data'] as Map<String, dynamic>;
    print('Dashboard data: $dashboardData');
    print('=====================================');
    return DriverDashboard.fromJson(dashboardData);
  }

  /// Update driver status (online/offline)
  /// Returns true if status is now 'available'
  Future<bool> updateStatus(bool isOnline) async {
    print('=== UPDATE STATUS ===');
    print('Setting status to: ${isOnline ? 'available' : 'offline'}');
    final response = await _apiService.put('/driver/status', data: {
      'status': isOnline ? 'available' : 'offline',
    });
    print('Status update response: ${response.data}');
    print('=====================');
    
    // Parse response to get actual status
    final data = response.data as Map<String, dynamic>;
    final driverData = data['data'] as Map<String, dynamic>?;
    if (driverData != null) {
      final status = driverData['status'] as String?;
      return status == 'available';
    }
    return isOnline;
  }

  /// Update driver location
  Future<void> updateLocation(double latitude, double longitude) async {
    await _apiService.post('/driver/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Get delivery queue
  Future<List<OrderModel>> getDeliveryQueue() async {
    final response = await _apiService.get('/driver/queue');
    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? [];
    return (ordersList as List<dynamic>)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update delivery status
  Future<OrderModel> updateDeliveryStatus(
    String deliveryId, 
    String status, {
    String? proofImageUrl,
    String? signature,
    double? collectedAmount,
  }) async {
    final response = await _apiService.put('/driver/deliveries/$deliveryId/status', data: {
      'status': status,
      if (proofImageUrl != null) 'proof_image': proofImageUrl,
      if (signature != null) 'signature': signature,
      if (collectedAmount != null) 'collected_amount': collectedAmount,
    });
    final data = response.data as Map<String, dynamic>;
    return OrderModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get delivery route
  Future<DeliveryRoute> getDeliveryRoute(String deliveryId) async {
    final response = await _apiService.get('/driver/deliveries/$deliveryId/route');
    final data = response.data as Map<String, dynamic>;
    return DeliveryRoute.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get earnings
  Future<DriverEarnings> getEarnings({String period = 'week'}) async {
    final response = await _apiService.get('/driver/earnings', queryParameters: {
      'period': period,
    });
    final data = response.data as Map<String, dynamic>;
    // Handle both nested data and root level data
    final earningsData = data['data'] ?? data;
    // Debug: Print the raw API response to see what fields are returned
    print('=== DRIVER EARNINGS API RESPONSE ===');
    print('Raw data: $data');
    print('Earnings data: $earningsData');
    print('====================================');
    return DriverEarnings.fromJson(earningsData as Map<String, dynamic>);
  }

  /// Get deliveries by status (for driver)
  Future<List<OrderModel>> getDeliveriesByStatus(String? status) async {
    final response = await _apiService.get('/orders', queryParameters: {
      if (status != null) 'status': status,
    });
    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? [];
    return (ordersList as List<dynamic>)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get delivery history
  Future<DeliveryHistoryResponse> getDeliveryHistory({
    String? status,
    String period = 'all',
  }) async {
    final response = await _apiService.get('/driver/deliveries/history', queryParameters: {
      if (status != null) 'status': status,
      'period': period,
    });
    final data = response.data as Map<String, dynamic>;
    return DeliveryHistoryResponse.fromJson(data);
  }

  /// Get work schedule
  Future<WorkSchedule> getSchedule() async {
    final response = await _apiService.get('/driver/schedule');
    final data = response.data as Map<String, dynamic>;
    return WorkSchedule.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update work schedule
  Future<WorkSchedule> updateSchedule(Map<String, DaySchedule> schedule) async {
    final scheduleMap = schedule.map((key, value) => MapEntry(key, value.toJson()));
    final response = await _apiService.put('/driver/schedule', data: {
      'schedule': scheduleMap,
    });
    final data = response.data as Map<String, dynamic>;
    return WorkSchedule.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get service areas
  Future<ServiceAreasResponse> getServiceAreas() async {
    final response = await _apiService.get('/driver/service-areas');
    final data = response.data as Map<String, dynamic>;
    return ServiceAreasResponse.fromJson(data['data'] as Map<String, dynamic>);
  }
}

class DriverDashboard {
  final bool isOnline;
  final int pendingDeliveries;
  final int completedToday;
  final double earningsToday;
  final double rating;
  final int totalDeliveries;

  DriverDashboard({
    required this.isOnline,
    required this.pendingDeliveries,
    required this.completedToday,
    required this.earningsToday,
    required this.rating,
    required this.totalDeliveries,
  });

  DriverDashboard copyWith({
    bool? isOnline,
    int? pendingDeliveries,
    int? completedToday,
    double? earningsToday,
    double? rating,
    int? totalDeliveries,
  }) {
    return DriverDashboard(
      isOnline: isOnline ?? this.isOnline,
      pendingDeliveries: pendingDeliveries ?? this.pendingDeliveries,
      completedToday: completedToday ?? this.completedToday,
      earningsToday: earningsToday ?? this.earningsToday,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
    );
  }

  factory DriverDashboard.fromJson(Map<String, dynamic> json) {
    print('=== PARSING DRIVER DASHBOARD ===');
    print('Keys: ${json.keys.toList()}');
    print('status field: ${json['status']}');
    print('is_online field: ${json['is_online']}');
    print('driver field: ${json['driver']}');
    
    // Helper to parse int that might be string
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }
    
    // Helper to parse double that might be string
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }
    
    // Handle status field - API returns 'available', 'busy', 'offline'
    // Also check for is_online boolean for backwards compatibility
    bool isOnline = false;
    if (json['is_online'] != null) {
      isOnline = json['is_online'] as bool;
    } else if (json['status'] != null) {
      isOnline = json['status'] == 'available';
    } else if (json['driver'] != null && json['driver'] is Map) {
      final driver = json['driver'] as Map<String, dynamic>;
      isOnline = driver['status'] == 'available';
    }
    
    print('Parsed isOnline: $isOnline');
    print('================================');
    
    // Handle nested today_stats
    final todayStats = json['today_stats'] as Map<String, dynamic>? ?? {};
    
    return DriverDashboard(
      isOnline: isOnline,
      pendingDeliveries: parseInt(json['pending_deliveries']),
      completedToday: parseInt(todayStats['completed'] ?? json['completed_today']),
      earningsToday: parseDouble(todayStats['earnings'] ?? json['earnings_today']),
      rating: parseDouble(json['rating'] ?? (json['driver'] is Map ? (json['driver'] as Map)['rating'] : null)),
      totalDeliveries: parseInt(todayStats['total_deliveries'] ?? json['total_deliveries'] ?? (json['driver'] is Map ? (json['driver'] as Map)['total_deliveries'] : null)),
    );
  }
}

class DeliveryRoute {
  final String deliveryId;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final int estimatedMinutes;
  final double distanceKm;

  DeliveryRoute({
    required this.deliveryId,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.estimatedMinutes,
    required this.distanceKm,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
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

    return DeliveryRoute(
      deliveryId: json['delivery_id']?.toString() ?? '',
      pickupLat: parseDouble(json['pickup_lat']),
      pickupLng: parseDouble(json['pickup_lng']),
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffLat: parseDouble(json['dropoff_lat']),
      dropoffLng: parseDouble(json['dropoff_lng']),
      dropoffAddress: json['dropoff_address'] as String? ?? '',
      estimatedMinutes: parseInt(json['estimated_minutes']),
      distanceKm: parseDouble(json['distance_km']),
    );
  }
}

class DriverEarnings {
  final double totalEarnings;
  final double deliveryFees;
  final double tips;
  final double bonuses;
  final int totalDeliveries;
  final List<EarningEntry> history;

  DriverEarnings({
    required this.totalEarnings,
    required this.deliveryFees,
    required this.tips,
    required this.bonuses,
    required this.totalDeliveries,
    required this.history,
  });

  factory DriverEarnings.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    return DriverEarnings(
      totalEarnings: parseDouble(json['total_earnings'] ?? json['total'] ?? json['earnings']),
      deliveryFees: parseDouble(json['delivery_fees'] ?? json['base_earnings'] ?? json['driver_earnings']),
      tips: parseDouble(json['tips'] ?? json['tip']),
      bonuses: parseDouble(json['bonuses'] ?? json['bonus'] ?? json['incentives']),
      totalDeliveries: parseInt(json['total_deliveries'] ?? json['deliveries_count'] ?? json['deliveries']),
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => EarningEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class EarningEntry {
  final String id;
  final String date;
  final double amount;
  final int deliveries;

  EarningEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.deliveries,
  });

  factory EarningEntry.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    return EarningEntry(
      id: json['id']?.toString() ?? '',
      date: (json['date'] ?? json['period'] ?? json['day']) as String? ?? '',
      amount: parseDouble(json['amount'] ?? json['total'] ?? json['earnings']),
      deliveries: parseInt(json['deliveries'] ?? json['count'] ?? json['total_deliveries']),
    );
  }
}

// ============= New Models for Work Section =============

class DeliveryHistoryResponse {
  final List<DeliveryRecord> deliveries;
  final DeliveryStats stats;

  DeliveryHistoryResponse({
    required this.deliveries,
    required this.stats,
  });

  factory DeliveryHistoryResponse.fromJson(Map<String, dynamic> json) {
    final deliveriesList = json['data'] as List<dynamic>? ?? [];
    final statsData = json['stats'] as Map<String, dynamic>? ?? {};
    
    return DeliveryHistoryResponse(
      deliveries: deliveriesList
          .map((e) => DeliveryRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: DeliveryStats.fromJson(statsData),
    );
  }
}

class DeliveryRecord {
  final String id;
  final String orderId;
  final String? customerName;
  final String? address;
  final double amount;
  final double tip;
  final String status;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final double distance;

  DeliveryRecord({
    required this.id,
    required this.orderId,
    this.customerName,
    this.address,
    required this.amount,
    required this.tip,
    required this.status,
    this.deliveredAt,
    required this.createdAt,
    required this.distance,
  });

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Get order data if nested
    final orderData = json['order'] as Map<String, dynamic>? ?? {};
    final customerData = orderData['customer'] as Map<String, dynamic>? ?? {};

    return DeliveryRecord(
      id: json['id']?.toString() ?? '',
      orderId: orderData['order_number']?.toString() ?? json['order_id']?.toString() ?? '',
      customerName: customerData['full_name'] as String? ?? customerData['name'] as String?,
      address: orderData['delivery_address'] as String?,
      amount: parseDouble(json['driver_earnings']),
      tip: parseDouble(json['tip_amount']),
      status: json['status'] as String? ?? 'pending',
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      distance: parseDouble(json['distance_km']),
    );
  }

  bool get isCompleted => status == 'delivered';
  bool get isCancelled => status == 'failed';
}

class DeliveryStats {
  final int today;
  final int week;
  final int total;

  DeliveryStats({
    required this.today,
    required this.week,
    required this.total,
  });

  factory DeliveryStats.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    return DeliveryStats(
      today: parseInt(json['today']),
      week: parseInt(json['week']),
      total: parseInt(json['total']),
    );
  }
}

class WorkSchedule {
  final Map<String, DaySchedule> schedule;
  final bool isOnline;

  WorkSchedule({
    required this.schedule,
    required this.isOnline,
  });

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    final scheduleData = json['schedule'] as Map<String, dynamic>? ?? {};
    final schedule = <String, DaySchedule>{};
    
    for (final entry in scheduleData.entries) {
      schedule[entry.key] = DaySchedule.fromJson(entry.value as Map<String, dynamic>);
    }

    // Ensure all days exist with defaults
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (final day in days) {
      schedule.putIfAbsent(day, () => DaySchedule(
        isEnabled: day != 'saturday' && day != 'sunday',
        startTime: '08:00',
        endTime: '18:00',
      ));
    }

    return WorkSchedule(
      schedule: schedule,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  int get enabledDaysCount => schedule.values.where((d) => d.isEnabled).length;
}

class DaySchedule {
  final bool isEnabled;
  final String startTime;
  final String endTime;

  DaySchedule({
    required this.isEnabled,
    required this.startTime,
    required this.endTime,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      isEnabled: json['enabled'] as bool? ?? false,
      startTime: json['start'] as String? ?? '08:00',
      endTime: json['end'] as String? ?? '18:00',
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': isEnabled,
    'start': startTime,
    'end': endTime,
  };

  DaySchedule copyWith({
    bool? isEnabled,
    String? startTime,
    String? endTime,
  }) {
    return DaySchedule(
      isEnabled: isEnabled ?? this.isEnabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class ServiceAreasResponse {
  final List<ServiceArea> areas;
  final int totalActive;

  ServiceAreasResponse({
    required this.areas,
    required this.totalActive,
  });

  factory ServiceAreasResponse.fromJson(Map<String, dynamic> json) {
    final areasList = json['areas'] as List<dynamic>? ?? [];
    
    return ServiceAreasResponse(
      areas: areasList
          .map((e) => ServiceArea.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalActive: json['total_active'] as int? ?? 0,
    );
  }
}

class ServiceArea {
  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final bool isActive;

  ServiceArea({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    required this.radiusKm,
    required this.isActive,
  });

  factory ServiceArea.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return ServiceArea(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      radiusKm: parseDouble(json['radius_km']),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
