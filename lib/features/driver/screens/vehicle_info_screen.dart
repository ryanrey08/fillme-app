import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class VehicleInfoScreen extends ConsumerStatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  ConsumerState<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends ConsumerState<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vehicleTypeController;
  late TextEditingController _vehiclePlateController;
  late TextEditingController _licenseNumberController;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _vehicleTypeController = TextEditingController(text: user?.vehicleType ?? '');
    _vehiclePlateController = TextEditingController(text: user?.vehiclePlate ?? '');
    _licenseNumberController = TextEditingController(text: user?.licenseNumber ?? '');

    // Listen for changes
    _vehicleTypeController.addListener(_onFieldChanged);
    _vehiclePlateController.addListener(_onFieldChanged);
    _licenseNumberController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final user = ref.read(authProvider).user;
    final hasChanges = _vehicleTypeController.text != (user?.vehicleType ?? '') ||
        _vehiclePlateController.text != (user?.vehiclePlate ?? '') ||
        _licenseNumberController.text != (user?.licenseNumber ?? '');
    
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _saveVehicleInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final vehicleType = _vehicleTypeController.text.trim().isNotEmpty 
        ? _vehicleTypeController.text.trim() 
        : null;
    final vehiclePlate = _vehiclePlateController.text.trim().isNotEmpty 
        ? _vehiclePlateController.text.trim() 
        : null;
    final licenseNumber = _licenseNumberController.text.trim().isNotEmpty 
        ? _licenseNumberController.text.trim() 
        : null;

    print('=== VEHICLE INFO SAVE ===');
    print('vehicleType: $vehicleType');
    print('vehiclePlate: $vehiclePlate');
    print('licenseNumber: $licenseNumber');

    try {
      final success = await ref.read(authProvider.notifier).updateProfile(
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
        licenseNumber: licenseNumber,
      );

      print('updateProfile result: $success');

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle information updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else {
          final errorMessage = ref.read(authProvider).errorMessage;
          print('Error message: $errorMessage');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage ?? 'Failed to update vehicle information'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Exception in _saveVehicleInfo: $e');
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  String _getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'motorcycle':
        return '🏍️';
      case 'bicycle':
        return '🚲';
      case 'car':
        return '🚗';
      case 'van':
        return '🚐';
      default:
        return '🛵';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vehicle Information'),
          backgroundColor: AppColors.driverColor,
          foregroundColor: AppColors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Vehicle Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.driverColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getVehicleIcon(user?.vehicleType),
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Vehicle Type
              CustomTextField(
                controller: _vehicleTypeController,
                label: 'Vehicle Type',
                hint: 'e.g., Motorcycle, Bicycle, Car',
                prefixIcon: Icons.two_wheeler,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vehicle type is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Vehicle Plate
              CustomTextField(
                controller: _vehiclePlateController,
                label: 'Plate Number',
                hint: 'Enter your plate number',
                prefixIcon: Icons.confirmation_number_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Plate number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // License Number
              CustomTextField(
                controller: _licenseNumberController,
                label: "Driver's License Number",
                hint: "Enter your driver's license number",
                prefixIcon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Driver's license number is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Make sure your vehicle information is accurate. It will be used for delivery assignments.',
                        style: TextStyle(
                          color: AppColors.info,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              CustomButton(
                text: 'Save Changes',
                onPressed: _hasChanges ? _saveVehicleInfo : null,
                isLoading: _isLoading,
                backgroundColor: AppColors.driverColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
