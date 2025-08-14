import 'package:json_annotation/json_annotation.dart';

part 'product_product.g.dart';

/// product.product - Product Variant
/// Specific variant of a product template with stock and pricing information
@JsonSerializable()
class ProductProduct {
  final int id;
  @JsonKey(name: 'product_tmpl_id')
  final int productTmplId;
  @JsonKey(name: 'default_code')
  final String? defaultCode;
  final String? barcode;
  final bool active;
  
  // Calculated Pricing
  @JsonKey(name: 'lst_price')
  final double lstPrice;
  @JsonKey(name: 'standard_price')
  final double standardPrice;
  @JsonKey(name: 'price_extra')
  final double priceExtra;
  
  // Stock Information
  @JsonKey(name: 'qty_available')
  final double qtyAvailable;
  @JsonKey(name: 'virtual_available')
  final double virtualAvailable;
  @JsonKey(name: 'incoming_qty')
  final double incomingQty;
  @JsonKey(name: 'outgoing_qty')
  final double outgoingQty;
  @JsonKey(name: 'free_qty')
  final double freeQty;
  
  // Display name for the product
  @JsonKey(name: 'display_name')
  final String displayName;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'product_template_variant_value_ids')
  final List<int> productTemplateVariantValueIds;
  @JsonKey(name: 'combo_ids')
  final List<int> comboIds;
  @JsonKey(name: 'packaging_ids')
  final List<int> packagingIds;
  @JsonKey(name: 'seller_ids')
  final List<int> sellerIds;

  ProductProduct({
    required this.id,
    required this.productTmplId,
    this.defaultCode,
    this.barcode,
    this.active = true,
    required this.lstPrice,
    required this.standardPrice,
    this.priceExtra = 0.0,
    this.qtyAvailable = 0.0,
    this.virtualAvailable = 0.0,
    this.incomingQty = 0.0,
    this.outgoingQty = 0.0,
    this.freeQty = 0.0,
    required this.displayName,
    this.productTemplateVariantValueIds = const [],
    this.comboIds = const [],
    this.packagingIds = const [],
    this.sellerIds = const [],
  });

  factory ProductProduct.fromJson(Map<String, dynamic> json) => _$ProductProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductProductToJson(this);

  /// Final price including extra costs from variants
  double get finalPrice => lstPrice + priceExtra;

  /// Check if product is in stock
  bool get isInStock => qtyAvailable > 0;

  /// Check if product has low stock (less than 5 units)
  bool get hasLowStock => qtyAvailable > 0 && qtyAvailable < 5;

  /// Check if product is out of stock
  bool get isOutOfStock => qtyAvailable <= 0;

  /// Get stock status
  ProductStockStatus get stockStatus {
    if (qtyAvailable <= 0) return ProductStockStatus.outOfStock;
    if (qtyAvailable < 5) return ProductStockStatus.lowStock;
    return ProductStockStatus.inStock;
  }

  /// Check if product has variants
  bool get hasVariants => productTemplateVariantValueIds.isNotEmpty;

  /// Check if product is part of combos
  bool get isPartOfCombos => comboIds.isNotEmpty;

  ProductProduct copyWith({
    int? id,
    int? productTmplId,
    String? defaultCode,
    String? barcode,
    bool? active,
    double? lstPrice,
    double? standardPrice,
    double? priceExtra,
    double? qtyAvailable,
    double? virtualAvailable,
    double? incomingQty,
    double? outgoingQty,
    double? freeQty,
    String? displayName,
    List<int>? productTemplateVariantValueIds,
    List<int>? comboIds,
    List<int>? packagingIds,
    List<int>? sellerIds,
  }) {
    return ProductProduct(
      id: id ?? this.id,
      productTmplId: productTmplId ?? this.productTmplId,
      defaultCode: defaultCode ?? this.defaultCode,
      barcode: barcode ?? this.barcode,
      active: active ?? this.active,
      lstPrice: lstPrice ?? this.lstPrice,
      standardPrice: standardPrice ?? this.standardPrice,
      priceExtra: priceExtra ?? this.priceExtra,
      qtyAvailable: qtyAvailable ?? this.qtyAvailable,
      virtualAvailable: virtualAvailable ?? this.virtualAvailable,
      incomingQty: incomingQty ?? this.incomingQty,
      outgoingQty: outgoingQty ?? this.outgoingQty,
      freeQty: freeQty ?? this.freeQty,
      displayName: displayName ?? this.displayName,
      productTemplateVariantValueIds: productTemplateVariantValueIds ?? this.productTemplateVariantValueIds,
      comboIds: comboIds ?? this.comboIds,
      packagingIds: packagingIds ?? this.packagingIds,
      sellerIds: sellerIds ?? this.sellerIds,
    );
  }
}

/// Product stock status enumeration
enum ProductStockStatus {
  inStock,
  lowStock,
  outOfStock,
}

/// Extension for ProductStockStatus
extension ProductStockStatusExtension on ProductStockStatus {
  String get displayName {
    switch (this) {
      case ProductStockStatus.inStock:
        return 'In Stock';
      case ProductStockStatus.lowStock:
        return 'Low Stock';
      case ProductStockStatus.outOfStock:
        return 'Out of Stock';
    }
  }

  String get colorCode {
    switch (this) {
      case ProductStockStatus.inStock:
        return '#4CAF50'; // Green
      case ProductStockStatus.lowStock:
        return '#FF9800'; // Orange
      case ProductStockStatus.outOfStock:
        return '#F44336'; // Red
    }
  }
}
