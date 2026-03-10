import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  readyForPickup,
  outForDelivery,
  delivered,
  cancelled,
  refunded,
}

enum OrderType {
  instant,
  subscription,
}

enum PaymentMethod {
  gcash,
  maya,
  card,
  cod,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

class OrderModel extends Equatable {
  final String id;
  final String? numericId; // Numeric ID for API calls
  final String? deliveryId; // Delivery wrapper ID for driver API calls
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String stationId;
  final String? stationName;
  final String? driverId;
  final String? driverName;
  final OrderType orderType;
  final OrderStatus status;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentReference;
  final String deliveryAddressId;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? notes;
  final String? proofImageUrl;
  final String? signatureUrl;
  final DateTime? scheduledDate;
  final DateTime? confirmedAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final int? loyaltyPointsEarned;
  final int? loyaltyPointsUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    this.numericId,
    this.deliveryId,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.stationId,
    this.stationName,
    this.driverId,
    this.driverName,
    required this.orderType,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    this.discount = 0,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentReference,
    required this.deliveryAddressId,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.notes,
    this.proofImageUrl,
    this.signatureUrl,
    this.scheduledDate,
    this.confirmedAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    this.loyaltyPointsEarned,
    this.loyaltyPointsUsed,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusDisplayName {
    switch (status) {
      case OrderStatus.pending:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'On The Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.maya:
        return 'Maya';
      case PaymentMethod.card:
        return 'Credit/Debit Card';
      case PaymentMethod.cod:
        return 'Cash on Delivery';
    }
  }

  bool get canCancel =>
      status == OrderStatus.pending || status == OrderStatus.confirmed;

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled && status != OrderStatus.refunded;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values that might be strings
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int? parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    // If this is a delivery wrapper with nested order, merge the data
    // The nested 'order' object contains the actual order details
    final nestedOrder = json['order'] as Map<String, dynamic>?;
    final orderData = nestedOrder ?? json;

    // Parse status from API (snake_case to enum)
    // Use status from nested order if available, otherwise from wrapper
    final rawStatus = orderData['status'] ?? json['status'];
    final statusStr = (rawStatus as String? ?? 'pending').toLowerCase();
    final orderNumber = orderData['order_number'] ?? json['order_number'] ?? 'unknown';
    
    debugPrint('[OrderModel.fromJson] Order $orderNumber: rawStatus="$rawStatus", statusStr="$statusStr"');
    
    final statusMap = {
      'pending': OrderStatus.pending,
      'confirmed': OrderStatus.confirmed,
      'preparing': OrderStatus.preparing,
      'ready_for_pickup': OrderStatus.readyForPickup,
      'ready': OrderStatus.readyForPickup,
      'out_for_delivery': OrderStatus.outForDelivery,
      'in_transit': OrderStatus.outForDelivery,
      'delivered': OrderStatus.delivered,
      'completed': OrderStatus.delivered, // API may return 'completed' for finished orders
      'cancelled': OrderStatus.cancelled,
      'canceled': OrderStatus.cancelled, // Handle alternate spelling
      'refunded': OrderStatus.refunded,
    };
    final status = statusMap[statusStr];
    if (status == null) {
      debugPrint('[OrderModel] WARNING: Unknown status "$rawStatus" (normalized: "$statusStr") for order $orderNumber - defaulting to pending');
    }
    final finalStatus = status ?? OrderStatus.pending;
    debugPrint('[OrderModel.fromJson] Order $orderNumber: finalStatus=$finalStatus');

    // Get station name from nested object or direct field
    String? stationName;
    if (orderData['station'] != null && orderData['station'] is Map) {
      stationName = orderData['station']['name'] as String?;
    } else {
      stationName = orderData['station_name'] as String?;
    }

    // Get customer info from nested object or direct fields
    String? customerName;
    String? customerPhone;
    if (orderData['customer'] != null && orderData['customer'] is Map) {
      final customer = orderData['customer'] as Map<String, dynamic>;
      customerName = customer['full_name'] as String? ?? 
                     customer['name'] as String? ??
                     '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
      if (customerName?.isEmpty ?? true) customerName = null;
      customerPhone = customer['phone'] as String?;
    } else if (orderData['user'] != null && orderData['user'] is Map) {
      final user = orderData['user'] as Map<String, dynamic>;
      customerName = user['full_name'] as String? ?? 
                     user['name'] as String? ??
                     '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
      if (customerName?.isEmpty ?? true) customerName = null;
      customerPhone = user['phone'] as String?;
    } else {
      customerName = orderData['customer_name'] as String?;
      customerPhone = orderData['customer_phone'] as String?;
    }

    // Get driver info from nested object
    String? driverId;
    String? driverName;
    if (orderData['driver'] != null && orderData['driver'] is Map) {
      final driver = orderData['driver'] as Map<String, dynamic>;
      driverId = driver['id']?.toString();
      // Try direct name fields first
      driverName = driver['full_name'] as String? ?? driver['name'] as String?;
      // If not found, check nested user object
      if (driverName == null && driver['user'] != null && driver['user'] is Map) {
        final driverUser = driver['user'] as Map<String, dynamic>;
        driverName = driverUser['full_name'] as String? ?? 
                     driverUser['name'] as String? ??
                     '${driverUser['first_name'] ?? ''} ${driverUser['last_name'] ?? ''}'.trim();
        if (driverName?.isEmpty ?? true) driverName = null;
      }
    } else {
      driverId = (orderData['driver_id'] ?? json['driver_id'])?.toString();
      driverName = orderData['driver_name'] as String?;
    }

    // Parse items - handle both nested and flat
    List<OrderItem> items = [];
    if (orderData['items'] != null && orderData['items'] is List) {
      items = (orderData['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // If there's a nested order, the wrapper's id is the delivery ID
    final deliveryId = nestedOrder != null ? json['id']?.toString() : null;

    return OrderModel(
      id: (orderData['order_number'] ?? orderData['id']?.toString() ?? '') as String,
      numericId: orderData['id']?.toString(),
      deliveryId: deliveryId,
      customerId: (orderData['user_id'] ?? orderData['customer_id'])?.toString() ?? '',
      customerName: customerName,
      customerPhone: customerPhone,
      stationId: orderData['station_id']?.toString() ?? '',
      stationName: stationName,
      driverId: driverId,
      driverName: driverName,
      orderType: orderData['subscription_id'] != null ? OrderType.subscription : OrderType.instant,
      status: finalStatus,
      items: items,
      subtotal: parseDouble(orderData['subtotal']),
      deliveryFee: parseDouble(orderData['delivery_fee']),
      discount: parseDouble(orderData['discount_amount'] ?? orderData['discount']),
      total: parseDouble(orderData['total_amount'] ?? orderData['total']),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == orderData['payment_method'],
        orElse: () => PaymentMethod.cod,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == orderData['payment_status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentReference: orderData['payment_reference'] as String?,
      deliveryAddressId: (orderData['address_id'] ?? orderData['delivery_address_id'])?.toString() ?? '',
      deliveryAddress: orderData['delivery_address'] as String? ?? '',
      deliveryLatitude: parseDouble(orderData['delivery_lat'] ?? orderData['delivery_latitude']),
      deliveryLongitude: parseDouble(orderData['delivery_lng'] ?? orderData['delivery_longitude']),
      notes: orderData['customer_notes'] ?? orderData['notes'] as String?,
      proofImageUrl: orderData['proof_image_url'] as String?,
      signatureUrl: orderData['signature_url'] as String?,
      scheduledDate: orderData['scheduled_date'] != null
          ? DateTime.tryParse(orderData['scheduled_date'].toString())
          : null,
      confirmedAt: orderData['confirmed_at'] != null
          ? DateTime.tryParse(orderData['confirmed_at'].toString())
          : null,
      assignedAt: (json['assigned_at'] ?? orderData['dispatched_at']) != null
          ? DateTime.tryParse((json['assigned_at'] ?? orderData['dispatched_at']).toString())
          : null,
      pickedUpAt: (json['picked_up_at'] ?? orderData['preparing_at']) != null
          ? DateTime.tryParse((json['picked_up_at'] ?? orderData['preparing_at']).toString())
          : null,
      deliveredAt: (json['delivered_at'] ?? orderData['delivered_at']) != null
          ? DateTime.tryParse((json['delivered_at'] ?? orderData['delivered_at']).toString())
          : null,
      cancelledAt: (orderData['cancelled_at'] ?? json['cancelled_at']) != null
          ? DateTime.tryParse((orderData['cancelled_at'] ?? json['cancelled_at']).toString())
          : null,
      cancellationReason: orderData['cancellation_reason'] as String?,
      loyaltyPointsEarned: parseIntOrNull(orderData['loyalty_points_earned']),
      loyaltyPointsUsed: parseIntOrNull(orderData['loyalty_points_used']),
      createdAt: DateTime.tryParse(orderData['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(orderData['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'station_id': stationId,
      'station_name': stationName,
      'driver_id': driverId,
      'driver_name': driverName,
      'order_type': orderType.name,
      'status': status.name,
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'discount': discount,
      'total': total,
      'payment_method': paymentMethod.name,
      'payment_status': paymentStatus.name,
      'payment_reference': paymentReference,
      'delivery_address_id': deliveryAddressId,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'notes': notes,
      'proof_image_url': proofImageUrl,
      'signature_url': signatureUrl,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'loyalty_points_earned': loyaltyPointsEarned,
      'loyalty_points_used': loyaltyPointsUsed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? numericId,
    String? deliveryId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? stationId,
    String? stationName,
    String? driverId,
    String? driverName,
    OrderType? orderType,
    OrderStatus? status,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    double? total,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    String? paymentReference,
    String? deliveryAddressId,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? notes,
    String? proofImageUrl,
    String? signatureUrl,
    DateTime? scheduledDate,
    DateTime? confirmedAt,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    int? loyaltyPointsEarned,
    int? loyaltyPointsUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      numericId: numericId ?? this.numericId,
      deliveryId: deliveryId ?? this.deliveryId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      deliveryAddressId: deliveryAddressId ?? this.deliveryAddressId,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      notes: notes ?? this.notes,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      assignedAt: assignedAt ?? this.assignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      loyaltyPointsEarned: loyaltyPointsEarned ?? this.loyaltyPointsEarned,
      loyaltyPointsUsed: loyaltyPointsUsed ?? this.loyaltyPointsUsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        numericId,
        deliveryId,
        customerId,
        customerName,
        customerPhone,
        stationId,
        stationName,
        driverId,
        driverName,
        orderType,
        status,
        items,
        subtotal,
        deliveryFee,
        discount,
        total,
        paymentMethod,
        paymentStatus,
        paymentReference,
        deliveryAddressId,
        deliveryAddress,
        deliveryLatitude,
        deliveryLongitude,
        notes,
        proofImageUrl,
        signatureUrl,
        scheduledDate,
        confirmedAt,
        assignedAt,
        pickedUpAt,
        deliveredAt,
        cancelledAt,
        cancellationReason,
        loyaltyPointsEarned,
        loyaltyPointsUsed,
        createdAt,
        updatedAt,
      ];
}

class OrderItem extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final bool isContainerIncluded;
  final int? containersReturned;

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.isContainerIncluded = false,
    this.containersReturned,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values that might be strings
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

    int? parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    // Get product name from nested product or direct field
    String productName = json['product_name'] as String? ?? '';
    String? productImage = json['product_image'] as String?;
    if (json['product'] != null && json['product'] is Map) {
      productName = json['product']['name'] as String? ?? productName;
      productImage = json['product']['image'] as String? ?? productImage;
    }

    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: productName,
      productImage: productImage,
      quantity: parseInt(json['quantity']),
      unitPrice: parseDouble(json['unit_price'] ?? json['price']),
      totalPrice: parseDouble(json['total_price'] ?? json['subtotal']),
      isContainerIncluded: json['is_container_included'] as bool? ?? false,
      containersReturned: parseIntOrNull(json['containers_returned']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'is_container_included': isContainerIncluded,
      'containers_returned': containersReturned,
    };
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        productImage,
        quantity,
        unitPrice,
        totalPrice,
        isContainerIncluded,
        containersReturned,
      ];
}
