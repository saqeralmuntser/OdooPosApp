import 'package:json_annotation/json_annotation.dart';
import 'odoo_converters.dart';

part 'res_partner.g.dart';

/// res.partner - Customer/Partner
/// Complete customer information for POS
@JsonSerializable()
class ResPartner {
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
  final String? mobile;
  @OdooStringConverter()
  final String? website;
  @JsonKey(name: 'vat')
  @OdooStringConverter()
  final String? vatNumber;
  @JsonKey(name: 'function')
  @OdooStringConverter()
  final String? jobPosition;
  @OdooStringConverter()
  final String? title;
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
  @JsonKey(name: 'is_company')
  final bool isCompany;
  @JsonKey(name: 'parent_id')
  @OdooIntConverter()
  final int? parentId;
  @JsonKey(name: 'company_id')
  @OdooIntConverter()
  final int? companyId;
  final bool active;
  @JsonKey(name: 'supplier_rank')
  final int supplierRank;
  @JsonKey(name: 'customer_rank')
  final int customerRank;
  
  // Contact Information
  @OdooStringConverter()
  final String? lang;
  @OdooStringConverter()
  final String? tz;
  @JsonKey(name: 'category_id')
  final List<int> categoryId;
  
  // Financial Information
  @JsonKey(name: 'property_account_position_id')
  @OdooIntConverter()
  final int? propertyAccountPositionId;
  @JsonKey(name: 'property_payment_term_id')
  @OdooIntConverter()
  final int? propertyPaymentTermId;
  
  // Image
  @JsonKey(name: 'image_128')
  @OdooStringConverter()
  final String? image128;
  @JsonKey(name: 'has_image')
  final bool hasImage;

  ResPartner({
    required this.id,
    required this.name,
    this.displayName,
    this.email,
    this.phone,
    this.mobile,
    this.website,
    this.vatNumber,
    this.jobPosition,
    this.title,
    this.street,
    this.street2,
    this.city,
    this.state,
    this.zip,
    this.countryId,
    this.isCompany = false,
    this.parentId,
    this.companyId,
    this.active = true,
    this.supplierRank = 0,
    this.customerRank = 0,
    this.lang,
    this.tz,
    this.categoryId = const [],
    this.propertyAccountPositionId,
    this.propertyPaymentTermId,
    this.image128,
    this.hasImage = false,
  });

  factory ResPartner.fromJson(Map<String, dynamic> json) => _$ResPartnerFromJson(json);
  Map<String, dynamic> toJson() => _$ResPartnerToJson(this);

  /// Get full address string
  String get fullAddress {
    List<String> addressParts = [];
    if (street != null) addressParts.add(street!);
    if (street2 != null) addressParts.add(street2!);
    if (city != null) addressParts.add(city!);
    if (state != null) addressParts.add(state!);
    if (zip != null) addressParts.add(zip!);
    return addressParts.join(', ');
  }

  /// Check if partner is a customer
  bool get isCustomer => customerRank > 0;

  /// Check if partner is a supplier
  bool get isSupplier => supplierRank > 0;

  /// Get contact phone (mobile first, then phone)
  String? get contactPhone => mobile ?? phone;

  /// Get formatted name for display
  String get formattedName => displayName ?? name;

  /// Check if partner has complete address
  bool get hasCompleteAddress => street != null && city != null;

  /// Check if partner has contact information
  bool get hasContactInfo => email != null || phone != null || mobile != null;

  /// Get partner type
  PartnerType get partnerType {
    if (isCompany) return PartnerType.company;
    if (parentId != null) return PartnerType.contact;
    return PartnerType.individual;
  }

  ResPartner copyWith({
    int? id,
    String? name,
    String? displayName,
    String? email,
    String? phone,
    String? mobile,
    String? website,
    String? vatNumber,
    String? jobPosition,
    String? title,
    String? street,
    String? street2,
    String? city,
    String? state,
    String? zip,
    int? countryId,
    bool? isCompany,
    int? parentId,
    int? companyId,
    bool? active,
    int? supplierRank,
    int? customerRank,
    String? lang,
    String? tz,
    List<int>? categoryId,
    int? propertyAccountPositionId,
    int? propertyPaymentTermId,
    String? image128,
    bool? hasImage,
  }) {
    return ResPartner(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      website: website ?? this.website,
      vatNumber: vatNumber ?? this.vatNumber,
      jobPosition: jobPosition ?? this.jobPosition,
      title: title ?? this.title,
      street: street ?? this.street,
      street2: street2 ?? this.street2,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      countryId: countryId ?? this.countryId,
      isCompany: isCompany ?? this.isCompany,
      parentId: parentId ?? this.parentId,
      companyId: companyId ?? this.companyId,
      active: active ?? this.active,
      supplierRank: supplierRank ?? this.supplierRank,
      customerRank: customerRank ?? this.customerRank,
      lang: lang ?? this.lang,
      tz: tz ?? this.tz,
      categoryId: categoryId ?? this.categoryId,
      propertyAccountPositionId: propertyAccountPositionId ?? this.propertyAccountPositionId,
      propertyPaymentTermId: propertyPaymentTermId ?? this.propertyPaymentTermId,
      image128: image128 ?? this.image128,
      hasImage: hasImage ?? this.hasImage,
    );
  }
}

/// Partner type enumeration
enum PartnerType {
  individual,
  company,
  contact,
}

/// Extension for PartnerType
extension PartnerTypeExtension on PartnerType {
  String get displayName {
    switch (this) {
      case PartnerType.individual:
        return 'Individual';
      case PartnerType.company:
        return 'Company';
      case PartnerType.contact:
        return 'Contact';
    }
  }
}
