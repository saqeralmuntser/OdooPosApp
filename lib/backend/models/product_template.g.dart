// GENERATED CODE - DO NOT MODIFY BY HAND
// Simplified version for demo purposes

part of 'product_template.dart';

// TODO: Run 'dart run build_runner build' to generate proper serialization

ProductTemplate _$ProductTemplateFromJson(Map<String, dynamic> json) {
  return ProductTemplate(
    id: json['id'] as int,
    name: json['name'] as String,
    defaultCode: json['default_code'] as String?,
    barcode: json['barcode'] as String?,
    sequence: json['sequence'] as int? ?? 0,
    description: json['description'] as String?,
    descriptionSale: json['description_sale'] as String?,
    publicDescription: json['public_description'] as String?,
    availableInPos: json['available_in_pos'] as bool? ?? false,
    toWeight: json['to_weight'] as bool? ?? false,
    color: json['color'] as int?,
    listPrice: (json['list_price'] as num).toDouble(),
    standardPrice: (json['standard_price'] as num).toDouble(),
    currencyId: json['currency_id'] as int,
    saleOk: json['sale_ok'] as bool? ?? true,
    purchaseOk: json['purchase_ok'] as bool? ?? true,
    active: json['active'] as bool? ?? true,
    canBeExpensed: json['can_be_expensed'] as bool? ?? false,
    uomId: json['uom_id'] as int,
    uomPoId: json['uom_po_id'] as int,
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    categId: json['categ_id'] as int,
    posCategIds: (json['pos_categ_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    taxesId: (json['taxes_id'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    supplierTaxesId: (json['supplier_taxes_id'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    productVariantIds: (json['product_variant_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    attributeLineIds: (json['attribute_line_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    productTagIds: (json['product_tag_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    routeIds: (json['route_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
  );
}

Map<String, dynamic> _$ProductTemplateToJson(ProductTemplate instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'default_code': instance.defaultCode,
      'barcode': instance.barcode,
      'sequence': instance.sequence,
      'description': instance.description,
      'description_sale': instance.descriptionSale,
      'public_description': instance.publicDescription,
      'available_in_pos': instance.availableInPos,
      'to_weight': instance.toWeight,
      'color': instance.color,
      'list_price': instance.listPrice,
      'standard_price': instance.standardPrice,
      'currency_id': instance.currencyId,
      'sale_ok': instance.saleOk,
      'purchase_ok': instance.purchaseOk,
      'active': instance.active,
      'can_be_expensed': instance.canBeExpensed,
      'uom_id': instance.uomId,
      'uom_po_id': instance.uomPoId,
      'weight': instance.weight,
      'volume': instance.volume,
      'categ_id': instance.categId,
      'pos_categ_ids': instance.posCategIds,
      'taxes_id': instance.taxesId,
      'supplier_taxes_id': instance.supplierTaxesId,
      'product_variant_ids': instance.productVariantIds,
      'attribute_line_ids': instance.attributeLineIds,
      'product_tag_ids': instance.productTagIds,
      'route_ids': instance.routeIds,
    };