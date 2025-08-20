import 'package:json_annotation/json_annotation.dart';
import 'odoo_converters.dart';

part 'res_company.g.dart';

/// res.company - Company Information
/// Represents the company information from Odoo
@JsonSerializable()
class ResCompany {
  final int id;
  final String name;
  
  @JsonKey(name: 'display_name')
  @OdooStringConverter()
  final String? displayName;
  
  @OdooStringConverter()
  final String? email;
  
  @OdooStringConverter()
  final String? phone;
  
  @OdooStringConverter()
  final String? website;
  
  @JsonKey(name: 'vat')
  @OdooStringConverter()
  final String? vatNumber;
  
  @OdooStringConverter()
  final String? street;
  
  @OdooStringConverter()
  final String? street2;
  
  @OdooStringConverter()
  final String? city;
  
  @OdooStringConverter()
  final String? state;
  
  @OdooStringConverter()
  final String? zip;
  
  @JsonKey(name: 'country_id')
  @OdooIntConverter()
  final int? countryId;
  
  @JsonKey(name: 'currency_id')
  @OdooIntConverter()
  final int? currencyId;
  
  @JsonKey(name: 'company_registry')
  @OdooStringConverter()
  final String? companyRegistry;
  
  @JsonKey(name: 'logo')
  @OdooStringConverter()
  final String? logo;
  
  final bool active;

  ResCompany({
    required this.id,
    required this.name,
    this.displayName,
    this.email,
    this.phone,
    this.website,
    this.vatNumber,
    this.street,
    this.street2,
    this.city,
    this.state,
    this.zip,
    this.countryId,
    this.currencyId,
    this.companyRegistry,
    this.logo,
    this.active = true,
  });

  factory ResCompany.fromJson(Map<String, dynamic> json) => _$ResCompanyFromJson(json);
  
  Map<String, dynamic> toJson() => _$ResCompanyToJson(this);
  
  /// Get full address as a single string
  String get fullAddress {
    final parts = <String>[];
    
    if (street?.isNotEmpty == true) parts.add(street!);
    if (street2?.isNotEmpty == true) parts.add(street2!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (state?.isNotEmpty == true) parts.add(state!);
    if (zip?.isNotEmpty == true) parts.add(zip!);
    
    return parts.join(', ');
  }
  
  /// Check if company has a complete address
  bool get hasAddress {
    return street?.isNotEmpty == true || 
           city?.isNotEmpty == true || 
           state?.isNotEmpty == true;
  }
  
  /// Get formatted VAT number
  String get formattedVatNumber {
    if (vatNumber?.isNotEmpty != true) return '';
    return 'ض.ب: $vatNumber';
  }
  
  /// Get formatted company registry
  String get formattedCompanyRegistry {
    if (companyRegistry?.isNotEmpty != true) return '';
    return 'س.ت: $companyRegistry';
  }

  ResCompany copyWith({
    int? id,
    String? name,
    String? displayName,
    String? email,
    String? phone,
    String? website,
    String? vatNumber,
    String? street,
    String? street2,
    String? city,
    String? state,
    String? zip,
    int? countryId,
    int? currencyId,
    String? companyRegistry,
    String? logo,
    bool? active,
  }) {
    return ResCompany(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      vatNumber: vatNumber ?? this.vatNumber,
      street: street ?? this.street,
      street2: street2 ?? this.street2,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      countryId: countryId ?? this.countryId,
      currencyId: currencyId ?? this.currencyId,
      companyRegistry: companyRegistry ?? this.companyRegistry,
      logo: logo ?? this.logo,
      active: active ?? this.active,
    );
  }
}
