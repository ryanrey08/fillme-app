import 'package:equatable/equatable.dart';
import 'order_model.dart';

/// Types of real-time order events
enum OrderEventType {
  /// A new order has been placed
  orderPlaced,
  
  /// Order status has been updated
  orderStatusUpdated,
  
  /// Order has been confirmed by the owner
  orderConfirmed,
  
  /// A driver has been assigned to the order
  driverAssigned,
  
  /// Driver is out for delivery
  outForDelivery,
  
  /// Order has been delivered
  orderDelivered,
  
  /// Order has been cancelled
  orderCancelled,
  
  /// Driver location updated (for tracking)
  driverLocationUpdated,
  
  /// Payment status updated
  paymentUpdated,
}

/// Base class for all order events
abstract class OrderEvent extends Equatable {
  final OrderEventType type;
  final String orderId;
  final DateTime timestamp;
  
  const OrderEvent({
    required this.type,
    required this.orderId,
    required this.timestamp,
  });
  
  /// Parse an order event from WebSocket message
  static OrderEvent fromJson(Map<String, dynamic> json) {
    final eventName = json['event'] as String? ?? '';
    final data = json['data'] as Map<String, dynamic>? ?? {};
    
    // Map event names from Laravel to event types
    switch (eventName) {
      case 'order.placed':
      case 'order.created':
      case 'OrderPlaced':
      case 'OrderCreated':
        return OrderPlacedEvent.fromJson(data);
      case 'order.status_updated':
      case 'order.status.changed':
      case 'OrderStatusUpdated':
      case 'OrderStatusChanged':
        return OrderStatusUpdatedEvent.fromJson(data);
      case 'order.confirmed':
      case 'OrderConfirmed':
        return OrderConfirmedEvent.fromJson(data);
      case 'order.driver_assigned':
      case 'driver.assigned':
      case 'DriverAssigned':
        return DriverAssignedEvent.fromJson(data);
      case 'order.out_for_delivery':
      case 'OutForDelivery':
        return OutForDeliveryEvent.fromJson(data);
      case 'order.delivered':
      case 'OrderDelivered':
        return OrderDeliveredEvent.fromJson(data);
      case 'order.cancelled':
      case 'OrderCancelled':
        return OrderCancelledEvent.fromJson(data);
      case 'driver.location_updated':
      case 'driver.location.updated':
      case 'DriverLocationUpdated':
        return DriverLocationUpdatedEvent.fromJson(data);
      case 'order.payment_updated':
      case 'PaymentUpdated':
        return PaymentUpdatedEvent.fromJson(data);
      default:
        // Return a generic status update for unknown events
        return OrderStatusUpdatedEvent.fromJson(data);
    }
  }
  
  @override
  List<Object?> get props => [type, orderId, timestamp];
}

/// Event when a new order is placed
class OrderPlacedEvent extends OrderEvent {
  final OrderModel order;
  
  const OrderPlacedEvent({
    required super.orderId,
    required super.timestamp,
    required this.order,
  }) : super(type: OrderEventType.orderPlaced);
  
  factory OrderPlacedEvent.fromJson(Map<String, dynamic> json) {
    // Laravel broadcasts data directly, not nested under 'order'
    // Check if it's nested (old format) or direct (new format)
    final orderData = json.containsKey('order') 
        ? json['order'] as Map<String, dynamic>
        : json;
    
    return OrderPlacedEvent(
      orderId: (orderData['order_number'] ?? orderData['id']?.toString() ?? '') as String,
      timestamp: DateTime.tryParse(orderData['created_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      order: OrderModel.fromJson(orderData),
    );
  }
  
  @override
  List<Object?> get props => [type, orderId, timestamp, order];
}

/// Event when order status is updated
class OrderStatusUpdatedEvent extends OrderEvent {
  final OrderStatus previousStatus;
  final OrderStatus newStatus;
  final OrderModel? order;
  
  const OrderStatusUpdatedEvent({
    required super.orderId,
    required super.timestamp,
    required this.previousStatus,
    required this.newStatus,
    this.order,
  }) : super(type: OrderEventType.orderStatusUpdated);
  
  factory OrderStatusUpdatedEvent.fromJson(Map<String, dynamic> json) {
    // Parse status strings to enums
    OrderStatus parseStatus(String? status) {
      final statusMap = {
        'pending': OrderStatus.pending,
        'confirmed': OrderStatus.confirmed,
        'preparing': OrderStatus.preparing,
        'ready_for_pickup': OrderStatus.readyForPickup,
        'out_for_delivery': OrderStatus.outForDelivery,
        'delivered': OrderStatus.delivered,
        'cancelled': OrderStatus.cancelled,
        'refunded': OrderStatus.refunded,
      };
      return statusMap[status] ?? OrderStatus.pending;
    }
    
    // Get order number from various possible locations
    final orderId = (json['order_number'] ?? json['order_id'] ?? json['id'] ?? '').toString();
    
    // Parse old/previous and new status
    final oldStatus = parseStatus(json['old_status'] as String? ?? json['previous_status'] as String?);
    final newStatus = parseStatus(json['new_status'] as String? ?? json['status'] as String?);
    
    // Try to build OrderModel from the data
    OrderModel? order;
    try {
      order = OrderModel.fromJson(json);
    } catch (e) {
      // If parsing fails, leave order as null
    }
    
    return OrderStatusUpdatedEvent(
      orderId: orderId,
      timestamp: DateTime.tryParse(json['updated_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      previousStatus: oldStatus,
      newStatus: newStatus,
      order: order,
    );
  }
  
  @override
  List<Object?> get props => [type, orderId, timestamp, previousStatus, newStatus, order];
}

/// Event when order is confirmed by owner
class OrderConfirmedEvent extends OrderEvent {
  final OrderModel? order;
  final DateTime? estimatedPrepTime;
  
  const OrderConfirmedEvent({
    required super.orderId,
    required super.timestamp,
    this.order,
    this.estimatedPrepTime,
  }) : super(type: OrderEventType.orderConfirmed);
  
  factory OrderConfirmedEvent.fromJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>?;
    return OrderConfirmedEvent(
      // Prefer order_number for matching with Flutter's local order storage
      orderId: (json['order_number'] ?? orderData?['order_number'] ?? json['order_id'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['confirmed_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      order: orderData != null ? OrderModel.fromJson(orderData) : null,
      estimatedPrepTime: json['estimated_prep_time'] != null 
          ? DateTime.tryParse(json['estimated_prep_time'].toString())
          : null,
    );
  }
  
  @override
  List<Object?> get props => [type, orderId, timestamp, order, estimatedPrepTime];
}

/// Event when a driver is assigned to the order
class DriverAssignedEvent extends OrderEvent {
  final String driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final double? driverRating;
  final OrderModel? order;
  
  const DriverAssignedEvent({
    required super.orderId,
    required super.timestamp,
    required this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPhotoUrl,
    this.driverRating,
    this.order,
  }) : super(type: OrderEventType.driverAssigned);
  
  factory DriverAssignedEvent.fromJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>?;
    final driverData = json['driver'] as Map<String, dynamic>?;
    
    // Prefer order_number for matching with Flutter's local order storage
    return DriverAssignedEvent(
      orderId: (json['order_number'] ?? orderData?['order_number'] ?? json['order_id'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['assigned_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      driverId: (driverData?['id'] ?? json['driver_id'] ?? '').toString(),
      driverName: driverData?['name'] as String? ?? json['driver_name'] as String?,
      driverPhone: driverData?['phone'] as String?,
      driverPhotoUrl: driverData?['photo_url'] as String?,
      driverRating: (driverData?['rating'] as num?)?.toDouble(),
      order: orderData != null ? OrderModel.fromJson(orderData) : null,
    );
  }
  
  @override
  List<Object?> get props => [
    type, orderId, timestamp, driverId, driverName, 
    driverPhone, driverPhotoUrl, driverRating, order
  ];
}

/// Event when driver is out for delivery
class OutForDeliveryEvent extends OrderEvent {
  final String driverId;
  final double? driverLatitude;
  final double? driverLongitude;
  final int? estimatedMinutes;
  final OrderModel? order;
  
  const OutForDeliveryEvent({
    required super.orderId,
    required super.timestamp,
    required this.driverId,
    this.driverLatitude,
    this.driverLongitude,
    this.estimatedMinutes,
    this.order,
  }) : super(type: OrderEventType.outForDelivery);
  
  factory OutForDeliveryEvent.fromJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>?;
    return OutForDeliveryEvent(
      // Prefer order_number for matching with Flutter's local order storage
      orderId: (json['order_number'] ?? orderData?['order_number'] ?? json['order_id'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['out_for_delivery_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      driverId: (json['driver_id'] ?? '').toString(),
      driverLatitude: (json['driver_latitude'] as num?)?.toDouble(),
      driverLongitude: (json['driver_longitude'] as num?)?.toDouble(),
      estimatedMinutes: json['estimated_minutes'] as int?,
      order: orderData != null ? OrderModel.fromJson(orderData) : null,
    );
  }
  
  @override
  List<Object?> get props => [
    type, orderId, timestamp, driverId, 
    driverLatitude, driverLongitude, estimatedMinutes, order
  ];
}

/// Event when order is delivered
class OrderDeliveredEvent extends OrderEvent {
  final String? proofImageUrl;
  final String? signatureUrl;
  final OrderModel? order;
  
  const OrderDeliveredEvent({
    required super.orderId,
    required super.timestamp,
    this.proofImageUrl,
    this.signatureUrl,
    this.order,
  }) : super(type: OrderEventType.orderDelivered);
  
  factory OrderDeliveredEvent.fromJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>?;
    return OrderDeliveredEvent(
      // Prefer order_number for matching with Flutter's local order storage
      orderId: (json['order_number'] ?? orderData?['order_number'] ?? json['order_id'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['delivered_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      proofImageUrl: json['proof_image_url'] as String?,
      signatureUrl: json['signature_url'] as String?,
      order: orderData != null ? OrderModel.fromJson(orderData) : null,
    );
  }
  
  @override
  List<Object?> get props => [type, orderId, timestamp, proofImageUrl, signatureUrl, order];
}

/// Event when order is cancelled
class OrderCancelledEvent extends OrderEvent {
  final String? reason;
  final String? cancelledBy;
  final OrderModel? order;
  
  const OrderCancelledEvent({
    required super.orderId,
    required super.timestamp,
    this.reason,
    this.cancelledBy,
    this.order,
  }) : super(type: OrderEventType.orderCancelled);
  
  factory OrderCancelledEvent.fromJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>?;
    return OrderCancelledEvent(
      // Prefer order_number for matching with Flutter's local order storage
      orderId: (json['order_number'] ?? orderData?['order_number'] ?? json['order_id'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['cancelled_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      order: orderData != null ? OrderModel.fromJson(orderData) : null,
    );
  }
  
  @override
  List<Object?> get props => [type, orderId, timestamp, reason, cancelledBy, order];
}

/// Event for driver location updates (for real-time tracking)
class DriverLocationUpdatedEvent extends OrderEvent {
  final String driverId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final int? estimatedMinutes;
  
  const DriverLocationUpdatedEvent({
    required super.orderId,
    required super.timestamp,
    required this.driverId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.estimatedMinutes,
  }) : super(type: OrderEventType.driverLocationUpdated);
  
  factory DriverLocationUpdatedEvent.fromJson(Map<String, dynamic> json) {
    return DriverLocationUpdatedEvent(
      orderId: (json['order_id'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      driverId: (json['driver_id'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      estimatedMinutes: json['estimated_minutes'] as int?,
    );
  }
  
  @override
  List<Object?> get props => [
    type, orderId, timestamp, driverId, 
    latitude, longitude, heading, speed, estimatedMinutes
  ];
}

/// Event when payment status is updated
class PaymentUpdatedEvent extends OrderEvent {
  final PaymentStatus previousStatus;
  final PaymentStatus newStatus;
  final String? paymentReference;
  final OrderModel? order;
  
  const PaymentUpdatedEvent({
    required super.orderId,
    required super.timestamp,
    required this.previousStatus,
    required this.newStatus,
    this.paymentReference,
    this.order,
  }) : super(type: OrderEventType.paymentUpdated);
  
  factory PaymentUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>?;
    return PaymentUpdatedEvent(
      orderId: (json['order_id'] ?? orderData?['order_number'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      previousStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == json['previous_status'],
        orElse: () => PaymentStatus.pending,
      ),
      newStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == json['new_status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentReference: json['payment_reference'] as String?,
      order: orderData != null ? OrderModel.fromJson(orderData) : null,
    );
  }
  
  @override
  List<Object?> get props => [
    type, orderId, timestamp, previousStatus, newStatus, paymentReference, order
  ];
}
