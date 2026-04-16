import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../services/owner_service.dart';

class OwnerInventoryScreen extends ConsumerStatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  ConsumerState<OwnerInventoryScreen> createState() =>
      _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends ConsumerState<OwnerInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load inventory from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ownerDataProvider.notifier).loadInventory();
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
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddStockDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showStockHistory(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Containers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProductInventoryList(),
          _ContainerInventoryList(),
        ],
      ),
    );
  }

  void _showAddStockDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Stock',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'purified', child: Text('Purified Water (5 gal)')),
                  DropdownMenuItem(value: 'mineral', child: Text('Mineral Water (5 gal)')),
                  DropdownMenuItem(value: 'alkaline', child: Text('Alkaline Water (5 gal)')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock added successfully')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Stock'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showStockHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Stock History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) {
                  final isIn = index % 3 != 0;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isIn ? AppColors.success : AppColors.error)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isIn ? Icons.add : Icons.remove,
                        color: isIn ? AppColors.success : AppColors.error,
                      ),
                    ),
                    title: Text(
                      isIn ? 'Stock In' : 'Stock Out (Order)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Purified Water (5 gal) x${5 + index}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${index + 1}h ago',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductInventoryList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerState = ref.watch(ownerDataProvider);
    final inventory = ownerState.inventory;

    if (ownerState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: AppColors.greyMedium),
            const SizedBox(height: 16),
            const Text(
              'No inventory items',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ownerDataProvider.notifier).loadInventory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: inventory.length,
        itemBuilder: (context, index) {
          final product = inventory[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (product.isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning,
                                size: 14,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Low Stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StockIndicator(
                          label: 'In Stock',
                          value: product.stockQuantity,
                          color: product.isLowStock ? AppColors.error : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StockIndicator(
                          label: 'Price',
                          value: product.price.toInt(),
                          color: AppColors.primary,
                          prefix: '₱',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: Add stock
                          },
                          child: const Text('Add Stock'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: View details
                          },
                          child: const Text('Details'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContainerInventoryList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final containers = [
      _ContainerStock(
        type: '5 Gallon Container',
        available: 250,
        inCirculation: 180,
        damaged: 12,
      ),
      _ContainerStock(
        type: '3 Gallon Container',
        available: 85,
        inCirculation: 45,
        damaged: 3,
      ),
      _ContainerStock(
        type: '1 Gallon Container',
        available: 120,
        inCirculation: 60,
        damaged: 5,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: containers.length,
      itemBuilder: (context, index) {
        final container = containers[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  container.type,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ContainerStat(
                        label: 'Available',
                        value: container.available,
                        color: AppColors.success,
                        icon: Icons.inventory_2,
                      ),
                    ),
                    Expanded(
                      child: _ContainerStat(
                        label: 'In Circulation',
                        value: container.inCirculation,
                        color: AppColors.info,
                        icon: Icons.sync,
                      ),
                    ),
                    Expanded(
                      child: _ContainerStat(
                        label: 'Damaged',
                        value: container.damaged,
                        color: AppColors.error,
                        icon: Icons.broken_image,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: container.available /
                      (container.available + container.inCirculation),
                  backgroundColor: AppColors.info.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
                const SizedBox(height: 4),
                Text(
                  '${((container.available / (container.available + container.inCirculation)) * 100).toInt()}% available',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockIndicator extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String? prefix;

  const _StockIndicator({
    required this.label,
    required this.value,
    required this.color,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${prefix ?? ''}${value.toString()}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ContainerStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _ContainerStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ProductStock {
  final String name;
  final int stock;
  final int lowStockThreshold;
  final int sold;

  _ProductStock({
    required this.name,
    required this.stock,
    required this.lowStockThreshold,
    required this.sold,
  });
}

class _ContainerStock {
  final String type;
  final int available;
  final int inCirculation;
  final int damaged;

  _ContainerStock({
    required this.type,
    required this.available,
    required this.inCirculation,
    required this.damaged,
  });
}
