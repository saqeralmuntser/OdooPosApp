import 'package:json_annotation/json_annotation.dart';

part 'pos_session.g.dart';

/// pos.session - POS Session Management
/// Represents a complete POS session with all states and controls
@JsonSerializable()
class POSSession {
  final int id;
  final String name;
  
  // References
  @JsonKey(name: 'config_id')
  final int configId;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'company_id')
  final int companyId;
  @JsonKey(name: 'currency_id')
  final int currencyId;
  
  // Session State and Timing
  final POSSessionState state;
  @JsonKey(name: 'start_at')
  final DateTime? startAt;
  @JsonKey(name: 'stop_at')
  final DateTime? stopAt;
  @JsonKey(name: 'sequence_number')
  final int sequenceNumber;
  @JsonKey(name: 'login_number')
  final int loginNumber;
  
  // Cash Management
  @JsonKey(name: 'cash_control')
  final bool cashControl;
  @JsonKey(name: 'cash_journal_id')
  final int? cashJournalId;
  @JsonKey(name: 'cash_register_balance_start')
  final double cashRegisterBalanceStart;
  @JsonKey(name: 'cash_register_balance_end_real')
  final double? cashRegisterBalanceEndReal;
  @JsonKey(name: 'cash_register_balance_end')
  final double? cashRegisterBalanceEnd;
  @JsonKey(name: 'cash_register_difference')
  final double? cashRegisterDifference;
  @JsonKey(name: 'cash_real_transaction')
  final double? cashRealTransaction;
  
  // Notes and Control
  @JsonKey(name: 'opening_notes')
  final String? openingNotes;
  @JsonKey(name: 'closing_notes')
  final String? closingNotes;
  final bool rescue;
  @JsonKey(name: 'update_stock_at_closing')
  final bool updateStockAtClosing;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'order_ids')
  final List<int> orderIds;
  @JsonKey(name: 'statement_line_ids')
  final List<int> statementLineIds;
  @JsonKey(name: 'picking_ids')
  final List<int> pickingIds;
  @JsonKey(name: 'payment_method_ids')
  final List<int> paymentMethodIds;
  @JsonKey(name: 'move_id')
  final int? moveId;
  @JsonKey(name: 'bank_payment_ids')
  final List<int> bankPaymentIds;

  POSSession({
    required this.id,
    required this.name,
    required this.configId,
    required this.userId,
    required this.companyId,
    required this.currencyId,
    this.state = POSSessionState.openingControl,
    this.startAt,
    this.stopAt,
    this.sequenceNumber = 1,
    this.loginNumber = 0,
    this.cashControl = false,
    this.cashJournalId,
    this.cashRegisterBalanceStart = 0.0,
    this.cashRegisterBalanceEndReal,
    this.cashRegisterBalanceEnd,
    this.cashRegisterDifference,
    this.cashRealTransaction,
    this.openingNotes,
    this.closingNotes,
    this.rescue = false,
    this.updateStockAtClosing = false,
    this.orderIds = const [],
    this.statementLineIds = const [],
    this.pickingIds = const [],
    this.paymentMethodIds = const [],
    this.moveId,
    this.bankPaymentIds = const [],
  });

  factory POSSession.fromJson(Map<String, dynamic> json) => _$POSSessionFromJson(json);
  Map<String, dynamic> toJson() => _$POSSessionToJson(this);

  /// Check if session can be opened
  bool get canOpen => state == POSSessionState.openingControl;

  /// Check if session is open and active
  bool get isOpen => state == POSSessionState.opened;

  /// Check if session can be closed
  bool get canClose => state == POSSessionState.opened;

  /// Check if session is in closing control
  bool get isClosing => state == POSSessionState.closingControl;

  /// Check if session is closed
  bool get isClosed => state == POSSessionState.closed;

  /// Calculate cash difference
  double get calculatedCashDifference {
    if (cashRegisterBalanceEndReal == null || cashRegisterBalanceEnd == null) {
      return 0.0;
    }
    return cashRegisterBalanceEndReal! - cashRegisterBalanceEnd!;
  }

  POSSession copyWith({
    int? id,
    String? name,
    int? configId,
    int? userId,
    int? companyId,
    int? currencyId,
    POSSessionState? state,
    DateTime? startAt,
    DateTime? stopAt,
    int? sequenceNumber,
    int? loginNumber,
    bool? cashControl,
    int? cashJournalId,
    double? cashRegisterBalanceStart,
    double? cashRegisterBalanceEndReal,
    double? cashRegisterBalanceEnd,
    double? cashRegisterDifference,
    double? cashRealTransaction,
    String? openingNotes,
    String? closingNotes,
    bool? rescue,
    bool? updateStockAtClosing,
    List<int>? orderIds,
    List<int>? statementLineIds,
    List<int>? pickingIds,
    List<int>? paymentMethodIds,
    int? moveId,
    List<int>? bankPaymentIds,
  }) {
    return POSSession(
      id: id ?? this.id,
      name: name ?? this.name,
      configId: configId ?? this.configId,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      currencyId: currencyId ?? this.currencyId,
      state: state ?? this.state,
      startAt: startAt ?? this.startAt,
      stopAt: stopAt ?? this.stopAt,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      loginNumber: loginNumber ?? this.loginNumber,
      cashControl: cashControl ?? this.cashControl,
      cashJournalId: cashJournalId ?? this.cashJournalId,
      cashRegisterBalanceStart: cashRegisterBalanceStart ?? this.cashRegisterBalanceStart,
      cashRegisterBalanceEndReal: cashRegisterBalanceEndReal ?? this.cashRegisterBalanceEndReal,
      cashRegisterBalanceEnd: cashRegisterBalanceEnd ?? this.cashRegisterBalanceEnd,
      cashRegisterDifference: cashRegisterDifference ?? this.cashRegisterDifference,
      cashRealTransaction: cashRealTransaction ?? this.cashRealTransaction,
      openingNotes: openingNotes ?? this.openingNotes,
      closingNotes: closingNotes ?? this.closingNotes,
      rescue: rescue ?? this.rescue,
      updateStockAtClosing: updateStockAtClosing ?? this.updateStockAtClosing,
      orderIds: orderIds ?? this.orderIds,
      statementLineIds: statementLineIds ?? this.statementLineIds,
      pickingIds: pickingIds ?? this.pickingIds,
      paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
      moveId: moveId ?? this.moveId,
      bankPaymentIds: bankPaymentIds ?? this.bankPaymentIds,
    );
  }
}

/// Session states according to Odoo 18 specification
@JsonEnum()
enum POSSessionState {
  @JsonValue('opening_control')
  openingControl,
  
  @JsonValue('opened')
  opened,
  
  @JsonValue('closing_control')
  closingControl,
  
  @JsonValue('closed')
  closed,
}

/// Extension for POSSessionState
extension POSSessionStateExtension on POSSessionState {
  String get displayName {
    switch (this) {
      case POSSessionState.openingControl:
        return 'Opening Control';
      case POSSessionState.opened:
        return 'Opened';
      case POSSessionState.closingControl:
        return 'Closing Control';
      case POSSessionState.closed:
        return 'Closed';
    }
  }

  bool get isActive {
    return this == POSSessionState.opened;
  }

  bool get canProcessOrders {
    return this == POSSessionState.opened;
  }
}
