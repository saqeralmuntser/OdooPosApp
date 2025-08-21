// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_combo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductCombo _$ProductComboFromJson(Map<String, dynamic> json) =>
    ProductCombo(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      basePrice: (json['base_price'] as num).toDouble(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      comboItemIds: (json['combo_item_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProductComboToJson(ProductCombo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'base_price': instance.basePrice,
      'sequence': instance.sequence,
      'combo_item_ids': instance.comboItemIds,
    };

ProductComboItem _$ProductComboItemFromJson(Map<String, dynamic> json) =>
    ProductComboItem(
      id: (json['id'] as num).toInt(),
      comboId: _extractIdFromArray(json['combo_id']),
      productId: _extractIdFromArray(json['product_id']),
      extraPrice: (json['extra_price'] as num?)?.toDouble() ?? 0.0,
      productName: null, // Set programmatically
      groupName: null, // Set programmatically
      selectionType: null, // Set programmatically
      required: false, // Set programmatically
    );

Map<String, dynamic> _$ProductComboItemToJson(ProductComboItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'combo_id': instance.comboId,
      'product_id': instance.productId,
      'extra_price': instance.extraPrice,
      'product_name': instance.productName,
      'group_name': instance.groupName,
      'selection_type': instance.selectionType,
      'required': instance.required,
    };
