import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';
import '../models/station_model.dart';
import '../models/product_model.dart' hide ProductCategory;
import '../models/order_model.dart';
import 'auth_provider.dart';

// Service Providers
final stationServiceProvider = Provider<StationService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return StationService(apiService);
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CustomerService(apiService);
});

final driverServiceProvider = Provider<DriverService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return DriverService(apiService);
});

final ownerServiceProvider = Provider<OwnerService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return OwnerService(apiService);
});

// ======================= STATION PROVIDERS =======================

class StationsState {
  final List<StationModel> stations;
  final bool isLoading;
  final String? errorMessage;

  const StationsState({
    this.stations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  // Aliases for compatibility
  List<StationModel> get nearbyStations => stations;
  String? get error => errorMessage;

  StationsState copyWith({
    List<StationModel>? stations,
    bool? isLoading,
    String? errorMessage,
  }) {
    return StationsState(
      stations: stations ?? this.stations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class StationsNotifier extends StateNotifier<StationsState> {
  final StationService _stationService;
  final LocationService _locationService;

  // Default location: Manila, Philippines
  static const double _defaultLatitude = 14.5995;
  static const double _defaultLongitude = 120.9842;

  StationsNotifier(this._stationService, this._locationService)
      : super(const StationsState());

  // Alias for compatibility
  Future<void> loadNearbyStations() => discoverStations();

  Future<void> discoverStations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final position = await _locationService.getCurrentPosition();
      
      // Use actual position or default to Manila
      final latitude = position?.latitude ?? _defaultLatitude;
      final longitude = position?.longitude ?? _defaultLongitude;
      
      if (position != null) {
        debugPrint('StationsNotifier: Using actual GPS location - lat: $latitude, lng: $longitude');
      } else {
        debugPrint('StationsNotifier: Using default Manila location - lat: $latitude, lng: $longitude');
      }
      
      final stations = await _stationService.discoverStations(
        latitude: latitude,
        longitude: longitude,
      );
      debugPrint('StationsNotifier: Found ${stations.length} stations');
      state = state.copyWith(stations: stations, isLoading: false);
    } catch (e) {
      debugPrint('StationsNotifier: Error discovering stations: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> discoverStationsAt(double latitude, double longitude) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final stations = await _stationService.discoverStations(
        latitude: latitude,
        longitude: longitude,
      );
      state = state.copyWith(stations: stations, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final stationsProvider =
    StateNotifierProvider<StationsNotifier, StationsState>((ref) {
  final stationService = ref.watch(stationServiceProvider);
  final locationService = ref.watch(locationServiceProvider);
  return StationsNotifier(stationService, locationService);
});

// Station Detail Provider
final stationDetailProvider = FutureProvider.family<StationModel, String>((ref, stationId) async {
  final stationService = ref.watch(stationServiceProvider);
  return stationService.getStationDetails(stationId);
});

// Station Products Provider
final stationProductsProvider = FutureProvider.family<List<ProductModel>, String>((ref, stationId) async {
  final stationService = ref.watch(stationServiceProvider);
  return stationService.getStationProducts(stationId);
});

// Station Categories Provider
final stationCategoriesProvider = FutureProvider.family<List<CategoryWithProducts>, String>((ref, stationId) async {
  final stationService = ref.watch(stationServiceProvider);
  return stationService.getStationCategories(stationId);
});

// Station Reviews Provider
final stationReviewsProvider = FutureProvider.family<List<StationReview>, String>((ref, stationId) async {
  final stationService = ref.watch(stationServiceProvider);
  return stationService.getStationReviews(stationId);
});

// ======================= CUSTOMER PROVIDERS =======================

class CustomerState {
  final List<CustomerAddress> addresses;
  final LoyaltyInfo? loyaltyInfo;
  final List<Subscription> subscriptions;
  final bool isLoading;
  final String? errorMessage;

  const CustomerState({
    this.addresses = const [],
    this.loyaltyInfo,
    this.subscriptions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CustomerState copyWith({
    List<CustomerAddress>? addresses,
    LoyaltyInfo? loyaltyInfo,
    List<Subscription>? subscriptions,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CustomerState(
      addresses: addresses ?? this.addresses,
      loyaltyInfo: loyaltyInfo ?? this.loyaltyInfo,
      subscriptions: subscriptions ?? this.subscriptions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomerService _customerService;

  CustomerNotifier(this._customerService) : super(const CustomerState());

  Future<void> loadAddresses() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final addresses = await _customerService.getAddresses();
      state = state.copyWith(addresses: addresses, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadLoyaltyInfo() async {
    try {
      final loyaltyInfo = await _customerService.getLoyaltyInfo();
      state = state.copyWith(loyaltyInfo: loyaltyInfo);
    } catch (e) {
      // Silently fail for loyalty info
    }
  }

  Future<void> loadSubscriptions() async {
    try {
      final subscriptions = await _customerService.getSubscriptions();
      state = state.copyWith(subscriptions: subscriptions);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final results = await Future.wait([
        _customerService.getAddresses(),
        _customerService.getLoyaltyInfo(),
        _customerService.getSubscriptions(),
      ]);

      state = state.copyWith(
        addresses: results[0] as List<CustomerAddress>,
        loyaltyInfo: results[1] as LoyaltyInfo,
        subscriptions: results[2] as List<Subscription>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> addAddress(CustomerAddress address) async {
    try {
      final newAddress = await _customerService.addAddress(
        label: address.label,
        fullAddress: address.fullAddress,
        latitude: address.latitude,
        longitude: address.longitude,
        buildingName: address.buildingName,
        unitNumber: address.unitNumber,
        deliveryInstructions: address.deliveryInstructions,
        contactName: address.contactName,
        contactPhone: address.contactPhone,
      );
      state = state.copyWith(addresses: [...state.addresses, newAddress]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _customerService.deleteAddress(addressId);
      state = state.copyWith(
        addresses: state.addresses.where((a) => a.id != addressId).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAddress(CustomerAddress address) async {
    try {
      final updated = await _customerService.updateAddress(
        address.id,
        label: address.label,
        fullAddress: address.fullAddress,
        latitude: address.latitude,
        longitude: address.longitude,
        buildingName: address.buildingName,
        unitNumber: address.unitNumber,
        deliveryInstructions: address.deliveryInstructions,
        contactName: address.contactName,
        contactPhone: address.contactPhone,
      );
      state = state.copyWith(
        addresses: state.addresses.map((a) => a.id == address.id ? updated : a).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    try {
      await _customerService.setDefaultAddress(addressId);
      await loadAddresses();
    } catch (e) {
      rethrow;
    }
  }
}

final customerDataProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  final customerService = ref.watch(customerServiceProvider);
  return CustomerNotifier(customerService);
});

// ======================= DRIVER PROVIDERS =======================

class DriverState {
  final DriverDashboard? dashboard;
  final List<OrderModel> deliveryQueue;
  final DriverEarnings? earnings;
  final bool isLoading;
  final String? errorMessage;

  const DriverState({
    this.dashboard,
    this.deliveryQueue = const [],
    this.earnings,
    this.isLoading = false,
    this.errorMessage,
  });

  // Alias for compatibility
  String? get error => errorMessage;

  DriverState copyWith({
    DriverDashboard? dashboard,
    List<OrderModel>? deliveryQueue,
    DriverEarnings? earnings,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DriverState(
      dashboard: dashboard ?? this.dashboard,
      deliveryQueue: deliveryQueue ?? this.deliveryQueue,
      earnings: earnings ?? this.earnings,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DriverNotifier extends StateNotifier<DriverState> {
  final DriverService _driverService;

  DriverNotifier(this._driverService) : super(const DriverState());

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final dashboard = await _driverService.getDashboard();
      state = state.copyWith(dashboard: dashboard, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadDeliveryQueue() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final deliveries = await _driverService.getDeliveryQueue();
      state = state.copyWith(deliveryQueue: deliveries, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadEarnings({String period = 'week'}) async {
    try {
      final earnings = await _driverService.getEarnings(period: period);
      state = state.copyWith(earnings: earnings);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> updateStatus(bool isOnline) async {
    try {
      final newStatus = await _driverService.updateStatus(isOnline);
      
      // Immediately update local state with the new status
      if (state.dashboard != null) {
        state = state.copyWith(
          dashboard: state.dashboard!.copyWith(isOnline: newStatus),
        );
      } else {
        // If no dashboard yet, create a minimal one with the status
        state = state.copyWith(
          dashboard: DriverDashboard(
            isOnline: newStatus,
            pendingDeliveries: 0,
            completedToday: 0,
            earningsToday: 0,
            rating: 0,
            totalDeliveries: 0,
          ),
        );
      }
      // Don't call loadDashboard() here - it may overwrite with stale data
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      await _driverService.updateLocation(latitude, longitude);
    } catch (e) {
      // Silently fail for location updates
    }
  }
}

final driverDataProvider =
    StateNotifierProvider<DriverNotifier, DriverState>((ref) {
  final driverService = ref.watch(driverServiceProvider);
  return DriverNotifier(driverService);
});

// Provider for fetching driver deliveries by status
final driverDeliveriesProvider = FutureProvider.family<List<OrderModel>, String?>((ref, status) async {
  final driverService = ref.read(driverServiceProvider);
  return driverService.getDeliveriesByStatus(status);
});

// ======================= OWNER PROVIDERS =======================

class OwnerState {
  final StationDashboard? dashboard;
  final StationAnalytics? analytics;
  final List<InventoryItem> inventory;
  final List<StationDriver> drivers;
  final List<StationPromo> promos;
  final List<OrderModel> orders;
  final bool isLoading;
  final String? errorMessage;

  const OwnerState({
    this.dashboard,
    this.analytics,
    this.inventory = const [],
    this.drivers = const [],
    this.promos = const [],
    this.orders = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  OwnerState copyWith({
    StationDashboard? dashboard,
    StationAnalytics? analytics,
    List<InventoryItem>? inventory,
    List<StationDriver>? drivers,
    List<StationPromo>? promos,
    List<OrderModel>? orders,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OwnerState(
      dashboard: dashboard ?? this.dashboard,
      analytics: analytics ?? this.analytics,
      inventory: inventory ?? this.inventory,
      drivers: drivers ?? this.drivers,
      promos: promos ?? this.promos,
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class OwnerNotifier extends StateNotifier<OwnerState> {
  final OwnerService _ownerService;

  OwnerNotifier(this._ownerService) : super(const OwnerState());

  Future<void> loadDashboard() async {
    debugPrint('[OwnerNotifier] loadDashboard() called');
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final dashboard = await _ownerService.getDashboard();
      debugPrint('[OwnerNotifier] Dashboard loaded: todayRevenue=${dashboard.todayRevenue}, pendingOrders=${dashboard.pendingOrders}, activeOrders=${dashboard.activeOrders}');
      state = state.copyWith(dashboard: dashboard, isLoading: false);
      debugPrint('[OwnerNotifier] State updated, dashboard is null? ${state.dashboard == null}');
    } catch (e) {
      debugPrint('[OwnerNotifier] loadDashboard() error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadAnalytics({String period = 'week'}) async {
    try {
      final analytics = await _ownerService.getAnalytics(period: period);
      state = state.copyWith(analytics: analytics);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadInventory() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final inventory = await _ownerService.getInventory();
      state = state.copyWith(inventory: inventory, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateInventory(String productId, int quantity) async {
    try {
      await _ownerService.updateInventory(productId, quantity);
      // Refresh inventory
      await loadInventory();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> approveOrder(String orderId) async {
    try {
      await _ownerService.approveOrder(orderId);
      await loadOrders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectOrder(String orderId, {String? reason}) async {
    try {
      await _ownerService.rejectOrder(orderId, reason: reason);
      await loadOrders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignDriver(String orderId, String driverId) async {
    try {
      await _ownerService.assignDriver(orderId, driverId);
      await loadOrders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadDrivers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final drivers = await _ownerService.getDrivers();
      state = state.copyWith(drivers: drivers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadPromos({String? status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final promos = await _ownerService.getPromos(status: status);
      state = state.copyWith(promos: promos, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> createPromo({
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
    try {
      await _ownerService.createPromo(
        name: name,
        code: code,
        type: type,
        value: value,
        description: description,
        minOrder: minOrder,
        maxDiscount: maxDiscount,
        usageLimit: usageLimit,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive,
      );
      await loadPromos();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePromo(String promoId, {
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
    try {
      await _ownerService.updatePromo(
        promoId,
        name: name,
        code: code,
        description: description,
        type: type,
        value: value,
        minOrder: minOrder,
        maxDiscount: maxDiscount,
        usageLimit: usageLimit,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive,
      );
      await loadPromos();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePromo(String promoId) async {
    try {
      await _ownerService.deletePromo(promoId);
      await loadPromos();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadOrders({String? status, String? date}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final orders = await _ownerService.getOrders(
        status: status,
        date: date,
      );
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final ownerDataProvider =
    StateNotifierProvider<OwnerNotifier, OwnerState>((ref) {
  final ownerService = ref.watch(ownerServiceProvider);
  return OwnerNotifier(ownerService);
});

// Owner orders provider
final ownerOrdersProvider = FutureProvider.family<List<OrderModel>, Map<String, dynamic>>((ref, params) async {
  final ownerService = ref.watch(ownerServiceProvider);
  return ownerService.getOrders(
    page: params['page'] ?? 1,
    limit: params['limit'] ?? 20,
    status: params['status'],
    date: params['date'],
    driverId: params['driver_id'],
  );
});

// ======================= STATION SETTINGS PROVIDERS =======================

// Station settings provider
final stationSettingsProvider = FutureProvider.autoDispose<StationSettings>((ref) async {
  final ownerService = ref.read(ownerServiceProvider);
  return ownerService.getStationSettings();
});

// Payment settings provider
final paymentSettingsProvider = FutureProvider.autoDispose<PaymentSettings>((ref) async {
  final ownerService = ref.read(ownerServiceProvider);
  return ownerService.getPaymentMethods();
});

// Owner's station products provider (for product management)
final ownerProductsProvider = FutureProvider.autoDispose<List<StationProduct>>((ref) async {
  final ownerService = ref.read(ownerServiceProvider);
  return ownerService.getProducts();
});

// Product categories provider
final productCategoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) async {
  final ownerService = ref.read(ownerServiceProvider);
  return ownerService.getCategories();
});
