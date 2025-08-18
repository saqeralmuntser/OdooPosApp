import 'package:json_annotation/json_annotation.dart';
import 'odoo_converters.dart';

part 'pos_category.g.dart';

/// pos.category - POS Category
/// Product categories specifically for Point of Sale
@JsonSerializable()
class POSCategory {
  final int id;
  final String name;
  @JsonKey(name: 'parent_id')
  @OdooIntConverter()
  final int? parentId;
  final int sequence;
  @OdooIntConverter()
  final int? color;
  @JsonKey(name: 'image_128')
  @OdooStringConverter()
  final String? image128;
  @JsonKey(name: 'has_image')
  final bool hasImage;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'child_ids')
  final List<int> childIds;

  POSCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.sequence = 0,
    this.color,
    this.image128,
    this.hasImage = false,
    this.childIds = const [],
  });

  factory POSCategory.fromJson(Map<String, dynamic> json) => _$POSCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$POSCategoryToJson(this);

  /// Check if category is a root category (no parent)
  bool get isRoot => parentId == null;

  /// Check if category has children
  bool get hasChildren => childIds.isNotEmpty;

  /// Check if category has an image
  bool get hasImageData => hasImage && image128 != null;

  /// Get display color (default to grey if not set)
  String get displayColor {
    if (color == null) return '#9E9E9E';
    // Convert Odoo color integer to hex
    return '#${color!.toRadixString(16).padLeft(6, '0')}';
  }

  POSCategory copyWith({
    int? id,
    String? name,
    int? parentId,
    int? sequence,
    int? color,
    String? image128,
    bool? hasImage,
    List<int>? childIds,
  }) {
    return POSCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sequence: sequence ?? this.sequence,
      color: color ?? this.color,
      image128: image128 ?? this.image128,
      hasImage: hasImage ?? this.hasImage,
      childIds: childIds ?? this.childIds,
    );
  }
}
