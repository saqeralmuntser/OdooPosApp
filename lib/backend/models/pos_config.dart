import 'package:json_annotation/json_annotation.dart';
import 'pos_printer.dart';

part 'pos_config.g.dart';

/// Helper function to extract ID from Odoo array format [id, name]
int _extractIdFromArray(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  }
  throw FormatException('Invalid ID format: $value');
}

/// Helper function to extract nullable ID from Odoo array format
int? _extractNullableIdFromArray(dynamic value) {
  if (value == false || value == null) {
    return null;
  }
  if (value is List && value.isNotEmpty) {
    return value[0] as int;
  } else if (value is int) {
    return value;
  }
  return null;
}

/// Helper function to handle nullable strings that might be false
String? _extractNullableString(dynamic value) {
  if (value == false || value == null) {
    return null;
  }
  return value.toString();
}

/// pos.config - Point of Sale Configuration
/// Represents the complete configuration for a POS terminal
@JsonSerializable()
class POSConfig {
  final int id;
  final String name;
  final bool active;
  
  // Company and Currency
  @JsonKey(name: 'company_id', fromJson: _extractIdFromArray)
  final int companyId;
  @JsonKey(name: 'currency_id', fromJson: _extractIdFromArray)
  final int currencyId;
  
  // Core Settings
  @JsonKey(name: 'pricelist_id', fromJson: _extractNullableIdFromArray)
  final int? pricelistId;
  @JsonKey(name: 'journal_id', fromJson: _extractNullableIdFromArray)
  final int? journalId;
  @JsonKey(name: 'invoice_journal_id', fromJson: _extractNullableIdFromArray)
  final int? invoiceJournalId;
  @JsonKey(name: 'picking_type_id', fromJson: _extractNullableIdFromArray)
  final int? pickingTypeId;
  @JsonKey(name: 'warehouse_id', fromJson: _extractNullableIdFromArray)
  final int? warehouseId;
  
  // Interface Settings
  @JsonKey(name: 'iface_cashdrawer')
  final bool? ifaceCashdrawer;
  @JsonKey(name: 'iface_electronic_scale')
  final bool? ifaceElectronicScale;
  @JsonKey(name: 'iface_customer_facing_display')
  final String? ifaceCustomerFacingDisplay;
  @JsonKey(name: 'iface_print_auto')
  final bool? ifacePrintAuto;
  @JsonKey(name: 'iface_print_skip_screen')
  final bool? ifacePrintSkipScreen;
  @JsonKey(name: 'iface_scan_via_proxy')
  final bool? ifaceScanViaProxy;
  @JsonKey(name: 'iface_big_scrollbars')
  final bool? ifaceBigScrollbars;
  @JsonKey(name: 'iface_print_via_proxy')
  final bool? ifacePrintViaProxy;
  
  // Module Settings
  @JsonKey(name: 'module_pos_restaurant')
  final bool? modulePosRestaurant;
  @JsonKey(name: 'module_pos_discount')
  final bool? modulePosDiscount;
  @JsonKey(name: 'module_pos_loyalty')
  final bool? modulePosLoyalty;
  @JsonKey(name: 'module_pos_mercury')
  final bool? modulePosMercury;
  
  // Features
  @JsonKey(name: 'use_pricelist')
  final bool? usePricelist;
  @JsonKey(name: 'group_by')
  final bool? groupBy;
  @JsonKey(name: 'limit_categories')
  final bool? limitCategories;
  @JsonKey(name: 'restrict_price_control')
  final bool? restrictPriceControl;
  @JsonKey(name: 'cash_control')
  final bool? cashControl;
  
  // Receipt Settings
  @JsonKey(name: 'receipt_header', fromJson: _extractNullableString)
  final String? receiptHeader;
  @JsonKey(name: 'receipt_footer', fromJson: _extractNullableString)
  final String? receiptFooter;
  @JsonKey(name: 'receipt_printer_type')
  final ReceiptPrinterType? receiptPrinterType;
  
  // Printer Settings
  @JsonKey(name: 'is_order_printer')
  final bool? isOrderPrinter;
  @JsonKey(name: 'printer_method')
  final PrinterMethod? printerMethod;
  
  // Network Settings
  @JsonKey(name: 'proxy_ip', fromJson: _extractNullableString)
  final String? proxyIp;
  @JsonKey(name: 'other_devices', fromJson: _extractNullableString)
  final String? otherDevices;
  
  // Cashier Printer IP  
  @JsonKey(name: 'epson_printer_ip', fromJson: _extractNullableString)
  final String? epsonPrinterIp;
  
  // Relationships (stored as IDs)
  @JsonKey(name: 'payment_method_ids')
  final List<int>? paymentMethodIds;
  @JsonKey(name: 'available_pricelist_ids')
  final List<int>? availablePricelistIds;
  @JsonKey(name: 'printer_ids')
  final List<int>? printerIds;
  @JsonKey(name: 'iface_available_categ_ids')
  final List<int>? ifaceAvailableCategIds;

  POSConfig({
    required this.id,
    required this.name,
    this.active = true,
    required this.companyId,
    required this.currencyId,
    this.pricelistId,
    this.journalId,
    this.invoiceJournalId,
    this.pickingTypeId,
    this.warehouseId,
    this.ifaceCashdrawer,
    this.ifaceElectronicScale,
    this.ifaceCustomerFacingDisplay,
    this.ifacePrintAuto,
    this.ifacePrintSkipScreen,
    this.ifaceScanViaProxy,
    this.ifaceBigScrollbars,
    this.ifacePrintViaProxy,
    this.modulePosRestaurant,
    this.modulePosDiscount,
    this.modulePosLoyalty,
    this.modulePosMercury,
    this.usePricelist,
    this.groupBy,
    this.limitCategories,
    this.restrictPriceControl,
    this.cashControl,
    this.receiptHeader,
    this.receiptFooter,
    this.receiptPrinterType,
    this.isOrderPrinter,
    this.printerMethod,
    this.proxyIp,
    this.otherDevices,
    this.epsonPrinterIp,
    this.paymentMethodIds,
    this.availablePricelistIds,
    this.printerIds,
    this.ifaceAvailableCategIds,
  });

  factory POSConfig.fromJson(Map<String, dynamic> json) => _$POSConfigFromJson(json);
  Map<String, dynamic> toJson() => _$POSConfigToJson(this);

  POSConfig copyWith({
    int? id,
    String? name,
    bool? active,
    int? companyId,
    int? currencyId,
    int? pricelistId,
    int? journalId,
    int? invoiceJournalId,
    int? pickingTypeId,
    int? warehouseId,
    bool? ifaceCashdrawer,
    bool? ifaceElectronicScale,
    String? ifaceCustomerFacingDisplay,
    bool? ifacePrintAuto,
    bool? ifacePrintSkipScreen,
    bool? ifaceScanViaProxy,
    bool? ifaceBigScrollbars,
    bool? ifacePrintViaProxy,
    bool? modulePosRestaurant,
    bool? modulePosDiscount,
    bool? modulePosLoyalty,
    bool? modulePosMercury,
    bool? usePricelist,
    bool? groupBy,
    bool? limitCategories,
    bool? restrictPriceControl,
    bool? cashControl,
    String? receiptHeader,
    String? receiptFooter,
    ReceiptPrinterType? receiptPrinterType,
    bool? isOrderPrinter,
    PrinterMethod? printerMethod,
    String? proxyIp,
    String? otherDevices,
    String? epsonPrinterIp,
    List<int>? paymentMethodIds,
    List<int>? availablePricelistIds,
    List<int>? printerIds,
    List<int>? ifaceAvailableCategIds,
  }) {
    return POSConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      companyId: companyId ?? this.companyId,
      currencyId: currencyId ?? this.currencyId,
      pricelistId: pricelistId ?? this.pricelistId,
      journalId: journalId ?? this.journalId,
      invoiceJournalId: invoiceJournalId ?? this.invoiceJournalId,
      pickingTypeId: pickingTypeId ?? this.pickingTypeId,
      warehouseId: warehouseId ?? this.warehouseId,
      ifaceCashdrawer: ifaceCashdrawer ?? this.ifaceCashdrawer,
      ifaceElectronicScale: ifaceElectronicScale ?? this.ifaceElectronicScale,
      ifaceCustomerFacingDisplay: ifaceCustomerFacingDisplay ?? this.ifaceCustomerFacingDisplay,
      ifacePrintAuto: ifacePrintAuto ?? this.ifacePrintAuto,
      ifacePrintSkipScreen: ifacePrintSkipScreen ?? this.ifacePrintSkipScreen,
      ifaceScanViaProxy: ifaceScanViaProxy ?? this.ifaceScanViaProxy,
      ifaceBigScrollbars: ifaceBigScrollbars ?? this.ifaceBigScrollbars,
      ifacePrintViaProxy: ifacePrintViaProxy ?? this.ifacePrintViaProxy,
      modulePosRestaurant: modulePosRestaurant ?? this.modulePosRestaurant,
      modulePosDiscount: modulePosDiscount ?? this.modulePosDiscount,
      modulePosLoyalty: modulePosLoyalty ?? this.modulePosLoyalty,
      modulePosMercury: modulePosMercury ?? this.modulePosMercury,
      usePricelist: usePricelist ?? this.usePricelist,
      groupBy: groupBy ?? this.groupBy,
      limitCategories: limitCategories ?? this.limitCategories,
      restrictPriceControl: restrictPriceControl ?? this.restrictPriceControl,
      cashControl: cashControl ?? this.cashControl,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      receiptPrinterType: receiptPrinterType ?? this.receiptPrinterType,
      isOrderPrinter: isOrderPrinter ?? this.isOrderPrinter,
      printerMethod: printerMethod ?? this.printerMethod,
      proxyIp: proxyIp ?? this.proxyIp,
      otherDevices: otherDevices ?? this.otherDevices,
      epsonPrinterIp: epsonPrinterIp ?? this.epsonPrinterIp,
      paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
      availablePricelistIds: availablePricelistIds ?? this.availablePricelistIds,
      printerIds: printerIds ?? this.printerIds,
      ifaceAvailableCategIds: ifaceAvailableCategIds ?? this.ifaceAvailableCategIds,
    );
  }
}
