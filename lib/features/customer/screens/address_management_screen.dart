import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../services/customer_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'map_picker_screen.dart';

class AddressManagementScreen extends ConsumerStatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  ConsumerState<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState
    extends ConsumerState<AddressManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load addresses when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerDataProvider.notifier).loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerDataProvider);
    final addresses = customerState.addresses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: customerState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
              ? _buildEmptyState()
              : _buildAddressList(addresses),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 80,
            color: AppColors.greyMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Saved Addresses',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your delivery addresses for faster checkout',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList(List<CustomerAddress> addresses) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        return _AddressCard(
          address: address,
          onEdit: () => _showAddressDialog(context, address: address),
          onDelete: () => _confirmDelete(context, address),
          onSetDefault: () => _setAsDefault(address),
        );
      },
    );
  }

  void _showAddressDialog(BuildContext context, {CustomerAddress? address}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressFormSheet(
        address: address,
        onSave: (newAddress) async {
          try {
            if (address != null) {
              // Edit existing
              await ref.read(customerDataProvider.notifier).updateAddress(newAddress);
            } else {
              // Add new
              await ref.read(customerDataProvider.notifier).addAddress(newAddress);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, CustomerAddress address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete "${address.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(customerDataProvider.notifier).deleteAddress(address.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _setAsDefault(CustomerAddress address) async {
    try {
      await ref.read(customerDataProvider.notifier).setDefaultAddress(address.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${address.label} set as default')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _AddressCard extends StatelessWidget {
  final CustomerAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getLabelIcon(address.label),
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  address.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (address.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'default':
                        onSetDefault();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (!address.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 18),
                            SizedBox(width: 8),
                            Text('Set as Default'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address.fullAddress,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (address.deliveryInstructions != null && address.deliveryInstructions!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Note: ${address.deliveryInstructions}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'office':
      case 'work':
        return Icons.business;
      default:
        return Icons.location_on;
    }
  }
}

class _AddressFormSheet extends StatefulWidget {
  final CustomerAddress? address;
  final Function(CustomerAddress) onSave;

  const _AddressFormSheet({
    this.address,
    required this.onSave,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _addressController;
  late TextEditingController _instructionsController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;
  bool _isDefault = false;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  bool _hasPickedLocation = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.address?.label ?? '');
    _addressController =
        TextEditingController(text: widget.address?.fullAddress ?? '');
    _instructionsController =
        TextEditingController(text: widget.address?.deliveryInstructions ?? '');
    _contactNameController =
        TextEditingController(text: widget.address?.contactName ?? '');
    _contactPhoneController =
        TextEditingController(text: widget.address?.contactPhone ?? '');
    _isDefault = widget.address?.isDefault ?? false;
    _latitude = widget.address?.latitude;
    _longitude = widget.address?.longitude;
    _hasPickedLocation = _latitude != null && _longitude != null;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _instructionsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.greyLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.address != null ? 'Edit Address' : 'Add New Address',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Label Field
              CustomTextField(
                controller: _labelController,
                label: 'Label',
                hint: 'e.g., Home, Office',
                prefixIcon: Icons.label,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a label';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address Field
              CustomTextField(
                controller: _addressController,
                label: 'Full Address',
                hint: 'Street, Barangay, City',
                prefixIcon: Icons.location_on,
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the full address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Delivery Instructions Field
              CustomTextField(
                controller: _instructionsController,
                label: 'Delivery Instructions (Optional)',
                hint: 'Nearby landmark or special instructions',
                prefixIcon: Icons.info_outline,
              ),
              const SizedBox(height: 16),

              // Contact Name Field
              CustomTextField(
                controller: _contactNameController,
                label: 'Contact Name (Optional)',
                hint: 'Name for this address',
                prefixIcon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Contact Phone Field
              CustomTextField(
                controller: _contactPhoneController,
                label: 'Contact Phone (Optional)',
                hint: 'Phone number for this address',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Pick Location Button
              OutlinedButton.icon(
                onPressed: _openMapPicker,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: _hasPickedLocation ? AppColors.primary.withValues(alpha: 0.1) : null,
                ),
                icon: Icon(
                  _hasPickedLocation ? Icons.check_circle : Icons.map,
                  color: _hasPickedLocation ? AppColors.success : null,
                ),
                label: Text(_hasPickedLocation ? 'Location Selected' : 'Pick Location on Map'),
              ),
              if (_hasPickedLocation && _latitude != null && _longitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Set as Default Checkbox
              CheckboxListTile(
                value: _isDefault,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value ?? false;
                  });
                },
                title: const Text('Set as default address'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Save Button
              CustomButton(
                text: widget.address != null ? 'Update Address' : 'Save Address',
                isLoading: _isLoading,
                onPressed: _saveAddress,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapPicker() async {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _hasPickedLocation = true;
        // Auto-fill address if it was empty or update it
        if (_addressController.text.isEmpty || 
            _addressController.text == widget.address?.fullAddress) {
          _addressController.text = result.address;
        }
      });
    }
  }

  void _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final newAddress = CustomerAddress(
        id: widget.address?.id ?? '',
        label: _labelController.text,
        fullAddress: _addressController.text,
        latitude: _latitude ?? widget.address?.latitude ?? 14.5547,
        longitude: _longitude ?? widget.address?.longitude ?? 121.0244,
        deliveryInstructions: _instructionsController.text.isNotEmpty
            ? _instructionsController.text
            : null,
        contactName: _contactNameController.text.isNotEmpty
            ? _contactNameController.text
            : null,
        contactPhone: _contactPhoneController.text.isNotEmpty
            ? _contactPhoneController.text
            : null,
        isDefault: _isDefault,
      );

      try {
        await widget.onSave(newAddress);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.address != null
                    ? 'Address updated successfully'
                    : 'Address added successfully',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
