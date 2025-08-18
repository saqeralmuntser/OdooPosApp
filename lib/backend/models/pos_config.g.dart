// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

POSConfig _$POSConfigFromJson(Map<String, dynamic> json) => POSConfig(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  active: json['active'] as bool? ?? true,
  companyId: _extractIdFromArray(json['company_id']),
  currencyId: _extractIdFromArray(json['currency_id']),
  pricelistId: _extractNullableIdFromArray(json['pricelist_id']),
  journalId: _extractNullableIdFromArray(json['journal_id']),
  invoiceJournalId: _extractNullableIdFromArray(json['invoice_journal_id']),
  pickingTypeId: _extractNullableIdFromArray(json['picking_type_id']),
  warehouseId: _extractNullableIdFromArray(json['warehouse_id']),
  ifaceCashdrawer: json['iface_cashdrawer'] as bool?,
  ifaceElectronicScale: json['iface_electronic_scale'] as bool?,
  ifaceCustomerFacingDisplay: json['iface_customer_facing_display'] as String?,
  ifacePrintAuto: json['iface_print_auto'] as bool?,
  ifacePrintSkipScreen: json['iface_print_skip_screen'] as bool?,
  ifaceScanViaProxy: json['iface_scan_via_proxy'] as bool?,
  ifaceBigScrollbars: json['iface_big_scrollbars'] as bool?,
  ifacePrintViaProxy: json['iface_print_via_proxy'] as bool?,
  modulePosRestaurant: json['module_pos_restaurant'] as bool?,
  modulePosDiscount: json['module_pos_discount'] as bool?,
  modulePosLoyalty: json['module_pos_loyalty'] as bool?,
  modulePosMercury: json['module_pos_mercury'] as bool?,
  usePricelist: json['use_pricelist'] as bool?,
  groupBy: json['group_by'] as bool?,
  limitCategories: json['limit_categories'] as bool?,
  restrictPriceControl: json['restrict_price_control'] as bool?,
  cashControl: json['cash_control'] as bool?,
  receiptHeader: _extractNullableString(json['receipt_header']),
  receiptFooter: _extractNullableString(json['receipt_footer']),
  proxyIp: _extractNullableString(json['proxy_ip']),
  otherDevices: _extractNullableString(json['other_devices']),
  paymentMethodIds: (json['payment_method_ids'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  availablePricelistIds: (json['available_pricelist_ids'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  printerIds: (json['printer_ids'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  ifaceAvailableCategIds: (json['iface_available_categ_ids'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$POSConfigToJson(POSConfig instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'active': instance.active,
  'company_id': instance.companyId,
  'currency_id': instance.currencyId,
  'pricelist_id': instance.pricelistId,
  'journal_id': instance.journalId,
  'invoice_journal_id': instance.invoiceJournalId,
  'picking_type_id': instance.pickingTypeId,
  'warehouse_id': instance.warehouseId,
  'iface_cashdrawer': instance.ifaceCashdrawer,
  'iface_electronic_scale': instance.ifaceElectronicScale,
  'iface_customer_facing_display': instance.ifaceCustomerFacingDisplay,
  'iface_print_auto': instance.ifacePrintAuto,
  'iface_print_skip_screen': instance.ifacePrintSkipScreen,
  'iface_scan_via_proxy': instance.ifaceScanViaProxy,
  'iface_big_scrollbars': instance.ifaceBigScrollbars,
  'iface_print_via_proxy': instance.ifacePrintViaProxy,
  'module_pos_restaurant': instance.modulePosRestaurant,
  'module_pos_discount': instance.modulePosDiscount,
  'module_pos_loyalty': instance.modulePosLoyalty,
  'module_pos_mercury': instance.modulePosMercury,
  'use_pricelist': instance.usePricelist,
  'group_by': instance.groupBy,
  'limit_categories': instance.limitCategories,
  'restrict_price_control': instance.restrictPriceControl,
  'cash_control': instance.cashControl,
  'receipt_header': instance.receiptHeader,
  'receipt_footer': instance.receiptFooter,
  'proxy_ip': instance.proxyIp,
  'other_devices': instance.otherDevices,
  'payment_method_ids': instance.paymentMethodIds,
  'available_pricelist_ids': instance.availablePricelistIds,
  'printer_ids': instance.printerIds,
  'iface_available_categ_ids': instance.ifaceAvailableCategIds,
};
