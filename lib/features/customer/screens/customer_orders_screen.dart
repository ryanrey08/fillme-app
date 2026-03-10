import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/order_provider.dart';

class CustomerOrdersScreen extends ConsumerStatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  ConsumerState<CustomerOrdersScreen> createState() =>
      _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends ConsumerState<CustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load orders when screen initializes
    Future.microtask(() {
      ref.read(customerOrdersProvider.notifier).loadOrders();
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
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(isActive: true),
          _OrderList(isActive: false),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  final bool isActive;

  const _OrderList({required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(customerOrdersProvider);
    final orders = isActive ? ordersState.activeOrders : ordersState.historyOrders;
    
    // Debug: Log what the UI is receiving
    debugPrint('[_OrderList] isActive=$isActive, orders count=${orders.length}');
    for (final order in orders.take(3)) {
      debugPrint('[_OrderList] Rendering order ${order.id}: status=${order.status}');
    }

    if (ordersState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ordersState.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load orders',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ordersState.errorMessage!,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(customerOrdersProvider.notifier).loadOrders(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.receipt_long : Icons.history,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active orders' : 'No order history',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your orders will appear here',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(customerOrdersProvider.notifier).refreshOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderCard(
            order: order,
            onTap: () => context.push('/customer/orders/${order.id}'),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                    order.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.stationName ?? 'Unknown Station',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${order.totalItems} items',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(order.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (order.status != OrderStatus.delivered &&
                      order.status != OrderStatus.cancelled)
                    TextButton(
                      onPressed: onTap,
                      child: const Text('Track Order'),
                    ),
                  // if (order.status == OrderStatus.delivered)
                  //   TextButton(
                  //     onPressed: () {
                  //       // TODO: Reorder
                  //     },
                  //     child: const Text('Reorder'),
                  //   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${_formatTime(date)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    debugPrint('[_StatusBadge] Building with status: $status');
    Color color;
    String text;

    switch (status) {
      case OrderStatus.pending:
        color = AppColors.statusPending;
        text = 'Pending';
        break;
      case OrderStatus.confirmed:
        color = AppColors.statusConfirmed;
        text = 'Confirmed';
        break;
      case OrderStatus.preparing:
        color = AppColors.statusPreparing;
        text = 'Preparing';
        break;
      case OrderStatus.readyForPickup:
        color = AppColors.statusDelivered;
        text = 'Ready for Pickup';
        break;
      case OrderStatus.outForDelivery:
        color = AppColors.statusOutForDelivery;
        text = 'On The Way';
        break;
      case OrderStatus.delivered:
        color = AppColors.statusDelivered;
        text = 'Delivered';
        break;
      case OrderStatus.cancelled:
        color = AppColors.statusCancelled;
        text = 'Cancelled';
        break;
      case OrderStatus.refunded:
        color = AppColors.statusRefunded;
        text = 'Refunded';
        break;
    }
    
    debugPrint('[_StatusBadge] Will render text: $text');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


