import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../services/customer_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _selectedPayment = PaymentMethod.cod;
  CustomerAddress? _selectedAddress;
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load addresses when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerDataProvider.notifier).loadAddresses();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cartState = ref.read(cartProvider);
    
    if (cartState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await ref.read(cartProvider.notifier).checkout(
        addressId: int.parse(_selectedAddress!.id),
        paymentMethod: _selectedPayment.name,
        customerNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (result != null) {
        // Capture the navigator context before showing dialog
        final navigatorContext = context;
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 28),
                SizedBox(width: 8),
                Text('Order Placed!'),
              ],
            ),
            content: Text(
              'Your order ${result.orderNumber} has been placed successfully. '
              'You can track your order in the Orders section.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  navigatorContext.go(AppRoutes.customerHome);
                },
                child: const Text('Continue Shopping'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  navigatorContext.go(AppRoutes.customerOrders);
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
        );
      } else {
        // Show error from cart state
        final error = ref.read(cartProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to place order')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final customerState = ref.watch(customerDataProvider);
    final addresses = customerState.addresses;
    final station = cartState.cart?.station;
    final deliveryFee = station?.deliveryFee ?? 30.0;
    final subtotal = cartState.subtotal;
    final total = subtotal + deliveryFee;

    // Auto-select first address if none selected
    if (_selectedAddress == null && addresses.isNotEmpty) {
      _selectedAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: cartState.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Address
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (customerState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (addresses.isEmpty)
              const Text('No addresses found. Please add an address.')
            else
              ...addresses.map((addr) => _AddressCard(
                label: addr.label,
                address: addr.fullAddress,
                isSelected: _selectedAddress?.id == addr.id,
                onTap: () => setState(() => _selectedAddress = addr),
              )),
            TextButton.icon(
              onPressed: () async {
                await context.push(AppRoutes.addressManagement);
                // Reload addresses after returning
                if (mounted) {
                  ref.read(customerDataProvider.notifier).loadAddresses();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New Address'),
            ),
            const Divider(height: 32),

            // Payment Method
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _PaymentMethodCard(
              icon: Icons.money,
              label: 'Cash on Delivery',
              isSelected: _selectedPayment == PaymentMethod.cod,
              onTap: () => setState(() => _selectedPayment = PaymentMethod.cod),
            ),
            _PaymentMethodCard(
              icon: Icons.account_balance_wallet,
              label: 'GCash',
              isSelected: _selectedPayment == PaymentMethod.gcash,
              onTap: () => setState(() => _selectedPayment = PaymentMethod.gcash),
            ),
            _PaymentMethodCard(
              icon: Icons.account_balance_wallet,
              label: 'Maya',
              isSelected: _selectedPayment == PaymentMethod.maya,
              onTap: () => setState(() => _selectedPayment = PaymentMethod.maya),
            ),
            _PaymentMethodCard(
              icon: Icons.credit_card,
              label: 'Credit/Debit Card',
              isSelected: _selectedPayment == PaymentMethod.card,
              onTap: () => setState(() => _selectedPayment = PaymentMethod.card),
            ),
            const Divider(height: 32),

            // Order Notes
            const Text(
              'Order Notes (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any special instructions...',
                filled: true,
                fillColor: AppColors.greyLight.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greyLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cart items
                  ...cartState.items.map((item) => _SummaryRow(
                    label: '${item.productName} x${item.quantity}',
                    value: '₱${item.totalPrice.toStringAsFixed(2)}',
                  )),
                  const Divider(),
                  _SummaryRow(label: 'Subtotal', value: '₱${subtotal.toStringAsFixed(2)}'),
                  _SummaryRow(label: 'Delivery Fee', value: '₱${deliveryFee.toStringAsFixed(2)}'),
                  const Divider(),
                  _SummaryRow(
                    label: 'Total',
                    value: '₱${total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: cartState.isEmpty ? null : Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing || _selectedAddress == null ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Text('Place Order (₱${total.toStringAsFixed(2)})'),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String label;
  final String address;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressCard({
    required this.label,
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                onChanged: (_) => onTap(),
              ),
              const Icon(Icons.location_on, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      address,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
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

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                onChanged: (_) => onTap(),
              ),
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
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
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
