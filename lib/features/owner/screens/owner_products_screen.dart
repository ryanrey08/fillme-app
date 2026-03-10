import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_providers.dart';
import '../../../services/owner_service.dart';

class OwnerProductsScreen extends ConsumerStatefulWidget {
  const OwnerProductsScreen({super.key});

  @override
  ConsumerState<OwnerProductsScreen> createState() => _OwnerProductsScreenState();
}

class _OwnerProductsScreenState extends ConsumerState<OwnerProductsScreen> {
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(ownerProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: AppColors.ownerColor,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProductDialog(context),
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: productsAsync.when(
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
                'Failed to load products',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(ownerProductsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ownerColor,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No products yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showProductDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ownerColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerProductsProvider),
            color: AppColors.ownerColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCard(
                  product: product,
                  onEdit: () => _showProductDialog(context, product: product),
                  onDelete: () => _confirmDelete(context, product),
                  onToggleActive: () => _toggleProductActive(product),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        backgroundColor: AppColors.ownerColor,
        child: const Icon(Icons.add, color: Colors.white,),
      ),
    );
  }

  void _showProductDialog(BuildContext context, {StationProduct? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(
      text: product?.price.toStringAsFixed(2) ?? '',
    );
    final stockController = TextEditingController(
      text: product?.stockQuantity.toString() ?? '',
    );
    String selectedUnit = product?.unit ?? 'gallon';
    int? selectedCategoryId = product?.categoryId;
    bool isActive = product?.isActive ?? true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final categoriesAsync = ref.watch(productCategoriesProvider);
          
          return StatefulBuilder(
            builder: (context, setModalState) => Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Product' : 'Add Product',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Category dropdown
                      categoriesAsync.when(
                        loading: () => const LinearProgressIndicator(color: AppColors.ownerColor),
                        error: (e, _) => Text('Failed to load categories: $e', style: const TextStyle(color: Colors.red)),
                        data: (categories) => DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: categories.map<DropdownMenuItem<int>>((cat) => DropdownMenuItem<int>(
                            value: cat.id,
                            child: Text(cat.name),
                          )).toList(),
                          onChanged: (value) {
                            setModalState(() => selectedCategoryId = value);
                          },
                          validator: (value) => value == null ? 'Please select a category' : null,
                        ),
                      ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Purified Water',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'gallon', child: Text('Gallon')),
                            DropdownMenuItem(value: 'liter', child: Text('Liter')),
                            DropdownMenuItem(value: 'bottle', child: Text('Bottle')),
                            DropdownMenuItem(value: 'container', child: Text('Container')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedUnit = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active'),
                    subtitle: const Text('Product is available for ordering'),
                    value: isActive,
                    onChanged: (value) {
                      setModalState(() => isActive = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.ownerColor,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!isEditing && selectedCategoryId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select a category'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              
                              if (nameController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a product name'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final price = double.tryParse(priceController.text);
                              if (price == null || price <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a valid price'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);
                              try {
                                final ownerService = ref.read(ownerServiceProvider);
                                
                                if (isEditing) {
                                  await ownerService.updateProduct(
                                    product.id,
                                    categoryId: selectedCategoryId,
                                    name: nameController.text,
                                    description: descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : null,
                                    price: price,
                                    unit: selectedUnit,
                                    stockQuantity: int.tryParse(stockController.text),
                                    isActive: isActive,
                                  );
                                } else {
                                  await ownerService.createProduct(
                                    categoryId: selectedCategoryId!,
                                    name: nameController.text,
                                    price: price,
                                    description: descriptionController.text.isNotEmpty
                                        ? descriptionController.text
                                        : null,
                                    unit: selectedUnit,
                                    stockQuantity: int.tryParse(stockController.text),
                                    isActive: isActive,
                                  );
                                }

                                ref.invalidate(ownerProductsProvider);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEditing
                                          ? 'Product updated successfully'
                                          : 'Product created successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
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
                          : Text(isEditing ? 'Update Product' : 'Add Product', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, StationProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final ownerService = ref.read(ownerServiceProvider);
                await ownerService.deleteProduct(product.id);
                ref.invalidate(ownerProductsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                    ),
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

  Future<void> _toggleProductActive(StationProduct product) async {
    try {
      final ownerService = ref.read(ownerServiceProvider);
      await ownerService.updateProduct(
        product.id,
        isActive: !product.isActive,
      );
      ref.invalidate(ownerProductsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(product.isActive
                ? 'Product deactivated'
                : 'Product activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  final StationProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image/Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.ownerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    image: product.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(product.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.imageUrl == null
                      ? const Icon(
                          Icons.water_drop,
                          color: AppColors.ownerColor,
                          size: 30,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: product.isActive
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.isActive
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (product.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₱${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ownerColor,
                            ),
                          ),
                          Text(
                            ' / ${product.unit}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: product.stockQuantity < 10
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.stockQuantity} in stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: product.stockQuantity < 10
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: product.stockQuantity < 10
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ownerColor,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.greyLight,
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onToggleActive,
                    icon: Icon(
                      product.isActive ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(product.isActive ? 'Deactivate' : 'Activate'),
                    style: TextButton.styleFrom(
                      foregroundColor: product.isActive
                          ? AppColors.textSecondary
                          : AppColors.success,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.greyLight,
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
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
