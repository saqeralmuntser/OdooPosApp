// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_attribute.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductAttribute _$ProductAttributeFromJson(Map<String, dynamic> json) =>
    ProductAttribute(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      displayType: json['display_type'] as String? ?? 'radio',
      createVariant: json['create_variant'] as String? ?? 'always',
      sequence: (json['sequence'] as num?)?.toInt() ?? 10,
    );

Map<String, dynamic> _$ProductAttributeToJson(ProductAttribute instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_type': instance.displayType,
      'create_variant': instance.createVariant,
      'sequence': instance.sequence,
    };

ProductAttributeValue _$ProductAttributeValueFromJson(
  Map<String, dynamic> json,
) => ProductAttributeValue(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  attributeId: _extractIdFromArray(json['attribute_id']),
  sequence: (json['sequence'] as num?)?.toInt() ?? 10,
  color: (json['color'] as num?)?.toInt() ?? 0,
  isCustom: json['is_custom'] as bool? ?? false,
  htmlColor: _htmlColorFromJson(json['html_color']),
  image: json['image'] as bool?,
  priceExtra: (json['price_extra'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$ProductAttributeValueToJson(
  ProductAttributeValue instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'attribute_id': instance.attributeId,
  'sequence': instance.sequence,
  'color': instance.color,
  'is_custom': instance.isCustom,
  'html_color': instance.htmlColor,
  'image': instance.image,
  'price_extra': instance.priceExtra,
};

ProductTemplateAttributeLine _$ProductTemplateAttributeLineFromJson(
  Map<String, dynamic> json,
) => ProductTemplateAttributeLine(
  id: (json['id'] as num).toInt(),
  productTmplId: _extractIdFromArray(json['product_tmpl_id']),
  attributeId: _extractIdFromArray(json['attribute_id']),
  required: json['required'] as bool? ?? false,
  valueIds:
      (json['value_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductTemplateAttributeLineToJson(
  ProductTemplateAttributeLine instance,
) => <String, dynamic>{
  'id': instance.id,
  'product_tmpl_id': instance.productTmplId,
  'attribute_id': instance.attributeId,
  'required': instance.required,
  'value_ids': instance.valueIds,
};

ProductTemplateAttributeValue _$ProductTemplateAttributeValueFromJson(
  Map<String, dynamic> json,
) => ProductTemplateAttributeValue(
  id: (json['id'] as num).toInt(),
  productTmplId: _extractIdFromArray(json['product_tmpl_id']),
  attributeLineId: _extractIdFromArray(json['attribute_line_id']),
  productAttributeValueId: _extractIdFromArray(
    json['product_attribute_value_id'],
  ),
  priceExtra: (json['price_extra'] as num?)?.toDouble() ?? 0.0,
  excludeFor: json['exclude_for'] as String?,
  htmlColor: _htmlColorFromJson(json['html_color']),
);

Map<String, dynamic> _$ProductTemplateAttributeValueToJson(
  ProductTemplateAttributeValue instance,
) => <String, dynamic>{
  'id': instance.id,
  'product_tmpl_id': instance.productTmplId,
  'attribute_line_id': instance.attributeLineId,
  'product_attribute_value_id': instance.productAttributeValueId,
  'price_extra': instance.priceExtra,
  'exclude_for': instance.excludeFor,
  'html_color': instance.htmlColor,
};
