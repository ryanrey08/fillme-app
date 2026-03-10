import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/order_event_model.dart';
import '../services/order_service.dart';
import 'auth_provider.dart';
import 'order_channel_provider.dart';

// Customer orders state
class CustomerOrdersState {
  final List<OrderModel> activeOrders;
  final List<OrderModel> historyOrders;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int activePage;
  final int historyPage;
  final bool hasMoreActive;
  final bool hasMoreHistory;
  final OrderEvent? lastEvent; // Track last real-time event

  const CustomerOrdersState({
    this.activeOrders = const [],
    this.historyOrders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.activePage = 1,
    this.historyPage = 1,
    this.hasMoreActive = true,
    this.hasMoreHistory = true,
    this.lastEvent,
  });

  CustomerOrdersState copyWith({
    List<OrderModel>? activeOrders,
    List<OrderModel>? historyOrders,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    int? activePage,
    int? historyPage,
    bool? hasMoreActive,
    bool? hasMoreHistory,
    OrderEvent? lastEvent,
  }) {
    return CustomerOrdersState(
      activeOrders: activeOrders ?? this.activeOrders,
      historyOrders: historyOrders ?? this.historyOrders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      activePage: activePage ?? this.activePage,
      historyPage: historyPage ?? this.historyPage,
      hasMoreActive: hasMoreActive ?? this.hasMoreActive,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

class CustomerOrdersNotifier extends StateNotifier<CustomerOrdersState> {
  final OrderService _orderService;
  final Ref _ref;
  StreamSubscription<OrderEvent>? _eventSubscription;

  CustomerOrdersNotifier(this._orderService, this._ref) : super(const CustomerOrdersState()) {
    _initRealTimeUpdates();
  }

  void _initRealTimeUpdates() {
    // Listen to order events from the channel provider
    _eventSubscription = _ref.read(orderChannelProvider.notifier).eventStream.listen((event) {
      _handleOrderEvent(event);
    });
    debugPrint('[CustomerOrders] Real-time updates initialized');
  }

  void _handleOrderEvent(OrderEvent event) {
    debugPrint('[CustomerOrders] Received event: ${event.type} for order ${event.orderId}');
    switch (event.type) {
      case OrderEventType.orderStatusUpdated:
        _handleStatusUpdate(event as OrderStatusUpdatedEvent);
        break;
      case OrderEventType.orderConfirmed:
        _handleOrderConfirmed(event as OrderConfirmedEvent);
        break;
      case OrderEventType.driverAssigned:
        _handleDriverAssigned(event as DriverAssignedEvent);
        break;
      case OrderEventType.outForDelivery:
        _handleOutForDelivery(event as OutForDeliveryEvent);
        break;
      case OrderEventType.orderDelivered:
        _handleOrderDelivered(event as OrderDeliveredEvent);
        break;
      case OrderEventType.orderCancelled:
        _handleOrderCancelled(event as OrderCancelledEvent);
        break;
      default:
        debugPrint('[CustomerOrders] Unhandled event type: ${event.type}');
        break;
    }
    
    state = state.copyWith(lastEvent: event);
  }

  void _handleStatusUpdate(OrderStatusUpdatedEvent event) {
    _updateOrderInLists(event.orderId, (order) {
      // Always ensure status matches the event, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(status: event.newStatus);
    });
  }

  void _handleOrderConfirmed(OrderConfirmedEvent event) {
    _updateOrderInLists(event.orderId, (order) {
      // Always ensure status is confirmed, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(
        status: OrderStatus.confirmed,
        confirmedAt: event.timestamp,
      );
    });
  }

  void _handleDriverAssigned(DriverAssignedEvent event) {
    debugPrint('[CustomerOrders] _handleDriverAssigned called for order: ${event.orderId}, driver: ${event.driverName}');
    _updateOrderInLists(event.orderId, (order) {
      debugPrint('[CustomerOrders] Updating order ${order.id} with driver ${event.driverName}');
      // Preserve current status when updating driver info
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(
        driverId: event.driverId,
        driverName: event.driverName,
        assignedAt: event.timestamp,
      );
    });
  }

  void _handleOutForDelivery(OutForDeliveryEvent event) {
    _updateOrderInLists(event.orderId, (order) {
      // Always ensure status is outForDelivery, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      return baseOrder.copyWith(status: OrderStatus.outForDelivery);
    });
  }

  /// Helper to find order index with flexible matching
  int _findOrderIndex(List<OrderModel> orders, String orderId) {
    return orders.indexWhere((o) => 
        o.id == orderId || o.numericId == orderId || o.id.contains(orderId) || orderId.contains(o.id));
  }

  void _handleOrderDelivered(OrderDeliveredEvent event) {
    final orderId = event.orderId;
    
    // Find the order in active orders using flexible matching
    final activeIndex = _findOrderIndex(state.activeOrders, orderId);
    if (activeIndex != -1) {
      final order = state.activeOrders[activeIndex];
      // Always ensure status is delivered, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      final updatedOrder = baseOrder.copyWith(
        status: OrderStatus.delivered,
        deliveredAt: event.timestamp,
        proofImageUrl: event.proofImageUrl,
        signatureUrl: event.signatureUrl,
      );
      
      // Move from active to history
      final newActiveOrders = [...state.activeOrders];
      newActiveOrders.removeAt(activeIndex);
      
      final newHistoryOrders = [updatedOrder, ...state.historyOrders];
      
      state = state.copyWith(
        activeOrders: newActiveOrders,
        historyOrders: newHistoryOrders,
      );
      debugPrint('[CustomerOrders] Order $orderId delivered and moved to history');
    }
  }

  void _handleOrderCancelled(OrderCancelledEvent event) {
    final orderId = event.orderId;
    
    // Find the order in active orders using flexible matching
    final activeIndex = _findOrderIndex(state.activeOrders, orderId);
    if (activeIndex != -1) {
      final order = state.activeOrders[activeIndex];
      // Always ensure status is cancelled, even if event.order has wrong status
      final baseOrder = event.order ?? order;
      final updatedOrder = baseOrder.copyWith(
        status: OrderStatus.cancelled,
        cancelledAt: event.timestamp,
        cancellationReason: event.reason,
      );
      
      // Move from active to history
      final newActiveOrders = [...state.activeOrders];
      newActiveOrders.removeAt(activeIndex);
      
      final newHistoryOrders = [updatedOrder, ...state.historyOrders];
      
      state = state.copyWith(
        activeOrders: newActiveOrders,
        historyOrders: newHistoryOrders,
      );
    }
  }

  void _updateOrderInLists(String orderId, OrderModel Function(OrderModel) updater) {
    // Only update orders in active list - history orders should not be modified by WebSocket events
    final activeIndex = state.activeOrders.indexWhere((o) => 
        o.id == orderId || o.numericId == orderId || o.id.contains(orderId) || orderId.contains(o.id));
    if (activeIndex != -1) {
      final newActiveOrders = [...state.activeOrders];
      newActiveOrders[activeIndex] = updater(newActiveOrders[activeIndex]);
      state = state.copyWith(activeOrders: newActiveOrders);
      debugPrint('[CustomerOrders] Updated order $orderId in active orders');
    } else {
      debugPrint('[CustomerOrders] Order $orderId not found in active orders (may be in history - ignoring WebSocket update)');
    }
  }

  /// Add a newly placed order to the active orders list
  void addNewOrder(OrderModel order) {
    state = state.copyWith(
      activeOrders: [order, ...state.activeOrders],
    );
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final allOrders = await _orderService.getCustomerOrders(page: 1, limit: 50);
      
      debugPrint('[CustomerOrders] Loaded ${allOrders.length} total orders');
      for (final order in allOrders) {
        debugPrint('[CustomerOrders] Order ${order.id}: status=${order.status}, isActive=${order.isActive}');
      }
      
      final activeOrders = allOrders.where((order) => order.isActive).toList();
      final historyOrders = allOrders.where((order) => !order.isActive).toList();
      
      debugPrint('[CustomerOrders] Split: ${activeOrders.length} active, ${historyOrders.length} history');

      state = state.copyWith(
        activeOrders: activeOrders,
        historyOrders: historyOrders,
        isLoading: false,
        activePage: 1,
        historyPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshOrders() async {
    await loadOrders();
  }

  Future<void> loadMoreActiveOrders() async {
    if (state.isLoadingMore || !state.hasMoreActive) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final newOrders = await _orderService.getCustomerOrders(
        page: state.activePage + 1,
        limit: 20,
      );

      final activeNewOrders = newOrders.where((order) => order.isActive).toList();

      state = state.copyWith(
        activeOrders: [...state.activeOrders, ...activeNewOrders],
        isLoadingMore: false,
        activePage: state.activePage + 1,
        hasMoreActive: activeNewOrders.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> loadMoreHistoryOrders() async {
    if (state.isLoadingMore || !state.hasMoreHistory) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final newOrders = await _orderService.getCustomerOrders(
        page: state.historyPage + 1,
        limit: 20,
      );

      final historyNewOrders = newOrders.where((order) => !order.isActive).toList();

      state = state.copyWith(
        historyOrders: [...state.historyOrders, ...historyNewOrders],
        isLoadingMore: false,
        historyPage: state.historyPage + 1,
        hasMoreHistory: historyNewOrders.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

final customerOrdersProvider =
    StateNotifierProvider<CustomerOrdersNotifier, CustomerOrdersState>((ref) {
  final orderService = ref.watch(orderServiceProvider);
  return CustomerOrdersNotifier(orderService, ref);
});
