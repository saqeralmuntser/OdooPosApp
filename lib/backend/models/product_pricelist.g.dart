// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_pricelist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductPricelist _$ProductPricelistFromJson(Map<String, dynamic> json) =>
    ProductPricelist(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      active: json['active'] as bool? ?? true,
      companyId: _extractNullableIdFromArray(json['company_id']),
      currencyId: _extractIdFromArray(json['currency_id']),
      sequence: json['sequence'] == null
          ? 10
          : _extractIntFromOdoo(json['sequence']),
      itemIds:
          (json['item_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      countryGroupIds:
          (json['country_group_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProductPricelistToJson(ProductPricelist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': instance.displayName,
      'active': instance.active,
      'company_id': instance.companyId,
      'currency_id': instance.currencyId,
      'sequence': instance.sequence,
      'item_ids': instance.itemIds,
      'country_group_ids': instance.countryGroupIds,
    };
