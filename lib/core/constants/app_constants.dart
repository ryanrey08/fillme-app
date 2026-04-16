// App Constants
class AppConstants {
  static const String appName = 'FillMe';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String apiBaseUrl = 'http://192.168.18.105:8080'; // Base Laravel URL
  // static const String baseUrl = 'http://10.124.54.202:8080/api/mobile/v1';
  static const String baseUrl = 'http://192.168.18.105:8080/api/mobile/v1';
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
  
  // WebSocket Configuration (Laravel Reverb)
  static const String wsHost = '10.124.54.202';
  static const int wsPort = 6001; // Reverb WebSocket port (separate from API port)
  static const String wsAppKey = 'ff3oyophbbp8r3orqian'; // Must match REVERB_APP_KEY in Laravel .env
  static const bool wsUseTls = false; // Set to true for production (wss://)
  static const int wsReconnectDelayMs = 3000;
  static const int wsMaxReconnectAttempts = 5;
  
  // WebSocket URL builder
  static String get wsUrl {
    final protocol = wsUseTls ? 'wss' : 'ws';
    return '$protocol://$wsHost:$wsPort/app/$wsAppKey';
  }
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String guestKey = 'guest_mode';
  static const String themeKey = 'app_theme';
  
  // Roles
  static const String roleCustomer = 'customer';
  static const String roleDriver = 'driver';
  static const String roleOwner = 'owner';
  
  // Order Status
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusPreparing = 'preparing';
  static const String statusReadyForPickup = 'ready_for_pickup';
  static const String statusOutForDelivery = 'out_for_delivery';
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';
  static const String statusRefunded = 'refunded';
  
  // Payment Methods
  static const String paymentGcash = 'gcash';
  static const String paymentMaya = 'maya';
  static const String paymentCard = 'card';
  static const String paymentCod = 'cod';
  
  // Map Configuration
  static const double defaultLatitude = 14.5995;
  static const double defaultLongitude = 120.9842;
  static const double defaultZoom = 15.0;
}
