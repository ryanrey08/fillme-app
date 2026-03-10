import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../shared/widgets/realtime_order_widgets.dart';

class OwnerOrdersScreen extends ConsumerStatefulWidget {
  const OwnerOrdersScreen({super.key});

  @override
  ConsumerState<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends ConsumerState<OwnerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Load orders and drivers from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeOwnerProvider.notifier).loadOrders();
      ref.read(realtimeOwnerProvider.notifier).loadDrivers();
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
        title: Row(
          children: [
            const Text('Orders'),
            const SizedBox(width: 8),
            const WebSocketStatusIndicator(size: 10),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Show search
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(status: 'pending'),
          _OrderList(status: 'active'),
          _OrderList(status: 'completed'),
          _OrderList(status: 'cancelled'),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['All', 'COD', 'Paid', 'Today', 'This Week']
                  .map((filter) => ChoiceChip(
                        label: Text(filter),
                        selected: _filterStatus == filter,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _filterStatus = filter);
                            Navigator.pop(context);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _filterStatus == filter
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  final String status;

  const _OrderList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerState = ref.watch(realtimeOwnerProvider);
    
    // Filter orders by status
    List<OrderModel> filteredOrders = ownerState.orders.where((order) {
      if (status == 'pending') {
        return order.status == OrderStatus.pending;
      } else if (status == 'active') {
        return order.status == OrderStatus.confirmed || 
               order.status == OrderStatus.preparing ||
               order.status == OrderStatus.readyForPickup ||
               order.status == OrderStatus.outForDelivery;
      } else if (status == 'completed') {
        return order.status == OrderStatus.delivered;
      } else if (status == 'cancelled') {
        return order.status == OrderStatus.cancelled ||
               order.status == OrderStatus.refunded;
      }
      return true;
    }).toList();

    if (ownerState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: AppColors.greyMedium),
            const SizedBox(height: 16),
            Text(
              'No $status orders',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(realtimeOwnerProvider.notifier).loadOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          final items = order.items.map((item) => 
            '${item.productName} x${item.quantity}'
          ).toList();

          return _OwnerOrderCard(
            orderId: 'ORD-${order.numericId ?? order.id}',
            customerName: order.customerName ?? 'Customer',
            customerPhone: order.customerPhone ?? '',
            address: order.deliveryAddress,
            items: items,
            total: order.total,
            status: order.status,
            paymentMethod: order.paymentMethodDisplayName,
            isPaid: order.paymentStatus == PaymentStatus.paid,
            driverAssigned: order.driverName ?? (order.driverId != null ? 'Driver #${order.driverId}' : null),
            orderTime: _formatOrderTime(order.createdAt),
            onApprove: order.status == OrderStatus.pending
                ? () => _showApproveDialog(context, ref, order)
                : null,
            onReject: order.status == OrderStatus.pending
                ? () => _showRejectDialog(context, ref, order)
                : null,
            onAssignDriver: order.driverName == null && order.driverId == null && order.isActive && order.status != OrderStatus.pending
                ? () => _showAssignDriverDialog(context, ref, order)
                : null,
            onReassignDriver: (order.driverName != null || order.driverId != null) && order.isActive
                ? () => _showAssignDriverDialog(context, ref, order)
                : null,
            onTap: () => _showOrderDetails(context, ref, order),
          );
        },
      ),
    );
  }

  String _formatOrderTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final orderId = 'ORD-${order.numericId ?? order.id}';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Order'),
        content: Text('Approve order $orderId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(realtimeOwnerProvider.notifier).approveOrder(order.id);
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Order $orderId approved')),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Failed to approve: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final reasonController = TextEditingController();
    final orderId = 'ORD-${order.numericId ?? order.id}';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject order $orderId?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(dialogContext);
              try {
                await ref.read(realtimeOwnerProvider.notifier).rejectOrder(order.id, reason: reason);
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Order $orderId rejected')),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Failed to reject: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showAssignDriverDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final orderId = 'ORD-${order.numericId ?? order.id}';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Refresh drivers before showing dialog
    ref.read(realtimeOwnerProvider.notifier).loadDrivers();
    
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final ownerState = ref.watch(realtimeOwnerProvider);
            final drivers = ownerState.drivers.where((d) => d.isOnline).toList();
            
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign Driver for $orderId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ownerState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (drivers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No online drivers available'),
                    )
                  else
                    ...drivers.map((driver) => ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.greyLight,
                            backgroundImage: driver.avatar != null 
                                ? NetworkImage(driver.avatar!) 
                                : null,
                            child: driver.avatar == null 
                                ? const Icon(Icons.person, color: AppColors.textSecondary)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: driver.isOnline ? AppColors.success : AppColors.greyMedium,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(driver.name),
                      subtitle: Text(
                        driver.isOnline
                            ? 'Online • ${driver.activeDeliveries} active'
                            : 'Offline',
                      ),
                      trailing: driver.isOnline
                          ? ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(bottomSheetContext);
                                try {
                                  await ref.read(realtimeOwnerProvider.notifier).assignDriver(order.id, driver.id);
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('${driver.name} assigned to $orderId'),
                                    ),
                                  );
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('Failed to assign: $e')),
                                  );
                                }
                              },
                              child: const Text('Assign'),
                            )
                          : null,
                    )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOrderDetails(BuildContext context, WidgetRef ref, OrderModel order) {
    final orderId = 'ORD-${order.numericId ?? order.id}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          orderId,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.statusDisplayName,
                            style: TextStyle(
                              color: _getStatusColor(order.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Placed on ${_formatDateTime(order.createdAt)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Customer Info
                    const Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.person,
                      label: 'Name',
                      value: order.customerName ?? 'N/A',
                    ),
                    _DetailRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: order.customerPhone ?? 'N/A',
                    ),
                    _DetailRow(
                      icon: Icons.location_on,
                      label: 'Address',
                      value: order.deliveryAddress,
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Driver Info
                    const Text(
                      'Driver Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (order.driverName != null || order.driverId != null) ...[
                      _DetailRow(
                        icon: Icons.local_shipping,
                        label: 'Driver',
                        value: order.driverName ?? 'Driver #${order.driverId}',
                      ),
                      _DetailRow(
                        icon: Icons.circle,
                        label: 'Status',
                        value: order.status == OrderStatus.outForDelivery ? 'On route' : 'Assigned',
                      ),
                    ] else
                      const Text(
                        'No driver assigned yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Order Items
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('${item.productName} x${item.quantity}'),
                          ),
                          Text(
                            '₱${item.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Payment Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('₱${order.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee'),
                        Text('₱${order.deliveryFee.toStringAsFixed(2)}'),
                      ],
                    ),
                    if (order.discount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount'),
                          Text('-₱${order.discount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '₱${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Method'),
                        Text(order.paymentMethodDisplayName),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Status'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (order.paymentStatus == PaymentStatus.paid ? AppColors.success : AppColors.warning).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.paymentStatus == PaymentStatus.paid ? 'Paid' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: order.paymentStatus == PaymentStatus.paid ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  if (order.isActive && (order.driverName != null || order.driverId != null)) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAssignDriverDialog(context, ref, order);
                        },
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Reassign'),
                      ),
                    ),
                  ],
                  if (order.isActive && order.driverName == null && order.driverId == null && order.status != OrderStatus.pending) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAssignDriverDialog(context, ref, order);
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Assign Driver'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.readyForPickup:
        return AppColors.success;
      case OrderStatus.outForDelivery:
        return AppColors.driverColor;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return AppColors.error;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }
}

class _OwnerOrderCard extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String address;
  final List<String> items;
  final double total;
  final OrderStatus status;
  final String paymentMethod;
  final bool isPaid;
  final String? driverAssigned;
  final String orderTime;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onAssignDriver;
  final VoidCallback? onReassignDriver;
  final VoidCallback? onTap;

  const _OwnerOrderCard({
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.items,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.isPaid,
    this.driverAssigned,
    required this.orderTime,
    this.onApprove,
    this.onReject,
    this.onAssignDriver,
    this.onReassignDriver,
    this.onTap,
  });

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
              // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      orderId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: status),
                  ],
                ),
                Text(
                  orderTime,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(),

            // Customer Info
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(customerName),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        (isPaid ? AppColors.success : AppColors.warning).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    paymentMethod,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPaid ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

            // Items
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• $item',
                    style: const TextStyle(fontSize: 13),
                  ),
                )),

            // Driver Info
            if (driverAssigned != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.driverColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_shipping,
                            size: 14,
                            color: AppColors.driverColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Assigned to: $driverAssigned',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.driverColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onReassignDriver != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onReassignDriver,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Reassign'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.driverColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Total and Actions
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  children: [
                    if (onReject != null)
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Reject'),
                      ),
                    if (onReject != null) const SizedBox(width: 8),
                    if (onApprove != null)
                      ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Approve'),
                      ),
                    if (onAssignDriver != null)
                      ElevatedButton.icon(
                        onPressed: onAssignDriver,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Assign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                  ],
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
        color = AppColors.error;
        text = 'Refunded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
