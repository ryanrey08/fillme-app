import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order_model.dart';
import '../../models/order_event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_channel_provider.dart';
import '../../providers/realtime_order_provider.dart';
import '../../services/websocket_service.dart';

/// A widget that manages WebSocket connection lifecycle based on authentication state.
/// 
/// Wrap your app's main content with this widget after authentication to enable
/// real-time order updates.
/// 
/// Example:
/// ```dart
/// OrderChannelManager(
///   child: MaterialApp(...),
/// )
/// ```
class OrderChannelManager extends ConsumerStatefulWidget {
  final Widget child;
  
  const OrderChannelManager({
    super.key,
    required this.child,
  });
  
  @override
  ConsumerState<OrderChannelManager> createState() => _OrderChannelManagerState();
}

class _OrderChannelManagerState extends ConsumerState<OrderChannelManager> {
  bool _wasAuthenticated = false;
  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();
    // Don't connect at startup - wait for auth state to be ready
    debugPrint('[OrderChannelManager] initState - waiting for auth state');
  }
  
  void _connectToWebSocket() {
    debugPrint('[OrderChannelManager] Attempting to connect to WebSocket...');
    // Fire and forget - don't block UI
    Future(() async {
      try {
        await ref.read(orderChannelProvider.notifier).connect();
        debugPrint('[OrderChannelManager] WebSocket connection completed');
      } catch (e) {
        debugPrint('[OrderChannelManager] WebSocket connection error: $e');
      }
    });
  }
  
  @override
  void dispose() {
    // Disconnect is handled by auth state change in build, 
    // so we don't need to duplicate it here
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Watch auth state to reconnect when user logs in/out
    final authState = ref.watch(authProvider);
    
    // Skip if auth is still in initial state
    if (authState.status == AuthStatus.initial) {
      debugPrint('[OrderChannelManager] Auth still initializing, skipping...');
      _wasAuthenticated = false;
      return widget.child;
    }
    
    // First time auth is ready
    if (!_initialCheckDone) {
      _initialCheckDone = true;
      if (authState.isAuthenticated) {
        debugPrint('[OrderChannelManager] Initial auth check: authenticated, connecting...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _connectToWebSocket();
        });
      }
    }
    
    // If user just logged in, connect to WebSocket
    if (authState.isAuthenticated && !_wasAuthenticated && _initialCheckDone) {
      debugPrint('[OrderChannelManager] User authenticated, connecting to WebSocket...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connectToWebSocket();
      });
    }
    
    // If user just logged out, disconnect
    if (!authState.isAuthenticated && _wasAuthenticated) {
      debugPrint('[OrderChannelManager] User logged out, disconnecting...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(orderChannelProvider.notifier).disconnect();
      });
    }
    
    _wasAuthenticated = authState.isAuthenticated;
    
    return widget.child;
  }
}

/// A widget that displays the WebSocket connection status indicator.
/// 
/// Shows a small colored dot indicating:
/// - Green: Connected
/// - Yellow/Orange: Connecting/Reconnecting
/// - Red: Disconnected/Error
class WebSocketStatusIndicator extends ConsumerWidget {
  final double size;
  final bool showLabel;
  
  const WebSocketStatusIndicator({
    super.key,
    this.size = 12,
    this.showLabel = false,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelState = ref.watch(orderChannelProvider);
    
    Color statusColor;
    String statusText;
    
    if (channelState.isConnected) {
      statusColor = Colors.green;
      statusText = 'Connected';
    } else {
      final wsService = ref.read(webSocketServiceProvider);
      switch (wsService.connectionState) {
        case WebSocketConnectionState.connecting:
          statusColor = Colors.orange;
          statusText = 'Connecting...';
          break;
        case WebSocketConnectionState.reconnecting:
          statusColor = Colors.yellow.shade700;
          statusText = 'Reconnecting...';
          break;
        case WebSocketConnectionState.error:
          statusColor = Colors.red;
          statusText = 'Connection error';
          break;
        default:
          statusColor = Colors.grey;
          statusText = 'Disconnected';
      }
    }
    
    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
            ),
          ),
        ],
      );
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A widget that displays real-time order status updates.
/// 
/// Automatically subscribes to the order tracking channel and updates
/// when new events are received.
class RealtimeOrderTracker extends ConsumerStatefulWidget {
  final String orderId;
  final Widget Function(BuildContext context, OrderModel? order, OrderEvent? lastEvent) builder;
  final Widget? loadingWidget;
  final Widget Function(String error)? errorBuilder;
  
  const RealtimeOrderTracker({
    super.key,
    required this.orderId,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
  });
  
  @override
  ConsumerState<RealtimeOrderTracker> createState() => _RealtimeOrderTrackerState();
}

class _RealtimeOrderTrackerState extends ConsumerState<RealtimeOrderTracker> {
  StreamSubscription<OrderEvent>? _subscription;
  OrderEvent? _lastEvent;
  
  @override
  void initState() {
    super.initState();
    // Subscribe to order-specific events
    _subscribeToOrderEvents();
  }
  
  @override
  void didUpdateWidget(RealtimeOrderTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _unsubscribe();
      _subscribeToOrderEvents();
    }
  }
  
  void _subscribeToOrderEvents() {
    // Subscribe to the order tracking channel
    ref.read(orderChannelProvider.notifier).subscribeToOrderTracking(widget.orderId);
    
    // Listen for events for this specific order
    _subscription = ref.read(orderChannelProvider.notifier)
        .eventStream
        .where((event) => event.orderId == widget.orderId)
        .listen((event) {
      if (mounted) {
        setState(() {
          _lastEvent = event;
        });
      }
    });
  }
  
  void _unsubscribe() {
    _subscription?.cancel();
    ref.read(orderChannelProvider.notifier).unsubscribeFromOrderTracking(widget.orderId);
  }
  
  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(realtimeOrderProvider(widget.orderId));
    
    return orderAsync.when(
      data: (order) => widget.builder(context, order, _lastEvent),
      loading: () => widget.loadingWidget ?? const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => widget.errorBuilder?.call(error.toString()) ?? Center(
        child: Text('Error: $error'),
      ),
    );
  }
}

/// A widget that listens for new order events and calls a callback.
/// 
/// Useful for showing notifications or triggering actions when orders update.
class OrderEventListener extends ConsumerStatefulWidget {
  final Widget child;
  final void Function(OrderEvent event)? onOrderPlaced;
  final void Function(OrderEvent event)? onOrderStatusChanged;
  final void Function(OrderEvent event)? onDriverAssigned;
  final void Function(OrderEvent event)? onOrderDelivered;
  final void Function(OrderEvent event)? onOrderCancelled;
  final void Function(OrderEvent event)? onAnyEvent;
  
  const OrderEventListener({
    super.key,
    required this.child,
    this.onOrderPlaced,
    this.onOrderStatusChanged,
    this.onDriverAssigned,
    this.onOrderDelivered,
    this.onOrderCancelled,
    this.onAnyEvent,
  });
  
  @override
  ConsumerState<OrderEventListener> createState() => _OrderEventListenerState();
}

class _OrderEventListenerState extends ConsumerState<OrderEventListener> {
  StreamSubscription<OrderEvent>? _subscription;
  
  @override
  void initState() {
    super.initState();
    _subscription = ref.read(orderChannelProvider.notifier)
        .eventStream
        .listen(_handleEvent);
  }
  
  void _handleEvent(OrderEvent event) {
    widget.onAnyEvent?.call(event);
    
    switch (event.type) {
      case OrderEventType.orderPlaced:
        widget.onOrderPlaced?.call(event);
        break;
      case OrderEventType.orderStatusUpdated:
      case OrderEventType.orderConfirmed:
      case OrderEventType.outForDelivery:
        widget.onOrderStatusChanged?.call(event);
        break;
      case OrderEventType.driverAssigned:
        widget.onDriverAssigned?.call(event);
        break;
      case OrderEventType.orderDelivered:
        widget.onOrderDelivered?.call(event);
        break;
      case OrderEventType.orderCancelled:
        widget.onOrderCancelled?.call(event);
        break;
      default:
        break;
    }
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) => widget.child;
}

/// A status timeline widget that updates in real-time.
/// 
/// Shows the order progress through different status stages.
class RealtimeOrderStatusTimeline extends ConsumerWidget {
  final String orderId;
  final OrderStatus currentStatus;
  
  const RealtimeOrderStatusTimeline({
    super.key,
    required this.orderId,
    required this.currentStatus,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for real-time status updates
    final eventAsync = ref.watch(orderEventsForOrderProvider(orderId));
    
    // Get the latest status (either from event or current)
    OrderStatus displayStatus = currentStatus;
    eventAsync.whenData((event) {
      if (event is OrderStatusUpdatedEvent) {
        displayStatus = event.newStatus;
      } else if (event is OrderConfirmedEvent) {
        displayStatus = OrderStatus.confirmed;
      } else if (event is OutForDeliveryEvent) {
        displayStatus = OrderStatus.outForDelivery;
      } else if (event is OrderDeliveredEvent) {
        displayStatus = OrderStatus.delivered;
      } else if (event is OrderCancelledEvent) {
        displayStatus = OrderStatus.cancelled;
      }
    });
    
    return _buildTimeline(context, displayStatus);
  }
  
  Widget _buildTimeline(BuildContext context, OrderStatus status) {
    final steps = [
      _TimelineStep(
        status: OrderStatus.pending,
        label: 'Order Placed',
        icon: Icons.shopping_cart,
      ),
      _TimelineStep(
        status: OrderStatus.confirmed,
        label: 'Confirmed',
        icon: Icons.check_circle,
      ),
      _TimelineStep(
        status: OrderStatus.preparing,
        label: 'Preparing',
        icon: Icons.restaurant,
      ),
      _TimelineStep(
        status: OrderStatus.outForDelivery,
        label: 'On The Way',
        icon: Icons.local_shipping,
      ),
      _TimelineStep(
        status: OrderStatus.delivered,
        label: 'Delivered',
        icon: Icons.home,
      ),
    ];
    
    final currentIndex = steps.indexWhere((s) => s.status == status);
    
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;
        
        return _buildTimelineItem(
          context,
          step: step,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: index == steps.length - 1,
        );
      }),
    );
  }
  
  Widget _buildTimelineItem(
    BuildContext context, {
    required _TimelineStep step,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final greyColor = Colors.grey.shade300;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted ? primaryColor : greyColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon,
                  size: 18,
                  color: isCompleted ? Colors.white : Colors.grey,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? primaryColor : greyColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (isCurrent)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Current status',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  final OrderStatus status;
  final String label;
  final IconData icon;
  
  _TimelineStep({
    required this.status,
    required this.label,
    required this.icon,
  });
}

/// A widget for displaying driver location on a map with real-time updates.
/// 
/// Use with google_maps_flutter to show driver location during delivery.
class DriverLocationTracker extends ConsumerWidget {
  final String orderId;
  final Widget Function(double latitude, double longitude, int? estimatedMinutes) builder;
  final Widget? loadingWidget;
  
  const DriverLocationTracker({
    super.key,
    required this.orderId,
    required this.builder,
    this.loadingWidget,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationStream = ref.watch(driverLocationForOrderProvider(orderId));
    
    return locationStream.when(
      data: (event) => builder(
        event.latitude,
        event.longitude,
        event.estimatedMinutes,
      ),
      loading: () => loadingWidget ?? const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => loadingWidget ?? const SizedBox.shrink(),
    );
  }
}
