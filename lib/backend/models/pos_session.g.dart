// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSSession _$POSSessionFromJson(Map<String, dynamic> json) => POSSession(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  configId: _extractIdFromArray(json['config_id']),
  userId: _extractIdFromArray(json['user_id']),
  companyId: _extractIdFromArray(json['company_id']),
  currencyId: _extractIdFromArray(json['currency_id']),
  state:
      $enumDecodeNullable(_$POSSessionStateEnumMap, json['state']) ??
      POSSessionState.openingControl,
  startAt: _extractNullableDateTime(json['start_at']),
  stopAt: _extractNullableDateTime(json['stop_at']),
  sequenceNumber: (json['sequence_number'] as num?)?.toInt() ?? 1,
  loginNumber: (json['login_number'] as num?)?.toInt() ?? 0,
  cashControl: json['cash_control'] as bool? ?? false,
  cashJournalId: _extractNullableIdFromArray(json['cash_journal_id']),
  cashRegisterBalanceStart:
      (json['cash_register_balance_start'] as num?)?.toDouble() ?? 0.0,
  cashRegisterBalanceEndReal: (json['cash_register_balance_end_real'] as num?)
      ?.toDouble(),
  cashRegisterBalanceEnd: (json['cash_register_balance_end'] as num?)
      ?.toDouble(),
  cashRegisterDifference: (json['cash_register_difference'] as num?)
      ?.toDouble(),
  cashRealTransaction: (json['cash_real_transaction'] as num?)?.toDouble(),
  openingNotes: _extractNullableString(json['opening_notes']),
  closingNotes: _extractNullableString(json['closing_notes']),
  rescue: json['rescue'] as bool? ?? false,
  updateStockAtClosing: json['update_stock_at_closing'] as bool? ?? false,
  orderIds:
      (json['order_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  statementLineIds:
      (json['statement_line_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  pickingIds:
      (json['picking_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  paymentMethodIds:
      (json['payment_method_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  moveId: _extractNullableIdFromArray(json['move_id']),
  bankPaymentIds:
      (json['bank_payment_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$POSSessionToJson(POSSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'config_id': instance.configId,
      'user_id': instance.userId,
      'company_id': instance.companyId,
      'currency_id': instance.currencyId,
      'state': _$POSSessionStateEnumMap[instance.state]!,
      'start_at': instance.startAt?.toIso8601String(),
      'stop_at': instance.stopAt?.toIso8601String(),
      'sequence_number': instance.sequenceNumber,
      'login_number': instance.loginNumber,
      'cash_control': instance.cashControl,
      'cash_journal_id': instance.cashJournalId,
      'cash_register_balance_start': instance.cashRegisterBalanceStart,
      'cash_register_balance_end_real': instance.cashRegisterBalanceEndReal,
      'cash_register_balance_end': instance.cashRegisterBalanceEnd,
      'cash_register_difference': instance.cashRegisterDifference,
      'cash_real_transaction': instance.cashRealTransaction,
      'opening_notes': instance.openingNotes,
      'closing_notes': instance.closingNotes,
      'rescue': instance.rescue,
      'update_stock_at_closing': instance.updateStockAtClosing,
      'order_ids': instance.orderIds,
      'statement_line_ids': instance.statementLineIds,
      'picking_ids': instance.pickingIds,
      'payment_method_ids': instance.paymentMethodIds,
      'move_id': instance.moveId,
      'bank_payment_ids': instance.bankPaymentIds,
    };

const _$POSSessionStateEnumMap = {
  POSSessionState.openingControl: 'opening_control',
  POSSessionState.opened: 'opened',
  POSSessionState.closingControl: 'closing_control',
  POSSessionState.closed: 'closed',
};
