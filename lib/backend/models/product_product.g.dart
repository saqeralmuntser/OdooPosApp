// GENERATED CODE - DO NOT MODIFY BY HAND
// Simplified version for demo purposes

part of 'product_product.dart';

// TODO: Run 'dart run build_runner build' to generate proper serialization

ProductProduct _$ProductProductFromJson(Map<String, dynamic> json) {
  return ProductProduct(
    id: json['id'] as int,
    productTmplId: json['product_tmpl_id'] as int,
    defaultCode: json['default_code'] as String?,
    barcode: json['barcode'] as String?,
    active: json['active'] as bool? ?? true,
    lstPrice: (json['lst_price'] as num).toDouble(),
    standardPrice: (json['standard_price'] as num).toDouble(),
    priceExtra: (json['price_extra'] as num?)?.toDouble() ?? 0.0,
    qtyAvailable: (json['qty_available'] as num?)?.toDouble() ?? 0.0,
    virtualAvailable: (json['virtual_available'] as num?)?.toDouble() ?? 0.0,
    incomingQty: (json['incoming_qty'] as num?)?.toDouble() ?? 0.0,
    outgoingQty: (json['outgoing_qty'] as num?)?.toDouble() ?? 0.0,
    freeQty: (json['free_qty'] as num?)?.toDouble() ?? 0.0,
    displayName: json['display_name'] as String,
    productTemplateVariantValueIds: (json['product_template_variant_value_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    comboIds: (json['combo_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    packagingIds: (json['packaging_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    sellerIds: (json['seller_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
  );
}

Map<String, dynamic> _$ProductProductToJson(ProductProduct instance) => <String, dynamic>{
      'id': instance.id,
      'product_tmpl_id': instance.productTmplId,
      'default_code': instance.defaultCode,
      'barcode': instance.barcode,
      'active': instance.active,
      'lst_price': instance.lstPrice,
      'standard_price': instance.standardPrice,
      'price_extra': instance.priceExtra,
      'qty_available': instance.qtyAvailable,
      'virtual_available': instance.virtualAvailable,
      'incoming_qty': instance.incomingQty,
      'outgoing_qty': instance.outgoingQty,
      'free_qty': instance.freeQty,
      'display_name': instance.displayName,
      'product_template_variant_value_ids': instance.productTemplateVariantValueIds,
      'combo_ids': instance.comboIds,
      'packaging_ids': instance.packagingIds,
      'seller_ids': instance.sellerIds,
    };