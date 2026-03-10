import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/order_event_model.dart';
import 'auth_provider.dart';
import 'order_channel_provider.dart';
import 'order_provider.dart';
import 'data_providers.dart';

/// Extension to add real-time order updates to the driver state
class RealtimeDriverNotifier extends StateNotifier<DriverState> {
  final DriverNotifier _driverNotifier;
  final Ref _ref;
  StreamSubscription<OrderEvent>? _eventSubscription;
  
  RealtimeDriverNotifier(this._driverNotifier, this._ref) : super(_driverNotifier.state) {
    _initRealTimeUpdates();
    
    // Forward state changes from the original notifier
    _driverNotifier.addListener((state) {
      if (mounted) {
        this.state = state;
      }
    });
  }
  
  void _initRealTimeUpdates() {
    _eventSubscription = _ref.read(orderChannelProvider.notifier).eventStream.listen((event) {
      _handleOrderEvent(event);
    });
    debugPrint('[RealtimeDriver] Real-time updates initialized');
  }
  
  void _handleOrderEvent(OrderEvent event) {
    debugPrint('[RealtimeDriver] Received event: ${event.type} for order ${event.orderId}');
    switch (event.type) {
      case OrderEventType.driverAssigned:
        _handleDeliveryAssigned(event as DriverAssignedEvent);
        break;
      case OrderEventType.orderStatusUpdated:
        _handleDeliveryStatusUpdate(event as OrderStatusUpdatedEvent);
        break;
      case OrderEventType.orderDelivered:
        _handleDeliveryCompleted(event as OrderDeliveredEvent);
        break;
      case OrderEventType.orderCancelled:
        _handleDeliveryCancelled(event as OrderCancelledEvent);
        break;
      default:
        break;
    }
  }
  
  /// Helper to find order index with flexible matching
  int _findOrderIndex(List<OrderModel> orders, String orderId) {
    return orders.indexWhere((o) => 
        o.id == orderId || o.numericId == orderId || o.id.contains(orderId) || orderId.contains(o.id));
  }
  
  void _handleDeliveryAssigned(DriverAssignedEvent event) {
    debugPrint('[RealtimeDriver] _handleDeliveryAssigned for order: ${event.orderId}');
    // Add new delivery to the queue if the order is included
    if (event.order != null) {
      final existingIndex = _findOrderIndex(state.deliveryQueue, event.orderId);
      if (existingIndex == -1) {
        // New delivery assignment
        debugPrint('[RealtimeDriver] Adding new delivery to queue: ${event.orderId}');
        state = state.copyWith(
          deliveryQueue: [event.order!, ...state.deliveryQueue],
        );
        
        // Update pending count in dashboard
        if (state.dashboard != null) {
          state = state.copyWith(
            dashboard: state.dashboard!.copyWith(
              pendingDeliveries: state.dashboard!.pendingDeliveries + 1,
            ),
          );
        }
      } else {
        // Update existing delivery with driver info
        debugPrint('[RealtimeDriver] Updating existing delivery: ${event.orderId}');
        _updateDeliveryInQueue(event.orderId, (order) {
          return event.order ?? order.copyWith(
            driverId: event.driverId,
            driverName: event.driverName,
            assignedAt: event.timestamp,
          );
        });
      }
    } else {
      // No order in event, try to refresh deliveries from API
      debugPrint('[RealtimeDriver] No order in event, refreshing from API');
      loadDeliveryQueue();
    }
  }
  
  void _handleDeliveryStatusUpdate(OrderStatusUpdatedEvent event) {
    debugPrint('[RealtimeDriver] _handleDeliveryStatusUpdate for order: ${event.orderId}, newStatus: ${event.newStatus}');
    _updateDeliveryInQueue(event.orderId, (order) {
      // Always ensure status matches the event, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(status: event.newStatus);
    });
  }
  
  void _handleDeliveryCompleted(OrderDeliveredEvent event) {
    debugPrint('[RealtimeDriver] _handleDeliveryCompleted for order: ${event.orderId}');
    // Remove from delivery queue when completed
    final queueIndex = _findOrderIndex(state.deliveryQueue, event.orderId);
    if (queueIndex != -1) {
      final newQueue = [...state.deliveryQueue];
      newQueue.removeAt(queueIndex);
      state = state.copyWith(deliveryQueue: newQueue);
      
      // Update dashboard counts
      if (state.dashboard != null) {
        state = state.copyWith(
          dashboard: state.dashboard!.copyWith(
            pendingDeliveries: (state.dashboard!.pendingDeliveries - 1).clamp(0, 999),
            completedToday: state.dashboard!.completedToday + 1,
          ),
        );
      }
    }
  }
  
  void _handleDeliveryCancelled(OrderCancelledEvent event) {
    debugPrint('[RealtimeDriver] _handleDeliveryCancelled for order: ${event.orderId}');
    // Remove from delivery queue when cancelled
    final queueIndex = _findOrderIndex(state.deliveryQueue, event.orderId);
    if (queueIndex != -1) {
      final newQueue = [...state.deliveryQueue];
      newQueue.removeAt(queueIndex);
      state = state.copyWith(deliveryQueue: newQueue);
      
      // Update pending count in dashboard
      if (state.dashboard != null) {
        state = state.copyWith(
          dashboard: state.dashboard!.copyWith(
            pendingDeliveries: (state.dashboard!.pendingDeliveries - 1).clamp(0, 999),
          ),
        );
      }
    }
  }
  
  void _updateDeliveryInQueue(String orderId, OrderModel Function(OrderModel) updater) {
    final index = _findOrderIndex(state.deliveryQueue, orderId);
    if (index != -1) {
      final newQueue = [...state.deliveryQueue];
      newQueue[index] = updater(newQueue[index]);
      state = state.copyWith(deliveryQueue: newQueue);
      debugPrint('[RealtimeDriver] Updated delivery $orderId in queue');
    } else {
      debugPrint('[RealtimeDriver] Delivery $orderId not found in queue');
    }
  }
  
  // Delegate methods to original notifier
  Future<void> loadDashboard() => _driverNotifier.loadDashboard();
  Future<void> loadDeliveryQueue() => _driverNotifier.loadDeliveryQueue();
  Future<void> loadEarnings({String period = 'week'}) => _driverNotifier.loadEarnings(period: period);
  Future<void> updateStatus(bool isOnline) => _driverNotifier.updateStatus(isOnline);
  Future<void> updateLocation(double latitude, double longitude) => 
      _driverNotifier.updateLocation(latitude, longitude);
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// Extension to add real-time order updates to the owner state
class RealtimeOwnerNotifier extends StateNotifier<OwnerState> {
  final OwnerNotifier _ownerNotifier;
  final Ref _ref;
  StreamSubscription<OrderEvent>? _eventSubscription;
  
  RealtimeOwnerNotifier(this._ownerNotifier, this._ref) : super(_ownerNotifier.state) {
    _initRealTimeUpdates();
    
    // Forward state changes from the original notifier
    _ownerNotifier.addListener((newState) {
      debugPrint('[RealtimeOwner] Listener received state update! dashboard is null? ${newState.dashboard == null}');
      if (newState.dashboard != null) {
        debugPrint('[RealtimeOwner] Listener: todayRevenue=${newState.dashboard!.todayRevenue}, pendingOrders=${newState.dashboard!.pendingOrders}');
      }
      if (mounted) {
        state = newState;
        debugPrint('[RealtimeOwner] State forwarded to RealtimeOwnerNotifier');
      } else {
        debugPrint('[RealtimeOwner] WARNING: Notifier not mounted, state not forwarded');
      }
    });
  }
  
  void _initRealTimeUpdates() {
    debugPrint('[RealtimeOwner] Initializing real-time updates...');
    
    // Debug: Show current channel subscription state
    final channelState = _ref.read(orderChannelProvider);
    debugPrint('[RealtimeOwner] Channel state - isConnected: ${channelState.isConnected}');
    debugPrint('[RealtimeOwner] Channel state - isSubscribed: ${channelState.isSubscribed}');
    debugPrint('[RealtimeOwner] Channel state - channels: ${channelState.subscribedChannels}');
    
    _eventSubscription = _ref.read(orderChannelProvider.notifier).eventStream.listen((event) {
      debugPrint('[RealtimeOwner] *** RECEIVED EVENT: ${event.type} ***');
      debugPrint('[RealtimeOwner] Event orderId: ${event.orderId}');
      _handleOrderEvent(event);
    }, onError: (e) {
      debugPrint('[RealtimeOwner] Event stream error: $e');
    });
    debugPrint('[RealtimeOwner] Subscribed to event stream');
  }
  
  void _handleOrderEvent(OrderEvent event) {
    debugPrint('[RealtimeOwner] _handleOrderEvent: ${event.type} for order ${event.orderId}');
    switch (event.type) {
      case OrderEventType.orderPlaced:
        _handleNewOrder(event as OrderPlacedEvent);
        break;
      case OrderEventType.orderStatusUpdated:
        _handleOrderStatusUpdate(event as OrderStatusUpdatedEvent);
        break;
      case OrderEventType.orderDelivered:
        _handleOrderDelivered(event as OrderDeliveredEvent);
        break;
      case OrderEventType.orderCancelled:
        _handleOrderCancelled(event as OrderCancelledEvent);
        break;
      default:
        debugPrint('[RealtimeOwner] Unhandled event type: ${event.type}');
        break;
    }
  }
  
  void _handleNewOrder(OrderPlacedEvent event) {
    debugPrint('[RealtimeOwner] _handleNewOrder: ${event.orderId}');
    debugPrint('[RealtimeOwner] Current orders count: ${state.orders.length}');
    
    // Add new order to the orders list
    final existingIndex = state.orders.indexWhere((o) => 
        o.id == event.orderId || 
        o.numericId == event.orderId || 
        o.id.contains(event.orderId) || 
        event.orderId.contains(o.id));
    
    if (existingIndex == -1) {
      debugPrint('[RealtimeOwner] Adding new order to list: ${event.orderId}');
      state = state.copyWith(
        orders: [event.order, ...state.orders],
      );
      debugPrint('[RealtimeOwner] New orders count: ${state.orders.length}');
      
      // Update dashboard pending count
      if (state.dashboard != null) {
        state = state.copyWith(
          dashboard: state.dashboard!.copyWith(
            pendingOrders: state.dashboard!.pendingOrders + 1,
          ),
        );
        debugPrint('[RealtimeOwner] Updated dashboard pending count');
      }
    } else {
      debugPrint('[RealtimeOwner] Order already exists at index: $existingIndex');
    }
  }
  
  void _handleOrderStatusUpdate(OrderStatusUpdatedEvent event) {
    _updateOrderInList(event.orderId, (order) {
      // Always ensure status matches the event, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(status: event.newStatus);
    });
  }
  
  void _handleOrderDelivered(OrderDeliveredEvent event) {
    _updateOrderInList(event.orderId, (order) {
      // Always ensure status is delivered, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(
        status: OrderStatus.delivered,
        deliveredAt: event.timestamp,
      );
    });
  }
  
  void _handleOrderCancelled(OrderCancelledEvent event) {
    _updateOrderInList(event.orderId, (order) {
      // Always ensure status is cancelled, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(
        status: OrderStatus.cancelled,
        cancelledAt: event.timestamp,
        cancellationReason: event.reason,
      );
    });
  }
  
  void _updateOrderInList(String orderId, OrderModel Function(OrderModel) updater) {
    final index = state.orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final newOrders = [...state.orders];
      newOrders[index] = updater(newOrders[index]);
      state = state.copyWith(orders: newOrders);
    }
  }
  
  // Delegate methods to original notifier
  Future<void> loadDashboard() {
    debugPrint('[RealtimeOwner] loadDashboard() delegating to _ownerNotifier');
    return _ownerNotifier.loadDashboard();
  }
  Future<void> loadAnalytics({String period = 'week'}) => _ownerNotifier.loadAnalytics(period: period);
  Future<void> loadInventory() => _ownerNotifier.loadInventory();
  Future<void> loadDrivers() => _ownerNotifier.loadDrivers();
  Future<void> loadPromos({String? status}) => _ownerNotifier.loadPromos(status: status);
  Future<void> loadOrders({String? status, String? date}) => _ownerNotifier.loadOrders(status: status, date: date);
  Future<void> approveOrder(String orderId) => _ownerNotifier.approveOrder(orderId);
  Future<void> rejectOrder(String orderId, {String? reason}) => 
      _ownerNotifier.rejectOrder(orderId, reason: reason);
  Future<void> assignDriver(String orderId, String driverId) => 
      _ownerNotifier.assignDriver(orderId, driverId);
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for driver data with real-time updates
final realtimeDriverProvider = StateNotifierProvider<RealtimeDriverNotifier, DriverState>((ref) {
  final driverNotifier = ref.watch(driverDataProvider.notifier);
  return RealtimeDriverNotifier(driverNotifier, ref);
});

/// Provider for owner data with real-time updates
final realtimeOwnerProvider = StateNotifierProvider<RealtimeOwnerNotifier, OwnerState>((ref) {
  final ownerNotifier = ref.watch(ownerDataProvider.notifier);
  return RealtimeOwnerNotifier(ownerNotifier, ref);
});

/// Provider to get a specific order by ID with real-time updates
final realtimeOrderProvider = StreamProvider.family<OrderModel?, String>((ref, orderId) async* {
  debugPrint('[RealtimeOrderProvider] ========================================');
  debugPrint('[RealtimeOrderProvider] Creating provider for orderId: $orderId');
  
  // First, try to get the order from any of the sources
  OrderModel? currentOrder;
  
  // Check customer orders
  final customerOrders = ref.read(customerOrdersProvider);
  debugPrint('[RealtimeOrderProvider] activeOrders count: ${customerOrders.activeOrders.length}');
  debugPrint('[RealtimeOrderProvider] historyOrders count: ${customerOrders.historyOrders.length}');
  
  // Find order in active orders
  try {
    currentOrder = customerOrders.activeOrders.firstWhere((o) => o.id == orderId);
    debugPrint('[RealtimeOrderProvider] Found order in active orders with status: ${currentOrder.status}');
  } catch (_) {
    // Not found in active orders, try history
    try {
      currentOrder = customerOrders.historyOrders.firstWhere((o) => o.id == orderId);
      debugPrint('[RealtimeOrderProvider] Found order in history orders with status: ${currentOrder.status}');
    } catch (_) {
      // Order not found in local state
      currentOrder = null;
      debugPrint('[RealtimeOrderProvider] Order not found in local state, will fetch from API');
    }
  }
  
  // If not found locally, fetch from API
  if (currentOrder == null) {
    try {
      debugPrint('[RealtimeOrderProvider] Fetching order from API...');
      final orderService = ref.read(orderServiceProvider);
      currentOrder = await orderService.getOrderDetails(orderId);
      debugPrint('[RealtimeOrderProvider] Fetched order from API: ${currentOrder.id}, status: ${currentOrder.status}');
    } catch (e) {
      debugPrint('[RealtimeOrderProvider] Error fetching order from API: $e');
    }
  }
  
  if (currentOrder != null) {
    debugPrint('[RealtimeOrderProvider] Yielding initial order: ${currentOrder.id}, status: ${currentOrder.status}');
    yield currentOrder;
  }
  
  // Only subscribe to WebSocket updates for active orders (not delivered/cancelled/refunded)
  final isActiveOrder = currentOrder?.isActive ?? false;
  if (!isActiveOrder) {
    debugPrint('[RealtimeOrderProvider] Order is not active (status: ${currentOrder?.status}), skipping WebSocket subscription');
    // For history orders, just yield the initial state and don't listen for updates
    return;
  }
  
  // Subscribe to order tracking channel
  final orderChannel = ref.read(orderChannelProvider.notifier);
  debugPrint('[RealtimeOrderProvider] Subscribing to order tracking channel for: $orderId');
  orderChannel.subscribeToOrderTracking(orderId);
  
  // Also subscribe using numericId if available
  if (currentOrder?.numericId != null && currentOrder!.numericId != orderId) {
    debugPrint('[RealtimeOrderProvider] Also subscribing with numericId: ${currentOrder.numericId}');
    orderChannel.subscribeToOrderTracking(currentOrder.numericId!);
  }
  
  // Helper to check if event matches this order (flexible matching)
  bool matchesOrder(OrderEvent e) {
    // Ignore events with empty order IDs
    if (e.orderId.isEmpty) {
      return false;
    }
    
    final matches = e.orderId == orderId || 
           e.orderId.contains(orderId) || 
           orderId.contains(e.orderId) ||
           (currentOrder?.numericId != null && e.orderId == currentOrder!.numericId) ||
           (currentOrder?.numericId != null && e.orderId.contains(currentOrder!.numericId!));
    
    debugPrint('[RealtimeOrderProvider] matchesOrder check: event.orderId=${e.orderId}, target=$orderId, numericId=${currentOrder?.numericId}, matches=$matches');
    return matches;
  }
  
  debugPrint('[RealtimeOrderProvider] Starting to listen for events...');
  
  // Listen for updates
  await for (final event in orderChannel.eventStream.where(matchesOrder)) {
    debugPrint('[RealtimeOrderProvider] *** Received matching event: ${event.type} for order ${event.orderId}');
    switch (event) {
      case OrderStatusUpdatedEvent():
        debugPrint('[RealtimeOrderProvider] Processing OrderStatusUpdatedEvent: ${event.previousStatus} -> ${event.newStatus}');
        // Always ensure status matches the event, even if event.order has wrong status
        final baseOrder = event.order ?? currentOrder;
        if (baseOrder != null) {
          currentOrder = baseOrder.copyWith(status: event.newStatus);
          debugPrint('[RealtimeOrderProvider] Updated status to ${event.newStatus}');
        }
        break;
      case OrderConfirmedEvent():
        // Always ensure status is confirmed
        final baseOrder = event.order ?? currentOrder;
        if (baseOrder != null) {
          currentOrder = baseOrder.copyWith(
            status: OrderStatus.confirmed,
            confirmedAt: event.timestamp,
          );
        }
        break;
      case DriverAssignedEvent():
        // Preserve current status when updating driver info
        final baseOrder = event.order ?? currentOrder;
        if (baseOrder != null) {
          currentOrder = baseOrder.copyWith(
            driverId: event.driverId,
            driverName: event.driverName,
            assignedAt: event.timestamp,
          );
        }
        break;
      case OutForDeliveryEvent():
        // Always ensure status is outForDelivery
        final baseOrder = event.order ?? currentOrder;
        if (baseOrder != null) {
          currentOrder = baseOrder.copyWith(status: OrderStatus.outForDelivery);
        }
        break;
      case OrderDeliveredEvent():
        // Always ensure status is delivered
        final baseOrder = event.order ?? currentOrder;
        if (baseOrder != null) {
          currentOrder = baseOrder.copyWith(
            status: OrderStatus.delivered,
            deliveredAt: event.timestamp,
            proofImageUrl: event.proofImageUrl,
            signatureUrl: event.signatureUrl,
          );
        }
        break;
      case OrderCancelledEvent():
        // Always ensure status is cancelled
        final baseOrder = event.order ?? currentOrder;
        if (baseOrder != null) {
          currentOrder = baseOrder.copyWith(
            status: OrderStatus.cancelled,
            cancelledAt: event.timestamp,
            cancellationReason: event.reason,
          );
        }
        break;
      default:
        break;
    }
    
    if (currentOrder != null) {
      yield currentOrder;
    }
  }
});
