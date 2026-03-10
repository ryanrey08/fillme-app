import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import 'api_service.dart';

class OrderService {
  final ApiService _apiService;

  OrderService(this._apiService);

  // Customer methods
  Future<List<OrderModel>> getCustomerOrders({
    int page = 1,
    int limit = 20,
    OrderStatus? status,
  }) async {
    final response = await _apiService.get('/orders/customer', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status.name,
    });

    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? data['orders'] ?? [];
    
    // Debug: Log raw API response for first few orders
    debugPrint('[OrderService] Loaded ${(ordersList as List).length} orders from API');
    for (var i = 0; i < ordersList.length && i < 5; i++) {
      final order = ordersList[i] as Map<String, dynamic>;
      debugPrint('[OrderService] Order ${order['order_number']}: status="${order['status']}"');
    }
    
    final orders = ordersList
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return orders;
  }

  Future<OrderModel> createOrder({
    required String stationId,
    required List<Map<String, dynamic>> items,
    required String deliveryAddressId,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.instant,
    String? notes,
    String? promoCode,
    DateTime? scheduledDate,
    int? loyaltyPointsToUse,
  }) async {
    final response = await _apiService.post('/orders', data: {
      'station_id': stationId,
      'items': items,
      'delivery_address_id': deliveryAddressId,
      'payment_method': paymentMethod.name,
      'order_type': orderType.name,
      'notes': notes,
      'promo_code': promoCode,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'loyalty_points_to_use': loyaltyPointsToUse,
    });

    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OrderModel> getOrderDetails(String orderId) async {
    // Use /orders/number/{orderNumber} for non-numeric IDs (order numbers)
    // Use /orders/{id} for numeric IDs
    final isNumeric = int.tryParse(orderId) != null;
    final endpoint = isNumeric ? '/orders/$orderId' : '/orders/number/$orderId';
    debugPrint('[OrderService] getOrderDetails: orderId=$orderId, endpoint=$endpoint');
    final response = await _apiService.get(endpoint);
    final data = response.data as Map<String, dynamic>;
    final orderData = data['data'] ?? data;
    debugPrint('[OrderService] getOrderDetails raw status: ${orderData['status']}');
    return OrderModel.fromJson(orderData as Map<String, dynamic>);
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await _apiService.post('/orders/$orderId/cancel', data: {
      'reason': reason,
    });
  }

  Future<void> rateOrder(String orderId, int rating, String? review) async {
    await _apiService.post('/orders/$orderId/rate', data: {
      'rating': rating,
      'review': review,
    });
  }

  // Driver methods
  Future<List<OrderModel>> getDriverDeliveryQueue({String? date}) async {
    final response = await _apiService.get('/orders/driver/queue', queryParameters: {
      if (date != null) 'date': date,
    });

    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? data['orders'] ?? [];
    final orders = (ordersList as List<dynamic>)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return orders;
  }

  Future<OrderModel> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? proofImageUrl,
    String? signatureUrl,
    double? collectedAmount,
  }) async {
    final response = await _apiService.patch('/orders/$orderId/status', data: {
      'status': status.name,
      if (proofImageUrl != null) 'proof_image_url': proofImageUrl,
      if (signatureUrl != null) 'signature_url': signatureUrl,
      if (collectedAmount != null) 'collected_amount': collectedAmount,
    });

    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateDriverLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    await _apiService.post('/orders/$orderId/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // Owner methods
  Future<List<OrderModel>> getStationOrders({
    int page = 1,
    int limit = 20,
    OrderStatus? status,
    String? date,
    String? driverId,
  }) async {
    final response = await _apiService.get('/orders/station', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status.name,
      if (date != null) 'date': date,
      if (driverId != null) 'driver_id': driverId,
    });

    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? data['orders'] ?? [];
    final orders = (ordersList as List<dynamic>)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return orders;
  }

  Future<OrderModel> approveOrder(String orderId) async {
    final response = await _apiService.post('/orders/$orderId/approve');
    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OrderModel> rejectOrder(String orderId, String reason) async {
    final response = await _apiService.post('/orders/$orderId/reject', data: {
      'reason': reason,
    });
    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OrderModel> assignDriver(String orderId, String driverId) async {
    final response = await _apiService.post('/orders/$orderId/assign', data: {
      'driver_id': driverId,
    });
    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  // Subscription orders
  Future<List<OrderModel>> getSubscriptionOrders() async {
    final response = await _apiService.get('/orders/subscriptions');
    final data = response.data as Map<String, dynamic>;
    final ordersList = data['data'] ?? data['orders'] ?? [];
    final orders = (ordersList as List<dynamic>)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return orders;
  }

  Future<void> cancelSubscription(String subscriptionId) async {
    await _apiService.delete('/orders/subscriptions/$subscriptionId');
  }
}
