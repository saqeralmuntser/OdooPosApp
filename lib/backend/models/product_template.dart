import 'package:json_annotation/json_annotation.dart';

part 'product_template.g.dart';

/// product.template - Product Template
/// Core product template with all attributes and configurations
@JsonSerializable()
class ProductTemplate {
  final int id;
  final String name;
  @JsonKey(name: 'default_code')
  final String? defaultCode;
  final String? barcode;
  final int sequence;
  final String? description;
  @JsonKey(name: 'description_sale')
  final String? descriptionSale;
  @JsonKey(name: 'public_description')
  final String? publicDescription;
  
  // POS Settings
  @JsonKey(name: 'available_in_pos')
  final bool availableInPos;
  @JsonKey(name: 'to_weight')
  final bool toWeight;
  final int? color;
  
  // Pricing and Costs
  @JsonKey(name: 'list_price')
  final double listPrice;
  @JsonKey(name: 'standard_price')
  final double standardPrice;
  @JsonKey(name: 'currency_id')
  final int currencyId;
  
  // Product Settings
  @JsonKey(name: 'sale_ok')
  final bool saleOk;
  @JsonKey(name: 'purchase_ok')
  final bool purchaseOk;
  final bool active;
  @JsonKey(name: 'can_be_expensed')
  final bool canBeExpensed;
  
  // Units and Measurements
  @JsonKey(name: 'uom_id')
  final int uomId;
  @JsonKey(name: 'uom_po_id')
  final int uomPoId;
  final double weight;
  final double volume;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'categ_id')
  final int categId;
  @JsonKey(name: 'pos_categ_ids')
  final List<int> posCategIds;
  @JsonKey(name: 'taxes_id')
  final List<int> taxesId;
  @JsonKey(name: 'supplier_taxes_id')
  final List<int> supplierTaxesId;
  @JsonKey(name: 'product_variant_ids')
  final List<int> productVariantIds;
  @JsonKey(name: 'attribute_line_ids')
  final List<int> attributeLineIds;
  @JsonKey(name: 'product_tag_ids')
  final List<int> productTagIds;
  @JsonKey(name: 'route_ids')
  final List<int> routeIds;

  ProductTemplate({
    required this.id,
    required this.name,
    this.defaultCode,
    this.barcode,
    this.sequence = 0,
    this.description,
    this.descriptionSale,
    this.publicDescription,
    this.availableInPos = false,
    this.toWeight = false,
    this.color,
    required this.listPrice,
    required this.standardPrice,
    required this.currencyId,
    this.saleOk = true,
    this.purchaseOk = true,
    this.active = true,
    this.canBeExpensed = false,
    required this.uomId,
    required this.uomPoId,
    this.weight = 0.0,
    this.volume = 0.0,
    required this.categId,
    this.posCategIds = const [],
    this.taxesId = const [],
    this.supplierTaxesId = const [],
    this.productVariantIds = const [],
    this.attributeLineIds = const [],
    this.productTagIds = const [],
    this.routeIds = const [],
  });

  factory ProductTemplate.fromJson(Map<String, dynamic> json) => _$ProductTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$ProductTemplateToJson(this);

  /// Calculate VAT amount based on tax rate
  double calculateVatAmount(double taxRate) => listPrice * taxRate;

  /// Get price including VAT
  double getPriceIncludingVat(double taxRate) => listPrice + calculateVatAmount(taxRate);

  /// Check if product has variants
  bool get hasVariants => productVariantIds.length > 1;

  /// Check if product has attributes
  bool get hasAttributes => attributeLineIds.isNotEmpty;

  ProductTemplate copyWith({
    int? id,
    String? name,
    String? defaultCode,
    String? barcode,
    int? sequence,
    String? description,
    String? descriptionSale,
    String? publicDescription,
    bool? availableInPos,
    bool? toWeight,
    int? color,
    double? listPrice,
    double? standardPrice,
    int? currencyId,
    bool? saleOk,
    bool? purchaseOk,
    bool? active,
    bool? canBeExpensed,
    int? uomId,
    int? uomPoId,
    double? weight,
    double? volume,
    int? categId,
    List<int>? posCategIds,
    List<int>? taxesId,
    List<int>? supplierTaxesId,
    List<int>? productVariantIds,
    List<int>? attributeLineIds,
    List<int>? productTagIds,
    List<int>? routeIds,
  }) {
    return ProductTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultCode: defaultCode ?? this.defaultCode,
      barcode: barcode ?? this.barcode,
      sequence: sequence ?? this.sequence,
      description: description ?? this.description,
      descriptionSale: descriptionSale ?? this.descriptionSale,
      publicDescription: publicDescription ?? this.publicDescription,
      availableInPos: availableInPos ?? this.availableInPos,
      toWeight: toWeight ?? this.toWeight,
      color: color ?? this.color,
      listPrice: listPrice ?? this.listPrice,
      standardPrice: standardPrice ?? this.standardPrice,
      currencyId: currencyId ?? this.currencyId,
      saleOk: saleOk ?? this.saleOk,
      purchaseOk: purchaseOk ?? this.purchaseOk,
      active: active ?? this.active,
      canBeExpensed: canBeExpensed ?? this.canBeExpensed,
      uomId: uomId ?? this.uomId,
      uomPoId: uomPoId ?? this.uomPoId,
      weight: weight ?? this.weight,
      volume: volume ?? this.volume,
      categId: categId ?? this.categId,
      posCategIds: posCategIds ?? this.posCategIds,
      taxesId: taxesId ?? this.taxesId,
      supplierTaxesId: supplierTaxesId ?? this.supplierTaxesId,
      productVariantIds: productVariantIds ?? this.productVariantIds,
      attributeLineIds: attributeLineIds ?? this.attributeLineIds,
      productTagIds: productTagIds ?? this.productTagIds,
      routeIds: routeIds ?? this.routeIds,
    );
  }
}
