import 'package:json_annotation/json_annotation.dart';

part 'product_pricelist.g.dart';

/// Helper function to extract ID from Odoo array format [id, name]
int _extractIdFromArray(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  }
  throw FormatException('Invalid ID format: $value');
}

/// Helper function to extract nullable ID from Odoo array format
int? _extractNullableIdFromArray(dynamic value) {
  if (value == false || value == null) {
    return null;
  }
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  }
  return null;
}

/// Helper function to extract required int values from Odoo
int _extractIntFromOdoo(dynamic value) {
  if (value == false || value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    try {
      return int.parse(value);
    } catch (e) {
      return 0;
    }
  }
  return 0;
}



/// product.pricelist - Product Pricelist
/// Represents a pricelist with pricing rules for products
@JsonSerializable()
class ProductPricelist {
  final int id;
  final String name;
  @JsonKey(name: 'display_name')
  final String displayName;
  final bool active;
  
  // Company and Currency
  @JsonKey(name: 'company_id', fromJson: _extractNullableIdFromArray)
  final int? companyId;
  @JsonKey(name: 'currency_id', fromJson: _extractIdFromArray)
  final int currencyId;
  
  // Settings
  @JsonKey(name: 'sequence', fromJson: _extractIntFromOdoo)
  final int sequence;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'item_ids')
  final List<int> itemIds;
  @JsonKey(name: 'country_group_ids')
  final List<int> countryGroupIds;

  ProductPricelist({
    required this.id,
    required this.name,
    required this.displayName,
    this.active = true,
    this.companyId,
    required this.currencyId,
    this.sequence = 10,
    this.itemIds = const [],
    this.countryGroupIds = const [],
  });

  factory ProductPricelist.fromJson(Map<String, dynamic> json) => _$ProductPricelistFromJson(json);
  Map<String, dynamic> toJson() => _$ProductPricelistToJson(this);

  ProductPricelist copyWith({
    int? id,
    String? name,
    String? displayName,
    bool? active,
    int? companyId,
    int? currencyId,
    int? sequence,
    List<int>? itemIds,
    List<int>? countryGroupIds,
  }) {
    return ProductPricelist(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      active: active ?? this.active,
      companyId: companyId ?? this.companyId,
      currencyId: currencyId ?? this.currencyId,
      sequence: sequence ?? this.sequence,
      itemIds: itemIds ?? this.itemIds,
      countryGroupIds: countryGroupIds ?? this.countryGroupIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductPricelist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProductPricelist(id: $id, name: $name)';
}
