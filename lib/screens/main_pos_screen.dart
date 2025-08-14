import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../theme/app_theme.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/actions_menu_dialog.dart';
import '../widgets/product_information_popup.dart';
import '../widgets/attribute_selection_popup.dart';

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

  void _showProductInformation(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductInformationPopup(product: product),
    );
  }

  void _showAttributeSelection(BuildContext context, Product product, POSProvider posProvider) {
    if (product.attributes.isEmpty) {
      // If no attributes, add directly to order
      posProvider.addProductToOrder(product);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AttributeSelectionPopup(
        product: product,
        onConfirm: (Product selectedProduct, List<AttributeGroup> selectedAttributes) {
          // Create a new product with selected attributes
          final customizedProduct = Product(
            id: selectedProduct.id,
            name: selectedProduct.name,
            price: selectedProduct.price,
            category: selectedProduct.category,
            image: selectedProduct.image,
            vatRate: selectedProduct.vatRate,
            attributes: selectedAttributes,
            inventory: selectedProduct.inventory,
            financials: selectedProduct.financials,
          );
          
          posProvider.addProductToOrder(customizedProduct);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedProduct.name} added to order'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
            // Table number
            Consumer<POSProvider>(
              builder: (context, posProvider, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  posProvider.tableNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // User
            Consumer<POSProvider>(
              builder: (context, posProvider, _) => Text(
                posProvider.currentUser ?? 'User',
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
                Consumer<POSProvider>(
                  builder: (context, posProvider, _) => Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: posProvider.categories.length,
                      itemBuilder: (context, index) {
                        final category = posProvider.categories[index];
                        final isSelected = posProvider.selectedCategory == category ||
                            (posProvider.selectedCategory.isEmpty && category == 'All');
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                posProvider.selectCategory(category);
                              }
                            },
                            selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primaryColor : AppTheme.blackColor,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Product grid
                Expanded(
                  child: Consumer<POSProvider>(
                    builder: (context, posProvider, _) {
                      final products = _searchQuery.isEmpty
                          ? posProvider.getFilteredProducts()
                          : posProvider.searchProducts(_searchQuery);

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
                            onTap: () => _showAttributeSelection(context, product, posProvider),
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
                  child: Consumer<POSProvider>(
                    builder: (context, posProvider, _) {
                      final hasItems = posProvider.orderItems.isNotEmpty;
                      final currencyFormat = NumberFormat.currency(symbol: 'SR ');
                      
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
                              Icon(
                                Icons.payment,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
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
                              Icon(
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
  final Product product;
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
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');

    return Card(
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
                  // Product image placeholder
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.fastfood,
                              size: 48,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          // Attributes indicator
                          if (product.attributes.isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.tune,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Product name
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Product price
                  Text(
                    currencyFormat.format(product.price),
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
    return Consumer<POSProvider>(
      builder: (context, posProvider, _) {
        final currencyFormat = NumberFormat.currency(symbol: 'SR ');

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
                child: posProvider.orderItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد عناصر في الطلب',
                              style: TextStyle(
                                color: AppTheme.secondaryColor,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: posProvider.orderItems.length,
                        itemBuilder: (context, index) {
                          final item = posProvider.orderItems[index];
                          return OrderItemCard(
                            item: item,
                            onRemove: () => posProvider.removeItemFromOrder(index),
                            onQuantityChanged: (quantity) =>
                                posProvider.updateItemQuantity(index, quantity),
                          );
                        },
                      ),
              ),

              // Order totals
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Taxes:'),
                  Text(currencyFormat.format(posProvider.taxAmount)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    currencyFormat.format(posProvider.total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;

  const OrderItemCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  // Display selected attributes
                  if (item.product.attributes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      children: item.product.attributes.map((attributeGroup) {
                        final selectedOptions = attributeGroup.options
                            .where((attr) => attr.isSelected)
                            .map((attr) => attr.name)
                            .join(', ');
                        
                        if (selectedOptions.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 2),
                            child: Text(
                              '• $selectedOptions',
                              style: const TextStyle(
                                color: AppTheme.secondaryColor,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${currencyFormat.format(item.product.price)} / وحدة',
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity controls
            Row(
              children: [
                IconButton(
                  onPressed: () => onQuantityChanged(item.quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => onQuantityChanged(item.quantity + 1),
                  icon: const Icon(Icons.add_circle_outline),
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
