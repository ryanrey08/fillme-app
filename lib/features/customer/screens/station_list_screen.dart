import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../shared/widgets/custom_text_field.dart';

class StationListScreen extends ConsumerStatefulWidget {
  const StationListScreen({super.key});

  @override
  ConsumerState<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends ConsumerState<StationListScreen> {
  final _searchController = TextEditingController();
  String _selectedZone = 'All';
  // ignore: unused_field - used for sorting logic
  String _sortBy = 'distance';

  final List<String> _zones = [
    'All',
    'Makati',
    'BGC',
    'Mandaluyong',
    'Pasig',
    'Quezon City',
  ];

  @override
  void initState() {
    super.initState();
    // Load all stations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stationsProvider.notifier).loadNearbyStations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Stations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              // TODO: Show map view
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CustomSearchField(
                  controller: _searchController,
                  hint: 'Search stations...',
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Zone Filter
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _zones.map((zone) {
                            final isSelected = _selectedZone == zone;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(zone),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedZone = zone;
                                  });
                                },
                                selectedColor: AppColors.primary.withOpacity(0.2),
                                checkmarkColor: AppColors.primary,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Sort Button
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      onSelected: (value) {
                        setState(() {
                          _sortBy = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'distance',
                          child: Text('Distance'),
                        ),
                        const PopupMenuItem(
                          value: 'rating',
                          child: Text('Rating'),
                        ),
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Name'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Station List
          Expanded(
            child: _buildStationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStationList() {
    final stationsState = ref.watch(stationsProvider);
    final searchQuery = _searchController.text.toLowerCase();

    if (stationsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stationsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              stationsState.error!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(stationsProvider.notifier).loadNearbyStations(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    var stations = stationsState.nearbyStations;

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      stations = stations.where((s) =>
        s.name.toLowerCase().contains(searchQuery) ||
        s.address.toLowerCase().contains(searchQuery)
      ).toList();
    }

    // Filter by zone
    if (_selectedZone != 'All') {
      stations = stations.where((s) =>
        s.zones.contains(_selectedZone) ||
        s.address.toLowerCase().contains(_selectedZone.toLowerCase())
      ).toList();
    }

    // Sort
    if (_sortBy == 'rating') {
      stations = [...stations]..sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'name') {
      stations = [...stations]..sort((a, b) => a.name.compareTo(b.name));
    }

    if (stations.isEmpty) {
      return const Center(
        child: Text(
          'No stations found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        return _StationListItem(
          name: station.name,
          address: station.address,
          distance: '${station.distance?.toStringAsFixed(1) ?? "N/A"} km',
          rating: station.rating,
          reviewCount: station.totalReviews,
          isOpen: station.isOpen,
          minOrder: station.minimumOrder ?? 0,
          deliveryFee: station.deliveryFee ?? 0,
          onTap: () => context.push('/customer/stations/${station.id}'),
        );
      },
    );
  }
}

class _StationListItem extends StatelessWidget {
  final String name;
  final String address;
  final String distance;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final double minOrder;
  final double deliveryFee;
  final VoidCallback onTap;

  const _StationListItem({
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    required this.isOpen,
    required this.minOrder,
    required this.deliveryFee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Station Image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.store,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOpen ? 'Open' : 'Closed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isOpen
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              ' ($reviewCount)',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Min. ₱${minOrder.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.delivery_dining,
                    size: 14,
                    color: deliveryFee == 0 ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deliveryFee == 0 ? 'Free Delivery' : '₱${deliveryFee.toStringAsFixed(0)} Delivery',
                    style: TextStyle(
                      color: deliveryFee == 0 ? AppColors.success : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: deliveryFee == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
