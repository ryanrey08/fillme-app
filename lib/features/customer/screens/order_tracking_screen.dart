import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../providers/order_channel_provider.dart';
import '../../../shared/widgets/realtime_order_widgets.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use realtimeOrderProvider for auto-updates when order status changes
    final orderAsync = ref.watch(realtimeOrderProvider(orderId));

    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Order $orderId')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text('Order $orderId')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load order: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(realtimeOrderProvider(orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Order $orderId')),
            body: const Center(child: Text('Order not found')),
          );
        }
        return _buildContent(context, order);
      },
    );
  }

  Widget _buildContent(BuildContext context, OrderModel order) {
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusText(order.status);
    final displayId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order $displayId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // TODO: Show help
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WebSocket Status (Debug)
            const WebSocketStatusIndicator(),
            
            // Order Status Timeline
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (order.status == OrderStatus.outForDelivery)
                        const Text(
                          'ETA: 15-20 mins',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Timeline
                  _TimelineStep(
                    title: 'Order Placed',
                    subtitle: _formatDateTime(order.createdAt),
                    isCompleted: true,
                    isFirst: true,
                    isCurrent: order.status == OrderStatus.pending,
                  ),
                  _TimelineStep(
                    title: 'Order Confirmed',
                    subtitle: order.confirmedAt != null 
                        ? _formatDateTime(order.confirmedAt!) 
                        : _hasReachedStatus(order.status, OrderStatus.confirmed) ? 'Confirmed' : 'Waiting',
                    isCompleted: _hasReachedStatus(order.status, OrderStatus.confirmed),
                    isCurrent: order.status == OrderStatus.confirmed,
                  ),
                  _TimelineStep(
                    title: 'Preparing',
                    subtitle: _hasReachedStatus(order.status, OrderStatus.preparing) ? 'Being prepared' : 'Waiting',
                    isCompleted: _hasReachedStatus(order.status, OrderStatus.preparing),
                    isCurrent: order.status == OrderStatus.preparing,
                  ),
                  _TimelineStep(
                    title: 'Ready for Pickup',
                    subtitle: _hasReachedStatus(order.status, OrderStatus.readyForPickup) 
                        ? 'Ready for driver pickup' 
                        : 'Waiting',
                    isCompleted: _hasReachedStatus(order.status, OrderStatus.readyForPickup),
                    isCurrent: order.status == OrderStatus.readyForPickup,
                  ),
                  _TimelineStep(
                    title: 'On The Way',
                    subtitle: order.status == OrderStatus.outForDelivery 
                        ? 'Driver is heading to you' 
                        : _hasReachedStatus(order.status, OrderStatus.outForDelivery)
                            ? 'Completed' 
                            : 'Waiting',
                    isCompleted: _hasReachedStatus(order.status, OrderStatus.outForDelivery),
                    isCurrent: order.status == OrderStatus.outForDelivery,
                  ),
                  _TimelineStep(
                    title: 'Delivered',
                    subtitle: order.deliveredAt != null 
                        ? _formatDateTime(order.deliveredAt!) 
                        : order.status == OrderStatus.delivered ? 'Order completed!' : 'Waiting',
                    isCompleted: order.status == OrderStatus.delivered,
                    isCurrent: order.status == OrderStatus.delivered,
                    isLast: true,
                  ),
                ],
              ),
            ),

            // Order Completed Card (for delivered orders)
            if (order.status == OrderStatus.delivered)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Order Completed!',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.deliveredAt != null
                          ? 'Delivered on ${_formatDateTime(order.deliveredAt!)}'
                          : 'Thank you for your order!',
                      style: TextStyle(
                        color: AppColors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Delivery Proof Image (for delivered orders)
            if (order.status == OrderStatus.delivered && order.proofImageUrl != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    const Row(
                      children: [
                        Icon(Icons.photo_camera, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Delivery Proof',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        order.proofImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: AppColors.greyLight,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Driver Info (show for preparing, out_for_delivery, and delivered orders)
            if (order.status == OrderStatus.outForDelivery ||
                order.status == OrderStatus.preparing ||
                (order.status == OrderStatus.delivered && order.driverName != null))
              Container(
                margin: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, color: AppColors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.driverName ?? 'Driver',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'Your Driver',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.primary),
                      onPressed: () {
                        // TODO: Call driver
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: AppColors.primary),
                      onPressed: () {
                        // TODO: Chat with driver
                      },
                    ),
                  ],
                ),
              ),

            // Delivery Address
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            // Order Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.stationName ?? 'Station',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.productName} x${item.quantity}'),
                            Text('₱${item.totalPrice.toStringAsFixed(2)}'),
                          ],
                        ),
                      )),
                  const Divider(),
                  _SummaryRow(
                    label: 'Subtotal',
                    value: '₱${order.subtotal.toStringAsFixed(2)}',
                  ),
                  _SummaryRow(
                    label: 'Delivery Fee',
                    value: '₱${order.deliveryFee.toStringAsFixed(2)}',
                  ),
                  const Divider(),
                  _SummaryRow(
                    label: 'Total',
                    value: '₱${order.total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.payment, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        order.paymentMethodDisplayName,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Cancel Order Button
            if (order.status == OrderStatus.pending ||
                order.status == OrderStatus.confirmed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Cancel order
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Cancel Order'),
                ),
              ),

            // Actions for Delivered Orders
            if (order.status == OrderStatus.delivered)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Reorder Button
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to station to reorder
                        if (order.stationId.isNotEmpty) {
                          context.push('/customer/stations/${order.stationId}');
                        }
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Order Again'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rate Order Button
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Show rating dialog
                        _showRatingDialog(context, order);
                      },
                      icon: const Icon(Icons.star_border),
                      label: const Text('Rate This Order'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
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
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.readyForPickup:
        return AppColors.success;
      case OrderStatus.outForDelivery:
        return AppColors.statusOnTheWay;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return AppColors.error;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'On The Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  /// Helper to check if an order has reached or passed a specific status in the delivery flow.
  /// This properly handles cancelled/refunded orders which should not show as having passed all steps.
  bool _hasReachedStatus(OrderStatus currentStatus, OrderStatus targetStatus) {
    // Define the normal delivery flow order
    const deliveryFlow = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    
    // If current status is cancelled or refunded, only show steps up to where it was cancelled
    if (currentStatus == OrderStatus.cancelled || currentStatus == OrderStatus.refunded) {
      // For cancelled/refunded orders, don't show any steps beyond pending as completed
      // unless we have more specific data about when it was cancelled
      return targetStatus == OrderStatus.pending;
    }
    
    final currentIndex = deliveryFlow.indexOf(currentStatus);
    final targetIndex = deliveryFlow.indexOf(targetStatus);
    
    // If status is not in the normal flow, return false
    if (currentIndex == -1 || targetIndex == -1) return false;
    
    return currentIndex >= targetIndex;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final timeStr = '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    if (isToday) {
      return 'Today, $timeStr';
    }
    return '${dateTime.month}/${dateTime.day}, $timeStr';
  }

  void _showRatingDialog(BuildContext context, OrderModel order) {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate Your Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How was your experience with this order?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setDialogState(() => selectedRating = index + 1);
                    },
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () {
                      // TODO: Submit rating to API
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for your feedback!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? AppColors.primary
                    : AppColors.greyLight,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: AppColors.primary, width: 3)
                    : null,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: AppColors.white)
                  : isCurrent
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppColors.primary : AppColors.greyLight,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted || isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isTotal ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
