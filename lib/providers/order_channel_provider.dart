import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_event_model.dart';
import '../models/user_model.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

/// Channel names for different user roles
class OrderChannels {
  /// Channel for customer orders - private channel for a specific customer
  static String customerOrders(String customerId) => 'private-customer.$customerId.orders';
  
  /// Channel for tracking a specific order
  static String orderTracking(String orderId) => 'private-order.$orderId';
  
  /// Channel for station/owner orders - receives all orders for a station
  static String stationOrders(String stationId) => 'private-station.$stationId.orders';
  
  /// Channel for driver deliveries - receives delivery assignments
  static String driverDeliveries(String driverId) => 'private-driver.$driverId.deliveries';
  
  /// Channel for new orders (for owners to see incoming orders)
  static String stationNewOrders(String stationId) => 'private-station.$stationId.new-orders';
}

/// State for order channel subscriptions
class OrderChannelState {
  final bool isConnected;
  final bool isSubscribed;
  final List<String> subscribedChannels;
  final OrderEvent? lastEvent;
  final String? errorMessage;
  
  const OrderChannelState({
    this.isConnected = false,
    this.isSubscribed = false,
    this.subscribedChannels = const [],
    this.lastEvent,
    this.errorMessage,
  });
  
  OrderChannelState copyWith({
    bool? isConnected,
    bool? isSubscribed,
    List<String>? subscribedChannels,
    OrderEvent? lastEvent,
    String? errorMessage,
  }) {
    return OrderChannelState(
      isConnected: isConnected ?? this.isConnected,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscribedChannels: subscribedChannels ?? this.subscribedChannels,
      lastEvent: lastEvent ?? this.lastEvent,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for managing order-related WebSocket channels
class OrderChannelNotifier extends StateNotifier<OrderChannelState> {
  final WebSocketService _webSocketService;
  final Ref _ref;
  
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;
  final List<StreamSubscription<Map<String, dynamic>>> _channelSubscriptions = [];
  
  // Event stream for components to listen to
  final _eventController = StreamController<OrderEvent>.broadcast();
  Stream<OrderEvent> get eventStream => _eventController.stream;
  
  OrderChannelNotifier(this._webSocketService, this._ref) 
      : super(const OrderChannelState()) {
    _init();
  }
  
  void _init() {
    // Listen to connection state changes
    _connectionSubscription = _webSocketService.connectionStateStream.listen((connectionState) {
      debugPrint('[OrderChannel] Connection state changed: $connectionState');
      final isConnected = connectionState == WebSocketConnectionState.connected;
      state = state.copyWith(isConnected: isConnected);
      
      if (isConnected) {
        // Re-subscribe to channels when reconnected
        _subscribeBasedOnRole();
      }
    });
    
    // Check if already connected and subscribe immediately
    if (_webSocketService.connectionState == WebSocketConnectionState.connected) {
      debugPrint('[OrderChannel] WebSocket already connected, subscribing now...');
      state = state.copyWith(isConnected: true);
      _subscribeBasedOnRole();
    }
  }
  
  /// Connect to WebSocket and subscribe to relevant channels based on user role
  Future<void> connect() async {
    final authState = _ref.read(authProvider);
    
    debugPrint('[OrderChannel] connect() called');
    debugPrint('[OrderChannel] isAuthenticated: ${authState.isAuthenticated}');
    debugPrint('[OrderChannel] user: ${authState.user?.email}');
    debugPrint('[OrderChannel] user role: ${authState.user?.role}');
    debugPrint('[OrderChannel] user stationId: ${authState.user?.stationId}');
    
    if (!authState.isAuthenticated || authState.user == null) {
      debugPrint('[OrderChannel] User not authenticated, skipping connection');
      return;
    }
    
    // Clear any existing subscriptions to prevent stale channels from previous sessions
    _clearAllSubscriptions();
    
    // Set auth token for private channels
    final storageService = _ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    _webSocketService.setAuthToken(token);
    
    // Connect to WebSocket
    await _webSocketService.connect();
    
    // After connecting, subscribe to role-based channels
    // (the listener also does this, but call it explicitly for immediate effect)
    if (_webSocketService.connectionState == WebSocketConnectionState.connected) {
      debugPrint('[OrderChannel] Connect successful, subscribing to channels...');
      _subscribeBasedOnRole();
    }
  }
  
  /// Clear all existing channel subscriptions
  void _clearAllSubscriptions() {
    debugPrint('[OrderChannel] Clearing all existing subscriptions...');
    for (final channel in state.subscribedChannels.toList()) {
      _webSocketService.unsubscribeFromChannel(channel);
    }
    state = state.copyWith(subscribedChannels: []);
  }
  
  /// Subscribe to channels based on user role
  void _subscribeBasedOnRole() {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    
    if (user == null) {
      debugPrint('[OrderChannel] _subscribeBasedOnRole: user is null, skipping');
      return;
    }
    
    debugPrint('[OrderChannel] Subscribing for role: ${user.role}');
    debugPrint('[OrderChannel] User ID: ${user.id}');
    debugPrint('[OrderChannel] Driver ID: ${user.driverId}');
    debugPrint('[OrderChannel] Station ID: ${user.stationId}');
    
    switch (user.role) {
      case UserRole.customer:
        debugPrint('[OrderChannel] Subscribing to customer channels for: ${user.id}');
        _subscribeToCustomerChannels(user.id);
        break;
      case UserRole.driver:
        // IMPORTANT: Use driverId (from drivers table) not user.id for driver channels
        // The Laravel backend broadcasts to private-driver.<driverId>.deliveries
        if (user.driverId != null) {
          debugPrint('[OrderChannel] Subscribing to driver channels for driverId: ${user.driverId}');
          _subscribeToDriverChannels(user.driverId!);
        } else {
          debugPrint('[OrderChannel] WARNING: Driver has no driverId! Cannot subscribe to driver channels. Falling back to user.id');
          _subscribeToDriverChannels(user.id);
        }
        break;
      case UserRole.owner:
        if (user.stationId != null) {
          debugPrint('[OrderChannel] Subscribing to owner channels for station: ${user.stationId}');
          _subscribeToOwnerChannels(user.stationId!);
        } else {
          debugPrint('[OrderChannel] WARNING: Owner has no stationId, cannot subscribe to owner channels!');
        }
        break;
    }
  }
  
  /// Subscribe to customer-specific channels
  void _subscribeToCustomerChannels(String customerId) {
    final channelName = OrderChannels.customerOrders(customerId);
    _subscribeToChannel(channelName);
  }
  
  /// Subscribe to driver-specific channels
  void _subscribeToDriverChannels(String driverId) {
    final channelName = OrderChannels.driverDeliveries(driverId);
    debugPrint('[OrderChannel] _subscribeToDriverChannels: driverId=$driverId');
    debugPrint('[OrderChannel] _subscribeToDriverChannels: channelName=$channelName');
    _subscribeToChannel(channelName);
  }
  
  /// Subscribe to owner/station-specific channels
  void _subscribeToOwnerChannels(String stationId) {
    // Subscribe to all orders for the station
    _subscribeToChannel(OrderChannels.stationOrders(stationId));
    
    // Subscribe to new order notifications
    _subscribeToChannel(OrderChannels.stationNewOrders(stationId));
  }
  
  /// Subscribe to a specific order for tracking
  void subscribeToOrderTracking(String orderId) {
    final channelName = OrderChannels.orderTracking(orderId);
    debugPrint('[OrderChannel] subscribeToOrderTracking called for: $orderId');
    debugPrint('[OrderChannel] Channel name: $channelName');
    _subscribeToChannel(channelName);
  }
  
  /// Unsubscribe from order tracking
  void unsubscribeFromOrderTracking(String orderId) {
    final channelName = OrderChannels.orderTracking(orderId);
    _unsubscribeFromChannel(channelName);
  }
  
  void _subscribeToChannel(String channelName) {
    if (state.subscribedChannels.contains(channelName)) {
      return;
    }
    
    debugPrint('[OrderChannel] Subscribing to: $channelName');
    
    final stream = _webSocketService.subscribeToPrivateChannel(channelName);
    final subscription = stream.listen(_handleChannelEvent);
    _channelSubscriptions.add(subscription);
    
    final newChannels = [...state.subscribedChannels, channelName];
    state = state.copyWith(
      subscribedChannels: newChannels,
      isSubscribed: newChannels.isNotEmpty,
    );
  }
  
  void _unsubscribeFromChannel(String channelName) {
    if (!state.subscribedChannels.contains(channelName)) {
      return;
    }
    
    debugPrint('[OrderChannel] Unsubscribing from: $channelName');
    
    _webSocketService.unsubscribeFromChannel(channelName);
    
    final newChannels = state.subscribedChannels.where((c) => c != channelName).toList();
    state = state.copyWith(
      subscribedChannels: newChannels,
      isSubscribed: newChannels.isNotEmpty,
    );
  }
  
  void _handleChannelEvent(Map<String, dynamic> message) {
    try {
      final eventName = message['event'] as String? ?? '';
      
      // Ignore internal Pusher events - they are not order events
      if (eventName.startsWith('pusher_internal:') || eventName.startsWith('pusher:')) {
        debugPrint('[OrderChannel] Ignoring internal Pusher event: $eventName');
        return;
      }
      
      debugPrint('[OrderChannel] ========================================');
      debugPrint('[OrderChannel] Received raw message from WebSocket');
      debugPrint('[OrderChannel] Event name: $eventName');
      debugPrint('[OrderChannel] Channel: ${message['channel']}');
      debugPrint('[OrderChannel] Data: ${message['data']}');
      
      final event = OrderEvent.fromJson(message);
      debugPrint('[OrderChannel] Parsed event type: ${event.type}');
      debugPrint('[OrderChannel] Parsed orderId: ${event.orderId}');
      debugPrint('[OrderChannel] ========================================');
      
      state = state.copyWith(lastEvent: event);
      
      // Emit to the event stream
      _eventController.add(event);
      debugPrint('[OrderChannel] Event emitted to stream');
    } catch (e, stackTrace) {
      debugPrint('[OrderChannel] Error parsing event: $e');
      debugPrint('[OrderChannel] Stack trace: $stackTrace');
      state = state.copyWith(errorMessage: e.toString());
    }
  }
  
  /// Disconnect and clean up
  void disconnect() {
    for (final subscription in _channelSubscriptions) {
      subscription.cancel();
    }
    _channelSubscriptions.clear();
    
    for (final channelName in state.subscribedChannels) {
      _webSocketService.unsubscribeFromChannel(channelName);
    }
    
    _webSocketService.disconnect();
    
    state = const OrderChannelState();
  }
  
  @override
  void dispose() {
    _connectionSubscription?.cancel();
    for (final subscription in _channelSubscriptions) {
      subscription.cancel();
    }
    _eventController.close();
    super.dispose();
  }
}

/// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Provider for order channel management
final orderChannelProvider = StateNotifierProvider<OrderChannelNotifier, OrderChannelState>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return OrderChannelNotifier(webSocketService, ref);
});

/// Stream provider for order events
final orderEventStreamProvider = StreamProvider<OrderEvent>((ref) {
  final orderChannel = ref.watch(orderChannelProvider.notifier);
  return orderChannel.eventStream;
});

/// Provider to filter events for a specific order
final orderEventsForOrderProvider = StreamProvider.family<OrderEvent, String>((ref, orderId) {
  final orderChannel = ref.watch(orderChannelProvider.notifier);
  return orderChannel.eventStream.where((event) => event.orderId == orderId);
});

/// Provider for driver location updates for a specific order
final driverLocationForOrderProvider = StreamProvider.family<DriverLocationUpdatedEvent, String>((ref, orderId) {
  final orderChannel = ref.watch(orderChannelProvider.notifier);
  return orderChannel.eventStream
      .where((event) => event.orderId == orderId && event.type == OrderEventType.driverLocationUpdated)
      .cast<DriverLocationUpdatedEvent>();
});
