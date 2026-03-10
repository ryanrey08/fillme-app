import 'package:equatable/equatable.dart';

enum ProductCategory {
  water,
  container,
  accessory,
  other,
}

class ProductModel extends Equatable {
  final String id;
  final String stationId;
  final String name;
  final String? description;
  final ProductCategory category;
  final String? imageUrl;
  final double price;
  final double? salePrice;
  final String unit;
  final int stockQuantity;
  final int? minOrderQuantity;
  final int? maxOrderQuantity;
  final bool isAvailable;
  final bool isFeatured;
  final double? containerDeposit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.stationId,
    required this.name,
    this.description,
    required this.category,
    this.imageUrl,
    required this.price,
    this.salePrice,
    required this.unit,
    required this.stockQuantity,
    this.minOrderQuantity,
    this.maxOrderQuantity,
    this.isAvailable = true,
    this.isFeatured = false,
    this.containerDeposit,
    required this.createdAt,
    required this.updatedAt,
  });

  double get effectivePrice => salePrice ?? price;
  
  bool get isOnSale => salePrice != null && salePrice! < price;
  
  double get discountPercentage {
    if (!isOnSale) return 0;
    return ((price - salePrice!) / price * 100);
  }

  bool get isInStock => stockQuantity > 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values that might be strings
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      return parsed == 0.0 ? null : parsed;
    }

    // Map category from API - could be category_id or nested category object
    ProductCategory category = ProductCategory.water;
    if (json['category'] != null && json['category'] is Map) {
      final catName = (json['category']['name'] as String?)?.toLowerCase();
      if (catName != null) {
        if (catName.contains('container')) {
          category = ProductCategory.container;
        } else if (catName.contains('accessory')) {
          category = ProductCategory.accessory;
        } else if (catName.contains('water') || catName.contains('purified') || catName.contains('alkaline') || catName.contains('mineral')) {
          category = ProductCategory.water;
        } else {
          category = ProductCategory.other;
        }
      }
    } else if (json['category'] is String) {
      category = ProductCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ProductCategory.water,
      );
    }

    // Determine unit from container_volume_liters or container_type
    String unit = json['unit'] as String? ?? 'gallon';
    if (json['container_volume_liters'] != null) {
      final liters = parseDouble(json['container_volume_liters']);
      if (liters >= 18) {
        unit = '5 gallon';
      } else if (liters >= 11) {
        unit = '3 gallon';
      } else if (liters >= 3.5) {
        unit = '1 gallon';
      } else {
        unit = '${liters.toStringAsFixed(1)}L';
      }
    }

    return ProductModel(
      id: json['id']?.toString() ?? '',
      stationId: json['station_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: category,
      imageUrl: json['image_url'] as String? ?? json['image'] as String?,
      price: parseDouble(json['price']),
      salePrice: parseDoubleNullable(json['sale_price']),
      unit: unit,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      minOrderQuantity: json['min_order_quantity'] as int?,
      maxOrderQuantity: json['max_order_quantity'] as int?,
      isAvailable: json['is_available'] as bool? ?? json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      containerDeposit: parseDoubleNullable(json['container_deposit']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'name': name,
      'description': description,
      'category': category.name,
      'image_url': imageUrl,
      'price': price,
      'sale_price': salePrice,
      'unit': unit,
      'stock_quantity': stockQuantity,
      'min_order_quantity': minOrderQuantity,
      'max_order_quantity': maxOrderQuantity,
      'is_available': isAvailable,
      'is_featured': isFeatured,
      'container_deposit': containerDeposit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? stationId,
    String? name,
    String? description,
    ProductCategory? category,
    String? imageUrl,
    double? price,
    double? salePrice,
    String? unit,
    int? stockQuantity,
    int? minOrderQuantity,
    int? maxOrderQuantity,
    bool? isAvailable,
    bool? isFeatured,
    double? containerDeposit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      unit: unit ?? this.unit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      maxOrderQuantity: maxOrderQuantity ?? this.maxOrderQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      containerDeposit: containerDeposit ?? this.containerDeposit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        stationId,
        name,
        description,
        category,
        imageUrl,
        price,
        salePrice,
        unit,
        stockQuantity,
        minOrderQuantity,
        maxOrderQuantity,
        isAvailable,
        isFeatured,
        containerDeposit,
        createdAt,
        updatedAt,
      ];
}

class CartItem extends Equatable {
  final ProductModel product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  double get totalPrice => product.effectivePrice * quantity;

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [product, quantity];
}
