import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../services/driver_service.dart';

// Provider for earnings with period parameter
final driverEarningsProvider = FutureProvider.family<DriverEarnings, String>((ref, period) async {
  final driverService = ref.read(driverServiceProvider);
  return driverService.getEarnings(period: period);
});

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() =>
      _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'Today';

  // Map display period to API period
  String get _apiPeriod {
    switch (_selectedPeriod) {
      case 'Today':
        return 'day';
      case 'This Week':
        return 'week';
      case 'This Month':
        return 'month';
      default:
        return 'day';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load dashboard data for performance section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeDriverProvider.notifier).loadDashboard();
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
        title: const Text('Earnings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Earnings'),
            Tab(text: 'COD Collections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarningsTab(),
          _buildCODTab(),
        ],
      ),
    );
  }

  Widget _buildEarningsTab() {
    final earningsAsync = ref.watch(driverEarningsProvider(_apiPeriod));

    return earningsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error loading earnings: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(driverEarningsProvider(_apiPeriod)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (earnings) => _buildEarningsContent(earnings),
    );
  }

  Widget _buildEarningsContent(DriverEarnings earnings) {
    final avgPerDelivery = earnings.totalDeliveries > 0
        ? earnings.totalEarnings / earnings.totalDeliveries
        : 0.0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverEarningsProvider(_apiPeriod));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Period Selector
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['Today', 'This Week', 'This Month'].map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(period),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPeriod = period);
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Earnings Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.driverColor, Color(0xFFE65100)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${earnings.totalEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _EarningStat(
                        label: 'Deliveries',
                        value: '${earnings.totalDeliveries}',
                        icon: Icons.local_shipping,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white24,
                      ),
                      _EarningStat(
                        label: 'Avg/Delivery',
                        value: '₱${avgPerDelivery.toStringAsFixed(0)}',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Breakdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Earnings Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _BreakdownRow(
                        label: 'Delivery Fees',
                        value: '₱${earnings.deliveryFees.toStringAsFixed(2)}',
                        icon: Icons.local_shipping,
                        color: AppColors.primary,
                      ),
                      const Divider(),
                      _BreakdownRow(
                        label: 'Tips',
                        value: '₱${earnings.tips.toStringAsFixed(2)}',
                        icon: Icons.favorite,
                        color: AppColors.success,
                      ),
                      const Divider(),
                      _BreakdownRow(
                        label: 'Bonuses',
                        value: '₱${earnings.bonuses.toStringAsFixed(2)}',
                        icon: Icons.star,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Performance Section
            _buildPerformanceSection(),

            // Earnings History
            if (earnings.history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...earnings.history.map((entry) => _HistoryRow(
                          date: entry.date,
                          amount: entry.amount,
                          deliveries: entry.deliveries,
                        )),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    final driverState = ref.watch(realtimeDriverProvider);
    final dashboard = driverState.dashboard;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PerformanceCard(
                    icon: Icons.check_circle,
                    label: 'Completed Today',
                    value: '${dashboard?.completedToday ?? 0}',
                    trend: '',
                    isPositive: true,
                  ),
                  const SizedBox(width: 12),
                  _PerformanceCard(
                    icon: Icons.star,
                    label: 'Rating',
                    value: (dashboard?.rating ?? 0).toStringAsFixed(1),
                    trend: '',
                    isPositive: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PerformanceCard(
                    icon: Icons.local_shipping,
                    label: 'Total Deliveries',
                    value: '${dashboard?.totalDeliveries ?? 0}',
                    trend: '',
                    isPositive: true,
                  ),
                  const SizedBox(width: 12),
                  _PerformanceCard(
                    icon: Icons.pending,
                    label: 'Pending',
                    value: '${dashboard?.pendingDeliveries ?? 0}',
                    trend: '',
                    isPositive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCODTab() {
    // Get delivered orders to show COD collections
    final deliveriesAsync = ref.watch(driverDeliveriesProvider('delivered'));

    return deliveriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error loading COD data: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(driverDeliveriesProvider('delivered')),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (deliveries) {
        // Filter for COD orders
        final codOrders = deliveries
            .where((order) => order.paymentMethod == PaymentMethod.cod)
            .toList();
        
        // Calculate totals
        final totalCod = codOrders.fold<double>(
          0, 
          (sum, order) {
            final amount = order.total > 0 
                ? order.total 
                : order.subtotal + order.deliveryFee - order.discount;
            return sum + amount;
          },
        );

        return Column(
          children: [
            // COD Summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'COD Collected',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${totalCod.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Orders',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${codOrders.length}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Remit collected COD to your station before end of shift',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // COD History Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Collection History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(driverDeliveriesProvider('delivered')),
                  ),
                ],
              ),
            ),

            // COD History List
            Expanded(
              child: codOrders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_outlined, size: 64, color: AppColors.greyMedium),
                          SizedBox(height: 16),
                          Text(
                            'No COD collections yet',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(driverDeliveriesProvider('delivered'));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: codOrders.length,
                        itemBuilder: (context, index) {
                          final order = codOrders[index];
                          final amount = order.total > 0
                              ? order.total
                              : order.subtotal + order.deliveryFee - order.discount;
                          return _CODHistoryItem(
                            orderId: order.id,
                            customerName: order.customerName ?? 'Customer',
                            amount: amount,
                            time: _formatDateTime(order.deliveredAt ?? order.createdAt),
                            isRemitted: order.paymentStatus == PaymentStatus.paid,
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

class _EarningStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _EarningStat({
    required this.label,
    required this.value,
    required this.icon,
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
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String date;
  final double amount;
  final int deliveries;

  const _HistoryRow({
    required this.date,
    required this.amount,
    required this.deliveries,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$deliveries deliveries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String trend;
  final bool isPositive;

  const _PerformanceCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.greyLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (trend.isNotEmpty)
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPositive ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w500,
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

class _CODHistoryItem extends StatelessWidget {
  final String orderId;
  final String customerName;
  final double amount;
  final String time;
  final bool isRemitted;

  const _CODHistoryItem({
    required this.orderId,
    required this.customerName,
    required this.amount,
    required this.time,
    required this.isRemitted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isRemitted ? AppColors.success : AppColors.warning)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRemitted ? Icons.check_circle : Icons.pending,
            color: isRemitted ? AppColors.success : AppColors.warning,
          ),
        ),
        title: Text(
          orderId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$customerName • $time'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₱${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              isRemitted ? 'Remitted' : 'Pending',
              style: TextStyle(
                fontSize: 12,
                color: isRemitted ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
