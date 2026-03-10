import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../shared/widgets/custom_button.dart';

// Provider to fetch a single order by ID for driver
final deliveryDetailProvider = FutureProvider.family<OrderModel?, String>((ref, orderId) async {
  // First try to find in delivery queue (already loaded data)
  final driverState = ref.read(driverDataProvider);
  final fromQueue = driverState.deliveryQueue.where((o) => o.id == orderId || o.numericId == orderId).firstOrNull;
  
  if (fromQueue != null) {
    return fromQueue;
  }
  
  // Try to find in cached delivery list providers
  for (final status in ['pending', 'out_for_delivery', 'delivered']) {
    final deliveriesAsync = ref.read(driverDeliveriesProvider(status));
    final deliveries = deliveriesAsync.valueOrNull;
    if (deliveries != null) {
      final found = deliveries.where((o) => o.id == orderId || o.numericId == orderId).firstOrNull;
      if (found != null) return found;
    }
  }
  
  try {
    final orderService = ref.read(orderServiceProvider);
    final order = await orderService.getOrderDetails(orderId);
    return order;
  } catch (e) {
    // Return null if not found anywhere
    return null;
  }
});

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DeliveryDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  bool _isUpdatingStatus = false;

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(deliveryDetailProvider(widget.orderId));

    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Order ${widget.orderId}')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('Order ${widget.orderId}')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load order: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(deliveryDetailProvider(widget.orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Order ${widget.orderId}')),
            body: const Center(child: Text('Order not found')),
          );
        }
        return _buildContent(context, order);
      },
    );
  }

  Widget _buildContent(BuildContext context, OrderModel order) {
    final displayId = order.id.length > 12 ? order.id.substring(0, 12) : order.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayId),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deliveryDetailProvider(widget.orderId)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: _getStatusColor(order.status).withOpacity(0.1),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(order.status),
                    color: _getStatusColor(order.status),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.statusDisplayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ],
              ),
            ),

            // Customer Info
            _SectionCard(
              title: 'Customer Information',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person,
                    label: 'Name',
                    value: order.customerName ?? 'Customer',
                  ),
                  if (order.customerPhone != null) ...[
                    const Divider(),
                    _InfoRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: order.customerPhone!,
                      onTap: () => _callCustomer(order.customerPhone!),
                    ),
                  ],
                ],
              ),
            ),

            // Delivery Address
            _SectionCard(
              title: 'Delivery Address',
              action: ElevatedButton.icon(
                onPressed: () => _openNavigation(order.deliveryLatitude, order.deliveryLongitude),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Station Info
            if (order.stationName != null)
              _SectionCard(
                title: 'Pickup Station',
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      order.stationName!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            // Order Items
            _SectionCard(
              title: 'Order Items (${order.items.length})',
              child: Builder(
                builder: (context) {
                  // Compute total from components if order.total is 0
                  final displayTotal = order.total > 0
                      ? order.total
                      : order.subtotal + order.deliveryFee - order.discount;
                  
                  return Column(
                    children: [
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productName} x${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Text(
                                  '₱${item.totalPrice.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text('₱${order.subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee'),
                          Text('₱${order.deliveryFee.toStringAsFixed(2)}'),
                        ],
                      ),
                      if (order.discount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount', style: TextStyle(color: AppColors.success)),
                            Text('-₱${order.discount.toStringAsFixed(2)}',
                                style: const TextStyle(color: AppColors.success)),
                          ],
                        ),
                      ],
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₱${displayTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            // Payment Info
            _SectionCard(
              title: 'Payment',
              child: Builder(
                builder: (context) {
                  final collectAmount = order.total > 0
                      ? order.total
                      : order.subtotal + order.deliveryFee - order.discount;
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: order.paymentMethod == PaymentMethod.cod
                                  ? AppColors.warning.withOpacity(0.2)
                                  : AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              order.paymentMethod == PaymentMethod.cod
                                  ? Icons.payments
                                  : Icons.account_balance_wallet,
                              color: order.paymentMethod == PaymentMethod.cod
                                  ? AppColors.warning
                                  : AppColors.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.paymentMethodDisplayName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                order.paymentStatus == PaymentStatus.paid
                                    ? 'Paid'
                                    : 'Collect ₱${collectAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: order.paymentStatus == PaymentStatus.paid
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            // Customer Notes
            if (order.notes != null && order.notes!.isNotEmpty)
              _SectionCard(
                title: 'Customer Notes',
                child: Row(
                  children: [
                    const Icon(
                      Icons.note,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (order.status == OrderStatus.preparing ||
                      order.status == OrderStatus.confirmed)
                    CustomButton(
                      text: 'Start Delivery',
                      isLoading: _isUpdatingStatus,
                      onPressed: () => _updateStatus(order, 'out_for_delivery'),
                    ),
                  if (order.status == OrderStatus.outForDelivery)
                    CustomButton(
                      text: 'Mark as Delivered',
                      isLoading: _isUpdatingStatus,
                      onPressed: () => _confirmDelivery(context, order),
                    ),
                  if (order.status != OrderStatus.delivered &&
                      order.status != OrderStatus.cancelled)
                    const SizedBox(height: 12),
                  if (order.status != OrderStatus.delivered &&
                      order.status != OrderStatus.cancelled)
                    OutlinedButton(
                      onPressed: () => _reportIssue(context, order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Report Issue'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
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
                child: OutlinedButton.icon(
                  onPressed: order.customerPhone != null
                      ? () => _callCustomer(order.customerPhone!)
                      : null,
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNavigation(order.deliveryLatitude, order.deliveryLongitude),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check;
      case OrderStatus.preparing:
        return Icons.assignment;
      case OrderStatus.readyForPickup:
        return Icons.inventory_2;
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateStatus(OrderModel order, String newStatus) async {
    setState(() => _isUpdatingStatus = true);

    try {
      final driverService = ref.read(driverServiceProvider);
      // Use deliveryId for driver API, fallback to order.id
      final apiId = order.deliveryId ?? order.numericId ?? order.id;
      await driverService.updateDeliveryStatus(apiId, newStatus);

      // Refresh the order
      ref.invalidate(deliveryDetailProvider(widget.orderId));
      // Refresh all delivery lists
      ref.invalidate(driverDeliveriesProvider('pending'));
      ref.invalidate(driverDeliveriesProvider('out_for_delivery'));
      ref.invalidate(driverDeliveriesProvider('delivered'));
      ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isUpdatingStatus = false);
    }
  }

  void _confirmDelivery(BuildContext context, OrderModel order) {
    final collectAmount = order.total > 0
        ? order.total
        : order.subtotal + order.deliveryFee - order.discount;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to mark this order as delivered?'),
            const SizedBox(height: 16),
            if (order.paymentMethod == PaymentMethod.cod &&
                order.paymentStatus != PaymentStatus.paid)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Collect ₱${collectAmount.toStringAsFixed(2)} before marking as delivered',
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _markAsDelivered(order);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsDelivered(OrderModel order) async {
    setState(() => _isUpdatingStatus = true);

    try {
      final driverService = ref.read(driverServiceProvider);
      // Use deliveryId for driver API, fallback to order.id
      final apiId = order.deliveryId ?? order.numericId ?? order.id;
      await driverService.updateDeliveryStatus(apiId, 'delivered');

      // Refresh all delivery lists
      ref.invalidate(driverDeliveriesProvider('pending'));
      ref.invalidate(driverDeliveriesProvider('out_for_delivery'));
      ref.invalidate(driverDeliveriesProvider('delivered'));
      ref.read(realtimeDriverProvider.notifier).loadDeliveryQueue();

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order ${order.id.length > 12 ? order.id.substring(0, 12) : order.id} has been delivered successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    // Go back to delivery list
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _reportIssue(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text('Customer not available'),
              onTap: () {
                Navigator.pop(dialogContext);
                // TODO: Handle issue
              },
            ),
            ListTile(
              leading: const Icon(Icons.wrong_location),
              title: const Text('Wrong address'),
              onTap: () {
                Navigator.pop(dialogContext);
                // TODO: Handle issue
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Order cancelled by customer'),
              onTap: () {
                Navigator.pop(dialogContext);
                // TODO: Handle issue
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Other issue'),
              onTap: () {
                Navigator.pop(dialogContext);
                // TODO: Handle issue
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (onTap != null) ...[
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
