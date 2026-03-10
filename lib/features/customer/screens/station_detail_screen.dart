import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/cart_provider.dart';
import '../../../models/station_model.dart';
import '../../../models/product_model.dart';

class StationDetailScreen extends ConsumerStatefulWidget {
  final String stationId;

  const StationDetailScreen({super.key, required this.stationId});

  @override
  ConsumerState<StationDetailScreen> createState() =>
      _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load cart when screen initializes
    Future.microtask(() => ref.read(cartProvider.notifier).loadCart());
  }

  @override
  Widget build(BuildContext context) {
    final stationAsync = ref.watch(stationDetailProvider(widget.stationId));
    final productsAsync = ref.watch(stationProductsProvider(widget.stationId));
    final cartState = ref.watch(cartProvider);
    final totalItems = cartState.totalItems;

    return stationAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load station: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(stationDetailProvider(widget.stationId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (station) => _buildContent(station, productsAsync, totalItems),
    );
  }

  Widget _buildContent(StationModel station, AsyncValue<List<ProductModel>> productsAsync, int totalItems) {

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Map
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: station.latitude != 0 && station.longitude != 0
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(station.latitude, station.longitude),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId(station.id),
                          position: LatLng(station.latitude, station.longitude),
                          infoWindow: InfoWindow(
                            title: station.name,
                            snippet: station.address,
                          ),
                        ),
                      },
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      myLocationButtonEnabled: false,
                      liteModeEnabled: true,
                    )
                  : Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.store,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Share station
                },
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {
                  // TODO: Add to favorites
                },
              ),
            ],
          ),

          // Station Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          station.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: station.isOpen
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          station.isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            color: station.isOpen ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.warning, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        station.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        ' (${station.totalReviews} reviews)',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${station.openTime ?? "N/A"} - ${station.closeTime ?? "N/A"}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          station.address,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.delivery_dining,
                        label: station.deliveryFee == 0 ? 'Free Delivery' : '₱${station.deliveryFee?.toStringAsFixed(0)} Delivery',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.shopping_bag,
                        label: 'Min. ₱${station.minimumOrder?.toStringAsFixed(0) ?? "0"}',
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      if (station.isVerified)
                        _InfoChip(
                          icon: Icons.verified,
                          label: 'Verified',
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Products Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Product List
          productsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, stack) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Text('Failed to load products: $error'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(stationProductsProvider(widget.stationId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (products) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: products.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'No products available',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = products[index];
                          final productId = product.id;
                          final cartNotifier = ref.read(cartProvider.notifier);
                          final quantity = cartNotifier.getProductQuantity(productId);

                          return _ProductCard(
                            name: product.name,
                            description: product.description ?? '',
                            price: product.price,
                            unit: product.unit,
                            quantity: quantity,
                            onAdd: () {
                              debugPrint('Add button pressed for product: $productId, station: ${station.id}');
                              ref.read(cartProvider.notifier).addItem(
                                stationId: station.id,
                                productId: productId,
                                quantity: 1,
                              );
                            },
                            onRemove: () {
                              if (quantity > 0) {
                                final itemId = cartNotifier.getCartItemId(productId);
                                if (itemId != null) {
                                  if (quantity == 1) {
                                    ref.read(cartProvider.notifier).removeItem(itemId);
                                  } else {
                                    ref.read(cartProvider.notifier).updateItemQuantity(
                                      itemId: itemId,
                                      quantity: quantity - 1,
                                    );
                                  }
                                }
                              }
                            },
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      bottomNavigationBar: totalItems > 0
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$totalItems items',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push(AppRoutes.cart),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('View Cart'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String description;
  final double price;
  final String unit;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.name,
    required this.description,
    required this.price,
    required this.unit,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.water_drop,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${price.toStringAsFixed(2)}/$unit',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      quantity == 0
                          ? ElevatedButton(
                              onPressed: onAdd,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Add'),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: onRemove,
                                    iconSize: 18,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: onAdd,
                                    iconSize: 18,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
