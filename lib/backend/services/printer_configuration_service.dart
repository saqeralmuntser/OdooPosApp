import 'package:flutter/material.dart';
import '../models/pos_config.dart';
import '../models/pos_printer.dart';
import '../models/pos_order_line.dart';
import '../api/odoo_api_client.dart';
import '../storage/local_storage.dart';
import 'enhanced_windows_printer_service.dart';

/// خدمة إدارة إعدادات الطابعات من Odoo
/// تربط بين إعدادات Odoo ونظام الطباعة في Windows
class PrinterConfigurationService {
  static final PrinterConfigurationService _instance = PrinterConfigurationService._internal();
  factory PrinterConfigurationService() => _instance;
  PrinterConfigurationService._internal();

  final OdooApiClient _apiClient = OdooApiClient();
  final LocalStorage _localStorage = LocalStorage();
  final EnhancedWindowsPrinterService _windowsPrinterService = EnhancedWindowsPrinterService();

  POSConfig? _currentPosConfig;
  List<PosPrinter> _printers = [];
  bool _isInitialized = false;

  /// تهيئة خدمة إعدادات الطابعات
  Future<void> initialize({int? posConfigId}) async {
    try {
      debugPrint('🚀 ==========================================');
      debugPrint('🚀 INITIALIZING PRINTER CONFIGURATION SERVICE');
      debugPrint('🚀 ==========================================');
      debugPrint('  📅 Time: ${DateTime.now()}');
      debugPrint('  🆔 POS Config ID: ${posConfigId ?? 'AUTO'}');
      
      await _localStorage.initialize();
      debugPrint('✅ Local Storage initialized');

      // تحميل إعدادات POS الحالية
      if (posConfigId != null) {
        debugPrint('🔄 Loading specific POS Config from Odoo...');
        await _loadPosConfig(posConfigId);
      } else {
        debugPrint('🔄 Loading current POS Config from local storage...');
        await _loadCurrentPosConfig();
      }

      // تحميل إعدادات الطابعات
      debugPrint('🔄 Loading printer configurations...');
      await _loadPrinters();

      // تهيئة خدمة طابعات Windows
      debugPrint('🔄 Initializing Windows Printer Service...');
      await _windowsPrinterService.initialize(posConfig: _currentPosConfig);

      _isInitialized = true;
      debugPrint('✅ ==========================================');
      debugPrint('✅ PRINTER CONFIGURATION SERVICE INITIALIZED');
      debugPrint('✅ ==========================================');
      debugPrint('  📊 Summary:');
      debugPrint('    🧾 Cashier Printer: ${_currentPosConfig?.epsonPrinterIp?.isNotEmpty == true ? 'CONFIGURED' : 'NOT CONFIGURED'}');
      debugPrint('    🍳 Kitchen Printers: ${_printers.length} configured');
      debugPrint('    🖨️ Total Printers: ${_printers.length + (_currentPosConfig?.epsonPrinterIp?.isNotEmpty == true ? 1 : 0)}');
      
    } catch (e) {
      debugPrint('❌ ==========================================');
      debugPrint('❌ PRINTER CONFIGURATION SERVICE INITIALIZATION FAILED');
      debugPrint('❌ ==========================================');
      debugPrint('  🔍 Error: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
      _isInitialized = false;
    }
  }

  /// تحميل إعدادات POS الحالية من التخزين المحلي
  Future<void> _loadCurrentPosConfig() async {
    try {
      debugPrint('🔄 Loading Current POS Config from Local Storage...');
      
      final configData = await _localStorage.getConfig();
      if (configData != null) {
        debugPrint('✅ POS Config found in local storage:');
        debugPrint('  📊 Data length: ${configData.length}');
        debugPrint('  🔍 Raw data: $configData');
        
        _currentPosConfig = POSConfig.fromJson(configData);
        
        debugPrint('✅ POS Config loaded from local storage:');
        debugPrint('  🏷️ Name: ${_currentPosConfig!.name}');
        debugPrint('  🆔 ID: ${_currentPosConfig!.id}');
        debugPrint('  🖨️ Cashier Printer IP: ${_currentPosConfig!.epsonPrinterIp ?? 'NOT SET'}');
        debugPrint('  🔗 Kitchen Printer IDs: ${_currentPosConfig!.printerIds ?? 'NONE'}');
        
        // تسجيل تفاصيل طابعة الكاشير
        if (_currentPosConfig!.epsonPrinterIp?.isNotEmpty == true) {
          debugPrint('💰 CASHIER PRINTER (from cache):');
          debugPrint('  🌐 IP Address: ${_currentPosConfig!.epsonPrinterIp}');
          debugPrint('  📍 Source: Local Storage Cache');
        } else {
          debugPrint('⚠️ CASHIER PRINTER (from cache): NOT CONFIGURED');
        }
        
        // تسجيل تفاصيل طابعات المطبخ
        if (_currentPosConfig!.printerIds?.isNotEmpty == true) {
          debugPrint('🍳 KITCHEN PRINTERS (from cache):');
          debugPrint('  🔢 Count: ${_currentPosConfig!.printerIds!.length}');
          debugPrint('  🆔 IDs: ${_currentPosConfig!.printerIds}');
          debugPrint('  📍 Source: Local Storage Cache');
        } else {
          debugPrint('⚠️ KITCHEN PRINTERS (from cache): NOT CONFIGURED');
        }
        
      } else {
        debugPrint('⚠️ No POS Config found in local storage');
      }
    } catch (e) {
      debugPrint('❌ Error loading current POS config from local storage: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
    }
  }

  /// تحميل إعدادات POS محددة من Odoo
  Future<void> _loadPosConfig(int posConfigId) async {
    try {
      debugPrint('🔄 Loading POS Config from Odoo...');
      debugPrint('  📍 Config ID: $posConfigId');
      
      final configData = await _apiClient.read('pos.config', posConfigId);
      
      if (configData.isNotEmpty) {
        debugPrint('✅ Raw POS Config Data received:');
        debugPrint('  📊 Data length: ${configData.length}');
        debugPrint('  🔍 Raw data: $configData');
        
        _currentPosConfig = POSConfig.fromJson(configData);
        
        debugPrint('✅ POS Config parsed successfully:');
        debugPrint('  🏷️ Name: ${_currentPosConfig!.name}');
        debugPrint('  🆔 ID: ${_currentPosConfig!.id}');
        debugPrint('  🖨️ Cashier Printer IP: ${_currentPosConfig!.epsonPrinterIp ?? 'NOT SET'}');
        debugPrint('  🧾 Receipt Header: ${_currentPosConfig!.receiptHeader ?? 'NOT SET'}');
        debugPrint('  📝 Receipt Footer: ${_currentPosConfig!.receiptFooter ?? 'NOT SET'}');
        debugPrint('  🔄 Auto Print: ${_currentPosConfig!.ifacePrintAuto ?? false}');
        debugPrint('  ⏭️ Skip Preview: ${_currentPosConfig!.ifacePrintSkipScreen ?? false}');
        debugPrint('  🍳 Order Printer Enabled: ${_currentPosConfig!.isOrderPrinter ?? false}');
        debugPrint('  🖨️ Receipt Printer Type: ${_currentPosConfig!.receiptPrinterType?.displayName ?? 'NOT SET'}');
        debugPrint('  🌐 Printer Method: ${_currentPosConfig!.printerMethod?.displayName ?? 'NOT SET'}');
        debugPrint('  🔗 Kitchen Printer IDs: ${_currentPosConfig!.printerIds ?? 'NONE'}');
        
        // تسجيل تفاصيل طابعة الكاشير
        if (_currentPosConfig!.epsonPrinterIp?.isNotEmpty == true) {
          debugPrint('💰 CASHIER PRINTER CONFIGURATION:');
          debugPrint('  🌐 IP Address: ${_currentPosConfig!.epsonPrinterIp}');
          debugPrint('  🎯 Type: Primary Cashier Receipt Printer');
          debugPrint('  📍 Source: epson_printer_ip field');
        } else {
          debugPrint('⚠️ CASHIER PRINTER: NOT CONFIGURED');
          debugPrint('  ❌ epson_printer_ip field is empty or null');
        }
        
        // تسجيل تفاصيل طابعات المطبخ
        if (_currentPosConfig!.printerIds?.isNotEmpty == true) {
          debugPrint('🍳 KITCHEN PRINTERS CONFIGURATION:');
          debugPrint('  🔢 Count: ${_currentPosConfig!.printerIds!.length}');
          debugPrint('  🆔 IDs: ${_currentPosConfig!.printerIds}');
          debugPrint('  📍 Source: printer_ids field (Many2many)');
        } else {
          debugPrint('⚠️ KITCHEN PRINTERS: NOT CONFIGURED');
          debugPrint('  ❌ printer_ids field is empty or null');
        }
        
      } else {
        debugPrint('❌ POS Config data is empty from Odoo');
      }
    } catch (e) {
      debugPrint('❌ Error loading POS config from Odoo: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
    }
  }

  /// تحميل إعدادات الطابعات
  Future<void> _loadPrinters() async {
    debugPrint('🔄 Loading Kitchen Printers from Odoo...');
    
    if (_currentPosConfig?.printerIds?.isNotEmpty != true) {
      debugPrint('⚠️ KITCHEN PRINTERS: No printer_ids configured in POS Config');
      debugPrint('  📍 Check printer_ids field in pos.config');
      debugPrint('  📍 Current value: ${_currentPosConfig?.printerIds}');
      return;
    }

    try {
      debugPrint('🍳 Fetching Kitchen Printer Details:');
      debugPrint('  🔢 Printer IDs to fetch: ${_currentPosConfig!.printerIds}');
      debugPrint('  🌐 API Call: searchRead("pos.printer", domain: [["id", "in", ${_currentPosConfig!.printerIds}]])');
      
      // جلب بيانات الطابعات من Odoo باستخدام searchRead للحصول على البيانات الكاملة
      final printersData = await _apiClient.searchRead(
        'pos.printer',
        domain: [['id', 'in', _currentPosConfig!.printerIds!]],
        fields: ['id', 'name', 'printer_type', 'proxy_ip', 'epson_printer_ip', 'company_id', 'create_date', 'write_date'],
      );

      debugPrint('✅ Raw Kitchen Printer Data received:');
      debugPrint('  📊 Data count: ${printersData.length}');
      debugPrint('  🔍 Raw data: $printersData');
      debugPrint('  🔍 Data type of first item: ${printersData.isNotEmpty ? printersData.first.runtimeType : 'empty'}');

      _printers = printersData
          .map((data) => PosPrinter.fromJson(data))
          .toList();

      debugPrint('✅ Kitchen Printers parsed successfully:');
      debugPrint('  📄 Total loaded: ${_printers.length}');
      
      // تسجيل تفاصيل كل طابعة مطبخ
      for (int i = 0; i < _printers.length; i++) {
        final printer = _printers[i];
        debugPrint('🍳 Kitchen Printer ${i + 1}:');
        debugPrint('  🆔 ID: ${printer.id}');
        debugPrint('  🏷️ Name: ${printer.name}');
        debugPrint('  🖨️ Type: ${printer.printerType.displayName}');
        debugPrint('  🌐 Proxy IP: ${printer.proxyIp ?? 'NOT SET'}');
        debugPrint('  🖥️ Printer IP: ${printer.printerIp ?? 'NOT SET'}');
        debugPrint('  🔌 Port: ${printer.port ?? 'DEFAULT'}');
        debugPrint('  🧾 Receipt Type: ${printer.receiptPrinterType?.displayName ?? 'NOT SET'}');
        debugPrint('  ✅ Active: ${printer.active}');
        debugPrint('  🔗 Connection: ${printer.connectionDescription}');
        debugPrint('  💻 Windows Compatible: ${printer.isWindowsCompatible}');
      }

      // حفظ في التخزين المحلي للاستخدام دون اتصال
      await _cachePrintersLocally();

    } catch (e) {
      debugPrint('❌ Error loading Kitchen Printers from Odoo: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
      // محاولة تحميل من التخزين المحلي
      await _loadPrintersFromCache();
    }
  }

  /// حفظ إعدادات الطابعات في التخزين المحلي
  Future<void> _cachePrintersLocally() async {
    try {
      final printersJson = _printers.map((p) => p.toJson()).toList();
      await _localStorage.saveCompany({'printers': printersJson}); // استخدام company storage مؤقتاً
      debugPrint('💾 Printers cached locally');
    } catch (e) {
      debugPrint('❌ Error caching printers: $e');
    }
  }

  /// تحميل إعدادات الطابعات من التخزين المحلي
  Future<void> _loadPrintersFromCache() async {
    try {
      debugPrint('🔄 Loading Kitchen Printers from Local Cache...');
      
      final companyData = await _localStorage.getCompany();
      if (companyData?['printers'] != null) {
        final printersData = companyData!['printers'] as List<dynamic>;
        
        debugPrint('✅ Kitchen Printer data found in cache:');
        debugPrint('  📊 Cached data count: ${printersData.length}');
        debugPrint('  🔍 Raw cached data: $printersData');
        
        _printers = printersData
            .map((data) => PosPrinter.fromJson(data))
            .toList();
            
        debugPrint('✅ Kitchen Printers loaded from cache:');
        debugPrint('  📄 Total loaded: ${_printers.length}');
        
        // تسجيل تفاصيل كل طابعة مطبخ من الكاش
        for (int i = 0; i < _printers.length; i++) {
          final printer = _printers[i];
          debugPrint('🍳 Cached Kitchen Printer ${i + 1}:');
          debugPrint('  🆔 ID: ${printer.id}');
          debugPrint('  🏷️ Name: ${printer.name}');
          debugPrint('  🖨️ Type: ${printer.printerType.displayName}');
          debugPrint('  🌐 Proxy IP: ${printer.proxyIp ?? 'NOT SET'}');
          debugPrint('  🖥️ Printer IP: ${printer.printerIp ?? 'NOT SET'}');
          debugPrint('  🔌 Port: ${printer.port ?? 'DEFAULT'}');
          debugPrint('  🧾 Receipt Type: ${printer.receiptPrinterType?.displayName ?? 'NOT SET'}');
          debugPrint('  ✅ Active: ${printer.active}');
          debugPrint('  🔗 Connection: ${printer.connectionDescription}');
          debugPrint('  💻 Windows Compatible: ${printer.isWindowsCompatible}');
          debugPrint('  📍 Source: Local Cache');
        }
        
      } else {
        debugPrint('⚠️ No Kitchen Printer data found in local cache');
        debugPrint('  📍 Check company storage for "printers" key');
        debugPrint('  🔍 Available keys: ${companyData?.keys.toList() ?? 'NONE'}');
      }
    } catch (e) {
      debugPrint('❌ Error loading Kitchen Printers from cache: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
    }
  }

  /// الحصول على إعدادات الطباعة للطلب الحالي
  PrintingSettings getPrintingSettings() {
    debugPrint('📋 Getting Current Printing Settings:');
    debugPrint('  🧾 Auto Print: ${_currentPosConfig?.ifacePrintAuto ?? false}');
    debugPrint('  ⏭️ Skip Preview: ${_currentPosConfig?.ifacePrintSkipScreen ?? false}');
    debugPrint('  📝 Receipt Header: ${_currentPosConfig?.receiptHeader ?? 'NOT SET'}');
    debugPrint('  📄 Receipt Footer: ${_currentPosConfig!.receiptFooter ?? 'NOT SET'}');
    debugPrint('  🖨️ Receipt Printer Type: ${_currentPosConfig?.receiptPrinterType?.displayName ?? 'NOT SET'}');
    debugPrint('  🍳 Order Printer Enabled: ${_currentPosConfig?.isOrderPrinter ?? false}');
    debugPrint('  🌐 Printer Method: ${_currentPosConfig?.printerMethod?.displayName ?? 'NOT SET'}');
    debugPrint('  🔢 Configured Printers Count: ${_printers.length}');
    
    return PrintingSettings(
      shouldPrintAutomatically: _currentPosConfig?.ifacePrintAuto ?? false,
      shouldSkipPreviewScreen: _currentPosConfig?.ifacePrintSkipScreen ?? false,
      receiptHeader: _currentPosConfig?.receiptHeader,
      receiptFooter: _currentPosConfig?.receiptFooter,
      receiptPrinterType: _currentPosConfig?.receiptPrinterType,
      isOrderPrinterEnabled: _currentPosConfig?.isOrderPrinter ?? false,
      printerMethod: _currentPosConfig?.printerMethod,
      configuredPrinters: _printers,
    );
  }

  /// طباعة شاملة للطلب (الكاشير + المطبخ) - الطريقة المفضلة
  Future<Map<String, dynamic>> printCompleteOrder({
    required dynamic order,
    required List<dynamic> orderLines,
    required Map<String, double> payments,
    dynamic customer,
    dynamic company,
  }) async {
    debugPrint('🖨️ Starting complete order printing from PrinterConfigurationService...');
    
    return await _windowsPrinterService.printCompleteOrder(
      order: order,
      orderLines: orderLines.cast<POSOrderLine>(),
      payments: payments,
      customer: customer,
      company: company,
    );
  }

  /// طباعة إيصال الكاشير (الطابعة الأساسية)
  Future<Map<String, dynamic>> printCashierReceipt({
    required dynamic order,
    required List<dynamic> orderLines,
    required Map<String, double> payments,
    dynamic customer,
    dynamic company,
  }) async {
    debugPrint('🧾 Printing cashier receipt...');
    
    return await _windowsPrinterService.printReceipt(
      order: order,
      orderLines: orderLines.cast<POSOrderLine>(),
      payments: payments,
      customer: customer,
      company: company,
      usageType: PrinterUsageType.cashier,
    );
  }

  /// طباعة الإيصال مع الإعدادات الصحيحة
  /// الطريقة الأساسية - تطبع على جميع الطابعات تلقائياً
  Future<Map<String, dynamic>> printReceipt({
    required dynamic order,
    required List<dynamic> orderLines,
    required Map<String, double> payments,
    dynamic customer,
    dynamic company,
    PrintType printType = PrintType.receipt,
    bool printOnAllPrinters = true, // جديد: للتحكم في الطباعة الشاملة
  }) async {
    
    // إذا طُلبت الطباعة على جميع الطابعات (الافتراضي)
    if (printOnAllPrinters && printType == PrintType.receipt) {
      debugPrint('🖨️ Printing on all configured printers...');
      return await printCompleteOrder(
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
      );
    }
    
    // للطباعة المنفصلة (للتوافق مع النسخة السابقة)
    if (printType == PrintType.kitchen) {
      return await printKitchenTicket(
        order: order,
        orderLines: orderLines,
        customer: customer,
        company: company,
      );
    } else {
      return await printCashierReceipt(
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
      );
    }
  }

  /// طباعة تذكرة المطبخ
  Future<Map<String, dynamic>> printKitchenTicket({
    required dynamic order,
    required List<dynamic> orderLines,
    dynamic customer,
    dynamic company,
  }) async {
    final settings = getPrintingSettings();
    
    if (!settings.isOrderPrinterEnabled) {
      return {
        'successful': false,
        'message': {
          'title': 'Kitchen Printing Disabled',
          'body': 'Order printer is not enabled in POS configuration',
        },
      };
    }

    debugPrint('🍳 Printing kitchen tickets...');

    // طباعة على جميع طابعات المطبخ
    final results = await _windowsPrinterService.printKitchenTickets(
      order: order,
      orderLines: orderLines.cast<POSOrderLine>(),
      customer: customer,
      company: company,
    );

    // تجميع النتائج
    final successful = results.where((r) => r['successful'] == true).length;
    final total = results.length;

    if (successful > 0) {
      return {
        'successful': true,
        'message': {
          'title': 'Kitchen Print Successful',
          'body': 'Kitchen tickets printed on $successful of $total printers',
        },
        'details': results,
      };
    } else {
      return {
        'successful': false,
        'message': {
          'title': 'Kitchen Print Failed',
          'body': 'Failed to print on all kitchen printers',
        },
        'details': results,
      };
    }
  }

  /// اختبار طباعة لجميع الطابعات المكونة
  Future<List<Map<String, dynamic>>> testAllPrinters() async {
    final results = <Map<String, dynamic>>[];
    
    for (var printer in _printers) {
      final result = await _windowsPrinterService.printTest(printer.id);
      results.add({
        'printer': printer,
        'result': result,
      });
    }
    
    return results;
  }

  /// الحصول على معلومات مطابقة الطابعات
  List<Map<String, dynamic>> getPrinterMappingInfo() {
    return _windowsPrinterService.getPrinterMappingInfo();
  }

  /// ربط طابعة يدوياً
  Future<void> setManualPrinterMapping(int odooPrinterId, String windowsPrinterName) async {
    await _windowsPrinterService.setManualPrinterMapping(odooPrinterId, windowsPrinterName);
  }

  /// إزالة ربط طابعة
  Future<void> removePrinterMapping(int odooPrinterId) async {
    await _windowsPrinterService.removePrinterMapping(odooPrinterId);
  }

  /// تحديث إعدادات الطابعات
  Future<void> refreshPrinterConfiguration() async {
    await _loadPrinters();
    await _windowsPrinterService.refreshPrinters();
  }

  /// فحص توافق النظام
  Map<String, dynamic> getSystemCompatibilityInfo() {
    final windowsPrinters = _windowsPrinterService.windowsPrinters;
    final mappings = _windowsPrinterService.getPrinterMappingInfo();
    
    return {
      'windows_printers_count': windowsPrinters.length,
      'odoo_printers_count': _printers.length,
      'mapped_printers_count': mappings.where((m) => m['is_mapped'] == true).length,
      'compatible_printers': _printers.where((p) => p.isWindowsCompatible).length,
      'system_ready': windowsPrinters.isNotEmpty && _printers.isNotEmpty,
      'auto_print_enabled': _currentPosConfig?.ifacePrintAuto ?? false,
      'mappings': mappings,
    };
  }

  // Getters
  POSConfig? get currentPosConfig => _currentPosConfig;
  List<PosPrinter> get configuredPrinters => List.unmodifiable(_printers);
  bool get isInitialized => _isInitialized;
  PrintingSettings get printingSettings => getPrintingSettings();
}

/// إعدادات الطباعة
class PrintingSettings {
  final bool shouldPrintAutomatically;
  final bool shouldSkipPreviewScreen;
  final String? receiptHeader;
  final String? receiptFooter;
  final ReceiptPrinterType? receiptPrinterType;
  final bool isOrderPrinterEnabled;
  final PrinterMethod? printerMethod;
  final List<PosPrinter> configuredPrinters;

  const PrintingSettings({
    required this.shouldPrintAutomatically,
    required this.shouldSkipPreviewScreen,
    this.receiptHeader,
    this.receiptFooter,
    this.receiptPrinterType,
    required this.isOrderPrinterEnabled,
    this.printerMethod,
    required this.configuredPrinters,
  });

  @override
  String toString() {
    return 'PrintingSettings(autoprint: $shouldPrintAutomatically, '
           'skipPreview: $shouldSkipPreviewScreen, '
           'orderPrinter: $isOrderPrinterEnabled, '
           'printers: ${configuredPrinters.length})';
  }
}

/// نوع الطباعة
enum PrintType {
  receipt,
  kitchen,
  label,
}

/// Extension methods للطابعات
extension PosPrinterExtensions on PosPrinter {
  /// فحص إمكانية الاستخدام مع Windows
  bool get isWindowsCompatible {
    return printerType == PrinterType.usb || 
           (printerType == PrinterType.network && printerIp != null) ||
           (printerType == PrinterType.epsonEpos && printerIp != null);
  }

  /// الحصول على معلومات الاتصال
  String get connectionDescription {
    switch (printerType) {
      case PrinterType.network:
        return printerIp != null ? '$printerIp:${port ?? 9100}' : 'Network (IP not configured)';
      case PrinterType.iot:
        return proxyIp != null ? 'IoT Box: $proxyIp' : 'IoT Box (IP not configured)';
      case PrinterType.usb:
        return 'USB/Local connection';
      case PrinterType.epsonEpos:
        return printerIp != null ? 'Epson EPOS: $printerIp:${port ?? 9100}' : 'Epson EPOS (IP not configured)';
    }
  }

  /// فحص صحة الإعدادات
  bool get isValidConfiguration {
    switch (printerType) {
      case PrinterType.network:
        return printerIp != null && printerIp!.isNotEmpty;
      case PrinterType.iot:
        return proxyIp != null && proxyIp!.isNotEmpty;
      case PrinterType.usb:
        return true; // USB printers just need to be connected
      case PrinterType.epsonEpos:
        return printerIp != null && printerIp!.isNotEmpty; // Epson EPOS requires IP configuration
    }
  }
}
