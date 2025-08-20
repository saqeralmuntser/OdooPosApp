import '../models/product_product.dart';
import '../models/product_pricelist.dart';
import '../models/product_pricelist_item.dart';
import '../models/pos_category.dart';

/// Pricing Service
/// Handles price calculations based on pricelists following Odoo's pricing logic
class PricingService {
  static final PricingService _instance = PricingService._internal();
  factory PricingService() => _instance;
  PricingService._internal();

  /// Calculate the price for a product using the specified pricelist
  /// Returns the calculated price or the product's list price if no applicable rule is found
  double calculateProductPrice({
    required ProductProduct product,
    required ProductPricelist pricelist,
    required List<ProductPricelistItem> pricelistItems,
    double quantity = 1.0,
    DateTime? currentDate,
    List<POSCategory>? categories,
  }) {
    // Find applicable pricelist items for this product
    final relevantItems = pricelistItems.where((item) => item.pricelistId == pricelist.id).toList();
    
    final applicableItems = _findApplicableItems(
      product: product,
      pricelistItems: relevantItems,
      quantity: quantity,
      currentDate: currentDate,
      categories: categories,
    );

    if (applicableItems.isEmpty) {
      // No applicable rules found, return the product's list price
      return product.lstPrice;
    }

    // Get the most specific applicable item (higher priority)
    final bestItem = _getBestPricelistItem(applicableItems);
    
    // Calculate the base price according to the item's base setting
    double basePrice = _getBasePrice(
      product: product,
      pricelistItem: bestItem,
      pricelist: pricelist,
      pricelistItems: pricelistItems,
      quantity: quantity,
      currentDate: currentDate,
      categories: categories,
    );

    // Apply the pricing computation
    return bestItem.calculatePrice(
      basePrice: basePrice,
      quantity: quantity,
    );
  }

  /// Calculate prices for a product across multiple pricelists
  Map<int, double> calculateProductPricesForPricelists({
    required ProductProduct product,
    required List<ProductPricelist> pricelists,
    required List<ProductPricelistItem> pricelistItems,
    double quantity = 1.0,
    DateTime? currentDate,
    List<POSCategory>? categories,
  }) {
    final Map<int, double> pricesByPricelist = {};
    
    for (final pricelist in pricelists) {
      pricesByPricelist[pricelist.id] = calculateProductPrice(
        product: product,
        pricelist: pricelist,
        pricelistItems: pricelistItems,
        quantity: quantity,
        currentDate: currentDate,
        categories: categories,
      );
    }
    
    return pricesByPricelist;
  }

  /// Find all applicable pricelist items for a product
  List<ProductPricelistItem> _findApplicableItems({
    required ProductProduct product,
    required List<ProductPricelistItem> pricelistItems,
    double quantity = 1.0,
    DateTime? currentDate,
    List<POSCategory>? categories,
  }) {
    final applicableItems = <ProductPricelistItem>[];
    
    // Get product categories for category-based rules
    final productCategories = categories?.where((cat) => 
      product.posCategIds.contains(cat.id)
    ).toList() ?? [];
    
    for (final item in pricelistItems) {
      // Check if this item is applicable for the product
      bool isApplicable = false;
      
      switch (item.appliedOn) {
        case '3_global':
          // Global rule - applies to all products
          isApplicable = true;
          break;
        case '2_product_category':
          // Category-based rule
          if (item.categId != null) {
            isApplicable = productCategories.any((cat) => cat.id == item.categId);
          }
          break;
        case '1_product':
          // Product template rule
          isApplicable = item.productTmplId == product.productTmplId;
          break;
        case '0_product_variant':
          // Product variant rule (most specific)
          isApplicable = item.productId == product.id;
          break;
      }
      
      if (isApplicable && item.isApplicableFor(
        productId: product.id,
        productTmplId: product.productTmplId,
        categId: productCategories.isNotEmpty ? productCategories.first.id : null,
        quantity: quantity,
        currentDate: currentDate,
      )) {
        applicableItems.add(item);
      }
    }
    
    return applicableItems;
  }

  /// Get the best (most specific) pricelist item from applicable items
  /// Priority order: 0_product_variant > 1_product > 2_product_category > 3_global
  ProductPricelistItem _getBestPricelistItem(List<ProductPricelistItem> applicableItems) {
    // Sort by specificity (applied_on) and then by minimum quantity (higher quantity = more specific)
    applicableItems.sort((a, b) {
      // First, sort by applied_on priority
      final aPriority = _getAppliedOnPriority(a.appliedOn);
      final bPriority = _getAppliedOnPriority(b.appliedOn);
      
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      
      // If same applied_on, prefer higher minimum quantity
      return b.minQuantity.compareTo(a.minQuantity);
    });
    
    return applicableItems.first;
  }

  /// Get priority value for applied_on field (lower = higher priority)
  int _getAppliedOnPriority(String appliedOn) {
    switch (appliedOn) {
      case '0_product_variant':
        return 0; // Highest priority
      case '1_product':
        return 1;
      case '2_product_category':
        return 2;
      case '3_global':
        return 3; // Lowest priority
      default:
        return 999;
    }
  }

  /// Get the base price for price calculation according to the item's base setting
  double _getBasePrice({
    required ProductProduct product,
    required ProductPricelistItem pricelistItem,
    required ProductPricelist pricelist,
    required List<ProductPricelistItem> pricelistItems,
    double quantity = 1.0,
    DateTime? currentDate,
    List<POSCategory>? categories,
  }) {
    switch (pricelistItem.base) {
      case 'list_price':
        return product.lstPrice;
      case 'standard_price':
        return product.standardPrice;
      case 'pricelist':
        // Recursive pricelist calculation
        if (pricelistItem.basePricelistId != null) {
          final basePricelist = ProductPricelist(
            id: pricelistItem.basePricelistId!,
            name: 'Base Pricelist',
            displayName: 'Base Pricelist',
            currencyId: pricelist.currencyId,
          );
          return calculateProductPrice(
            product: product,
            pricelist: basePricelist,
            pricelistItems: pricelistItems,
            quantity: quantity,
            currentDate: currentDate,
            categories: categories,
          );
        }
        return product.lstPrice;
      default:
        return product.lstPrice;
    }
  }

  /// Get product category IDs that are relevant for pricing
  List<int> getProductCategoryIds(ProductProduct product, List<POSCategory> categories) {
    return categories
        .where((cat) => product.posCategIds.contains(cat.id))
        .map((cat) => cat.id)
        .toList();
  }

  /// Check if a pricelist item is currently valid based on date constraints
  bool isItemDateValid(ProductPricelistItem item, DateTime? currentDate) {
    final now = currentDate ?? DateTime.now();
    
    if (item.dateStart != null && now.isBefore(item.dateStart!)) {
      return false;
    }
    
    if (item.dateEnd != null && now.isAfter(item.dateEnd!)) {
      return false;
    }
    
    return true;
  }

  /// Get all valid pricelist items for a specific pricelist
  List<ProductPricelistItem> getValidItemsForPricelist({
    required int pricelistId,
    required List<ProductPricelistItem> allItems,
    DateTime? currentDate,
  }) {
    return allItems
        .where((item) => 
          item.pricelistId == pricelistId && 
          isItemDateValid(item, currentDate)
        )
        .toList();
  }

  /// Calculate discount percentage for display purposes
  double calculateDiscountPercentage({
    required double originalPrice,
    required double discountedPrice,
  }) {
    if (originalPrice <= 0) return 0.0;
    return ((originalPrice - discountedPrice) / originalPrice) * 100;
  }

  /// Format price according to currency settings
  String formatPrice(double price, {int decimals = 2}) {
    return price.toStringAsFixed(decimals);
  }
}
