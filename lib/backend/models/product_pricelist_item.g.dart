// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_pricelist_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductPricelistItem _$ProductPricelistItemFromJson(
  Map<String, dynamic> json,
) => ProductPricelistItem(
  id: (json['id'] as num).toInt(),
  pricelistId: _extractIdFromArray(json['pricelist_id']),
  productTmplId: _extractNullableIdFromArray(json['product_tmpl_id']),
  productId: _extractNullableIdFromArray(json['product_id']),
  categId: _extractNullableIdFromArray(json['categ_id']),
  appliedOn: json['applied_on'] as String? ?? '3_global',
  minQuantity: json['min_quantity'] == null
      ? 0.0
      : _extractDoubleFromOdoo(json['min_quantity']),
  computePrice: json['compute_price'] as String? ?? 'fixed',
  fixedPrice: _extractNullableDoubleFromOdoo(json['fixed_price']),
  percentPrice: _extractNullableDoubleFromOdoo(json['percent_price']),
  priceDiscount: _extractNullableDoubleFromOdoo(json['price_discount']),
  priceRound: _extractNullableDoubleFromOdoo(json['price_round']),
  priceSurcharge: _extractNullableDoubleFromOdoo(json['price_surcharge']),
  priceMinMargin: _extractNullableDoubleFromOdoo(json['price_min_margin']),
  priceMaxMargin: _extractNullableDoubleFromOdoo(json['price_max_margin']),
  base: json['base'] as String? ?? 'list_price',
  basePricelistId: _extractNullableIdFromArray(json['base_pricelist_id']),
  dateStart: _extractNullableDateTimeFromOdoo(json['date_start']),
  dateEnd: _extractNullableDateTimeFromOdoo(json['date_end']),
  companyId: _extractNullableIdFromArray(json['company_id']),
  currencyId: _extractNullableIdFromArray(json['currency_id']),
);

Map<String, dynamic> _$ProductPricelistItemToJson(
  ProductPricelistItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'pricelist_id': instance.pricelistId,
  'product_tmpl_id': instance.productTmplId,
  'product_id': instance.productId,
  'categ_id': instance.categId,
  'applied_on': instance.appliedOn,
  'min_quantity': instance.minQuantity,
  'compute_price': instance.computePrice,
  'fixed_price': instance.fixedPrice,
  'percent_price': instance.percentPrice,
  'price_discount': instance.priceDiscount,
  'price_round': instance.priceRound,
  'price_surcharge': instance.priceSurcharge,
  'price_min_margin': instance.priceMinMargin,
  'price_max_margin': instance.priceMaxMargin,
  'base': instance.base,
  'base_pricelist_id': instance.basePricelistId,
  'date_start': instance.dateStart?.toIso8601String(),
  'date_end': instance.dateEnd?.toIso8601String(),
  'company_id': instance.companyId,
  'currency_id': instance.currencyId,
};
