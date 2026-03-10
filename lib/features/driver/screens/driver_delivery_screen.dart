import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';

class DriverDeliveryScreen extends ConsumerStatefulWidget {
  const DriverDeliveryScreen({super.key});

  @override
  ConsumerState<DriverDeliveryScreen> createState() =>
      _DriverDeliveryScreenState();
}

class _DriverDeliveryScreenState extends ConsumerState<DriverDeliveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Pending: assigned, pending, confirmed, preparing, ready_for_pickup
          _RealtimeDeliveryList(statuses: [
            OrderStatus.pending,
            OrderStatus.confirmed,
            OrderStatus.preparing,
            OrderStatus.readyForPickup,
          ]),
          // Active: out_for_delivery
          _RealtimeDeliveryList(statuses: [OrderStatus.outForDelivery]),
          // Completed: delivered (use API for history)
          _DeliveryHistoryList(),
        ],
      ),
    );
  }
}

/// Real-time delivery list using realtimeDriverProvider
class _RealtimeDeliveryList extends ConsumerWidget {
  final List<OrderStatus> statuses;

  const _RealtimeDeliveryList({required this.statuses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverState = ref.watch(realtimeDriverProvider);
    
    if (driverState.isLoading && driverState.deliveryQueue.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (driverState.errorMessage != null && driverState.deliveryQueue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading deliveries',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Filter deliveries by status
    final filteredDeliveries = driverState.deliveryQueue
        .where((order) => statuses.contains(order.status))
        .toList();
    
    if (filteredDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: AppColors.greyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'No deliveries',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredDeliveries.length,
        itemBuilder: (context, index) {
          final order = filteredDeliveries[index];
          return _DeliveryCard(
            order: order,
            onTap: () {
              context.push('/driver/deliveries/${order.id}');
            },
          );
        },
      ),
    );
  }
}

/// History list using API (for completed deliveries)
class _DeliveryHistoryList extends ConsumerWidget {
  const _DeliveryHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(driverDeliveriesProvider('delivered'));

    return deliveriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading deliveries',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(driverDeliveriesProvider('delivered')),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (deliveries) {
        if (deliveries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppColors.greyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed deliveries',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverDeliveriesProvider('delivered'));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final order = deliveries[index];
              return _DeliveryCard(
                order: order,
                onTap: () {
                  context.push('/driver/deliveries/${order.id}');
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _DeliveryList extends ConsumerWidget {
  final List<String> statuses;

  const _DeliveryList({required this.statuses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the first status for the query (API handles filtering)
    final deliveriesAsync = ref.watch(driverDeliveriesProvider(statuses.first));

    return deliveriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading deliveries',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(driverDeliveriesProvider(statuses.first)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (deliveries) {
        // Filter to only include orders matching the statuses we want
        final filteredDeliveries = deliveries.where((order) {
          final statusName = order.status.name.toLowerCase();
          // Map enum names to API status strings
          final statusMap = {
            'pending': 'pending',
            'confirmed': 'confirmed',
            'preparing': 'preparing',
            'outfordelivery': 'out_for_delivery',
            'delivered': 'delivered',
            'cancelled': 'cancelled',
          };
          final apiStatus = statusMap[statusName] ?? statusName;
          return statuses.contains(apiStatus);
        }).toList();

        if (filteredDeliveries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: AppColors.greyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'No deliveries',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverDeliveriesProvider(statuses.first));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDeliveries.length,
            itemBuilder: (context, index) {
              final order = filteredDeliveries[index];
              return _DeliveryCard(
                order: order,
                onTap: () {
                  context.push('/driver/deliveries/${order.id}');
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _DeliveryCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayId = order.id.length > 12 ? order.id.substring(0, 12) : order.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Row(
                    children: [
                      _StatusBadge(status: order.status),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order.paymentMethod == PaymentMethod.cod
                              ? AppColors.warning.withOpacity(0.2)
                              : AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.paymentMethodDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.paymentMethod == PaymentMethod.cod
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    order.customerName ?? 'Customer',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (order.stationName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      order.stationName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(icon: Icons.shopping_bag, label: '${order.items.length} items'),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.access_time, label: _formatTime(order.createdAt)),
                  const Spacer(),
                  Text(
                    '₱${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary,
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case OrderStatus.pending:
        color = AppColors.warning;
        text = 'Pending';
        break;
      case OrderStatus.confirmed:
        color = AppColors.info;
        text = 'Confirmed';
        break;
      case OrderStatus.preparing:
        color = AppColors.info;
        text = 'Preparing';
        break;
      case OrderStatus.readyForPickup:
        color = AppColors.success;
        text = 'Ready for Pickup';
        break;
      case OrderStatus.outForDelivery:
        color = AppColors.driverColor;
        text = 'On The Way';
        break;
      case OrderStatus.delivered:
        color = AppColors.success;
        text = 'Delivered';
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        text = 'Cancelled';
        break;
      case OrderStatus.refunded:
        color = AppColors.textSecondary;
        text = 'Refunded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
