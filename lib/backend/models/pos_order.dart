import 'package:json_annotation/json_annotation.dart';

part 'pos_order.g.dart';

/// pos.order - POS Order
/// Complete representation of a Point of Sale order
@JsonSerializable()
class POSOrder {
  final int id;
  final String name;
  @JsonKey(name: 'pos_reference')
  final String? posReference;
  final String uuid;
  @JsonKey(name: 'session_id')
  final int sessionId;
  @JsonKey(name: 'config_id')
  final int configId;
  @JsonKey(name: 'company_id')
  final int companyId;
  @JsonKey(name: 'partner_id')
  final int? partnerId;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'salesman_id')
  final int? salesmanId;
  
  // Timing
  @JsonKey(name: 'date_order')
  final DateTime dateOrder;
  @JsonKey(name: 'create_date')
  final DateTime createDate;
  @JsonKey(name: 'write_date')
  final DateTime? writeDate;
  
  // Amounts and Calculations
  @JsonKey(name: 'amount_total')
  final double amountTotal;
  @JsonKey(name: 'amount_tax')
  final double amountTax;
  @JsonKey(name: 'amount_paid')
  final double amountPaid;
  @JsonKey(name: 'amount_return')
  final double amountReturn;
  @JsonKey(name: 'currency_id')
  final int currencyId;
  @JsonKey(name: 'currency_rate')
  final double currencyRate;
  
  // Order State
  final POSOrderState state;
  @JsonKey(name: 'to_invoice')
  final bool toInvoice;
  @JsonKey(name: 'is_invoiced')
  final bool isInvoiced;
  @JsonKey(name: 'is_tipped')
  final bool isTipped;
  @JsonKey(name: 'tip_amount')
  final double tipAmount;
  
  // Additional Settings
  @JsonKey(name: 'sequence_number')
  final int sequenceNumber;
  @JsonKey(name: 'tracking_number')
  final String? trackingNumber;
  @JsonKey(name: 'fiscal_position_id')
  final int? fiscalPositionId;
  @JsonKey(name: 'pricelist_id')
  final int pricelistId;
  final String? note;
  @JsonKey(name: 'nb_print')
  final int nbPrint;
  @JsonKey(name: 'pos_session_id')
  final int? posSessionId;
  @JsonKey(name: 'ticket_code')
  final String? ticketCode;
  @JsonKey(name: 'access_token')
  final String? accessToken;
  
  // Relationships (stored as IDs)
  final List<int> lines;
  @JsonKey(name: 'payment_ids')
  final List<int> paymentIds;
  @JsonKey(name: 'statement_ids')
  final List<int> statementIds;
  @JsonKey(name: 'picking_ids')
  final List<int> pickingIds;
  @JsonKey(name: 'invoice_ids')
  final List<int> invoiceIds;
  @JsonKey(name: 'account_move')
  final int? accountMove;

  POSOrder({
    required this.id,
    required this.name,
    this.posReference,
    required this.uuid,
    required this.sessionId,
    required this.configId,
    required this.companyId,
    this.partnerId,
    required this.userId,
    this.salesmanId,
    required this.dateOrder,
    required this.createDate,
    this.writeDate,
    required this.amountTotal,
    required this.amountTax,
    required this.amountPaid,
    this.amountReturn = 0.0,
    required this.currencyId,
    this.currencyRate = 1.0,
    this.state = POSOrderState.draft,
    this.toInvoice = false,
    this.isInvoiced = false,
    this.isTipped = false,
    this.tipAmount = 0.0,
    required this.sequenceNumber,
    this.trackingNumber,
    this.fiscalPositionId,
    required this.pricelistId,
    this.note,
    this.nbPrint = 0,
    this.posSessionId,
    this.ticketCode,
    this.accessToken,
    this.lines = const [],
    this.paymentIds = const [],
    this.statementIds = const [],
    this.pickingIds = const [],
    this.invoiceIds = const [],
    this.accountMove,
  });

  factory POSOrder.fromJson(Map<String, dynamic> json) => _$POSOrderFromJson(json);
  Map<String, dynamic> toJson() => _$POSOrderToJson(this);

  /// Calculate subtotal (amount without tax)
  double get subtotal => amountTotal - amountTax;

  /// Check if order is fully paid
  bool get isFullyPaid => amountPaid >= amountTotal;

  /// Get remaining amount to pay
  double get remainingAmount => amountTotal - amountPaid;

  /// Check if order has change to return
  bool get hasChange => amountReturn > 0;

  /// Check if order is in draft state
  bool get isDraft => state == POSOrderState.draft;

  /// Check if order is cancelled
  bool get isCancelled => state == POSOrderState.cancel;

  /// Check if order is paid
  bool get isPaid => state == POSOrderState.paid;

  /// Check if order is done
  bool get isDone => state == POSOrderState.done;

  /// Check if order can be modified
  bool get canModify => state == POSOrderState.draft;

  /// Check if order can be paid
  bool get canPay => state == POSOrderState.draft && lines.isNotEmpty;

  /// Check if order can be cancelled
  bool get canCancel => state == POSOrderState.draft;

  POSOrder copyWith({
    int? id,
    String? name,
    String? posReference,
    String? uuid,
    int? sessionId,
    int? configId,
    int? companyId,
    int? partnerId,
    int? userId,
    int? salesmanId,
    DateTime? dateOrder,
    DateTime? createDate,
    DateTime? writeDate,
    double? amountTotal,
    double? amountTax,
    double? amountPaid,
    double? amountReturn,
    int? currencyId,
    double? currencyRate,
    POSOrderState? state,
    bool? toInvoice,
    bool? isInvoiced,
    bool? isTipped,
    double? tipAmount,
    int? sequenceNumber,
    String? trackingNumber,
    int? fiscalPositionId,
    int? pricelistId,
    String? note,
    int? nbPrint,
    int? posSessionId,
    String? ticketCode,
    String? accessToken,
    List<int>? lines,
    List<int>? paymentIds,
    List<int>? statementIds,
    List<int>? pickingIds,
    List<int>? invoiceIds,
    int? accountMove,
  }) {
    return POSOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      posReference: posReference ?? this.posReference,
      uuid: uuid ?? this.uuid,
      sessionId: sessionId ?? this.sessionId,
      configId: configId ?? this.configId,
      companyId: companyId ?? this.companyId,
      partnerId: partnerId ?? this.partnerId,
      userId: userId ?? this.userId,
      salesmanId: salesmanId ?? this.salesmanId,
      dateOrder: dateOrder ?? this.dateOrder,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
      amountTotal: amountTotal ?? this.amountTotal,
      amountTax: amountTax ?? this.amountTax,
      amountPaid: amountPaid ?? this.amountPaid,
      amountReturn: amountReturn ?? this.amountReturn,
      currencyId: currencyId ?? this.currencyId,
      currencyRate: currencyRate ?? this.currencyRate,
      state: state ?? this.state,
      toInvoice: toInvoice ?? this.toInvoice,
      isInvoiced: isInvoiced ?? this.isInvoiced,
      isTipped: isTipped ?? this.isTipped,
      tipAmount: tipAmount ?? this.tipAmount,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      fiscalPositionId: fiscalPositionId ?? this.fiscalPositionId,
      pricelistId: pricelistId ?? this.pricelistId,
      note: note ?? this.note,
      nbPrint: nbPrint ?? this.nbPrint,
      posSessionId: posSessionId ?? this.posSessionId,
      ticketCode: ticketCode ?? this.ticketCode,
      accessToken: accessToken ?? this.accessToken,
      lines: lines ?? this.lines,
      paymentIds: paymentIds ?? this.paymentIds,
      statementIds: statementIds ?? this.statementIds,
      pickingIds: pickingIds ?? this.pickingIds,
      invoiceIds: invoiceIds ?? this.invoiceIds,
      accountMove: accountMove ?? this.accountMove,
    );
  }
}

/// POS Order states according to Odoo 18 specification
@JsonEnum()
enum POSOrderState {
  @JsonValue('draft')
  draft,
  
  @JsonValue('cancel')
  cancel,
  
  @JsonValue('paid')
  paid,
  
  @JsonValue('done')
  done,
  
  @JsonValue('invoiced')
  invoiced,
}

/// Extension for POSOrderState
extension POSOrderStateExtension on POSOrderState {
  String get displayName {
    switch (this) {
      case POSOrderState.draft:
        return 'Draft';
      case POSOrderState.cancel:
        return 'Cancelled';
      case POSOrderState.paid:
        return 'Paid';
      case POSOrderState.done:
        return 'Done';
      case POSOrderState.invoiced:
        return 'Invoiced';
    }
  }

  String get colorCode {
    switch (this) {
      case POSOrderState.draft:
        return '#9E9E9E'; // Grey
      case POSOrderState.cancel:
        return '#F44336'; // Red
      case POSOrderState.paid:
        return '#4CAF50'; // Green
      case POSOrderState.done:
        return '#2196F3'; // Blue
      case POSOrderState.invoiced:
        return '#9C27B0'; // Purple
    }
  }

  bool get isCompleted {
    return this == POSOrderState.paid || 
           this == POSOrderState.done || 
           this == POSOrderState.invoiced;
  }

  bool get canModify {
    return this == POSOrderState.draft;
  }
}
