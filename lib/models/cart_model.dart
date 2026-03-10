import 'package:equatable/equatable.dart';
import 'station_model.dart';

class CartModel extends Equatable {
  final int id;
  final String stationId;
  final StationModel? station;
  final List<CartItemModel> items;
  final double subtotal;
  final int totalItems;

  const CartModel({
    required this.id,
    required this.stationId,
    this.station,
    this.items = const [],
    this.subtotal = 0.0,
    this.totalItems = 0,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: json['id'] as int? ?? 0,
      stationId: json['station_id']?.toString() ?? '',
      station: json['station'] != null
          ? StationModel.fromJson(json['station'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: _parseDouble(json['subtotal']),
      totalItems: json['total_items'] as int? ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'station': station?.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'total_items': totalItems,
    };
  }

  CartModel copyWith({
    int? id,
    String? stationId,
    StationModel? station,
    List<CartItemModel>? items,
    double? subtotal,
    int? totalItems,
  }) {
    return CartModel(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      station: station ?? this.station,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalItems: totalItems ?? this.totalItems,
    );
  }

  @override
  List<Object?> get props => [id, stationId, station, items, subtotal, totalItems];
}

class CartItemModel extends Equatable {
  final int id;
  final String productId;
  final String productName;
  final String? productDescription;
  final String? productImage;
  final String? productUnit;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productDescription,
    this.productImage,
    this.productUnit,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as int? ?? 0,
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name'] as String? ?? '',
      productDescription: json['product_description'] as String?,
      productImage: json['product_image'] as String?,
      productUnit: json['product_unit'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: _parseDouble(json['unit_price']),
      totalPrice: _parseDouble(json['total_price']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_description': productDescription,
      'product_image': productImage,
      'product_unit': productUnit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  CartItemModel copyWith({
    int? id,
    String? productId,
    String? productName,
    String? productDescription,
    String? productImage,
    String? productUnit,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productDescription: productDescription ?? this.productDescription,
      productImage: productImage ?? this.productImage,
      productUnit: productUnit ?? this.productUnit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  @override
  List<Object?> get props => [id, productId, productName, productDescription, productImage, productUnit, quantity, unitPrice, totalPrice];
}
