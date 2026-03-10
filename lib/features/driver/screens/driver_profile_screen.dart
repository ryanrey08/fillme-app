import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/realtime_order_provider.dart';
import '../../../services/driver_service.dart';
import 'work_schedule_screen.dart';
import 'service_areas_screen.dart';
import 'delivery_history_screen.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    // Load dashboard data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeDriverProvider.notifier).loadDashboard();
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    if (_isUpdatingStatus) return;
    
    setState(() => _isUpdatingStatus = true);
    
    try {
      await ref.read(realtimeDriverProvider.notifier).updateStatus(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'You are now online' : 'You are now offline'),
            backgroundColor: value ? AppColors.success : AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final driverState = ref.watch(realtimeDriverProvider);
    final dashboard = driverState.dashboard;
    final isOnline = dashboard?.isOnline ?? false;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.driverColor, Color(0xFFE65100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white24,
                          backgroundImage: user?.profileImage != null
                              ? NetworkImage(user!.profileImage!)
                              : null,
                          child: user?.profileImage == null
                              ? Text(
                                  user?.firstName?.substring(0, 1).toUpperCase() ?? 'D',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: AppColors.driverColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.fullName ?? 'Driver',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver ID: ${user?.id ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (user?.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user!.email,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Online Status Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isUpdatingStatus)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                              ),
                            )
                          else
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color:
                                    isOnline ? AppColors.success : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isOnline,
                            onChanged: _isUpdatingStatus ? null : _toggleOnlineStatus,
                            activeColor: AppColors.success,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: driverState.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            label: 'Total Deliveries',
                            value: _formatNumber(dashboard?.totalDeliveries ?? 0),
                          ),
                          _VerticalDivider(),
                          _StatItem(
                            label: 'Rating',
                            value: (dashboard?.rating ?? 0).toStringAsFixed(1),
                          ),
                          _VerticalDivider(),
                          _StatItem(
                            label: 'Today',
                            value: '${dashboard?.completedToday ?? 0}',
                          ),
                        ],
                      ),
              ),

              // Menu Items
              const SizedBox(height: 16),

              _MenuSection(
                title: 'Account',
                items: [
                  _MenuItem(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    subtitle: user?.fullName ?? 'Edit your details',
                    onTap: () {
                      context.push(AppRoutes.driverEditProfile);
                    },
                  ),
                  _MenuItem(
                    icon: Icons.two_wheeler,
                    title: 'Vehicle Information',
                    subtitle: user?.vehicleType ?? 'Add vehicle details',
                    onTap: () {
                      context.push(AppRoutes.driverVehicleInfo);
                    },
                  ),
                  _MenuItem(
                    icon: Icons.badge_outlined,
                    title: 'Documents',
                    subtitle: user?.licenseNumber ?? 'Upload documents',
                    onTap: () {
                      // TODO: Navigate to documents
                    },
                  ),
                ],
              ),

              _WorkSection(
                onScheduleTap: () => context.push(AppRoutes.driverWorkSchedule),
                onAreasTap: () => context.push(AppRoutes.driverServiceAreas),
                onHistoryTap: () => context.push(AppRoutes.driverDeliveryHistory),
              ),

              _MenuSection(
                title: 'Settings',
                items: [
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {},
                      activeColor: AppColors.primary,
                    ),
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    trailing: Switch(
                      value: false,
                      onChanged: (value) {},
                      activeColor: AppColors.primary,
                    ),
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {
                      // TODO: Change language
                    },
                  ),
                ],
              ),

              _MenuSection(
                title: 'Support',
                items: [
                  _MenuItem(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () {
                      // TODO: Navigate to help
                    },
                  ),
                  _MenuItem(
                    icon: Icons.headset_mic_outlined,
                    title: 'Contact Support',
                    onTap: () {
                      // TODO: Contact support
                    },
                  ),
                  _MenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      // TODO: Show about
                    },
                  ),
                ],
              ),

              // Logout Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => _showLogoutDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Logout'),
                ),
              ),

              // App Version
              const Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.driverColor,
          ),
        ),
        const SizedBox(height: 4),
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

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.greyLight,
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
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
            children: items
                .map((item) => Column(
                      children: [
                        item,
                        if (items.indexOf(item) != items.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.driverColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.driverColor, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: trailing == null ? onTap : null,
    );
  }
}

class _WorkSection extends ConsumerWidget {
  final VoidCallback onScheduleTap;
  final VoidCallback onAreasTap;
  final VoidCallback onHistoryTap;

  const _WorkSection({
    required this.onScheduleTap,
    required this.onAreasTap,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider);
    final areasAsync = ref.watch(serviceAreasProvider);
    final historyAsync = ref.watch(deliveryHistoryProvider('all'));

    // Get schedule subtitle
    String scheduleSubtitle = 'Set your availability';
    scheduleAsync.whenData((schedule) {
      final activeDays = schedule.enabledDaysCount;
      
      if (activeDays > 0) {
        scheduleSubtitle = '$activeDays day${activeDays != 1 ? 's' : ''} active';
      } else {
        scheduleSubtitle = 'No active days';
      }
    });

    // Get areas subtitle
    String areasSubtitle = 'Manage delivery zones';
    areasAsync.whenData((data) {
      final count = data.areas.length;
      if (count > 0) {
        areasSubtitle = '$count service area${count != 1 ? 's' : ''}';
      } else {
        areasSubtitle = 'No areas assigned';
      }
    });

    // Get history subtitle
    String historySubtitle = 'View past deliveries';
    historyAsync.whenData((data) {
      final total = data.stats.total;
      if (total > 0) {
        historySubtitle = '$total total deliver${total != 1 ? 'ies' : 'y'}';
      } else {
        historySubtitle = 'No deliveries yet';
      }
    });

    return _MenuSection(
      title: 'Work',
      items: [
        _MenuItem(
          icon: Icons.schedule,
          title: 'Work Schedule',
          subtitle: scheduleSubtitle,
          onTap: onScheduleTap,
        ),
        _MenuItem(
          icon: Icons.map_outlined,
          title: 'Service Areas',
          subtitle: areasSubtitle,
          onTap: onAreasTap,
        ),
        _MenuItem(
          icon: Icons.history,
          title: 'Delivery History',
          subtitle: historySubtitle,
          onTap: onHistoryTap,
        ),
      ],
    );
  }
}
