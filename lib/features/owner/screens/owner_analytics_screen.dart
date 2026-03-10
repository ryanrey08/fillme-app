import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../services/owner_service.dart';

class OwnerAnalyticsScreen extends ConsumerStatefulWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  ConsumerState<OwnerAnalyticsScreen> createState() =>
      _OwnerAnalyticsScreenState();
}

class _OwnerAnalyticsScreenState extends ConsumerState<OwnerAnalyticsScreen> {
  String _selectedPeriod = 'This Week';

  @override
  void initState() {
    super.initState();
    // Load analytics from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
    });
  }

  void _loadAnalytics() {
    String period = 'week';
    if (_selectedPeriod == 'Today') period = 'day';
    if (_selectedPeriod == 'This Month') period = 'month';
    if (_selectedPeriod == 'This Year') period = 'year';
    ref.read(ownerDataProvider.notifier).loadAnalytics(period: period);
  }

  @override
  Widget build(BuildContext context) {
    final ownerState = ref.watch(ownerDataProvider);
    final analytics = ownerState.analytics;

    if (ownerState.isLoading && analytics == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report download coming soon')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadAnalytics(),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: ['Today', 'This Week', 'This Month', 'This Year']
                    .map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(period),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPeriod = period);
                          _loadAnalytics();
                        }
                      },
                      selectedColor: AppColors.ownerColor,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Revenue Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.ownerColor, Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Revenue',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱${_formatCurrency(analytics?.totalRevenue ?? 0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _RevenueMetric(
                        label: 'Orders',
                        value: '${analytics?.totalOrders ?? 0}',
                        change: '',
                        isPositive: true,
                      ),
                      _RevenueMetric(
                        label: 'Avg. Order',
                        value: '₱${(analytics?.averageOrderValue ?? 0).toStringAsFixed(0)}',
                        change: '',
                        isPositive: true,
                      ),
                      _RevenueMetric(
                        label: 'Customers',
                        value: '${(analytics?.newCustomers ?? 0) + (analytics?.returningCustomers ?? 0)}',
                        change: '',
                        isPositive: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chart Placeholder
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: CustomPaint(
                      size: const Size(double.infinity, 200),
                      painter: _ChartPainter(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Mon', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text('Tue', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text('Wed', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text('Thu', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text('Fri', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text('Sat', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text('Sun', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            // KPIs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Key Performance Indicators',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _KPICard(
                        title: 'Order Completion',
                        value: '96%',
                        icon: Icons.check_circle,
                        color: AppColors.success,
                        trend: '+2%',
                      ),
                      const SizedBox(width: 12),
                      _KPICard(
                        title: 'Avg. Delivery Time',
                        value: '25 min',
                        icon: Icons.timer,
                        color: AppColors.info,
                        trend: '-3 min',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _KPICard(
                        title: 'Customer Rating',
                        value: '4.7',
                        icon: Icons.star,
                        color: AppColors.warning,
                        trend: '+0.2',
                      ),
                      const SizedBox(width: 12),
                      _KPICard(
                        title: 'Repeat Orders',
                        value: '${analytics?.returningCustomers ?? 0}',
                        icon: Icons.replay,
                        color: AppColors.ownerColor,
                        trend: '',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Top Products
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (analytics?.topProducts.isEmpty ?? true)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No product data available',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...List.generate(analytics!.topProducts.length, (index) {
                      final product = analytics.topProducts[index];
                      final totalRevenue = analytics.totalRevenue > 0 ? analytics.totalRevenue : 1;
                      return _TopProductItem(
                        rank: index + 1,
                        name: product.name,
                        sales: product.quantity,
                        revenue: product.revenue,
                        percentage: product.revenue / totalRevenue,
                      );
                    }),
                ],
              ),
            ),

            // Delivery Performance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Performance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PerformanceRow(
                        label: 'On-Time Deliveries',
                        value: '92%',
                        progress: 0.92,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      _PerformanceRow(
                        label: 'Customer Satisfaction',
                        value: '88%',
                        progress: 0.88,
                        color: AppColors.info,
                      ),
                      const SizedBox(height: 12),
                      _PerformanceRow(
                        label: 'First-Time Resolution',
                        value: '95%',
                        progress: 0.95,
                        color: AppColors.ownerColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
}

class _RevenueMetric extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool isPositive;

  const _RevenueMetric({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          change,
          style: TextStyle(
            color: isPositive ? AppColors.success : AppColors.error,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Text(
                  trend,
                  style: TextStyle(
                    color: trend.contains('-') ? AppColors.error : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductItem extends StatelessWidget {
  final int rank;
  final String name;
  final int sales;
  final double revenue;
  final double percentage;

  const _TopProductItem({
    required this.rank,
    required this.name,
    required this.sales,
    required this.revenue,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppColors.warning
                  : rank == 2
                      ? AppColors.greyMedium
                      : rank == 3
                          ? Colors.brown
                          : AppColors.greyLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3 ? AppColors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$sales sold',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _PerformanceRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ownerColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.ownerColor.withOpacity(0.3),
          AppColors.ownerColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Mock data points
    final points = [0.4, 0.6, 0.35, 0.7, 0.55, 0.85, 0.75];
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final y = size.height - (size.height * points[i]);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = AppColors.ownerColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final y = size.height - (size.height * points[i]);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
