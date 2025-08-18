// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSPayment _$POSPaymentFromJson(Map<String, dynamic> json) => POSPayment(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String?,
  posOrderId: (json['pos_order_id'] as num).toInt(),
  paymentMethodId: (json['payment_method_id'] as num).toInt(),
  uuid: json['uuid'] as String,
  amount: (json['amount'] as num).toDouble(),
  currencyId: (json['currency_id'] as num).toInt(),
  currencyRate: (json['currency_rate'] as num?)?.toDouble() ?? 1.0,
  paymentDate: DateTime.parse(json['payment_date'] as String),
  isChange: json['is_change'] as bool? ?? false,
  cardType: json['card_type'] as String?,
  cardBrand: json['card_brand'] as String?,
  cardNo: json['card_no'] as String?,
  cardholderName: json['cardholder_name'] as String?,
  paymentRefNo: json['payment_ref_no'] as String?,
  paymentMethodAuthcode: json['payment_method_authcode'] as String?,
  paymentMethodIssuerBank: json['payment_method_issuer_bank'] as String?,
  paymentMethodPaymentMode: json['payment_method_payment_mode'] as String?,
  transactionId: json['transaction_id'] as String?,
  paymentStatus: json['payment_status'] as String?,
  ticket: json['ticket'] as String?,
  sessionId: (json['session_id'] as num?)?.toInt(),
  partnerId: (json['partner_id'] as num?)?.toInt(),
  userId: (json['user_id'] as num?)?.toInt(),
  companyId: (json['company_id'] as num?)?.toInt(),
  accountMoveId: (json['account_move_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$POSPaymentToJson(POSPayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'pos_order_id': instance.posOrderId,
      'payment_method_id': instance.paymentMethodId,
      'uuid': instance.uuid,
      'amount': instance.amount,
      'currency_id': instance.currencyId,
      'currency_rate': instance.currencyRate,
      'payment_date': instance.paymentDate.toIso8601String(),
      'is_change': instance.isChange,
      'card_type': instance.cardType,
      'card_brand': instance.cardBrand,
      'card_no': instance.cardNo,
      'cardholder_name': instance.cardholderName,
      'payment_ref_no': instance.paymentRefNo,
      'payment_method_authcode': instance.paymentMethodAuthcode,
      'payment_method_issuer_bank': instance.paymentMethodIssuerBank,
      'payment_method_payment_mode': instance.paymentMethodPaymentMode,
      'transaction_id': instance.transactionId,
      'payment_status': instance.paymentStatus,
      'ticket': instance.ticket,
      'session_id': instance.sessionId,
      'partner_id': instance.partnerId,
      'user_id': instance.userId,
      'company_id': instance.companyId,
      'account_move_id': instance.accountMoveId,
    };
