import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/models/product_product.dart';
import '../backend/models/res_partner.dart';
import '../theme/app_theme.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/actions_menu_dialog.dart';
import '../widgets/product_information_popup.dart';
import '../widgets/attribute_selection_popup.dart';
import '../widgets/combo_selection_popup.dart';
import '../backend/providers/product_attribute_provider.dart';
import '../backend/models/product_combo.dart';

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
    print('🎯 Product "${product.displayName}" (ID: ${product.id}) was tapped');
    
    // First check if product is a combo product
    if (posProvider.backendService.isComboProduct(product)) {
      print('✅ Product is combo, showing combo selection popup');
      _showComboSelectionPopup(context, product, posProvider);
      return;
    } else {
      print('ℹ️ Product is not combo, checking for attributes...');
    }
    
    // Check if product has variants/attributes using the backend service
    bool hasAttributes = posProvider.backendService.productHasAttributes(product);
    
    if (!hasAttributes) {
      // Product has no attributes, add directly to order
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

  /// Show combo selection popup for combo products
  void _showComboSelectionPopup(BuildContext context, ProductProduct product, EnhancedPOSProvider posProvider) async {
    try {
      print('🍔 Combo Detection: Product ${product.displayName} has combo IDs: ${product.comboIds}');
      print('🍔 Available combos in system: ${posProvider.combos.length}');
      print('🍔 Available combo items in system: ${posProvider.comboItems.length}');
      
      // Get combo details from backend service
      print('🔍 جاري الحصول على تفاصيل الكومبو من الخادم...');
      final comboDetails = await posProvider.backendService.getComboDetails(product.id);
      
      if (comboDetails == null) {
        print('❌ No combo details found for product ${product.id}');
        print('🔍 تشخيص المشكلة:');
        print('   - المنتج له combo_ids: ${product.comboIds}');
        print('   - لكن لا توجد عناصر كومبو محملة');
        print('   - جدول product.combo.item فارغ أو لا يحتوي على بيانات');
        print('💡 الحل: إضافة عناصر كومبو في Odoo أولاً');
        
        if (!mounted) return;
        
        // Show informative message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ لا يمكن عرض نافذة اختيار الكومبو\n'
              '💡 يجب إعداد عناصر الكومبو في Odoo أولاً\n'
              '📋 جدول product.combo.item فارغ\n'
              '🔧 سيتم إضافة المنتج كمنتج عادي',
              style: TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'إغلاق',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        
        // Fallback to regular product addition
        _addProductToOrder(context, product, posProvider);
        return;
      }

      final combo = comboDetails['combo'] as ProductCombo;
      final sections = comboDetails['sections'] as List<ComboSection>;

      print('✅ Found combo details: ${combo.name} with ${sections.length} sections');
      print('🔍 تفاصيل الأقسام:');
      for (final section in sections) {
        print('  📋 Section: ${section.groupName} (${section.items.length} items)');
        for (final item in section.items) {
          print('    • ${item.name} (+${item.extraPrice} ريال)');
        }
      }
      
      if (sections.isEmpty) {
        print('⚠️ تحذير: لا توجد أقسام في الكومبو!');
        print('💡 هذا يعني أن جدول product.combo.item فارغ');
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => ComboSelectionPopup(
          product: product,
          combo: combo,
          sections: sections,
          onConfirm: (ComboSelectionResult result) {
            _handleComboSelection(product, result, posProvider);
          },
          onCancel: () {
            print('Combo selection cancelled');
          },
        ),
      );
      
    } catch (e) {
      print('Error showing combo selection popup: $e');
      
      if (!mounted) return;
      
      // Show error message and fallback to regular product addition
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل تفاصيل الكومبو: $e'),
          backgroundColor: Colors.orange,
        ),
      );
      
      _addProductToOrder(context, product, posProvider);
    }
  }

  /// Handle combo selection result
  void _handleComboSelection(ProductProduct product, ComboSelectionResult result, EnhancedPOSProvider posProvider) async {
    try {
      print('Handling combo selection for ${product.displayName}');
      print('Selected items: ${result.selectedItems.keys.join(', ')}');
      print('Total extra price: ${result.totalExtraPrice}');
      
      // Ensure there's an active order, create one if needed
      if (!posProvider.hasActiveOrder) {
        final session = posProvider.currentSession;
        final config = posProvider.selectedConfig;
        if (session == null || config == null) {
          throw Exception('No active session or config found');
        }
        
        final pricelistId = config.pricelistId ?? 1;
        print('📝 Creating order (combo) using pricelist_id: $pricelistId');
        
        final orderResult = await posProvider.backendService.orderManager.createOrder(
          session: session,
          pricelistId: pricelistId,
          partnerId: posProvider.selectedCustomer?.id,
        );
        if (!orderResult.success) {
          throw Exception(orderResult.error ?? 'Failed to create order');
        }
      }
      
      // Calculate the final price including combo base price and extra prices
      final basePrice = posProvider.getProductPrice(product, quantity: 1.0);
      final totalPrice = basePrice + result.totalExtraPrice;
      
      // Create combo description for order line
      final comboDescription = result.selectionDescription.isNotEmpty 
          ? ' (${result.selectionDescription})'
          : '';
      
      // Add the main combo product to the order with selected components info
      final orderResult = await posProvider.backendService.orderManager.addProductToOrder(
        product: product,
        quantity: 1.0,
        customPrice: totalPrice,
        attributeNames: [result.selectionDescription], // Use combo selections as attribute display
        attributeExtraPrices: [result.totalExtraPrice],
      );
      
      if (!orderResult.success) {
        throw Exception(orderResult.error ?? 'Failed to add combo to order');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة ${product.displayName}$comboDescription للطلب'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('Error handling combo selection: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إضافة الكومبو: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build product card with combo indicator
  Widget _buildProductCard({
    required ProductProduct product,
    required VoidCallback onTap,
    required VoidCallback onInfoTap,
    required EnhancedPOSProvider posProvider,
  }) {
    // Check if product is combo using both the provider (for testing) and the product itself
    final isCombo = product.isComboProduct || posProvider.isComboProduct(product);
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCombo ? Colors.orange.withOpacity(0.6) : Colors.grey.withOpacity(0.2),
            width: isCombo ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCombo 
                ? Colors.orange.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
              blurRadius: isCombo ? 12 : 8,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product image with improved styling
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      color: Colors.grey[50],
                    ),
                    child: product.image128 != null && product.image128!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.memory(
                              base64Decode(product.image128!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Icon(
                                    Icons.fastfood,
                                    size: 36,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Icon(
                              Icons.fastfood,
                              size: 36,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                  
                  // Combo indicator with improved design
                  if (isCombo)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange, Colors.orange.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.dining,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'COMBO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Information icon with improved styling
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onInfoTap,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Product details with improved layout
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name with better typography
                    Expanded(
                      child: Text(
                        product.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isCombo ? Colors.orange[800] : Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Price with improved styling
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCombo 
                            ? Colors.orange.withOpacity(0.1)
                            : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCombo 
                              ? Colors.orange.withOpacity(0.3)
                              : AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        currencyFormat.format(product.lstPrice),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isCombo ? Colors.orange[700] : AppTheme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle customer selection
  void _selectCustomer(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed('/customers');
    if (result != null && result is ResPartner) {
      // Handle the selected customer
      final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      posProvider.selectCustomer(result);
    }
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
          partnerId: posProvider.selectedCustomer?.id,
        );
        if (!orderResult.success) {
          throw Exception(orderResult.error ?? 'Failed to create order');
        }
      }
      
      // Calculate the correct price using current pricelist + extra prices from attributes
      final correctPrice = posProvider.getProductPrice(
        product, 
        quantity: quantity, 
        extraPrices: selectedAttributeExtraPrices,
      );
      
      // Add the product with attributes to the order
      final result = await posProvider.backendService.orderManager.addProductToOrder(
        product: product,
        quantity: quantity,
        customPrice: correctPrice,
        attributeNames: selectedAttributeNames,
        attributeExtraPrices: selectedAttributeExtraPrices,
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
          partnerId: posProvider.selectedCustomer?.id,
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
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '🔍 البحث عن المنتجات...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
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
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = posProvider.selectedCategoryName == category ||
                              (posProvider.selectedCategoryName.isEmpty && category == 'الكل');
                          
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: ChoiceChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
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
                              backgroundColor: Colors.grey[100],
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected 
                                      ? AppTheme.primaryColor.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              elevation: isSelected ? 4 : 1,
                              shadowColor: isSelected 
                                  ? AppTheme.primaryColor.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.1),
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
                        padding: const EdgeInsets.all(20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildProductCard(
                            product: product,
                            onTap: () => _showAttributeSelectionPopup(context, product, posProvider),
                            onInfoTap: () => _showProductInformation(context, product),
                            posProvider: posProvider,
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
            width: 420,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // Order summary
                Expanded(
                  flex: 2,
                  child: OrderSummary(),
                ),

                // Selected Customer Display
                Consumer<EnhancedPOSProvider>(
                  builder: (context, posProvider, _) {
                    final selectedCustomer = posProvider.selectedCustomer;
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer display
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedCustomer != null 
                                  ? AppTheme.primaryColor.withOpacity(0.08)
                                  : Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selectedCustomer != null 
                                    ? AppTheme.primaryColor.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selectedCustomer != null 
                                        ? AppTheme.primaryColor.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 20,
                                    color: selectedCustomer != null 
                                        ? AppTheme.primaryColor
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedCustomer?.name ?? 'لم يتم اختيار عميل',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: selectedCustomer != null 
                                              ? AppTheme.primaryColor
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      if (selectedCustomer?.phone != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          selectedCustomer!.phone!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selectedCustomer != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        posProvider.clearSelectedCustomer();
                                      },
                                      icon: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red[600],
                                      ),
                                      tooltip: 'إلغاء اختيار العميل',
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Customer and Actions buttons
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () => _selectCustomer(context),
                            icon: const Icon(
                              Icons.person_search,
                              size: 18,
                            ),
                            label: const Text(
                              'اختيار العميل',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                              foregroundColor: AppTheme.primaryColor,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                              foregroundColor: AppTheme.primaryColor,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Numpad
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: const NumpadWidget(),
                ),

                // Payment button
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  width: double.infinity,
                  child: Consumer<EnhancedPOSProvider>(
                    builder: (context, posProvider, _) {
                      final hasItems = posProvider.orderLines.isNotEmpty;
                      final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
                      
                      return Container(
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasItems 
                                ? [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)]
                                : [Colors.grey.shade400, Colors.grey.shade500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: hasItems ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.payment,
                                color: Colors.white,
                                size: 26,
                              ),
                              const SizedBox(width: 14),
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
                                size: 18,
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
                  Consumer<EnhancedPOSProvider>(
                    builder: (context, posProvider, _) {
                      final effectivePrice = posProvider.getProductPrice(product);
                      final hasDiscount = effectivePrice < product.lstPrice;
                      final hasIncrease = effectivePrice > product.lstPrice;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount) ...[
                            // Original price (crossed out) - only show for discounts
                            Text(
                              currencyFormat.format(product.lstPrice),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          // Effective price
                          Text(
                            currencyFormat.format(effectivePrice),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: hasDiscount 
                                  ? Colors.green 
                                  : hasIncrease 
                                      ? Colors.orange 
                                      : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Combo indicator badge
            Consumer<EnhancedPOSProvider>(
              builder: (context, posProvider, _) {
                final isCombo = posProvider.isComboProduct(product);
                if (!isCombo) return const SizedBox.shrink();
                
                return Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'COMBO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with improved styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ملخص الطلب',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Order items
              Expanded(
                child: orderLines.isEmpty
                    ? Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 48,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد عناصر في الطلب',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'قم بإضافة منتجات من القائمة',
                              style: TextStyle(
                                color: Colors.grey[500],
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: OrderItemCard(
                              orderLine: orderLine,
                              onRemove: () => posProvider.removeOrderLine(index),
                              onQuantityChanged: (quantity) =>
                                  posProvider.updateOrderLineQuantity(index, quantity),
                            ),
                          );
                        },
                      ),
              ),

              // Order totals with improved styling
              if (orderLines.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المجموع الفرعي:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            currencyFormat.format(posProvider.subtotal),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الضرائب:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            currencyFormat.format(posProvider.taxAmount),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الإجمالي:',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
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
                  ),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product info section
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name (compact)
                  Text(
                    orderLine.displayNameWithAttributes,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Price per unit (compact)
                  Text(
                    '${currencyFormat.format(orderLine.priceUnit ?? 0)} / وحدة',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity controls (compact)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Decrease button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final newQty = (orderLine.qty ?? 1) - 1;
                        if (newQty > 0) {
                          onQuantityChanged(newQty);
                        }
                      },
                      icon: Icon(
                        Icons.remove,
                        color: Colors.red[600],
                        size: 16,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  
                  // Quantity display
                  Container(
                    width: 36,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      (orderLine.qty ?? 1).toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  // Increase button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final newQty = (orderLine.qty ?? 1) + 1;
                        onQuantityChanged(newQty);
                      },
                      icon: Icon(
                        Icons.add,
                        color: Colors.green[600],
                        size: 16,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Total price and remove button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Total price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    currencyFormat.format(orderLine.priceSubtotal ?? 0),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // Remove button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close,
                      color: Colors.red[600],
                      size: 16,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: 'حذف العنصر',
                    padding: EdgeInsets.zero,
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
