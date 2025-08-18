import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/models/product_product.dart';
import '../theme/app_theme.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/actions_menu_dialog.dart';
import '../widgets/product_information_popup.dart';
import '../widgets/attribute_selection_popup.dart';
import '../backend/providers/product_attribute_provider.dart';

class MainPOSScreen extends StatefulWidget {
  const MainPOSScreen({super.key});

  @override
  State<MainPOSScreen> createState() => _MainPOSScreenState();
}

class _MainPOSScreenState extends State<MainPOSScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  void _showProductInformation(BuildContext context, ProductProduct product) {
    showDialog(
      context: context,
      builder: (context) => ProductInformationPopup(product: product),
    );
  }



  void _showAttributeSelectionPopup(BuildContext context, ProductProduct product, EnhancedPOSProvider posProvider) {
    print('=== Product Debug Info ===');
    print('Product: ${product.displayName}');
    print('Product ID: ${product.id}');
    print('Product Template ID: ${product.productTmplId}');
    print('Has Variants: ${product.hasVariants}');
    print('Variant Value IDs: ${product.productTemplateVariantValueIds}');
    print('Product JSON: ${product.toJson()}');
    print('========================');
    
    // Check if product has variants/attributes using the backend service
    bool hasAttributes = posProvider.backendService.productHasAttributes(product);
    print('Has Attributes (from template): $hasAttributes');
    
    if (!hasAttributes) {
      // Product has no attributes, add directly to order
      print('No attributes - adding directly');
      _addProductToOrder(context, product, posProvider);
      return;
    }
    
    print('Has variants - showing popup');

    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider(
        create: (context) {
          final provider = ProductAttributeProvider();
          // Set the backend service instance from the POS provider
          provider.setBackendService(posProvider.backendService);
          return provider;
        },
        child: AttributeSelectionPopup(
          product: product,
          onConfirm: (productId, quantity, selectedAttributeValueIds, selectedAttributeNames, selectedAttributeExtraPrices) {
            // Add product using a delayed approach to avoid context issues
            _handleAttributeProductAdd(
              product, 
              quantity, 
              selectedAttributeValueIds,
              selectedAttributeNames: selectedAttributeNames,
              selectedAttributeExtraPrices: selectedAttributeExtraPrices,
            );
          },
        ),
      ),
    );
  }

  /// Handle adding product with attributes in a safer way
  void _handleAttributeProductAdd(ProductProduct product, double quantity, List<int> selectedAttributeValueIds, {List<String>? selectedAttributeNames, List<double>? selectedAttributeExtraPrices}) async {
    // Get the current provider in a safe way
    if (!mounted) return;
    
    try {
      final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      
      // Ensure there's an active order, create one if needed
      if (!posProvider.hasActiveOrder) {
        final session = posProvider.currentSession;
        final config = posProvider.selectedConfig;
        if (session == null || config == null) {
          throw Exception('No active session or config found');
        }
        
        // Use pricelist_id from config, fallback to 1 if null
        final pricelistId = config.pricelistId ?? 1;
        print('📝 Creating order (with attributes) using pricelist_id: $pricelistId (from config: ${config.pricelistId})');
        
        final orderResult = await posProvider.backendService.orderManager.createOrder(
          session: session,
          pricelistId: pricelistId,
        );
        if (!orderResult.success) {
          throw Exception(orderResult.error ?? 'Failed to create order');
        }
      }
      
      // Add the product with attributes to the order
      // Note: Custom attributes are stored in the order line but passed through the product name
      final result = await posProvider.backendService.orderManager.addProductToOrder(
        product: product,
        quantity: quantity,
      );
      
      if (!result.success) {
        throw Exception(result.error ?? 'Failed to add product to order');
      }
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      // Use the actual attribute names passed in
      String attributeText = '';
      if (selectedAttributeNames != null && selectedAttributeNames.isNotEmpty) {
        attributeText = ' (${selectedAttributeNames.join(', ')})';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة ${product.displayName}$attributeText للطلب (الكمية: ${quantity.toStringAsFixed(0)})'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error adding product to order: $e');
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إضافة المنتج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Add product to order without attributes (for simple products)
  void _addProductToOrder(BuildContext context, ProductProduct product, EnhancedPOSProvider posProvider) async {
    try {
      print('Adding product without attributes: ${product.displayName}');
      
      // Ensure there's an active order, create one if needed
      if (!posProvider.hasActiveOrder) {
        final session = posProvider.currentSession;
        final config = posProvider.selectedConfig;
        if (session == null || config == null) {
          throw Exception('No active session or config found');
        }
        
        // Use pricelist_id from config, fallback to 1 if null
        final pricelistId = config.pricelistId ?? 1;
        print('📝 Creating order (simple product) using pricelist_id: $pricelistId (from config: ${config.pricelistId})');
        
        final orderResult = await posProvider.backendService.orderManager.createOrder(
          session: session,
          pricelistId: pricelistId,
        );
        if (!orderResult.success) {
          throw Exception(orderResult.error ?? 'Failed to create order');
        }
      }
      
      // Add the product to the order
      await posProvider.addProductToCurrentOrder(product, 1.0);
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.displayName} to order'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding product to order: $e');
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product to order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }








  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false),
        ),
        title: Row(
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'odoo',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            // Session info
            Consumer<EnhancedPOSProvider>(
              builder: (context, posProvider, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  posProvider.currentSession?.name ?? 'جلسة غير محددة',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // User
            Consumer<EnhancedPOSProvider>(
              builder: (context, posProvider, _) => Text(
                posProvider.currentUser ?? 'مستخدم',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Main content area
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Category tabs
                Consumer<EnhancedPOSProvider>(
                  builder: (context, posProvider, _) {
                    final categories = ['الكل', ...posProvider.categories.map((cat) => cat.name)];
                    
                    return Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = posProvider.selectedCategoryName == category ||
                              (posProvider.selectedCategoryName.isEmpty && category == 'الكل');
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  if (category == 'الكل') {
                                    posProvider.selectCategory(null);
                                  } else {
                                    final selectedCat = posProvider.categories
                                        .firstWhere((cat) => cat.name == category);
                                    posProvider.selectCategory(selectedCat);
                                  }
                                }
                              },
                              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                // Product grid
                Expanded(
                  child: Consumer<EnhancedPOSProvider>(
                    builder: (context, posProvider, _) {
                      List<ProductProduct> products;
                      
                      if (_searchQuery.isEmpty) {
                        products = posProvider.getFilteredProducts();
                      } else {
                        products = posProvider.products
                            .where((product) => product.displayName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                            .toList();
                      }

                      if (products.isEmpty) {
                        return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                                Icons.inventory_2_outlined,
                    size: 64,
                                color: Colors.grey,
                  ),
                              SizedBox(height: 16),
                  Text(
                                'لا توجد منتجات',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                  ),
                ],
              ),
            );
          }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            onTap: () => _showAttributeSelectionPopup(context, product, posProvider),
                            onInfoTap: () => _showProductInformation(context, product),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right sidebar
          Container(
            width: 400,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              children: [
                // Order summary
                Expanded(
                  flex: 2,
                  child: OrderSummary(),
                ),

                // Customer and Actions buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/customers');
                          },
                          icon: const Icon(
                            Icons.person_outline,
                            size: 18,
                          ),
                          label: const Text(
                            'العميل',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ActionsMenuDialog(),
                            );
                          },
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 18,
                          ),
                          label: const Text(
                            'الإجراءات',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Numpad
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const NumpadWidget(),
                ),

                                // Payment button
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Consumer<EnhancedPOSProvider>(
                    builder: (context, posProvider, _) {
                      final hasItems = posProvider.orderLines.isNotEmpty;
                      final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
                      
                      return Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasItems 
                                ? [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)]
                                : [Colors.grey.shade400, Colors.grey.shade500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: hasItems ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: ElevatedButton(
                          onPressed: hasItems ? () {
                            Navigator.of(context).pushNamed('/payment');
                          } : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إضافة عناصر للطلب أولاً'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.payment,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الدفع',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (hasItems)
                                    Text(
                                      currencyFormat.format(posProvider.total),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductProduct product;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: product.image128 != null && product.image128!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(product.image128!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.fastfood,
                                      size: 48,
                                      color: AppTheme.primaryColor,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.fastfood,
                                size: 48,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Product name
                  Text(
                    product.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Product price
                  Text(
                    currencyFormat.format(product.lstPrice),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Information icon
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onInfoTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderSummary extends StatelessWidget {
  const OrderSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, posProvider, _) {
        final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
        final orderLines = posProvider.orderLines;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'ملخص الطلب',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Order items
              Expanded(
                child: orderLines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد عناصر في الطلب',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: orderLines.length,
                        itemBuilder: (context, index) {
                          final orderLine = orderLines[index];
                          return OrderItemCard(
                            orderLine: orderLine,
                            onRemove: () => posProvider.removeOrderLine(index),
                            onQuantityChanged: (quantity) =>
                                posProvider.updateOrderLineQuantity(index, quantity),
                          );
                        },
                      ),
              ),

              // Order totals
              if (orderLines.isNotEmpty) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المجموع الفرعي:'),
                    Text(currencyFormat.format(posProvider.subtotal)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الضرائب:'),
                    Text(currencyFormat.format(posProvider.taxAmount)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الإجمالي:',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currencyFormat.format(posProvider.total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class OrderItemCard extends StatelessWidget {
  final dynamic orderLine; // Can be POSOrderLine
  final VoidCallback onRemove;
  final Function(double) onQuantityChanged;

  const OrderItemCard({
    super.key,
    required this.orderLine,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    orderLine.fullProductName ?? 'منتج غير محدد',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currencyFormat.format(orderLine.priceUnit ?? 0)} / وحدة',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الإجمالي: ${currencyFormat.format(orderLine.priceSubtotal ?? 0)}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity controls
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    final newQty = (orderLine.qty ?? 1) - 1;
                    if (newQty > 0) {
                      onQuantityChanged(newQty);
                    }
                  },
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    (orderLine.qty ?? 1).toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final newQty = (orderLine.qty ?? 1) + 1;
                    onQuantityChanged(newQty);
                  },
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),

            // Remove button
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
