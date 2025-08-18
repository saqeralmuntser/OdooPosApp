// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSCategory _$POSCategoryFromJson(Map<String, dynamic> json) => POSCategory(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  parentId: const OdooIntConverter().fromJson(json['parent_id']),
  sequence: (json['sequence'] as num?)?.toInt() ?? 0,
  color: const OdooIntConverter().fromJson(json['color']),
  image128: const OdooStringConverter().fromJson(json['image_128']),
  hasImage: json['has_image'] as bool? ?? false,
  childIds:
      (json['child_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$POSCategoryToJson(POSCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'parent_id': const OdooIntConverter().toJson(instance.parentId),
      'sequence': instance.sequence,
      'color': const OdooIntConverter().toJson(instance.color),
      'image_128': const OdooStringConverter().toJson(instance.image128),
      'has_image': instance.hasImage,
      'child_ids': instance.childIds,
    };
