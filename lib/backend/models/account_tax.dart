import 'package:json_annotation/json_annotation.dart';

part 'account_tax.g.dart';

/// Custom converter for Odoo many2one fields that return [id, display_name]
class OdooMany2OneConverter implements JsonConverter<int, dynamic> {
  const OdooMany2OneConverter();

  @override
  int fromJson(dynamic json) {
    if (json is List && json.isNotEmpty) {
      return json[0] as int;
    } else if (json is int) {
      return json;
    }
    return 0; // Default value if parsing fails
  }

  @override
  dynamic toJson(int object) => object;
}

/// Custom converter for Odoo many2many fields that return list of IDs
class OdooMany2ManyConverter implements JsonConverter<List<int>, dynamic> {
  const OdooMany2ManyConverter();

  @override
  List<int> fromJson(dynamic json) {
    if (json is List) {
      return json.cast<int>();
    }
    return [];
  }

  @override
  dynamic toJson(List<int> object) => object;
}

/// account.tax - Tax Configuration
/// Tax configuration for products and orders
@JsonSerializable()
class AccountTax {
  final int id;
  final String name;
  @JsonKey(name: 'amount_type')
  final TaxAmountType amountType;
  final double amount;
  @JsonKey(name: 'type_tax_use')
  final TaxTypeUse typeTaxUse;
  @JsonKey(name: 'price_include')
  final bool priceInclude;
  @JsonKey(name: 'include_base_amount')
  final bool includeBaseAmount;
  @JsonKey(name: 'is_base_affected')
  final bool isBaseAffected;
  final int sequence;
  @JsonKey(name: 'company_id')
  @OdooMany2OneConverter()
  final int companyId;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'tax_group_id')
  @OdooMany2OneConverter()
  final int? taxGroupId;
  @JsonKey(name: 'children_tax_ids')
  @OdooMany2ManyConverter()
  final List<int> childrenTaxIds;
  @JsonKey(name: 'invoice_repartition_line_ids')
  @OdooMany2ManyConverter()
  final List<int> invoiceRepartitionLineIds;
  @JsonKey(name: 'refund_repartition_line_ids')
  @OdooMany2ManyConverter()
  final List<int> refundRepartitionLineIds;

  AccountTax({
    required this.id,
    required this.name,
    required this.amountType,
    required this.amount,
    required this.typeTaxUse,
    this.priceInclude = false,
    this.includeBaseAmount = false,
    this.isBaseAffected = false,
    this.sequence = 0,
    required this.companyId,
    this.taxGroupId,
    this.childrenTaxIds = const [],
    this.invoiceRepartitionLineIds = const [],
    this.refundRepartitionLineIds = const [],
  });

  factory AccountTax.fromJson(Map<String, dynamic> json) => _$AccountTaxFromJson(json);
  Map<String, dynamic> toJson() => _$AccountTaxToJson(this);

  /// Calculate tax amount for a given base amount
  double calculateTaxAmount(double baseAmount) {
    switch (amountType) {
      case TaxAmountType.fixed:
        return amount;
      case TaxAmountType.percent:
        return baseAmount * (amount / 100);
      case TaxAmountType.division:
        return baseAmount * (amount / (100 + amount));
      case TaxAmountType.group:
        return 0.0; // Group taxes are calculated from children
    }
  }

  /// Calculate total amount including tax
  double calculateTotalAmount(double baseAmount) {
    if (priceInclude) {
      return baseAmount;
    }
    return baseAmount + calculateTaxAmount(baseAmount);
  }

  /// Check if tax is percentage-based
  bool get isPercentage => amountType == TaxAmountType.percent;

  /// Check if tax is fixed amount
  bool get isFixed => amountType == TaxAmountType.fixed;

  /// Check if tax is a group
  bool get isGroup => amountType == TaxAmountType.group;

  /// Check if tax applies to sales
  bool get appliesToSales => typeTaxUse == TaxTypeUse.sale;

  /// Check if tax applies to purchases
  bool get appliesToPurchases => typeTaxUse == TaxTypeUse.purchase;

  /// Get formatted tax rate for display
  String get formattedRate {
    switch (amountType) {
      case TaxAmountType.fixed:
        return '${amount.toStringAsFixed(2)} (Fixed)';
      case TaxAmountType.percent:
        return '${amount.toStringAsFixed(1)}%';
      case TaxAmountType.division:
        return '${amount.toStringAsFixed(1)}% (Division)';
      case TaxAmountType.group:
        return 'Group';
    }
  }

  AccountTax copyWith({
    int? id,
    String? name,
    TaxAmountType? amountType,
    double? amount,
    TaxTypeUse? typeTaxUse,
    bool? priceInclude,
    bool? includeBaseAmount,
    bool? isBaseAffected,
    int? sequence,
    int? companyId,
    int? taxGroupId,
    List<int>? childrenTaxIds,
    List<int>? invoiceRepartitionLineIds,
    List<int>? refundRepartitionLineIds,
  }) {
    return AccountTax(
      id: id ?? this.id,
      name: name ?? this.name,
      amountType: amountType ?? this.amountType,
      amount: amount ?? this.amount,
      typeTaxUse: typeTaxUse ?? this.typeTaxUse,
      priceInclude: priceInclude ?? this.priceInclude,
      includeBaseAmount: includeBaseAmount ?? this.includeBaseAmount,
      isBaseAffected: isBaseAffected ?? this.isBaseAffected,
      sequence: sequence ?? this.sequence,
      companyId: companyId ?? this.companyId,
      taxGroupId: taxGroupId ?? this.taxGroupId,
      childrenTaxIds: childrenTaxIds ?? this.childrenTaxIds,
      invoiceRepartitionLineIds: invoiceRepartitionLineIds ?? this.invoiceRepartitionLineIds,
      refundRepartitionLineIds: refundRepartitionLineIds ?? this.refundRepartitionLineIds,
    );
  }
}

/// Tax amount type enumeration
@JsonEnum()
enum TaxAmountType {
  @JsonValue('fixed')
  fixed,
  
  @JsonValue('percent')
  percent,
  
  @JsonValue('division')
  division,
  
  @JsonValue('group')
  group,
}

/// Tax type use enumeration
@JsonEnum()
enum TaxTypeUse {
  @JsonValue('sale')
  sale,
  
  @JsonValue('purchase')
  purchase,
  
  @JsonValue('none')
  none,
}

/// Extension for TaxAmountType
extension TaxAmountTypeExtension on TaxAmountType {
  String get displayName {
    switch (this) {
      case TaxAmountType.fixed:
        return 'Fixed';
      case TaxAmountType.percent:
        return 'Percentage';
      case TaxAmountType.division:
        return 'Division';
      case TaxAmountType.group:
        return 'Group';
    }
  }
}

/// Extension for TaxTypeUse
extension TaxTypeUseExtension on TaxTypeUse {
  String get displayName {
    switch (this) {
      case TaxTypeUse.sale:
        return 'Sale';
      case TaxTypeUse.purchase:
        return 'Purchase';
      case TaxTypeUse.none:
        return 'None';
    }
  }
}
