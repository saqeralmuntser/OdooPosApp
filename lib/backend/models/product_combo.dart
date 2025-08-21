import 'package:json_annotation/json_annotation.dart';

part 'product_combo.g.dart';

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





/// product.combo - Combo Product Definition
/// Represents a combo that contains multiple products with optional extra pricing
@JsonSerializable()
class ProductCombo {
  final int id;
  final String name;
  @JsonKey(name: 'base_price')
  final double basePrice;
  final int sequence;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'combo_item_ids')
  final List<int> comboItemIds;

  ProductCombo({
    required this.id,
    required this.name,
    required this.basePrice,
    this.sequence = 0,
    this.comboItemIds = const [],
  });

  factory ProductCombo.fromJson(Map<String, dynamic> json) => _$ProductComboFromJson(json);
  Map<String, dynamic> toJson() => _$ProductComboToJson(this);

  ProductCombo copyWith({
    int? id,
    String? name,
    double? basePrice,
    int? sequence,
    List<int>? comboItemIds,
  }) {
    return ProductCombo(
      id: id ?? this.id,
      name: name ?? this.name,
      basePrice: basePrice ?? this.basePrice,
      sequence: sequence ?? this.sequence,
      comboItemIds: comboItemIds ?? this.comboItemIds,
    );
  }
}

/// product.combo.item - Individual Item in a Combo
/// Represents a product that can be selected as part of a combo with optional extra pricing
@JsonSerializable()
class ProductComboItem {
  final int id;
  @JsonKey(name: 'combo_id', fromJson: _extractIdFromArray)
  final int comboId;
  @JsonKey(name: 'product_id', fromJson: _extractIdFromArray)
  final int productId;
  @JsonKey(name: 'extra_price')
  final double extraPrice;
  
  // Fields that may come from Odoo (if they exist in the database)
  @JsonKey(name: 'group_name')
  final String? groupName;
  @JsonKey(name: 'selection_type')
  final String? selectionType;
  @JsonKey(name: 'required')
  final bool? required;
  
  // Additional fields for UI purposes (set programmatically if not from Odoo)
  final String? productName;

  ProductComboItem({
    required this.id,
    required this.comboId,
    required this.productId,
    this.extraPrice = 0.0,
    this.productName,
    this.groupName,
    this.selectionType,
    this.required = false,
  });

  factory ProductComboItem.fromJson(Map<String, dynamic> json) => _$ProductComboItemFromJson(json);
  Map<String, dynamic> toJson() => _$ProductComboItemToJson(this);

  ProductComboItem copyWith({
    int? id,
    int? comboId,
    int? productId,
    double? extraPrice,
    String? productName,
    String? groupName,
    String? selectionType,
    bool? required,
  }) {
    return ProductComboItem(
      id: id ?? this.id,
      comboId: comboId ?? this.comboId,
      productId: productId ?? this.productId,
      extraPrice: extraPrice ?? this.extraPrice,
      productName: productName ?? this.productName,
      groupName: groupName ?? this.groupName,
      selectionType: selectionType ?? this.selectionType,
      required: required ?? this.required,
    );
  }
}

/// Combo Section for UI organization
/// Groups related combo items together (e.g., "Burgers Choice", "Drinks Choice")
class ComboSection {
  final String groupName;
  final String selectionType; // 'single' or 'multiple'
  final bool required;
  final List<ComboSectionItem> items;

  ComboSection({
    required this.groupName,
    required this.selectionType,
    this.required = false,
    required this.items,
  });
}

/// Individual item within a combo section
class ComboSectionItem {
  final int productId;
  final String name;
  final String? image;
  final double extraPrice;
  final bool isSelected;

  ComboSectionItem({
    required this.productId,
    required this.name,
    this.image,
    required this.extraPrice,
    this.isSelected = false,
  });

  ComboSectionItem copyWith({
    int? productId,
    String? name,
    String? image,
    double? extraPrice,
    bool? isSelected,
  }) {
    return ComboSectionItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      image: image ?? this.image,
      extraPrice: extraPrice ?? this.extraPrice,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Result of combo selection
class ComboSelectionResult {
  final ProductCombo combo;
  final Map<String, ComboSectionItem> selectedItems; // groupName -> selected item
  final double totalExtraPrice;
  final bool isComplete;

  ComboSelectionResult({
    required this.combo,
    required this.selectedItems,
    required this.totalExtraPrice,
    required this.isComplete,
  });

  /// Get list of selected product IDs
  List<int> get selectedProductIds => selectedItems.values.map((item) => item.productId).toList();

  /// Get list of extra prices
  List<double> get extraPrices => selectedItems.values.map((item) => item.extraPrice).toList();

  /// Get formatted description of selections
  String get selectionDescription {
    if (selectedItems.isEmpty) return '';
    return selectedItems.values.map((item) => item.name).join(', ');
  }
}
