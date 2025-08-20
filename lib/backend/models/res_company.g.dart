// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_company.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResCompany _$ResCompanyFromJson(Map<String, dynamic> json) => ResCompany(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  displayName: const OdooStringConverter().fromJson(json['display_name']),
  email: const OdooStringConverter().fromJson(json['email']),
  phone: const OdooStringConverter().fromJson(json['phone']),
  website: const OdooStringConverter().fromJson(json['website']),
  vatNumber: const OdooStringConverter().fromJson(json['vat']),
  street: const OdooStringConverter().fromJson(json['street']),
  street2: const OdooStringConverter().fromJson(json['street2']),
  city: const OdooStringConverter().fromJson(json['city']),
  state: const OdooStringConverter().fromJson(json['state']),
  zip: const OdooStringConverter().fromJson(json['zip']),
  countryId: const OdooIntConverter().fromJson(json['country_id']),
  currencyId: const OdooIntConverter().fromJson(json['currency_id']),
  companyRegistry: const OdooStringConverter().fromJson(
    json['company_registry'],
  ),
  logo: const OdooStringConverter().fromJson(json['logo']),
  active: json['active'] as bool? ?? true,
);

Map<String, dynamic> _$ResCompanyToJson(ResCompany instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': const OdooStringConverter().toJson(instance.displayName),
      'email': const OdooStringConverter().toJson(instance.email),
      'phone': const OdooStringConverter().toJson(instance.phone),
      'website': const OdooStringConverter().toJson(instance.website),
      'vat': const OdooStringConverter().toJson(instance.vatNumber),
      'street': const OdooStringConverter().toJson(instance.street),
      'street2': const OdooStringConverter().toJson(instance.street2),
      'city': const OdooStringConverter().toJson(instance.city),
      'state': const OdooStringConverter().toJson(instance.state),
      'zip': const OdooStringConverter().toJson(instance.zip),
      'country_id': const OdooIntConverter().toJson(instance.countryId),
      'currency_id': const OdooIntConverter().toJson(instance.currencyId),
      'company_registry': const OdooStringConverter().toJson(
        instance.companyRegistry,
      ),
      'logo': const OdooStringConverter().toJson(instance.logo),
      'active': instance.active,
    };
