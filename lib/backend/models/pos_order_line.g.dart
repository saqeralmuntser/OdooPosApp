// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_order_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSOrderLine _$POSOrderLineFromJson(Map<String, dynamic> json) => POSOrderLine(
  id: (json['id'] as num).toInt(),
  orderId: (json['order_id'] as num).toInt(),
  productId: (json['product_id'] as num).toInt(),
  uuid: json['uuid'] as String,
  fullProductName: json['full_product_name'] as String?,
  companyId: (json['company_id'] as num).toInt(),
  qty: (json['qty'] as num).toDouble(),
  priceUnit: (json['price_unit'] as num).toDouble(),
  priceSubtotal: (json['price_subtotal'] as num).toDouble(),
  priceSubtotalIncl: (json['price_subtotal_incl'] as num).toDouble(),
  discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
  margin: (json['margin'] as num?)?.toDouble() ?? 0.0,
  marginPercent: (json['margin_percent'] as num?)?.toDouble() ?? 0.0,
  customerNote: json['customer_note'] as String?,
  refundedOrderlineId: (json['refunded_orderline_id'] as num?)?.toInt(),
  refundedQty: (json['refunded_qty'] as num?)?.toDouble() ?? 0.0,
  totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
  isTotalCostComputed: json['is_total_cost_computed'] as bool? ?? false,
  taxIds:
      (json['tax_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  taxIdsAfterFiscalPosition:
      (json['tax_ids_after_fiscal_position'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  packLotIds:
      (json['pack_lot_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$POSOrderLineToJson(POSOrderLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_id': instance.orderId,
      'product_id': instance.productId,
      'uuid': instance.uuid,
      'full_product_name': instance.fullProductName,
      'company_id': instance.companyId,
      'qty': instance.qty,
      'price_unit': instance.priceUnit,
      'price_subtotal': instance.priceSubtotal,
      'price_subtotal_incl': instance.priceSubtotalIncl,
      'discount': instance.discount,
      'margin': instance.margin,
      'margin_percent': instance.marginPercent,
      'customer_note': instance.customerNote,
      'refunded_orderline_id': instance.refundedOrderlineId,
      'refunded_qty': instance.refundedQty,
      'total_cost': instance.totalCost,
      'is_total_cost_computed': instance.isTotalCostComputed,
      'tax_ids': instance.taxIds,
      'tax_ids_after_fiscal_position': instance.taxIdsAfterFiscalPosition,
      'pack_lot_ids': instance.packLotIds,
    };
