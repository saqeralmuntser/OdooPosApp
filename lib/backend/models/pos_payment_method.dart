import 'package:json_annotation/json_annotation.dart';

part 'pos_payment_method.g.dart';

/// pos.payment.method - POS Payment Method
/// Defines available payment methods for POS
@JsonSerializable()
class POSPaymentMethod {
  final int id;
  final String name;
  final int? sequence;
  final bool? active;
  @JsonKey(name: 'company_id')
  final int? companyId;
  
  // Account Settings
  @JsonKey(name: 'outstanding_account_id')
  final int? outstandingAccountId;
  @JsonKey(name: 'receivable_account_id')
  final int? receivableAccountId;
  @JsonKey(name: 'journal_id')
  final int? journalId;
  
  // Behavior Settings
  @JsonKey(name: 'is_cash_count')
  final bool isCashCount;
  @JsonKey(name: 'split_transactions')
  final bool splitTransactions;
  @JsonKey(name: 'use_payment_terminal')
  final bool usePaymentTerminal;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'open_session_ids')
  final List<int> openSessionIds;
  @JsonKey(name: 'config_ids')
  final List<int> configIds;

  POSPaymentMethod({
    required this.id,
    required this.name,
    this.sequence,
    this.active,
    this.companyId,
    this.outstandingAccountId,
    this.receivableAccountId,
    this.journalId,
    this.isCashCount = false,
    this.splitTransactions = false,
    this.usePaymentTerminal = false,
    this.openSessionIds = const [],
    this.configIds = const [],
  });

  factory POSPaymentMethod.fromJson(Map<String, dynamic> json) => _$POSPaymentMethodFromJson(json);
  Map<String, dynamic> toJson() => _$POSPaymentMethodToJson(this);

  /// Check if this is a cash payment method
  bool get isCash => isCashCount;

  /// Check if this is a card payment method
  bool get isCard => usePaymentTerminal;

  /// Check if payment method requires terminal
  bool get requiresTerminal => usePaymentTerminal;

  /// Get payment method type
  PaymentMethodType get type {
    if (isCash) return PaymentMethodType.cash;
    if (isCard) return PaymentMethodType.card;
    return PaymentMethodType.other;
  }

  POSPaymentMethod copyWith({
    int? id,
    String? name,
    int? sequence,
    bool? active,
    int? companyId,
    int? outstandingAccountId,
    int? receivableAccountId,
    int? journalId,
    bool? isCashCount,
    bool? splitTransactions,
    bool? usePaymentTerminal,
    List<int>? openSessionIds,
    List<int>? configIds,
  }) {
    return POSPaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      sequence: sequence ?? this.sequence,
      active: active ?? this.active,
      companyId: companyId ?? this.companyId,
      outstandingAccountId: outstandingAccountId ?? this.outstandingAccountId,
      receivableAccountId: receivableAccountId ?? this.receivableAccountId,
      journalId: journalId ?? this.journalId,
      isCashCount: isCashCount ?? this.isCashCount,
      splitTransactions: splitTransactions ?? this.splitTransactions,
      usePaymentTerminal: usePaymentTerminal ?? this.usePaymentTerminal,
      openSessionIds: openSessionIds ?? this.openSessionIds,
      configIds: configIds ?? this.configIds,
    );
  }
}

/// Payment method types
enum PaymentMethodType {
  cash,
  card,
  other,
}

/// Extension for PaymentMethodType
extension PaymentMethodTypeExtension on PaymentMethodType {
  String get displayName {
    switch (this) {
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.card:
        return 'Card';
      case PaymentMethodType.other:
        return 'Other';
    }
  }

  String get iconCode {
    switch (this) {
      case PaymentMethodType.cash:
        return '💵';
      case PaymentMethodType.card:
        return '💳';
      case PaymentMethodType.other:
        return '💰';
    }
  }
}
