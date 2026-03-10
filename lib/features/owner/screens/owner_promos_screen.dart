import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/promo_model.dart';
import '../../../providers/data_providers.dart';
import '../../../services/owner_service.dart';

class OwnerPromosScreen extends ConsumerStatefulWidget {
  const OwnerPromosScreen({super.key});

  @override
  ConsumerState<OwnerPromosScreen> createState() => _OwnerPromosScreenState();
}

class _OwnerPromosScreenState extends ConsumerState<OwnerPromosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load promos from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ownerDataProvider.notifier).loadPromos();
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
        title: const Text('Promotions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Scheduled'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PromoList(status: 'active'),
          _PromoList(status: 'scheduled'),
          _PromoList(status: 'expired'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePromoDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Promo'),
      ),
    );
  }

  void _showCreatePromoDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
                    const Text(
                      'Create Promotion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Promo Code
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Promo Code',
                        hintText: 'e.g., SUMMER20',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Promo Name
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Promotion Name',
                        hintText: 'e.g., Summer Sale 2024',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the promotion',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Discount Type
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Discount Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'percentage',
                          child: Text('Percentage Discount'),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Fixed Amount'),
                        ),
                        DropdownMenuItem(
                          value: 'freeDelivery',
                          child: Text('Free Delivery'),
                        ),
                        DropdownMenuItem(
                          value: 'buyOneGetOne',
                          child: Text('Buy 1 Get 1'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 16),

                    // Discount Value
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Discount Value',
                        hintText: 'e.g., 20 for 20%',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_offer),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Min Order Amount
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Minimum Order Amount',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Usage Limit
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Usage Limit (optional)',
                        hintText: 'Leave empty for unlimited',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Date Range
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () async {
                              // TODO: Show date picker
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () async {
                              // TODO: Show date picker
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Promotion created successfully'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Create Promotion'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoList extends ConsumerWidget {
  final String status;

  const _PromoList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerState = ref.watch(ownerDataProvider);
    
    // Filter promos by status
    final promos = ownerState.promos.where((promo) {
      if (status == 'active') {
        return promo.status == 'active' && promo.isActive;
      } else if (status == 'scheduled') {
        return promo.status == 'scheduled' || 
               (promo.startDate != null && promo.startDate!.isAfter(DateTime.now()));
      } else if (status == 'expired') {
        return promo.status == 'expired' || 
               (promo.endDate != null && promo.endDate!.isBefore(DateTime.now()));
      }
      return true;
    }).toList();

    if (ownerState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (promos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: AppColors.greyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'No $status promotions',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ownerDataProvider.notifier).loadPromos(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: promos.length,
        itemBuilder: (context, index) {
          final promo = promos[index];
          return _PromoCard(promo: promo);
        },
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final StationPromo promo;

  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final isExpired = promo.endDate?.isBefore(DateTime.now()) ?? false;
    final isScheduled = promo.startDate?.isAfter(DateTime.now()) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPromoDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      promo.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(
                    isExpired: isExpired,
                    isScheduled: isScheduled,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                promo.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getDiscountDescription(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoItem(
                    icon: Icons.local_offer,
                    label: _getDiscountText(),
                  ),
                  const SizedBox(width: 16),
                  if (promo.minOrder != null)
                    _InfoItem(
                      icon: Icons.shopping_cart,
                      label: 'Min ₱${promo.minOrder!.toStringAsFixed(0)}',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoItem(
                    icon: Icons.calendar_today,
                    label: _getDateRange(),
                  ),
                ],
              ),
              if (promo.usageLimit != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: promo.usageCount / promo.usageLimit!,
                          backgroundColor: AppColors.greyLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            promo.usageCount / promo.usageLimit! > 0.8
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${promo.usageCount}/${promo.usageLimit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getDiscountDescription() {
    if (promo.type == 'percentage') {
      return '${promo.value.toInt()}% off on all orders';
    } else if (promo.type == 'fixed' || promo.type == 'fixedAmount') {
      return '₱${promo.value.toInt()} off on orders';
    } else if (promo.type == 'freeDelivery') {
      return 'Free delivery on qualifying orders';
    }
    return promo.name;
  }

  String _getDiscountText() {
    if (promo.type == 'percentage') {
      return '${promo.value.toInt()}% off';
    } else if (promo.type == 'fixed' || promo.type == 'fixedAmount') {
      return '₱${promo.value.toInt()} off';
    } else if (promo.type == 'freeDelivery') {
      return 'Free Delivery';
    } else if (promo.type == 'freeItem') {
      return 'Free Item';
    } else if (promo.type == 'buyOneGetOne') {
      return 'Buy 1 Get 1';
    }
    return promo.type;
  }

  String _getDateRange() {
    if (promo.startDate == null || promo.endDate == null) {
      return 'No date set';
    }
    final start = '${promo.startDate!.day}/${promo.startDate!.month}';
    final end = '${promo.endDate!.day}/${promo.endDate!.month}';
    return '$start - $end';
  }

  void _showPromoDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  promo.code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Edit promo
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Delete promo
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Name', value: promo.name),
            _DetailRow(label: 'Discount', value: _getDiscountText()),
            if (promo.minOrder != null)
              _DetailRow(
                label: 'Minimum Order',
                value: '₱${promo.minOrder!.toStringAsFixed(0)}',
              ),
            _DetailRow(label: 'Period', value: _getDateRange()),
            _DetailRow(
              label: 'Usage',
              value: promo.usageLimit != null
                  ? '${promo.usageCount}/${promo.usageLimit}'
                  : '${promo.usageCount} (unlimited)',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isExpired;
  final bool isScheduled;

  const _StatusBadge({
    required this.isExpired,
    required this.isScheduled,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (isExpired) {
      color = AppColors.error;
      text = 'Expired';
    } else if (isScheduled) {
      color = AppColors.info;
      text = 'Scheduled';
    } else {
      color = AppColors.success;
      text = 'Active';
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
