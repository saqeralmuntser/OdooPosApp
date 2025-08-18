// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSOrder _$POSOrderFromJson(Map<String, dynamic> json) => POSOrder(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  posReference: json['pos_reference'] as String?,
  uuid: json['uuid'] as String,
  sessionId: (json['session_id'] as num).toInt(),
  configId: (json['config_id'] as num).toInt(),
  companyId: (json['company_id'] as num).toInt(),
  partnerId: (json['partner_id'] as num?)?.toInt(),
  userId: (json['user_id'] as num).toInt(),
  dateOrder: DateTime.parse(json['date_order'] as String),
  createDate: DateTime.parse(json['create_date'] as String),
  writeDate: json['write_date'] == null
      ? null
      : DateTime.parse(json['write_date'] as String),
  amountTotal: (json['amount_total'] as num).toDouble(),
  amountTax: (json['amount_tax'] as num).toDouble(),
  amountPaid: (json['amount_paid'] as num).toDouble(),
  amountReturn: (json['amount_return'] as num?)?.toDouble() ?? 0.0,
  currencyId: (json['currency_id'] as num).toInt(),
  currencyRate: (json['currency_rate'] as num?)?.toDouble() ?? 1.0,
  state:
      $enumDecodeNullable(_$POSOrderStateEnumMap, json['state']) ??
      POSOrderState.draft,
  toInvoice: json['to_invoice'] as bool? ?? false,
  isTipped: json['is_tipped'] as bool? ?? false,
  tipAmount: (json['tip_amount'] as num?)?.toDouble() ?? 0.0,
  sequenceNumber: (json['sequence_number'] as num).toInt(),
  fiscalPositionId: (json['fiscal_position_id'] as num?)?.toInt(),
  pricelistId: (json['pricelist_id'] as num).toInt(),
  generalNote: json['general_note'] as String?,
  nbPrint: (json['nb_print'] as num?)?.toInt() ?? 0,
  ticketCode: json['ticket_code'] as String?,
  accessToken: json['access_token'] as String?,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  paymentIds:
      (json['payment_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  statementIds:
      (json['statement_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  pickingIds:
      (json['picking_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  invoiceIds:
      (json['invoice_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  accountMove: (json['account_move'] as num?)?.toInt(),
);

Map<String, dynamic> _$POSOrderToJson(POSOrder instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'pos_reference': instance.posReference,
  'uuid': instance.uuid,
  'session_id': instance.sessionId,
  'config_id': instance.configId,
  'company_id': instance.companyId,
  'partner_id': instance.partnerId,
  'user_id': instance.userId,
  'date_order': instance.dateOrder.toIso8601String(),
  'create_date': instance.createDate.toIso8601String(),
  'write_date': instance.writeDate?.toIso8601String(),
  'amount_total': instance.amountTotal,
  'amount_tax': instance.amountTax,
  'amount_paid': instance.amountPaid,
  'amount_return': instance.amountReturn,
  'currency_id': instance.currencyId,
  'currency_rate': instance.currencyRate,
  'state': _$POSOrderStateEnumMap[instance.state]!,
  'to_invoice': instance.toInvoice,
  'is_tipped': instance.isTipped,
  'tip_amount': instance.tipAmount,
  'sequence_number': instance.sequenceNumber,
  'fiscal_position_id': instance.fiscalPositionId,
  'pricelist_id': instance.pricelistId,
  'general_note': instance.generalNote,
  'nb_print': instance.nbPrint,
  'ticket_code': instance.ticketCode,
  'access_token': instance.accessToken,
  'lines': instance.lines,
  'payment_ids': instance.paymentIds,
  'statement_ids': instance.statementIds,
  'picking_ids': instance.pickingIds,
  'invoice_ids': instance.invoiceIds,
  'account_move': instance.accountMove,
};

const _$POSOrderStateEnumMap = {
  POSOrderState.draft: 'draft',
  POSOrderState.cancel: 'cancel',
  POSOrderState.paid: 'paid',
  POSOrderState.done: 'done',
  POSOrderState.invoiced: 'invoiced',
};
