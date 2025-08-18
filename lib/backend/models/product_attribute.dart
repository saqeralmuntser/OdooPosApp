import 'package:json_annotation/json_annotation.dart';

part 'product_attribute.g.dart';

/// product.attribute - Product Attribute
/// Defines an attribute that can be applied to products (like Size, Color, etc.)
@JsonSerializable()
class ProductAttribute {
  final int id;
  final String name;
  @JsonKey(name: 'display_type')
  final String displayType; // 'radio', 'select', 'color', 'pills'
  @JsonKey(name: 'create_variant')
  final String createVariant; // 'always', 'dynamic', 'no_variant'
  final int sequence;

  ProductAttribute({
    required this.id,
    required this.name,
    this.displayType = 'radio',
    this.createVariant = 'always',
    this.sequence = 10,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) => _$ProductAttributeFromJson(json);
  Map<String, dynamic> toJson() => _$ProductAttributeToJson(this);

  ProductAttribute copyWith({
    int? id,
    String? name,
    String? displayType,
    String? createVariant,
    int? sequence,
  }) {
    return ProductAttribute(
      id: id ?? this.id,
      name: name ?? this.name,
      displayType: displayType ?? this.displayType,
      createVariant: createVariant ?? this.createVariant,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// product.attribute.value - Product Attribute Value
/// Represents specific values for an attribute (like Red for Color, Large for Size)
@JsonSerializable()
class ProductAttributeValue {
  final int id;
  final String name;
  @JsonKey(name: 'attribute_id', fromJson: _extractIdFromArray)
  final int attributeId;
  final int sequence;
  final int color;
  @JsonKey(name: 'is_custom')
  final bool isCustom;
  @JsonKey(name: 'html_color', fromJson: _htmlColorFromJson)
  final String? htmlColor;
  final bool? image; // Whether the value has an image
  @JsonKey(name: 'price_extra')
  final double priceExtra;

  ProductAttributeValue({
    required this.id,
    required this.name,
    required this.attributeId,
    this.sequence = 10,
    this.color = 0,
    this.isCustom = false,
    this.htmlColor,
    this.image,
    this.priceExtra = 0.0,
  });

  factory ProductAttributeValue.fromJson(Map<String, dynamic> json) => _$ProductAttributeValueFromJson(json);
  Map<String, dynamic> toJson() => _$ProductAttributeValueToJson(this);

  ProductAttributeValue copyWith({
    int? id,
    String? name,
    int? attributeId,
    int? sequence,
    int? color,
    bool? isCustom,
    String? htmlColor,
    bool? image,
    double? priceExtra,
  }) {
    return ProductAttributeValue(
      id: id ?? this.id,
      name: name ?? this.name,
      attributeId: attributeId ?? this.attributeId,
      sequence: sequence ?? this.sequence,
      color: color ?? this.color,
      isCustom: isCustom ?? this.isCustom,
      htmlColor: htmlColor ?? this.htmlColor,
      image: image ?? this.image,
      priceExtra: priceExtra ?? this.priceExtra,
    );
  }
}

/// product.template.attribute.line - Product Template Attribute Line
/// Links a product template to an attribute and defines which values are available
@JsonSerializable()
class ProductTemplateAttributeLine {
  final int id;
  @JsonKey(name: 'product_tmpl_id', fromJson: _extractIdFromArray)
  final int productTmplId;
  @JsonKey(name: 'attribute_id', fromJson: _extractIdFromArray)
  final int attributeId;
  final bool required;
  @JsonKey(name: 'value_ids')
  final List<int> valueIds; // Available attribute value IDs

  ProductTemplateAttributeLine({
    required this.id,
    required this.productTmplId,
    required this.attributeId,
    this.required = false,
    this.valueIds = const [],
  });

  factory ProductTemplateAttributeLine.fromJson(Map<String, dynamic> json) => _$ProductTemplateAttributeLineFromJson(json);
  Map<String, dynamic> toJson() => _$ProductTemplateAttributeLineToJson(this);

  ProductTemplateAttributeLine copyWith({
    int? id,
    int? productTmplId,
    int? attributeId,
    bool? required,
    List<int>? valueIds,
  }) {
    return ProductTemplateAttributeLine(
      id: id ?? this.id,
      productTmplId: productTmplId ?? this.productTmplId,
      attributeId: attributeId ?? this.attributeId,
      required: required ?? this.required,
      valueIds: valueIds ?? this.valueIds,
    );
  }
}

/// product.template.attribute.value - Product Template Attribute Value
/// Links a product template to specific attribute values with pricing information
@JsonSerializable()
class ProductTemplateAttributeValue {
  final int id;
  @JsonKey(name: 'product_tmpl_id', fromJson: _extractIdFromArray)
  final int productTmplId;
  @JsonKey(name: 'attribute_line_id', fromJson: _extractIdFromArray)
  final int attributeLineId;
  @JsonKey(name: 'product_attribute_value_id', fromJson: _extractIdFromArray)
  final int productAttributeValueId;
  @JsonKey(name: 'price_extra')
  final double priceExtra;
  @JsonKey(name: 'exclude_for')
  final String? excludeFor;
  @JsonKey(name: 'html_color', fromJson: _htmlColorFromJson)
  final String? htmlColor;

  ProductTemplateAttributeValue({
    required this.id,
    required this.productTmplId,
    required this.attributeLineId,
    required this.productAttributeValueId,
    this.priceExtra = 0.0,
    this.excludeFor,
    this.htmlColor,
  });

  factory ProductTemplateAttributeValue.fromJson(Map<String, dynamic> json) => _$ProductTemplateAttributeValueFromJson(json);
  Map<String, dynamic> toJson() => _$ProductTemplateAttributeValueToJson(this);

  ProductTemplateAttributeValue copyWith({
    int? id,
    int? productTmplId,
    int? attributeLineId,
    int? productAttributeValueId,
    double? priceExtra,
    String? excludeFor,
    String? htmlColor,
  }) {
    return ProductTemplateAttributeValue(
      id: id ?? this.id,
      productTmplId: productTmplId ?? this.productTmplId,
      attributeLineId: attributeLineId ?? this.attributeLineId,
      productAttributeValueId: productAttributeValueId ?? this.productAttributeValueId,
      priceExtra: priceExtra ?? this.priceExtra,
      excludeFor: excludeFor ?? this.excludeFor,
      htmlColor: htmlColor ?? this.htmlColor,
    );
  }
}

/// Helper function to extract ID from Odoo array format [id, name]
int _extractIdFromArray(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  } else if (value == false || value == null) {
    return 0; // Handle false values as 0
  }
  throw FormatException('Invalid ID format: $value');
}

/// Helper function to handle html_color field from Odoo (can be false or string)
String? _htmlColorFromJson(dynamic value) {
  if (value is bool && value == false) {
    return null;
  }
  return value as String?;
}

/// Data structure for frontend attribute group display
class AttributeGroupDisplayData {
  final int attributeId;
  final String attributeName;
  final String displayType;
  final bool required;
  final List<AttributeValueDisplayData> values;

  AttributeGroupDisplayData({
    required this.attributeId,
    required this.attributeName,
    required this.displayType,
    required this.required,
    required this.values,
  });

  factory AttributeGroupDisplayData.fromJson(Map<String, dynamic> json) {
    return AttributeGroupDisplayData(
      attributeId: json['attribute_id'] as int,
      attributeName: json['attribute_name'] as String,
      displayType: json['display_type'] as String? ?? 'radio',
      required: json['required'] as bool? ?? false,
      values: (json['values'] as List<dynamic>)
          .map((v) => AttributeValueDisplayData.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attribute_id': attributeId,
      'attribute_name': attributeName,
      'display_type': displayType,
      'required': required,
      'values': values.map((v) => v.toJson()).toList(),
    };
  }
}

/// Data structure for frontend attribute value display
class AttributeValueDisplayData {
  final int valueId;
  final String valueName;
  final double priceExtra;
  final String? htmlColor;
  final bool hasImage;
  final bool isSelected;

  AttributeValueDisplayData({
    required this.valueId,
    required this.valueName,
    required this.priceExtra,
    this.htmlColor,
    this.hasImage = false,
    this.isSelected = false,
  });

  factory AttributeValueDisplayData.fromJson(Map<String, dynamic> json) {
    return AttributeValueDisplayData(
      valueId: json['value_id'] as int,
      valueName: json['value_name'] as String,
      priceExtra: (json['price_extra'] as num?)?.toDouble() ?? 0.0,
      htmlColor: json['html_color'] as String?,
      hasImage: json['has_image'] as bool? ?? false,
      isSelected: json['is_selected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value_id': valueId,
      'value_name': valueName,
      'price_extra': priceExtra,
      'html_color': htmlColor,
      'has_image': hasImage,
      'is_selected': isSelected,
    };
  }

  AttributeValueDisplayData copyWith({
    int? valueId,
    String? valueName,
    double? priceExtra,
    String? htmlColor,
    bool? hasImage,
    bool? isSelected,
  }) {
    return AttributeValueDisplayData(
      valueId: valueId ?? this.valueId,
      valueName: valueName ?? this.valueName,
      priceExtra: priceExtra ?? this.priceExtra,
      htmlColor: htmlColor ?? this.htmlColor,
      hasImage: hasImage ?? this.hasImage,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Complete product information with attributes
class ProductCompleteInfo {
  final int productId;
  final String productName;
  final double basePrice;
  final double finalPrice;
  final List<int> taxIds;
  final double vatRate;
  final List<AttributeGroupDisplayData> attributeGroups;

  ProductCompleteInfo({
    required this.productId,
    required this.productName,
    required this.basePrice,
    required this.finalPrice,
    required this.taxIds,
    required this.vatRate,
    required this.attributeGroups,
  });

  factory ProductCompleteInfo.fromJson(Map<String, dynamic> json) {
    return ProductCompleteInfo(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      basePrice: (json['base_price'] as num).toDouble(),
      finalPrice: (json['final_price'] as num).toDouble(),
      taxIds: List<int>.from(json['tax_ids'] as List),
      vatRate: (json['vat_rate'] as num).toDouble(),
      attributeGroups: (json['attribute_groups'] as List<dynamic>)
          .map((g) => AttributeGroupDisplayData.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'base_price': basePrice,
      'final_price': finalPrice,
      'tax_ids': taxIds,
      'vat_rate': vatRate,
      'attribute_groups': attributeGroups.map((g) => g.toJson()).toList(),
    };
  }
}
