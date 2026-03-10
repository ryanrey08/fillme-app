import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../providers/auth_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    // Load driver data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeDriverProvider.notifier).loadDashboard();
      ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue();
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    try {
      await ref.read(realtimeDriverProvider.notifier).updateStatus(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final driverState = ref.watch(realtimeDriverProvider);
    final driverName = authState.user?.firstName ?? 'Driver';
    final isOnline = driverState.dashboard?.isOnline ?? false;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.driverColor, Color(0xFFE65100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $driverName!',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ready for deliveries today?',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white24,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Online Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                            if (_isUpdatingStatus)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                                ),
                              )
                            else
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? AppColors.success
                                      : AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Text(
                              isOnline ? 'You are Online' : 'You are Offline',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                          value: isOnline,
                          onChanged: _isUpdatingStatus ? null : _toggleOnlineStatus,
                            activeColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Today's Stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.local_shipping,
                          label: 'Deliveries',
                          value: '${driverState.dashboard?.completedToday ?? 0}',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.attach_money,
                          label: 'Earnings',
                          value: '₱${driverState.dashboard?.earningsToday.toStringAsFixed(0) ?? '0'}',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.timer,
                          label: 'Pending',
                          value: '${driverState.dashboard?.pendingDeliveries ?? 0}',
                          color: AppColors.driverColor,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.star,
                          label: 'Rating',
                          value: (driverState.dashboard?.rating ?? 0).toStringAsFixed(1),
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Pending Deliveries
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pending Deliveries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to delivery queue
                      },
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),
            ),

            // Delivery List
            _buildDeliveryList(driverState),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryList(DriverState driverState) {
    if (driverState.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (driverState.error != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(driverState.error!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final deliveries = driverState.deliveryQueue;
    if (deliveries.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text(
                  'No pending deliveries',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final order = deliveries[index];
          // Safely truncate order ID for display
          final displayId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
          return _DeliveryCard(
            orderNumber: 'ORD-$displayId',
            customerName: order.customerName ?? 'Customer',
            address: order.deliveryAddress,
            items: '${order.items.length} items',
            distance: 'N/A',
            amount: '₱${order.total.toStringAsFixed(2)}',
            paymentMethod: order.paymentMethodDisplayName,
            onTap: () => context.push('/driver/deliveries/${order.id}'),
          );
        },
        childCount: deliveries.length > 5 ? 5 : deliveries.length,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final String orderNumber;
  final String customerName;
  final String address;
  final String items;
  final String distance;
  final String amount;
  final String paymentMethod;
  final VoidCallback onTap;

  const _DeliveryCard({
    required this.orderNumber,
    required this.customerName,
    required this.address,
    required this.items,
    required this.distance,
    required this.amount,
    required this.paymentMethod,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'COD'
                          ? AppColors.warning.withOpacity(0.2)
                          : AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      paymentMethod,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: paymentMethod == 'COD'
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    customerName,
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
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(icon: Icons.shopping_bag, label: items),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.directions, label: distance),
                  const Spacer(),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
