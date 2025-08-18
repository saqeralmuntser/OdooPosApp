// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_partner.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResPartner _$ResPartnerFromJson(Map<String, dynamic> json) => ResPartner(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  displayName: const OdooStringConverter().fromJson(json['display_name']),
  email: const OdooStringConverter().fromJson(json['email']),
  phone: const OdooStringConverter().fromJson(json['phone']),
  mobile: const OdooStringConverter().fromJson(json['mobile']),
  website: const OdooStringConverter().fromJson(json['website']),
  vatNumber: const OdooStringConverter().fromJson(json['vat']),
  jobPosition: const OdooStringConverter().fromJson(json['function']),
  title: const OdooStringConverter().fromJson(json['title']),
  street: const OdooStringConverter().fromJson(json['street']),
  street2: const OdooStringConverter().fromJson(json['street2']),
  city: const OdooStringConverter().fromJson(json['city']),
  state: const OdooStringConverter().fromJson(json['state']),
  zip: const OdooStringConverter().fromJson(json['zip']),
  countryId: const OdooIntConverter().fromJson(json['country_id']),
  isCompany: json['is_company'] as bool? ?? false,
  parentId: const OdooIntConverter().fromJson(json['parent_id']),
  companyId: const OdooIntConverter().fromJson(json['company_id']),
  active: json['active'] as bool? ?? true,
  supplierRank: (json['supplier_rank'] as num?)?.toInt() ?? 0,
  customerRank: (json['customer_rank'] as num?)?.toInt() ?? 0,
  lang: const OdooStringConverter().fromJson(json['lang']),
  tz: const OdooStringConverter().fromJson(json['tz']),
  categoryId:
      (json['category_id'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  propertyAccountPositionId: const OdooIntConverter().fromJson(
    json['property_account_position_id'],
  ),
  propertyPaymentTermId: const OdooIntConverter().fromJson(
    json['property_payment_term_id'],
  ),
  image128: const OdooStringConverter().fromJson(json['image_128']),
  hasImage: json['has_image'] as bool? ?? false,
);

Map<String, dynamic> _$ResPartnerToJson(ResPartner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': const OdooStringConverter().toJson(instance.displayName),
      'email': const OdooStringConverter().toJson(instance.email),
      'phone': const OdooStringConverter().toJson(instance.phone),
      'mobile': const OdooStringConverter().toJson(instance.mobile),
      'website': const OdooStringConverter().toJson(instance.website),
      'vat': const OdooStringConverter().toJson(instance.vatNumber),
      'function': const OdooStringConverter().toJson(instance.jobPosition),
      'title': const OdooStringConverter().toJson(instance.title),
      'street': const OdooStringConverter().toJson(instance.street),
      'street2': const OdooStringConverter().toJson(instance.street2),
      'city': const OdooStringConverter().toJson(instance.city),
      'state': const OdooStringConverter().toJson(instance.state),
      'zip': const OdooStringConverter().toJson(instance.zip),
      'country_id': const OdooIntConverter().toJson(instance.countryId),
      'is_company': instance.isCompany,
      'parent_id': const OdooIntConverter().toJson(instance.parentId),
      'company_id': const OdooIntConverter().toJson(instance.companyId),
      'active': instance.active,
      'supplier_rank': instance.supplierRank,
      'customer_rank': instance.customerRank,
      'lang': const OdooStringConverter().toJson(instance.lang),
      'tz': const OdooStringConverter().toJson(instance.tz),
      'category_id': instance.categoryId,
      'property_account_position_id': const OdooIntConverter().toJson(
        instance.propertyAccountPositionId,
      ),
      'property_payment_term_id': const OdooIntConverter().toJson(
        instance.propertyPaymentTermId,
      ),
      'image_128': const OdooStringConverter().toJson(instance.image128),
      'has_image': instance.hasImage,
    };
