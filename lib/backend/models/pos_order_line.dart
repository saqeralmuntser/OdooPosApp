import 'package:json_annotation/json_annotation.dart';

part 'pos_order_line.g.dart';

/// pos.order.line - POS Order Line
/// Individual line item in a POS order
@JsonSerializable()
class POSOrderLine {
  final int id;
  @JsonKey(name: 'order_id')
  final int orderId;
  @JsonKey(name: 'product_id')
  final int productId;
  final String uuid;
  @JsonKey(name: 'full_product_name')
  final String? fullProductName;
  @JsonKey(name: 'company_id')
  final int companyId;
  
  // Quantities and Pricing
  final double qty;
  @JsonKey(name: 'price_unit')
  final double priceUnit;
  @JsonKey(name: 'price_subtotal')
  final double priceSubtotal;
  @JsonKey(name: 'price_subtotal_incl')
  final double priceSubtotalIncl;
  final double discount;
  final double margin;
  @JsonKey(name: 'margin_percent')
  final double marginPercent;
  
  // Additional Information
  @JsonKey(name: 'customer_note')
  final String? customerNote;
  @JsonKey(name: 'refunded_orderline_id')
  final int? refundedOrderlineId;
  @JsonKey(name: 'refunded_qty')
  final double refundedQty;
  @JsonKey(name: 'total_cost')
  final double totalCost;
  @JsonKey(name: 'is_total_cost_computed')
  final bool isTotalCostComputed;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'tax_ids')
  final List<int> taxIds;
  @JsonKey(name: 'tax_ids_after_fiscal_position')
  final List<int> taxIdsAfterFiscalPosition;
  @JsonKey(name: 'pack_lot_ids')
  final List<int> packLotIds;
  @JsonKey(name: 'custom_attribute_value_ids')
  final List<int> customAttributeValueIds;

  POSOrderLine({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.uuid,
    this.fullProductName,
    required this.companyId,
    required this.qty,
    required this.priceUnit,
    required this.priceSubtotal,
    required this.priceSubtotalIncl,
    this.discount = 0.0,
    this.margin = 0.0,
    this.marginPercent = 0.0,
    this.customerNote,
    this.refundedOrderlineId,
    this.refundedQty = 0.0,
    this.totalCost = 0.0,
    this.isTotalCostComputed = false,
    this.taxIds = const [],
    this.taxIdsAfterFiscalPosition = const [],
    this.packLotIds = const [],
    this.customAttributeValueIds = const [],
  });

  factory POSOrderLine.fromJson(Map<String, dynamic> json) => _$POSOrderLineFromJson(json);
  Map<String, dynamic> toJson() => _$POSOrderLineToJson(this);

  /// Calculate discount amount
  double get discountAmount => priceSubtotal * (discount / 100);

  /// Calculate tax amount
  double get taxAmount => priceSubtotalIncl - priceSubtotal;

  /// Check if line has discount
  bool get hasDiscount => discount > 0;

  /// Check if line has tax
  bool get hasTax => taxIds.isNotEmpty;

  /// Check if line is refunded
  bool get isRefunded => refundedOrderlineId != null || refundedQty > 0;

  /// Check if line has custom attributes
  bool get hasCustomAttributes => customAttributeValueIds.isNotEmpty;

  /// Check if line has lot/serial numbers
  bool get hasLotNumbers => packLotIds.isNotEmpty;

  /// Get net quantity (qty - refunded)
  double get netQuantity => qty - refundedQty;

  /// Calculate profit per unit
  double get profitPerUnit => priceUnit - (totalCost / qty);

  /// Calculate total profit for this line
  double get totalProfit => profitPerUnit * qty;

  POSOrderLine copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? uuid,
    String? fullProductName,
    int? companyId,
    double? qty,
    double? priceUnit,
    double? priceSubtotal,
    double? priceSubtotalIncl,
    double? discount,
    double? margin,
    double? marginPercent,
    String? customerNote,
    int? refundedOrderlineId,
    double? refundedQty,
    double? totalCost,
    bool? isTotalCostComputed,
    List<int>? taxIds,
    List<int>? taxIdsAfterFiscalPosition,
    List<int>? packLotIds,
    List<int>? customAttributeValueIds,
  }) {
    return POSOrderLine(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      uuid: uuid ?? this.uuid,
      fullProductName: fullProductName ?? this.fullProductName,
      companyId: companyId ?? this.companyId,
      qty: qty ?? this.qty,
      priceUnit: priceUnit ?? this.priceUnit,
      priceSubtotal: priceSubtotal ?? this.priceSubtotal,
      priceSubtotalIncl: priceSubtotalIncl ?? this.priceSubtotalIncl,
      discount: discount ?? this.discount,
      margin: margin ?? this.margin,
      marginPercent: marginPercent ?? this.marginPercent,
      customerNote: customerNote ?? this.customerNote,
      refundedOrderlineId: refundedOrderlineId ?? this.refundedOrderlineId,
      refundedQty: refundedQty ?? this.refundedQty,
      totalCost: totalCost ?? this.totalCost,
      isTotalCostComputed: isTotalCostComputed ?? this.isTotalCostComputed,
      taxIds: taxIds ?? this.taxIds,
      taxIdsAfterFiscalPosition: taxIdsAfterFiscalPosition ?? this.taxIdsAfterFiscalPosition,
      packLotIds: packLotIds ?? this.packLotIds,
      customAttributeValueIds: customAttributeValueIds ?? this.customAttributeValueIds,
    );
  }
}
