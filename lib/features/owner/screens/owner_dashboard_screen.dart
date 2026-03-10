import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_channel_provider.dart';
import '../../../shared/widgets/realtime_order_widgets.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeOwnerProvider.notifier).loadDashboard();
      ref.read(realtimeOwnerProvider.notifier).loadOrders();
      ref.read(realtimeOwnerProvider.notifier).loadDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ownerState = ref.watch(realtimeOwnerProvider);
    final userName = authState.user?.firstName ?? 'Owner';
    final dashboard = ownerState.dashboard;
    debugPrint('[OwnerDashboard] build() - dashboard is null? ${dashboard == null}');
    debugPrint('[OwnerDashboard] build() - isLoading: ${ownerState.isLoading}, error: ${ownerState.errorMessage}');
    if (dashboard != null) {
      debugPrint('[OwnerDashboard] build() - todayRevenue: ${dashboard.todayRevenue}, pendingOrders: ${dashboard.pendingOrders}');
    }
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
                    colors: [AppColors.ownerColor, Color(0xFF7B1FA2)],
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
                            const Text(
                              'My Station',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome back, $userName!',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Badge(
                                label: Text('3'),
                                child: Icon(Icons.notifications, color: AppColors.white),
                              ),
                              onPressed: () {
                                // TODO: Show notifications
                              },
                            ),
                            const CircleAvatar(
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: AppColors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _HeaderStat(
                            icon: Icons.attach_money,
                            value: '₱${dashboard?.todayRevenue.toStringAsFixed(0) ?? '0'}',
                            label: 'Today\'s Sales',
                          ),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _HeaderStat(
                            icon: Icons.shopping_bag,
                            value: '${dashboard?.todayOrders ?? 0}',
                            label: 'Orders',
                          ),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _HeaderStat(
                            icon: Icons.local_shipping,
                            value: '${dashboard?.availableDrivers ?? 0}',
                            label: 'Active Drivers',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pending Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ActionCard(
                          icon: Icons.pending_actions,
                          count: dashboard?.pendingOrders ?? 0,
                          label: 'Orders to Approve',
                          color: AppColors.warning,
                          onTap: () => context.push('/owner/orders'),
                        ),
                        const SizedBox(width: 12),
                        _ActionCard(
                          icon: Icons.assignment_ind,
                          count: dashboard?.activeOrders ?? 0,
                          label: 'Active Orders',
                          color: AppColors.info,
                          onTap: () => context.push('/owner/orders'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ActionCard(
                          icon: Icons.inventory,
                          count: dashboard?.lowStockItems ?? 0,
                          label: 'Low Stock Items',
                          color: AppColors.error,
                          onTap: () => context.push('/owner/inventory'),
                        ),
                        const SizedBox(width: 12),
                        _ActionCard(
                          icon: Icons.report_problem,
                          count: dashboard?.openIssues ?? 0,
                          label: 'Issues',
                          color: AppColors.greyMedium,
                          onTap: () {
                            // TODO: Navigate to issues
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Recent Orders
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Debug: WebSocket Status
                    // _WebSocketDebugCard(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Orders',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.push('/owner/orders');
                          },
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Order List
            _buildOrdersList(ownerState),

            // Active Drivers
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Drivers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.push('/owner/drivers');
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDriversList(ownerState),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversList(OwnerState ownerState) {
    final drivers = ownerState.drivers;
    
    if (drivers.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(
          child: Text(
            'No drivers available',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: drivers.length > 5 ? 5 : drivers.length,
        itemBuilder: (context, index) {
          final driver = drivers[index];
          return _DriverCard(
            name: driver.name.isNotEmpty ? driver.name : 'Driver ${index + 1}',
            deliveries: driver.completedToday,
            isOnline: driver.isOnline,
            onTap: () => context.push('/owner/drivers'),
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(OwnerState ownerState) {
    if (ownerState.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final orders = ownerState.orders;
    if (orders.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No recent orders',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final order = orders[index];
          return _RecentOrderCard(
            orderId: 'ORD-${order.id.substring(0, 8)}',
            customerName: order.customerName ?? 'Customer',
            items: '${order.items.length} items',
            total: order.total,
            status: order.status,
            time: _formatTimeAgo(order.createdAt),
            onTap: () => _navigateToOrderDetails(context, order),
          );
        },
        childCount: orders.length > 5 ? 5 : orders.length,
      ),
    );
  }

  void _navigateToOrderDetails(BuildContext context, OrderModel order) {
    // Navigate to orders screen - user can click on the order there to see details
    context.push('/owner/orders');
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String items;
  final double total;
  final OrderStatus status;
  final String time;
  final VoidCallback? onTap;

  const _RecentOrderCard({
    required this.orderId,
    required this.customerName,
    required this.items,
    required this.total,
    required this.status,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
              size: 20,
            ),
          ),
          title: Text(
            orderId,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$customerName • $items'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.readyForPickup:
        return AppColors.success;
      case OrderStatus.outForDelivery:
        return AppColors.driverColor;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.refunded:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_actions;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.readyForPickup:
        return Icons.inventory_2;
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
    }
  }
}

class _DriverCard extends StatelessWidget {
  final String name;
  final int deliveries;
  final bool isOnline;
  final VoidCallback? onTap;

  const _DriverCard({
    required this.name,
    required this.deliveries,
    required this.isOnline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.greyLight,
                  child: Icon(Icons.person, color: AppColors.textSecondary),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.success : AppColors.greyMedium,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$deliveries deliveries',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebSocketDebugCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelState = ref.watch(orderChannelProvider);
    final authState = ref.watch(authProvider);
    
    return Card(
      color: AppColors.greyLight,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'WebSocket Debug',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                const WebSocketStatusIndicator(size: 10, showLabel: true),
              ],
            ),
            const Divider(),
            Text(
              'User Station ID: ${authState.user?.stationId ?? "NULL"}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(
              'Connected: ${channelState.isConnected}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(
              'Channels (${channelState.subscribedChannels.length}):',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            ...channelState.subscribedChannels.map((ch) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '• $ch',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: ch.contains('station') ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            )),
            if (channelState.subscribedChannels.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  '(No channels subscribed)',
                  style: TextStyle(fontSize: 10, color: AppColors.error),
                ),
              ),
            if (channelState.lastEvent != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last Event: ${channelState.lastEvent!.type}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.success),
              ),
            ],
            if (channelState.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${channelState.errorMessage}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
