/// pos.printer - Point of Sale Printer Configuration
/// Represents printer settings from Odoo POS system
class PosPrinter {
  final int id;
  final String name;
  final PrinterType printerType;
  final String? proxyIp;
  final String? printerIp;
  final int? port;
  final bool active;
  final ReceiptPrinterType? receiptPrinterType;
  final DateTime? createDate;
  final DateTime? writeDate;
  final List<int> categoryIds; // الفئات المرتبطة بهذه الطابعة

  const PosPrinter({
    required this.id,
    required this.name,
    required this.printerType,
    this.proxyIp,
    this.printerIp,
    this.port,
    this.active = true,
    this.receiptPrinterType,
    this.createDate,
    this.writeDate,
    this.categoryIds = const [],
  });

  factory PosPrinter.fromJson(Map<String, dynamic> json) {
    return PosPrinter(
      id: json['id'] as int,
      name: json['name'] as String,
      printerType: PrinterType.values.firstWhere(
        (e) => e.value == json['printer_type'],
        orElse: () => PrinterType.usb,
      ),
      proxyIp: _parseProxyIp(json['proxy_ip']),
      printerIp: json['epson_printer_ip'] as String?,
      port: json['port'] as int? ?? 9100, // افتراضي لمنافذ الطابعات
      active: json['active'] as bool? ?? true, // افتراضي نشط
      receiptPrinterType: json['receipt_printer_type'] != null
          ? ReceiptPrinterType.values.firstWhere(
              (e) => e.value == json['receipt_printer_type'],
              orElse: () => ReceiptPrinterType.custom,
            )
          : null,
      createDate: json['create_date'] != null
          ? DateTime.parse(json['create_date'])
          : null,
      writeDate: json['write_date'] != null
          ? DateTime.parse(json['write_date'])
          : null,
      categoryIds: _parseCategoryIds(json['category_ids']),
    );
  }

  /// Parse proxy_ip which can be either String or bool
  static String? _parseProxyIp(dynamic value) {
    if (value == null || value == false) {
      return null;
    }
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    return value.toString();
  }

  /// Parse category_ids which can be List, false, or null
  static List<int> _parseCategoryIds(dynamic value) {
    if (value == null || value == false) {
      return [];
    }
    if (value is List) {
      try {
        return value.cast<int>();
      } catch (e) {
        // إذا فشل التحويل، حاول استخراج الأرقام يدوياً
        return value.where((item) => item is int).cast<int>().toList();
      }
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'printer_type': printerType.value,
      'proxy_ip': proxyIp,
      'epson_printer_ip': printerIp,
      'port': port,
      'active': active,
      'receipt_printer_type': receiptPrinterType?.value,
      'create_date': createDate?.toIso8601String(),
      'write_date': writeDate?.toIso8601String(),
      'category_ids': categoryIds,
    };
  }

  /// Check if this is a network printer
  bool get isNetworkPrinter => (printerType == PrinterType.network && printerIp != null) || 
                               (printerType == PrinterType.epsonEpos && printerIp != null) ||
                               (printerIp != null && printerIp!.isNotEmpty);

  /// Check if this is an IoT Box printer
  bool get isIotPrinter => printerType == PrinterType.iot && proxyIp != null;

  /// Check if this is a USB printer (handled by Windows)
  bool get isUsbPrinter => printerType == PrinterType.usb;

  /// Check if this is an Epson ePOS printer
  bool get isEpsonEposPrinter => printerType == PrinterType.epsonEpos;

  /// Get the printer connection string for display
  String get connectionInfo {
    switch (printerType) {
      case PrinterType.network:
        return printerIp != null ? '$printerIp:${port ?? 9100}' : 'Network';
      case PrinterType.iot:
        return proxyIp != null ? 'IoT Box: $proxyIp' : 'IoT Box';
      case PrinterType.usb:
        return 'USB/Local';
      case PrinterType.epsonEpos:
        return printerIp != null ? 'Epson ePOS: $printerIp:${port ?? 9100}' : 'Epson ePOS';
    }
  }

  /// Check if printer can be used with Windows printing
  bool get isWindowsCompatible => isUsbPrinter || isNetworkPrinter || printerType == PrinterType.epsonEpos;

  /// Check if this printer has assigned categories
  bool get hasCategories => categoryIds.isNotEmpty;

  /// Check if this printer should print items from a specific category
  bool shouldPrintCategory(int categoryId) => categoryIds.contains(categoryId);

  /// Check if this printer should print items from any of the specified categories
  bool shouldPrintAnyCategory(List<int> categories) => 
      categories.any((catId) => categoryIds.contains(catId));

  /// Get category display info for debugging
  String get categoryDisplayInfo => hasCategories 
      ? 'Categories: ${categoryIds.join(', ')}'
      : 'No categories assigned';

  PosPrinter copyWith({
    int? id,
    String? name,
    PrinterType? printerType,
    String? proxyIp,
    String? printerIp,
    int? port,
    bool? active,
    ReceiptPrinterType? receiptPrinterType,
    DateTime? createDate,
    DateTime? writeDate,
    List<int>? categoryIds,
  }) {
    return PosPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      printerType: printerType ?? this.printerType,
      proxyIp: proxyIp ?? this.proxyIp,
      printerIp: printerIp ?? this.printerIp,
      port: port ?? this.port,
      active: active ?? this.active,
      receiptPrinterType: receiptPrinterType ?? this.receiptPrinterType,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }
}

/// Printer type enumeration
enum PrinterType {
  iot('iot'),
  network('network'),
  usb('usb'),
  epsonEpos('epson_epos');

  const PrinterType(this.value);
  final String value;

  @override
  String toString() => value;

  /// Get display name for the printer type
  String get displayName {
    switch (this) {
      case PrinterType.iot:
        return 'IoT Box';
      case PrinterType.network:
        return 'Network Printer';
      case PrinterType.usb:
        return 'USB/Local Printer';
      case PrinterType.epsonEpos:
        return 'Epson ePOS Printer';
    }
  }
}

/// Receipt printer type enumeration
enum ReceiptPrinterType {
  epson('epson'),
  star('star'),
  custom('custom');

  const ReceiptPrinterType(this.value);
  final String value;

  @override
  String toString() => value;

  /// Get display name for the receipt printer type
  String get displayName {
    switch (this) {
      case ReceiptPrinterType.epson:
        return 'EPSON';
      case ReceiptPrinterType.star:
        return 'STAR';
      case ReceiptPrinterType.custom:
        return 'Custom';
    }
  }
}

/// Printer method enumeration
enum PrinterMethod {
  posbox('posbox'),
  network('network');

  const PrinterMethod(this.value);
  final String value;

  @override
  String toString() => value;

  /// Get display name for the printer method
  String get displayName {
    switch (this) {
      case PrinterMethod.posbox:
        return 'PosBox/IoT Box';
      case PrinterMethod.network:
        return 'Network Printer';
    }
  }
}
