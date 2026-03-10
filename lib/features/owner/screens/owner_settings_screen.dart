import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../services/owner_service.dart';

class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(stationSettingsProvider);
    final paymentAsync = ref.watch(paymentSettingsProvider);

    return Scaffold(
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.ownerColor),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load settings',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(stationSettingsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ownerColor,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (settings) => SingleChildScrollView(
            child: Column(
              children: [
                // Station Header
                _buildHeader(settings),

                // Station Stats
                _buildStats(settings),

                const SizedBox(height: 8),

                // Menu Sections
                _MenuSection(
                  title: 'Station Settings',
                  items: [
                    _MenuItem(
                      icon: Icons.storefront,
                      title: 'Station Profile',
                      subtitle: settings.name,
                      onTap: () => _showStationProfileDialog(context, settings),
                    ),
                    _MenuItem(
                      icon: Icons.location_on,
                      title: 'Location & Zone',
                      subtitle: _getLocationSummary(settings),
                      onTap: () => _showLocationZoneDialog(context, settings),
                    ),
                    _MenuItem(
                      icon: Icons.schedule,
                      title: 'Operating Hours',
                      subtitle: _getOperatingHoursSummary(settings.operatingHours),
                      onTap: () => _showOperatingHoursDialog(context, settings),
                    ),
                    _MenuItem(
                      icon: Icons.delivery_dining,
                      title: 'Delivery Settings',
                      subtitle: '₱${settings.baseDeliveryFee.toStringAsFixed(0)} fee, ₱${settings.minimumOrderAmount.toStringAsFixed(0)} min',
                      onTap: () => _showDeliverySettingsDialog(context, settings),
                    ),
                  ],
                ),

                _MenuSection(
                  title: 'Products & Inventory',
                  items: [
                    _MenuItem(
                      icon: Icons.inventory_2,
                      title: 'Products',
                      subtitle: 'Manage products and prices',
                      onTap: () => context.push('/owner/products'),
                    ),
                    _MenuItem(
                      icon: Icons.inventory,
                      title: 'Inventory',
                      subtitle: 'Stock levels, alerts',
                      onTap: () => context.push('/owner/inventory'),
                    ),
                    _MenuItem(
                      icon: Icons.local_offer,
                      title: 'Promotions',
                      subtitle: 'Create and manage promos',
                      onTap: () => context.push('/owner/promos'),
                    ),
                  ],
                ),

                _MenuSection(
                  title: 'Payments',
                  items: [
                    _MenuItem(
                      icon: Icons.payment,
                      title: 'Payment Methods',
                      subtitle: paymentAsync.when(
                        data: (payment) => _getPaymentMethodsSummary(payment),
                        loading: () => 'Loading...',
                        error: (_, __) => 'Tap to configure',
                      ),
                      onTap: () => _showPaymentMethodsDialog(context),
                    ),
                    _MenuItem(
                      icon: Icons.account_balance,
                      title: 'Bank Account',
                      subtitle: 'For settlements',
                      onTap: () {
                        // TODO: Navigate to bank settings
                      },
                    ),
                  ],
                ),

                _MenuSection(
                  title: 'Notifications',
                  items: [
                    _MenuItem(
                      icon: Icons.notifications,
                      title: 'Push Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppColors.primary,
                      ),
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.email,
                      title: 'Email Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppColors.primary,
                      ),
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.sms,
                      title: 'SMS Alerts',
                      trailing: Switch(
                        value: false,
                        onChanged: (value) {},
                        activeColor: AppColors.primary,
                      ),
                      onTap: () {},
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
                      icon: Icons.headset_mic,
                      title: 'Contact Support',
                      onTap: () {
                        // TODO: Contact support
                      },
                    ),
                    _MenuItem(
                      icon: Icons.description,
                      title: 'Terms & Conditions',
                      onTap: () {
                        // TODO: Show terms
                      },
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip,
                      title: 'Privacy Policy',
                      onTap: () {
                        // TODO: Show privacy policy
                      },
                    ),
                  ],
                ),

                // Logout Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: () => _showLogoutDialog(context, ref),
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
                  'FillMe Owner v1.0.0',
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
      ),
    );
  }

  Widget _buildHeader(StationSettings settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.ownerColor, Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white24,
            backgroundImage: settings.logoUrl != null 
                ? NetworkImage(settings.logoUrl!) 
                : null,
            child: settings.logoUrl == null
                ? const Icon(
                    Icons.store,
                    size: 40,
                    color: AppColors.white,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            settings.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: settings.isActive 
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  settings.isActive ? Icons.check_circle : Icons.cancel,
                  color: settings.isActive ? AppColors.success : AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  settings.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: settings.isActive ? AppColors.success : AppColors.error,
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

  Widget _buildStats(StationSettings settings) {
    final createdDate = settings.createdAt != null
        ? '${_getMonthName(settings.createdAt!.month)} ${settings.createdAt!.year}'
        : 'N/A';

    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: 'Since', value: createdDate),
          _VerticalDivider(),
          _StatItem(label: 'Min Order', value: '₱${settings.minimumOrderAmount.toStringAsFixed(0)}'),
          _VerticalDivider(),
          _StatItem(label: 'Delivery', value: '₱${settings.baseDeliveryFee.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getOperatingHoursSummary(Map<String, OperatingHours> hours) {
    if (hours.isEmpty) return 'Not configured';
    
    final firstDay = hours.values.first;
    if (!firstDay.isOpen) return 'Closed';
    
    return '${firstDay.openTime} - ${firstDay.closeTime}';
  }

  String _getPaymentMethodsSummary(PaymentSettings payment) {
    final methods = <String>[];
    if (payment.codEnabled) methods.add('COD');
    if (payment.gcashEnabled) methods.add('GCash');
    if (payment.mayaEnabled) methods.add('Maya');
    if (payment.cardEnabled) methods.add('Card');
    
    if (methods.isEmpty) return 'None enabled';
    return methods.join(', ');
  }

  String _getLocationSummary(StationSettings settings) {
    final parts = <String>[];
    
    if (settings.zoneName != null) {
      parts.add(settings.zoneName!);
    }
    if (settings.zoneCity != null) {
      parts.add(settings.zoneCity!);
    }
    
    if (parts.isEmpty && settings.address != null) {
      return settings.address!;
    }
    
    if (parts.isEmpty) {
      return 'Location not set';
    }
    
    return parts.join(', ');
  }

  void _showLocationZoneDialog(BuildContext context, StationSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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
              Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.ownerColor),
                  const SizedBox(width: 12),
                  const Text(
                    'Location & Zone',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              // Address Section
              _buildInfoRow(
                icon: Icons.home,
                label: 'Address',
                value: settings.address ?? 'Not set',
              ),
              const SizedBox(height: 16),
              
              // Zone Section
              _buildInfoRow(
                icon: Icons.map,
                label: 'Zone',
                value: settings.zoneName ?? 'Not assigned',
              ),
              const SizedBox(height: 16),
              
              // City & Barangay
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      label: 'City',
                      value: settings.zoneCity ?? 'N/A',
                      icon: Icons.location_city,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Barangay',
                      value: settings.zoneBarangay ?? 'N/A',
                      icon: Icons.place,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Coordinates
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Latitude',
                      value: settings.latitude?.toStringAsFixed(6) ?? 'N/A',
                      icon: Icons.explore,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Longitude',
                      value: settings.longitude?.toStringAsFixed(6) ?? 'N/A',
                      icon: Icons.explore,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Delivery Radius
              _buildInfoRow(
                icon: Icons.radar,
                label: 'Delivery Radius',
                value: '${settings.deliveryRadius.toStringAsFixed(1)} km',
              ),
              
              const SizedBox(height: 24),
              
              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Contact support to update your station location or zone assignment.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showStationProfileDialog(BuildContext context, StationSettings settings) {
    final nameController = TextEditingController(text: settings.name);
    final descriptionController = TextEditingController(text: settings.description ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                  'Station Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Station Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Upload logo
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload Logo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              final ownerService = ref.read(ownerServiceProvider);
                              await ownerService.updateProfile(
                                name: nameController.text,
                                description: descriptionController.text,
                              );
                              ref.invalidate(stationSettingsProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.ownerColor,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save', style: TextStyle(color: Colors.white),),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOperatingHoursDialog(BuildContext context, StationSettings settings) {
    final hours = Map<String, OperatingHours>.from(settings.operatingHours);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operating Hours',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                  .map((day) {
                    final dayHours = hours[day] ?? OperatingHours(isOpen: true, openTime: '06:00', closeTime: '21:00');
                    final dayName = day[0].toUpperCase() + day.substring(1);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(dayName),
                          ),
                          Switch(
                            value: dayHours.isOpen,
                            onChanged: (value) {
                              setModalState(() {
                                hours[day] = dayHours.copyWith(isOpen: value);
                              });
                            },
                            activeColor: AppColors.ownerColor,
                          ),
                          const Spacer(),
                          if (dayHours.isOpen)
                            Text(
                              '${dayHours.openTime} - ${dayHours.closeTime}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            const Text(
                              'Closed',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            final ownerService = ref.read(ownerServiceProvider);
                            await ownerService.updateOperatingHours(hours);
                            ref.invalidate(stationSettingsProvider);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Operating hours updated'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.ownerColor,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeliverySettingsDialog(BuildContext context, StationSettings settings) {
    final deliveryFeeController = TextEditingController(text: settings.baseDeliveryFee.toStringAsFixed(0));
    final minOrderController = TextEditingController(text: settings.minimumOrderAmount.toStringAsFixed(0));
    final freeDeliveryController = TextEditingController(
      text: settings.freeDeliveryMinimum?.toStringAsFixed(0) ?? '',
    );
    bool enableFreeDelivery = settings.enableFreeDelivery;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                  'Delivery Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: deliveryFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Base Delivery Fee',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: minOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Order Amount',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: freeDeliveryController,
                  decoration: const InputDecoration(
                    labelText: 'Free Delivery Minimum',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enable Free Delivery'),
                  value: enableFreeDelivery,
                  onChanged: (value) {
                    setModalState(() => enableFreeDelivery = value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.ownerColor,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              final ownerService = ref.read(ownerServiceProvider);
                              await ownerService.updateDeliverySettings(
                                baseDeliveryFee: double.tryParse(deliveryFeeController.text),
                                minimumOrderAmount: double.tryParse(minOrderController.text),
                                freeDeliveryMinimum: double.tryParse(freeDeliveryController.text),
                                enableFreeDelivery: enableFreeDelivery,
                              );
                              ref.invalidate(stationSettingsProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Delivery settings updated'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.ownerColor,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentMethodsDialog(BuildContext context) {
    final paymentAsync = ref.read(paymentSettingsProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => paymentAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(color: AppColors.ownerColor),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $error'),
          ),
        ),
        data: (payment) => _PaymentMethodsContent(
          payment: payment,
          onSave: () {
            ref.invalidate(paymentSettingsProvider);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
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

class _PaymentMethodsContent extends ConsumerStatefulWidget {
  final PaymentSettings payment;
  final VoidCallback onSave;

  const _PaymentMethodsContent({
    required this.payment,
    required this.onSave,
  });

  @override
  ConsumerState<_PaymentMethodsContent> createState() => _PaymentMethodsContentState();
}

class _PaymentMethodsContentState extends ConsumerState<_PaymentMethodsContent> {
  late bool codEnabled;
  late bool gcashEnabled;
  late bool mayaEnabled;
  late bool cardEnabled;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    codEnabled = widget.payment.codEnabled;
    gcashEnabled = widget.payment.gcashEnabled;
    mayaEnabled = widget.payment.mayaEnabled;
    cardEnabled = widget.payment.cardEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Cash on Delivery'),
            subtitle: const Text('Accept COD payments'),
            value: codEnabled,
            onChanged: (value) => setState(() => codEnabled = value),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.ownerColor,
          ),
          SwitchListTile(
            title: const Text('GCash'),
            subtitle: const Text('Accept GCash payments'),
            value: gcashEnabled,
            onChanged: (value) => setState(() => gcashEnabled = value),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.ownerColor,
          ),
          SwitchListTile(
            title: const Text('Maya'),
            subtitle: const Text('Accept Maya payments'),
            value: mayaEnabled,
            onChanged: (value) => setState(() => mayaEnabled = value),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.ownerColor,
          ),
          SwitchListTile(
            title: const Text('Credit/Debit Card'),
            subtitle: const Text('Accept card payments'),
            value: cardEnabled,
            onChanged: (value) => setState(() => cardEnabled = value),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.ownerColor,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      try {
                        final ownerService = ref.read(ownerServiceProvider);
                        await ownerService.updatePaymentMethods(
                          codEnabled: codEnabled,
                          gcashEnabled: gcashEnabled,
                          mayaEnabled: mayaEnabled,
                          cardEnabled: cardEnabled,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment methods updated'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          widget.onSave();
                        }
                      } catch (e) {
                        setState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.ownerColor,
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save', style: TextStyle(color: Colors.white),),
            ),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.ownerColor,
          ),
        ),
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
          color: AppColors.ownerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.ownerColor, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: trailing == null ? onTap : null,
    );
  }
}
