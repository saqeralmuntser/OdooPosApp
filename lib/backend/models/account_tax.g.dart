// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_tax.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountTax _$AccountTaxFromJson(Map<String, dynamic> json) => AccountTax(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  amountType: $enumDecode(_$TaxAmountTypeEnumMap, json['amount_type']),
  amount: (json['amount'] as num).toDouble(),
  typeTaxUse: $enumDecode(_$TaxTypeUseEnumMap, json['type_tax_use']),
  priceInclude: json['price_include'] as bool? ?? false,
  includeBaseAmount: json['include_base_amount'] as bool? ?? false,
  isBaseAffected: json['is_base_affected'] as bool? ?? false,
  sequence: (json['sequence'] as num?)?.toInt() ?? 0,
  companyId: const OdooMany2OneConverter().fromJson(json['company_id']),
  taxGroupId: const OdooMany2OneConverter().fromJson(json['tax_group_id']),
  childrenTaxIds: json['children_tax_ids'] == null
      ? const []
      : const OdooMany2ManyConverter().fromJson(json['children_tax_ids']),
  invoiceRepartitionLineIds: json['invoice_repartition_line_ids'] == null
      ? const []
      : const OdooMany2ManyConverter().fromJson(
          json['invoice_repartition_line_ids'],
        ),
  refundRepartitionLineIds: json['refund_repartition_line_ids'] == null
      ? const []
      : const OdooMany2ManyConverter().fromJson(
          json['refund_repartition_line_ids'],
        ),
);

Map<String, dynamic> _$AccountTaxToJson(AccountTax instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'amount_type': _$TaxAmountTypeEnumMap[instance.amountType]!,
      'amount': instance.amount,
      'type_tax_use': _$TaxTypeUseEnumMap[instance.typeTaxUse]!,
      'price_include': instance.priceInclude,
      'include_base_amount': instance.includeBaseAmount,
      'is_base_affected': instance.isBaseAffected,
      'sequence': instance.sequence,
      'company_id': const OdooMany2OneConverter().toJson(instance.companyId),
      'tax_group_id': _$JsonConverterToJson<dynamic, int>(
        instance.taxGroupId,
        const OdooMany2OneConverter().toJson,
      ),
      'children_tax_ids': const OdooMany2ManyConverter().toJson(
        instance.childrenTaxIds,
      ),
      'invoice_repartition_line_ids': const OdooMany2ManyConverter().toJson(
        instance.invoiceRepartitionLineIds,
      ),
      'refund_repartition_line_ids': const OdooMany2ManyConverter().toJson(
        instance.refundRepartitionLineIds,
      ),
    };

const _$TaxAmountTypeEnumMap = {
  TaxAmountType.fixed: 'fixed',
  TaxAmountType.percent: 'percent',
  TaxAmountType.division: 'division',
  TaxAmountType.group: 'group',
};

const _$TaxTypeUseEnumMap = {
  TaxTypeUse.sale: 'sale',
  TaxTypeUse.purchase: 'purchase',
  TaxTypeUse.none: 'none',
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
