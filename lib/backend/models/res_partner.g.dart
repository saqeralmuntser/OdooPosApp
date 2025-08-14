// GENERATED CODE - DO NOT MODIFY BY HAND
// Simplified version for demo purposes

part of 'res_partner.dart';

// TODO: Run 'dart run build_runner build' to generate proper serialization

ResPartner _$ResPartnerFromJson(Map<String, dynamic> json) {
  return ResPartner(
    id: json['id'] as int,
    name: json['name'] as String,
    displayName: json['display_name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    mobile: json['mobile'] as String?,
    website: json['website'] as String?,
    vatNumber: json['vat'] as String?,
    jobPosition: json['function'] as String?,
    title: json['title'] as String?,
    street: json['street'] as String?,
    street2: json['street2'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
    zip: json['zip'] as String?,
    countryId: json['country_id'] as int?,
    isCompany: json['is_company'] as bool? ?? false,
    parentId: json['parent_id'] as int?,
    companyId: json['company_id'] as int?,
    active: json['active'] as bool? ?? true,
    supplierRank: json['supplier_rank'] as int? ?? 0,
    customerRank: json['customer_rank'] as int? ?? 0,
    lang: json['lang'] as String?,
    tz: json['tz'] as String?,
    categoryId: (json['category_id'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
    propertyAccountPositionId: json['property_account_position_id'] as int?,
    propertyPaymentTermId: json['property_payment_term_id'] as int?,
    image128: json['image_128'] as String?,
    hasImage: json['has_image'] as bool? ?? false,
  );
}

Map<String, dynamic> _$ResPartnerToJson(ResPartner instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': instance.displayName,
      'email': instance.email,
      'phone': instance.phone,
      'mobile': instance.mobile,
      'website': instance.website,
      'vat': instance.vatNumber,
      'function': instance.jobPosition,
      'title': instance.title,
      'street': instance.street,
      'street2': instance.street2,
      'city': instance.city,
      'state': instance.state,
      'zip': instance.zip,
      'country_id': instance.countryId,
      'is_company': instance.isCompany,
      'parent_id': instance.parentId,
      'company_id': instance.companyId,
      'active': instance.active,
      'supplier_rank': instance.supplierRank,
      'customer_rank': instance.customerRank,
      'lang': instance.lang,
      'tz': instance.tz,
      'category_id': instance.categoryId,
      'property_account_position_id': instance.propertyAccountPositionId,
      'property_payment_term_id': instance.propertyPaymentTermId,
      'image_128': instance.image128,
      'has_image': instance.hasImage,
    };