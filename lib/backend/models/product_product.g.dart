// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductProduct _$ProductProductFromJson(Map<String, dynamic> json) =>
    ProductProduct(
      id: (json['id'] as num).toInt(),
      productTmplId: _extractIdFromArray(json['product_tmpl_id']),
      defaultCode: _extractNullableString(json['default_code']),
      barcode: _extractNullableString(json['barcode']),
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
      image128: _extractNullableString(json['image_128']),
      productTemplateVariantValueIds:
          (json['product_template_variant_value_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      comboIds:
          (json['combo_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      packagingIds:
          (json['packaging_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      sellerIds:
          (json['seller_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      taxesId:
          (json['taxes_id'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      posCategIds:
          (json['pos_categ_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProductProductToJson(
  ProductProduct instance,
) => <String, dynamic>{
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
  'image_128': instance.image128,
  'product_template_variant_value_ids': instance.productTemplateVariantValueIds,
  'combo_ids': instance.comboIds,
  'packaging_ids': instance.packagingIds,
  'seller_ids': instance.sellerIds,
  'taxes_id': instance.taxesId,
  'pos_categ_ids': instance.posCategIds,
};
