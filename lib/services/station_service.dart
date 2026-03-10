import '../models/station_model.dart';
import '../models/product_model.dart';
import 'api_service.dart';

class StationService {
  final ApiService _apiService;

  StationService(this._apiService);

  /// Discover stations near a location
  Future<List<StationModel>> discoverStations({
    required double latitude,
    required double longitude,
    String? zoneId,
  }) async {
    final response = await _apiService.get('/stations/discover', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      if (zoneId != null) 'zone_id': zoneId,
    });

    final data = response.data as Map<String, dynamic>;
    final stationsList = data['data'] ?? [];
    return (stationsList as List<dynamic>)
        .map((e) => StationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get station details
  Future<StationModel> getStationDetails(String stationId) async {
    final response = await _apiService.get('/stations/$stationId');
    final data = response.data as Map<String, dynamic>;
    return StationModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get products for a station
  Future<List<ProductModel>> getStationProducts(String stationId) async {
    final response = await _apiService.get('/stations/$stationId/products');
    final data = response.data as Map<String, dynamic>;
    final productsList = data['data'] ?? [];
    return (productsList as List<dynamic>)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get categories with products for a station
  Future<List<CategoryWithProducts>> getStationCategories(String stationId) async {
    final response = await _apiService.get('/stations/$stationId/categories');
    final data = response.data as Map<String, dynamic>;
    final categoriesList = data['data'] ?? [];
    return (categoriesList as List<dynamic>)
        .map((e) => CategoryWithProducts.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get reviews for a station
  Future<List<StationReview>> getStationReviews(String stationId, {int page = 1}) async {
    final response = await _apiService.get('/stations/$stationId/reviews', queryParameters: {
      'page': page,
    });
    final data = response.data as Map<String, dynamic>;
    final reviewsList = data['data'] ?? [];
    return (reviewsList as List<dynamic>)
        .map((e) => StationReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class CategoryWithProducts {
  final String id;
  final String name;
  final String? description;
  final List<ProductModel> products;

  CategoryWithProducts({
    required this.id,
    required this.name,
    this.description,
    required this.products,
  });

  factory CategoryWithProducts.fromJson(Map<String, dynamic> json) {
    return CategoryWithProducts(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      products: (json['products'] as List<dynamic>?)
              ?.map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class StationReview {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  StationReview({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory StationReview.fromJson(Map<String, dynamic> json) {
    String? userName;
    String? userAvatar;
    if (json['user'] != null && json['user'] is Map) {
      userName = '${json['user']['first_name'] ?? ''} ${json['user']['last_name'] ?? ''}'.trim();
      userAvatar = json['user']['avatar'] as String?;
    }
    
    return StationReview(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: userName ?? json['user_name'] as String?,
      userAvatar: userAvatar,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
