import '../models/cart_model.dart';
import 'api_service.dart';

class CartService {
  final ApiService _apiService;

  CartService(this._apiService);

  /// Get current user's cart
  Future<CartModel?> getCart() async {
    try {
      final response = await _apiService.get('/cart');
      final data = response.data['data'];
      if (data == null) return null;
      return CartModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Add item to cart
  Future<CartModel?> addItem({
    required String stationId,
    required String productId,
    required int quantity,
  }) async {
    try {
      final response = await _apiService.post('/cart/add', data: {
        'station_id': stationId,
        'product_id': productId,
        'quantity': quantity,
      });
      final data = response.data['data'];
      if (data == null) return null;
      return CartModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Update item quantity
  Future<CartModel?> updateItem({
    required int itemId,
    required int quantity,
  }) async {
    try {
      final response = await _apiService.put('/cart/items/$itemId', data: {
        'quantity': quantity,
      });
      final data = response.data['data'];
      if (data == null) return null;
      return CartModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Remove item from cart
  Future<CartModel?> removeItem(int itemId) async {
    try {
      final response = await _apiService.delete('/cart/items/$itemId');
      final data = response.data['data'];
      if (data == null) return null;
      return CartModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    try {
      await _apiService.post('/cart/clear');
    } catch (e) {
      rethrow;
    }
  }

  /// Checkout: Create order from cart and clear cart
  Future<CheckoutResult> checkout({
    required int addressId,
    required String paymentMethod,
    String? customerNotes,
    String? promoCode,
    int? loyaltyPointsUsed,
  }) async {
    try {
      final response = await _apiService.post('/cart/checkout', data: {
        'address_id': addressId,
        'payment_method': paymentMethod,
        if (customerNotes != null) 'customer_notes': customerNotes,
        if (promoCode != null) 'promo_code': promoCode,
        if (loyaltyPointsUsed != null) 'loyalty_points_used': loyaltyPointsUsed,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      return CheckoutResult.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }
}

/// Result from checkout API
class CheckoutResult {
  final int orderId;
  final String orderNumber;
  final String status;
  final double totalAmount;

  CheckoutResult({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    // Parse numeric values that may come as string from API
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return CheckoutResult(
      orderId: parseInt(json['order_id']),
      orderNumber: json['order_number']?.toString() ?? 'ORD-${json['order_id']}',
      status: json['status'] as String? ?? 'pending',
      totalAmount: parseDouble(json['total_amount']),
    );
  }
}
