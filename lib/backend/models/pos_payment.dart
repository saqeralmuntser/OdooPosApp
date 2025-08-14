import 'package:json_annotation/json_annotation.dart';

part 'pos_payment.g.dart';

/// pos.payment - POS Payment
/// Individual payment transaction in a POS order
@JsonSerializable()
class POSPayment {
  final int id;
  final String? name;
  @JsonKey(name: 'pos_order_id')
  final int posOrderId;
  @JsonKey(name: 'payment_method_id')
  final int paymentMethodId;
  final String uuid;
  final double amount;
  @JsonKey(name: 'currency_id')
  final int currencyId;
  @JsonKey(name: 'currency_rate')
  final double currencyRate;
  @JsonKey(name: 'payment_date')
  final DateTime paymentDate;
  @JsonKey(name: 'is_change')
  final bool isChange;
  
  // Card Information
  @JsonKey(name: 'card_type')
  final String? cardType;
  @JsonKey(name: 'card_brand')
  final String? cardBrand;
  @JsonKey(name: 'card_no')
  final String? cardNo;
  @JsonKey(name: 'cardholder_name')
  final String? cardholderName;
  
  // Transaction Information
  @JsonKey(name: 'payment_ref_no')
  final String? paymentRefNo;
  @JsonKey(name: 'payment_method_authcode')
  final String? paymentMethodAuthcode;
  @JsonKey(name: 'payment_method_issuer_bank')
  final String? paymentMethodIssuerBank;
  @JsonKey(name: 'payment_method_payment_mode')
  final String? paymentMethodPaymentMode;
  @JsonKey(name: 'transaction_id')
  final String? transactionId;
  @JsonKey(name: 'payment_status')
  final String? paymentStatus;
  final String? ticket;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'session_id')
  final int? sessionId;
  @JsonKey(name: 'partner_id')
  final int? partnerId;
  @JsonKey(name: 'user_id')
  final int? userId;
  @JsonKey(name: 'company_id')
  final int? companyId;
  @JsonKey(name: 'account_move_id')
  final int? accountMoveId;

  POSPayment({
    required this.id,
    this.name,
    required this.posOrderId,
    required this.paymentMethodId,
    required this.uuid,
    required this.amount,
    required this.currencyId,
    this.currencyRate = 1.0,
    required this.paymentDate,
    this.isChange = false,
    this.cardType,
    this.cardBrand,
    this.cardNo,
    this.cardholderName,
    this.paymentRefNo,
    this.paymentMethodAuthcode,
    this.paymentMethodIssuerBank,
    this.paymentMethodPaymentMode,
    this.transactionId,
    this.paymentStatus,
    this.ticket,
    this.sessionId,
    this.partnerId,
    this.userId,
    this.companyId,
    this.accountMoveId,
  });

  factory POSPayment.fromJson(Map<String, dynamic> json) => _$POSPaymentFromJson(json);
  Map<String, dynamic> toJson() => _$POSPaymentToJson(this);

  /// Check if payment is successful
  bool get isSuccessful => paymentStatus == 'done' || paymentStatus == 'confirmed';

  /// Check if payment is pending
  bool get isPending => paymentStatus == 'pending';

  /// Check if payment failed
  bool get isFailed => paymentStatus == 'failed' || paymentStatus == 'cancelled';

  /// Check if payment is a card payment
  bool get isCardPayment => cardType != null || cardBrand != null;

  /// Check if payment is cash
  bool get isCashPayment => !isCardPayment && !isChange;

  /// Get masked card number for display
  String? get maskedCardNumber {
    if (cardNo == null) return null;
    if (cardNo!.length < 4) return cardNo;
    return '**** **** **** ${cardNo!.substring(cardNo!.length - 4)}';
  }

  /// Get payment type for display
  String get paymentTypeDisplay {
    if (isChange) return 'Change';
    if (isCardPayment) return cardBrand ?? cardType ?? 'Card';
    return 'Cash';
  }

  POSPayment copyWith({
    int? id,
    String? name,
    int? posOrderId,
    int? paymentMethodId,
    String? uuid,
    double? amount,
    int? currencyId,
    double? currencyRate,
    DateTime? paymentDate,
    bool? isChange,
    String? cardType,
    String? cardBrand,
    String? cardNo,
    String? cardholderName,
    String? paymentRefNo,
    String? paymentMethodAuthcode,
    String? paymentMethodIssuerBank,
    String? paymentMethodPaymentMode,
    String? transactionId,
    String? paymentStatus,
    String? ticket,
    int? sessionId,
    int? partnerId,
    int? userId,
    int? companyId,
    int? accountMoveId,
  }) {
    return POSPayment(
      id: id ?? this.id,
      name: name ?? this.name,
      posOrderId: posOrderId ?? this.posOrderId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      uuid: uuid ?? this.uuid,
      amount: amount ?? this.amount,
      currencyId: currencyId ?? this.currencyId,
      currencyRate: currencyRate ?? this.currencyRate,
      paymentDate: paymentDate ?? this.paymentDate,
      isChange: isChange ?? this.isChange,
      cardType: cardType ?? this.cardType,
      cardBrand: cardBrand ?? this.cardBrand,
      cardNo: cardNo ?? this.cardNo,
      cardholderName: cardholderName ?? this.cardholderName,
      paymentRefNo: paymentRefNo ?? this.paymentRefNo,
      paymentMethodAuthcode: paymentMethodAuthcode ?? this.paymentMethodAuthcode,
      paymentMethodIssuerBank: paymentMethodIssuerBank ?? this.paymentMethodIssuerBank,
      paymentMethodPaymentMode: paymentMethodPaymentMode ?? this.paymentMethodPaymentMode,
      transactionId: transactionId ?? this.transactionId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      ticket: ticket ?? this.ticket,
      sessionId: sessionId ?? this.sessionId,
      partnerId: partnerId ?? this.partnerId,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      accountMoveId: accountMoveId ?? this.accountMoveId,
    );
  }
}
