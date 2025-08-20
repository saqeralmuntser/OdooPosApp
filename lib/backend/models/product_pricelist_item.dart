import 'package:json_annotation/json_annotation.dart';

part 'product_pricelist_item.g.dart';

/// Helper function to extract ID from Odoo array format [id, name]
int _extractIdFromArray(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  }
  throw FormatException('Invalid ID format: $value');
}

/// Helper function to extract nullable ID from Odoo array format
int? _extractNullableIdFromArray(dynamic value) {
  if (value == false || value == null) {
    return null;
  }
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  }
  return null;
}



/// Helper function to handle nullable DateTime values from Odoo
DateTime? _extractNullableDateTimeFromOdoo(dynamic value) {
  if (value == false || value == null) {
    return null;
  }
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

/// Helper function to handle nullable double values from Odoo
double? _extractNullableDoubleFromOdoo(dynamic value) {
  if (value == false || value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

/// Helper function to handle required double values from Odoo
double _extractDoubleFromOdoo(dynamic value) {
  if (value == false || value == null) {
    return 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      return 0.0;
    }
  }
  return 0.0;
}

/// product.pricelist.item - Product Pricelist Item
/// Represents pricing rules for specific products or categories within a pricelist
@JsonSerializable()
class ProductPricelistItem {
  final int id;
  @JsonKey(name: 'pricelist_id', fromJson: _extractIdFromArray)
  final int pricelistId;
  
  // Product/Category targeting
  @JsonKey(name: 'product_tmpl_id', fromJson: _extractNullableIdFromArray)
  final int? productTmplId;
  @JsonKey(name: 'product_id', fromJson: _extractNullableIdFromArray)
  final int? productId;
  @JsonKey(name: 'categ_id', fromJson: _extractNullableIdFromArray)
  final int? categId;
  
  // Application rules
  @JsonKey(name: 'applied_on')
  final String appliedOn; // '3_global', '2_product_category', '1_product', '0_product_variant'
  @JsonKey(name: 'min_quantity', fromJson: _extractDoubleFromOdoo)
  final double minQuantity;
  
  // Pricing computation
  @JsonKey(name: 'compute_price')
  final String computePrice; // 'fixed', 'percentage', 'formula'
  @JsonKey(name: 'fixed_price', fromJson: _extractNullableDoubleFromOdoo)
  final double? fixedPrice;
  @JsonKey(name: 'percent_price', fromJson: _extractNullableDoubleFromOdoo)
  final double? percentPrice;
  @JsonKey(name: 'price_discount', fromJson: _extractNullableDoubleFromOdoo)
  final double? priceDiscount;
  @JsonKey(name: 'price_round', fromJson: _extractNullableDoubleFromOdoo)
  final double? priceRound;
  @JsonKey(name: 'price_surcharge', fromJson: _extractNullableDoubleFromOdoo)
  final double? priceSurcharge;
  @JsonKey(name: 'price_min_margin', fromJson: _extractNullableDoubleFromOdoo)
  final double? priceMinMargin;
  @JsonKey(name: 'price_max_margin', fromJson: _extractNullableDoubleFromOdoo)
  final double? priceMaxMargin;
  
  // Base price calculation
  final String base; // 'list_price', 'standard_price', 'pricelist'
  @JsonKey(name: 'base_pricelist_id', fromJson: _extractNullableIdFromArray)
  final int? basePricelistId;
  
  // Date validity
  @JsonKey(name: 'date_start', fromJson: _extractNullableDateTimeFromOdoo)
  final DateTime? dateStart;
  @JsonKey(name: 'date_end', fromJson: _extractNullableDateTimeFromOdoo)
  final DateTime? dateEnd;
  
  // Company and Currency
  @JsonKey(name: 'company_id', fromJson: _extractNullableIdFromArray)
  final int? companyId;
  @JsonKey(name: 'currency_id', fromJson: _extractNullableIdFromArray)
  final int? currencyId;

  ProductPricelistItem({
    required this.id,
    required this.pricelistId,
    this.productTmplId,
    this.productId,
    this.categId,
    this.appliedOn = '3_global',
    this.minQuantity = 0.0,
    this.computePrice = 'fixed',
    this.fixedPrice,
    this.percentPrice,
    this.priceDiscount,
    this.priceRound,
    this.priceSurcharge,
    this.priceMinMargin,
    this.priceMaxMargin,
    this.base = 'list_price',
    this.basePricelistId,
    this.dateStart,
    this.dateEnd,
    this.companyId,
    this.currencyId,
  });

  factory ProductPricelistItem.fromJson(Map<String, dynamic> json) => _$ProductPricelistItemFromJson(json);
  Map<String, dynamic> toJson() => _$ProductPricelistItemToJson(this);

  /// Check if this item is applicable for the given product and quantity
  bool isApplicableFor({
    int? productId,
    int? productTmplId,
    int? categId,
    double quantity = 1.0,
    DateTime? currentDate,
  }) {
    // Check quantity
    if (quantity < minQuantity) return false;
    
    // Check date validity
    final now = currentDate ?? DateTime.now();
    if (dateStart != null && now.isBefore(dateStart!)) return false;
    if (dateEnd != null && now.isAfter(dateEnd!)) return false;
    
    // Check product/category applicability
    switch (appliedOn) {
      case '3_global':
        return true;
      case '2_product_category':
        return this.categId == categId;
      case '1_product':
        return this.productTmplId == productTmplId;
      case '0_product_variant':
        return this.productId == productId;
      default:
        return false;
    }
  }

  /// Calculate the final price based on this item's rules
  double calculatePrice({
    required double basePrice,
    double quantity = 1.0,
  }) {
    double finalPrice = basePrice;
    
    switch (computePrice) {
      case 'fixed':
        if (fixedPrice != null) {
          finalPrice = fixedPrice!;
        }
        break;
      case 'percentage':
        if (percentPrice != null) {
          finalPrice = basePrice * (percentPrice! / 100);
        }
        break;
      case 'formula':
        // Apply discount
        if (priceDiscount != null) {
          finalPrice = basePrice * (1 - (priceDiscount! / 100));
        }
        // Apply surcharge
        if (priceSurcharge != null) {
          finalPrice += priceSurcharge!;
        }
        break;
    }
    
    // Apply rounding
    if (priceRound != null && priceRound! > 0) {
      finalPrice = (finalPrice / priceRound!).round() * priceRound!;
    }
    
    // Apply margin constraints (only if margin values are > 0)
    if (priceMinMargin != null && priceMinMargin! > 0 && finalPrice < basePrice + priceMinMargin!) {
      finalPrice = basePrice + priceMinMargin!;
    }
    if (priceMaxMargin != null && priceMaxMargin! > 0 && finalPrice > basePrice + priceMaxMargin!) {
      finalPrice = basePrice + priceMaxMargin!;
    }
    
    return finalPrice;
  }

  ProductPricelistItem copyWith({
    int? id,
    int? pricelistId,
    int? productTmplId,
    int? productId,
    int? categId,
    String? appliedOn,
    double? minQuantity,
    String? computePrice,
    double? fixedPrice,
    double? percentPrice,
    double? priceDiscount,
    double? priceRound,
    double? priceSurcharge,
    double? priceMinMargin,
    double? priceMaxMargin,
    String? base,
    int? basePricelistId,
    DateTime? dateStart,
    DateTime? dateEnd,
    int? companyId,
    int? currencyId,
  }) {
    return ProductPricelistItem(
      id: id ?? this.id,
      pricelistId: pricelistId ?? this.pricelistId,
      productTmplId: productTmplId ?? this.productTmplId,
      productId: productId ?? this.productId,
      categId: categId ?? this.categId,
      appliedOn: appliedOn ?? this.appliedOn,
      minQuantity: minQuantity ?? this.minQuantity,
      computePrice: computePrice ?? this.computePrice,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      percentPrice: percentPrice ?? this.percentPrice,
      priceDiscount: priceDiscount ?? this.priceDiscount,
      priceRound: priceRound ?? this.priceRound,
      priceSurcharge: priceSurcharge ?? this.priceSurcharge,
      priceMinMargin: priceMinMargin ?? this.priceMinMargin,
      priceMaxMargin: priceMaxMargin ?? this.priceMaxMargin,
      base: base ?? this.base,
      basePricelistId: basePricelistId ?? this.basePricelistId,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      companyId: companyId ?? this.companyId,
      currencyId: currencyId ?? this.currencyId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductPricelistItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProductPricelistItem(id: $id, pricelistId: $pricelistId, appliedOn: $appliedOn)';
}
