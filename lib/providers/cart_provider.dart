import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_model.dart';
import '../services/services.dart';
import 'auth_provider.dart';

// Cart Service Provider
final cartServiceProvider = Provider<CartService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CartService(apiService);
});

// Cart State
class CartState {
  final CartModel? cart;
  final bool isLoading;
  final String? error;

  const CartState({
    this.cart,
    this.isLoading = false,
    this.error,
  });

  CartState copyWith({
    CartModel? cart,
    bool? isLoading,
    String? error,
    bool clearCart = false,
  }) {
    return CartState(
      cart: clearCart ? null : (cart ?? this.cart),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get totalItems => cart?.totalItems ?? 0;
  double get subtotal => cart?.subtotal ?? 0.0;
  List<CartItemModel> get items => cart?.items ?? [];
  bool get isEmpty => cart == null || cart!.items.isEmpty;
}

// Cart Notifier
class CartNotifier extends StateNotifier<CartState> {
  final CartService _cartService;

  CartNotifier(this._cartService) : super(const CartState());

  /// Load cart from API
  Future<void> loadCart() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cart = await _cartService.getCart();
      state = state.copyWith(cart: cart, isLoading: false, clearCart: cart == null);
    } catch (e) {
      debugPrint('CartNotifier: Error loading cart: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add item to cart
  Future<void> addItem({
    required String stationId,
    required String productId,
    int quantity = 1,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      debugPrint('CartNotifier: Adding product $productId to station $stationId, qty: $quantity');
      final cart = await _cartService.addItem(
        stationId: stationId,
        productId: productId,
        quantity: quantity,
      );
      state = state.copyWith(cart: cart, isLoading: false);
      debugPrint('CartNotifier: Cart updated, total items: ${cart?.totalItems}');
    } catch (e) {
      debugPrint('CartNotifier: Error adding item: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update item quantity
  Future<void> updateItemQuantity({
    required int itemId,
    required int quantity,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cart = await _cartService.updateItem(
        itemId: itemId,
        quantity: quantity,
      );
      state = state.copyWith(cart: cart, isLoading: false, clearCart: cart == null);
    } catch (e) {
      debugPrint('CartNotifier: Error updating item: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Remove item from cart
  Future<void> removeItem(int itemId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cart = await _cartService.removeItem(itemId);
      state = state.copyWith(cart: cart, isLoading: false, clearCart: cart == null);
    } catch (e) {
      debugPrint('CartNotifier: Error removing item: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _cartService.clearCart();
      state = state.copyWith(isLoading: false, clearCart: true);
    } catch (e) {
      debugPrint('CartNotifier: Error clearing cart: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Checkout: Create order from cart items and clear cart
  Future<CheckoutResult?> checkout({
    required int addressId,
    required String paymentMethod,
    String? customerNotes,
    String? promoCode,
    int? loyaltyPointsUsed,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _cartService.checkout(
        addressId: addressId,
        paymentMethod: paymentMethod,
        customerNotes: customerNotes,
        promoCode: promoCode,
        loyaltyPointsUsed: loyaltyPointsUsed,
      );
      // Clear cart state after successful checkout
      state = state.copyWith(isLoading: false, clearCart: true);
      debugPrint('CartNotifier: Checkout successful, order: ${result.orderNumber}');
      return result;
    } catch (e) {
      debugPrint('CartNotifier: Checkout error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Get quantity for a specific product in cart
  int getProductQuantity(String productId) {
    if (state.cart == null) return 0;
    final item = state.cart!.items.firstWhere(
      (item) => item.productId == productId,
      orElse: () => const CartItemModel(
        id: 0,
        productId: '',
        productName: '',
        quantity: 0,
        unitPrice: 0,
        totalPrice: 0,
      ),
    );
    return item.quantity;
  }

  /// Get cart item ID for a specific product
  int? getCartItemId(String productId) {
    if (state.cart == null) return null;
    try {
      final item = state.cart!.items.firstWhere(
        (item) => item.productId == productId,
      );
      return item.id;
    } catch (_) {
      return null;
    }
  }
}

// Cart Provider
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final cartService = ref.watch(cartServiceProvider);
  return CartNotifier(cartService);
});

// Convenience providers
final cartItemsProvider = Provider<List<CartItemModel>>((ref) {
  return ref.watch(cartProvider).items;
});

final cartTotalItemsProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItems;
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});

final cartIsEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

final cartIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isLoading;
});
