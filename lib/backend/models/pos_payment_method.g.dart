// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_payment_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSPaymentMethod _$POSPaymentMethodFromJson(Map<String, dynamic> json) =>
    POSPaymentMethod(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      sequence: (json['sequence'] as num?)?.toInt(),
      active: json['active'] as bool?,
      companyId: (json['company_id'] as num?)?.toInt(),
      outstandingAccountId: (json['outstanding_account_id'] as num?)?.toInt(),
      receivableAccountId: (json['receivable_account_id'] as num?)?.toInt(),
      journalId: (json['journal_id'] as num?)?.toInt(),
      isCashCount: json['is_cash_count'] as bool? ?? false,
      splitTransactions: json['split_transactions'] as bool? ?? false,
      usePaymentTerminal: json['use_payment_terminal'] as bool? ?? false,
      openSessionIds:
          (json['open_session_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      configIds:
          (json['config_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$POSPaymentMethodToJson(POSPaymentMethod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'sequence': instance.sequence,
      'active': instance.active,
      'company_id': instance.companyId,
      'outstanding_account_id': instance.outstandingAccountId,
      'receivable_account_id': instance.receivableAccountId,
      'journal_id': instance.journalId,
      'is_cash_count': instance.isCashCount,
      'split_transactions': instance.splitTransactions,
      'use_payment_terminal': instance.usePaymentTerminal,
      'open_session_ids': instance.openSessionIds,
      'config_ids': instance.configIds,
    };
