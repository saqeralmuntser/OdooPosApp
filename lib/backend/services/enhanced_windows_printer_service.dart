import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/res_partner.dart';
import '../models/res_company.dart';
import '../models/pos_config.dart';
import '../models/pos_printer.dart';
import '../api/odoo_api_client.dart';
import 'arabic_font_service.dart';

/// نوع استخدام الطابعة
enum PrinterUsageType {
  cashier,  // طابعة الكاشير الأساسية
  kitchen,  // طابعات المطبخ
}

/// خدمة طباعة Windows محسنة مع دعم إعدادات Odoo
/// تربط بين إعدادات طابعات Odoo وطابعات Windows المتاحة
class EnhancedWindowsPrinterService {
  static final EnhancedWindowsPrinterService _instance = EnhancedWindowsPrinterService._internal();
  factory EnhancedWindowsPrinterService() => _instance;
  EnhancedWindowsPrinterService._internal();

  final OdooApiClient _apiClient = OdooApiClient();
  final ArabicFontService _fontService = ArabicFontService();
  List<Printer> _windowsPrinters = [];
  List<PosPrinter> _odooPrinters = [];
  POSConfig? _currentPosConfig;
  Map<int, String> _printerMatching = {}; // Odoo Printer ID -> Windows Printer Name
  bool _isInitialized = false;

  /// تهيئة الخدمة وجلب البيانات
  Future<void> initialize({POSConfig? posConfig}) async {
    if (_isInitialized && posConfig == null) return;

    try {
      debugPrint('🔄 ==========================================');
      debugPrint('🔄 INITIALIZING ENHANCED WINDOWS PRINTER SERVICE');
      debugPrint('🔄 ==========================================');
      debugPrint('  📅 Time: ${DateTime.now()}');
      
      // حفظ إعدادات POS الحالية
      if (posConfig != null) {
        _currentPosConfig = posConfig;
        debugPrint('✅ POS Config received:');
        debugPrint('  🏷️ Name: ${posConfig.name}');
        debugPrint('  🆔 ID: ${posConfig.id}');
        debugPrint('  💰 Cashier Printer IP: ${posConfig.epsonPrinterIp ?? 'NOT SET'}');
        debugPrint('  🍳 Kitchen Printer IDs: ${posConfig.printerIds ?? 'NONE'}');
      } else {
        debugPrint('⚠️ No POS Config provided');
      }

      // جلب طابعات Windows المتاحة
      debugPrint('🔄 Loading Windows Printers...');
      await _loadWindowsPrinters();
      
      // جلب إعدادات طابعات Odoo
      debugPrint('🔄 Loading Odoo Printer Configurations...');
      await _loadOdooPrinters();
      
      // تحميل المطابقات المحفوظة
      debugPrint('🔄 Loading Saved Printer Mappings...');
      await _loadPrinterMatching();
      
      // إجراء مطابقة تلقائية للطابعات الجديدة
      debugPrint('🔄 Performing Automatic Printer Matching...');
      await _performAutomaticMatching();
      
      // تحميل الخطوط العربية
      debugPrint('🔄 Loading Arabic Fonts...');
      await _fontService.loadFonts();
      debugPrint('✅ Font Status: ${_fontService.fontStatus}');
      
      // اختبار معالج النص العربي
      debugPrint('🔤 Testing Arabic Text Processor...');
      _fontService.runArabicProcessorTests();
      
      _isInitialized = true;
      debugPrint('✅ ==========================================');
      debugPrint('✅ ENHANCED WINDOWS PRINTER SERVICE INITIALIZED');
      debugPrint('✅ ==========================================');
      debugPrint('  📊 Summary:');
      debugPrint('    🖥️ Windows Printers: ${_windowsPrinters.length}');
      debugPrint('    🍳 Odoo Kitchen Printers: ${_odooPrinters.length}');
      debugPrint('    💰 Cashier Printer: ${_currentPosConfig?.epsonPrinterIp?.isNotEmpty == true ? 'CONFIGURED' : 'NOT CONFIGURED'}');
      debugPrint('    🔗 Mapped Printers: ${_printerMatching.length}');
      
    } catch (e) {
      debugPrint('❌ ==========================================');
      debugPrint('❌ ENHANCED WINDOWS PRINTER SERVICE INITIALIZATION FAILED');
      debugPrint('❌ ==========================================');
      debugPrint('  🔍 Error: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
      // في حالة الفشل، نحاول التهيئة الأساسية على الأقل
      await _loadWindowsPrinters();
      _isInitialized = true;
    }
  }

  /// جلب طابعات Windows المتاحة
  Future<void> _loadWindowsPrinters() async {
    try {
      _windowsPrinters = await Printing.listPrinters();
      debugPrint('🖨️ Windows Printers Found: ${_windowsPrinters.length}');
      for (var printer in _windowsPrinters) {
        debugPrint('  - ${printer.name} (${printer.isDefault ? 'Default' : 'Available'})');
      }
    } catch (e) {
      debugPrint('❌ Error loading Windows printers: $e');
      _windowsPrinters = [];
    }
  }

  /// جلب إعدادات طابعات Odoo
  Future<void> _loadOdooPrinters() async {
    try {
      debugPrint('🍳 Loading Odoo Kitchen Printer Configurations...');
      
      if (_currentPosConfig?.printerIds?.isNotEmpty == true) {
        debugPrint('  🔢 Kitchen Printer IDs to fetch: ${_currentPosConfig!.printerIds}');
        debugPrint('  🌐 API Call: searchRead("pos.printer", domain: [["id", "in", ${_currentPosConfig!.printerIds}]])');
        
        try {
          // استخدم searchRead مباشرة للحصول على البيانات الكاملة
          final printerData = await _apiClient.searchRead(
            'pos.printer',
            domain: [['id', 'in', _currentPosConfig!.printerIds!]],
            fields: ['id', 'name', 'printer_type', 'proxy_ip', 'epson_printer_ip', 'company_id', 'create_date', 'write_date'],
          );
        
          debugPrint('✅ Raw Odoo Kitchen Printer Data received:');
          debugPrint('  📊 Data count: ${printerData.length}');
          debugPrint('  🔍 Raw data: $printerData');
          debugPrint('  🔍 Data type of first item: ${printerData.isNotEmpty ? printerData.first.runtimeType : 'empty'}');
        
          _odooPrinters = [];
          
          // معالجة البيانات المُستلمة
          for (int i = 0; i < printerData.length; i++) {
            final item = printerData[i];
            debugPrint('  🔍 Item $i: ${item['name']} (ID: ${item['id']})');
            
            try {
              final printer = PosPrinter.fromJson(item);
              _odooPrinters.add(printer);
              debugPrint('  ✅ Parsed printer: ${printer.name} (Type: ${printer.printerType.displayName})');
            } catch (e) {
              debugPrint('  ❌ Error parsing printer: $e');
              debugPrint('    🔍 Raw data: $item');
            }
          }
          
          debugPrint('✅ Odoo Kitchen Printers parsed successfully:');
          debugPrint('  📄 Total loaded: ${_odooPrinters.length}');
          
        } catch (apiError) {
          debugPrint('❌ Error calling pos.printer API: $apiError');
          debugPrint('  💡 SUGGESTION: pos.printer model may not exist in this Odoo version');
          debugPrint('  💡 This might be Odoo Community Edition without restaurant features');
          _odooPrinters = [];
        }
        
        // تسجيل تفاصيل كل طابعة مطبخ من Odoo
        for (int i = 0; i < _odooPrinters.length; i++) {
          final printer = _odooPrinters[i];
          debugPrint('🍳 Odoo Kitchen Printer ${i + 1}:');
          debugPrint('  🆔 ID: ${printer.id}');
          debugPrint('  🏷️ Name: ${printer.name}');
          debugPrint('  🖨️ Type: ${printer.printerType.displayName}');
          debugPrint('  🌐 Proxy IP: ${printer.proxyIp ?? 'NOT SET'}');
          debugPrint('  🖥️ Printer IP: ${printer.printerIp ?? 'NOT SET'}');
          debugPrint('  🔌 Port: ${printer.port ?? 'DEFAULT'}');
          debugPrint('  🧾 Receipt Type: ${printer.printerType.displayName}');
          debugPrint('  ✅ Active: ${printer.active}');
          debugPrint('  💻 Windows Compatible: ${printer.isWindowsCompatible}');
        }
        
      } else {
        debugPrint('⚠️ KITCHEN PRINTERS: No printer_ids configured in POS Config');
        debugPrint('  📍 Check printer_ids field in pos.config');
        debugPrint('  📍 Current value: ${_currentPosConfig?.printerIds}');
        _odooPrinters = [];
      }
    } catch (e) {
      debugPrint('❌ Error loading Odoo Kitchen Printers: $e');
      debugPrint('  🔍 Stack trace: ${StackTrace.current}');
      
      // التحقق من نوع الخطأ لتقديم اقتراحات
      if (e.toString().contains('pos.printer') && e.toString().contains('not found')) {
        debugPrint('💡 SUGGESTION: pos.printer model may not be available in this Odoo version');
        debugPrint('💡 This might be an Odoo Community Edition without restaurant module');
        debugPrint('💡 Kitchen printing will be disabled');
      }
      
      _odooPrinters = [];
    }
  }

  /// تحميل المطابقات المحفوظة
  Future<void> _loadPrinterMatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final matchingJson = prefs.getString('odoo_windows_printer_matching');
      if (matchingJson != null) {
        final Map<String, dynamic> matchingData = jsonDecode(matchingJson);
        _printerMatching = matchingData.map((key, value) => MapEntry(int.parse(key), value as String));
        debugPrint('🔗 Printer matching loaded: $_printerMatching');
      }
    } catch (e) {
      debugPrint('❌ Error loading printer matching: $e');
      _printerMatching = {};
    }
  }

  /// حفظ المطابقات
  Future<void> _savePrinterMatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringMap = _printerMatching.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString('odoo_windows_printer_matching', jsonEncode(stringMap));
      debugPrint('💾 Printer matching saved');
    } catch (e) {
      debugPrint('❌ Error saving printer matching: $e');
    }
  }

  /// إجراء مطابقة تلقائية للطابعات
  Future<void> _performAutomaticMatching() async {
    debugPrint('🤖 Performing automatic printer matching...');
    debugPrint('  🔢 Odoo printers to match: ${_odooPrinters.length}');
    debugPrint('  🖥️ Windows printers available: ${_windowsPrinters.length}');
    
    for (var odooPrinter in _odooPrinters) {
      debugPrint('🔄 Processing Odoo printer: ${odooPrinter.name} (ID: ${odooPrinter.id})');
      
      // تخطي الطابعات المطابقة مسبقاً
      if (_printerMatching.containsKey(odooPrinter.id)) {
        debugPrint('  ⏭️ Already matched, skipping');
        continue;
      }
      
      // البحث عن طابعة Windows مطابقة
      final matchedWindowsPrinter = _findMatchingWindowsPrinter(odooPrinter);
      if (matchedWindowsPrinter != null) {
        _printerMatching[odooPrinter.id] = matchedWindowsPrinter.name;
        debugPrint('🎯 Auto-matched: ${odooPrinter.name} -> ${matchedWindowsPrinter.name}');
      } else {
        debugPrint('❌ No match found for: ${odooPrinter.name}');
      }
    }
    
    // حفظ المطابقات الجديدة
    if (_printerMatching.isNotEmpty) {
      await _savePrinterMatching();
    }
  }

  /// البحث عن طابعة Windows مطابقة لطابعة Odoo
  Printer? _findMatchingWindowsPrinter(PosPrinter odooPrinter) {
    debugPrint('🔍 Searching for Windows printer matching Odoo printer: ${odooPrinter.name}');
    
    // 1. البحث بالاسم المطابق تماماً
    var match = _windowsPrinters.where((wp) => 
        wp.name.toLowerCase() == odooPrinter.name.toLowerCase()).firstOrNull;
    if (match != null) {
      debugPrint('  ✅ Found exact name match: ${match.name}');
      return match;
    }

    // 2. البحث بالاسم الجزئي
    match = _windowsPrinters.where((wp) => 
        wp.name.toLowerCase().contains(odooPrinter.name.toLowerCase()) ||
        odooPrinter.name.toLowerCase().contains(wp.name.toLowerCase())).firstOrNull;
    if (match != null) {
      debugPrint('  ✅ Found partial name match: ${match.name}');
      return match;
    }

    // 3. البحث حسب نوع الطابعة (إذا كان متوفراً)
    try {
      if (odooPrinter.receiptPrinterType != null) {
        final printerType = odooPrinter.receiptPrinterType!.value.toLowerCase();
        match = _windowsPrinters.where((wp) => 
            wp.name.toLowerCase().contains(printerType)).firstOrNull;
        if (match != null) return match;
      }
    } catch (e) {
      debugPrint('⚠️ Receipt printer type not available, skipping type-based matching');
    }

    // 4. للطابعات الشبكية، البحث بعنوان IP
    if (odooPrinter.isNetworkPrinter && odooPrinter.printerIp != null) {
      debugPrint('  🔍 Searching by IP: ${odooPrinter.printerIp}');
      match = _windowsPrinters.where((wp) => 
          wp.name.contains(odooPrinter.printerIp!)).firstOrNull;
      if (match != null) {
        debugPrint('  ✅ Found IP match: ${match.name}');
        return match;
      }
    }

    debugPrint('  ❌ No matching Windows printer found for Odoo printer: ${odooPrinter.name}');
    return null;
  }

  /// ربط طابعة Odoo مع طابعة Windows يدوياً
  Future<void> setManualPrinterMapping(int odooPrinterId, String windowsPrinterName) async {
    _printerMatching[odooPrinterId] = windowsPrinterName;
    await _savePrinterMatching();
    debugPrint('✅ Manual mapping set: Odoo Printer $odooPrinterId -> $windowsPrinterName');
  }

  /// إزالة ربط طابعة
  Future<void> removePrinterMapping(int odooPrinterId) async {
    _printerMatching.remove(odooPrinterId);
    await _savePrinterMatching();
    debugPrint('🗑️ Mapping removed for Odoo Printer $odooPrinterId');
  }

  /// الحصول على طابعة Windows لطابعة Odoo محددة
  Printer? getWindowsPrinterForOdoo(int odooPrinterId) {
    final windowsPrinterName = _printerMatching[odooPrinterId];
    if (windowsPrinterName == null) return null;
    
    return _windowsPrinters.where((p) => p.name == windowsPrinterName).firstOrNull;
  }

  /// الحصول على طابعة الإيصالات الأساسية للكاشير
  Printer? getCashierPrinter() {
    debugPrint('💰 ==========================================');
    debugPrint('💰 SEARCHING FOR CASHIER PRINTER');
    debugPrint('💰 ==========================================');
    debugPrint('  📍 POS Config Cashier IP: ${_currentPosConfig?.epsonPrinterIp ?? 'NOT SET'}');
    debugPrint('  🖥️ Available Windows Printers: ${_windowsPrinters.length}');
    
    // 1. البحث عن الطابعة الأساسية من IP في إعدادات POS
    if (_currentPosConfig?.epsonPrinterIp?.isNotEmpty == true) {
      final printerIP = _currentPosConfig!.epsonPrinterIp!;
      debugPrint('  🔍 Step 1: Searching by IP address: $printerIP');
      
      // البحث عن طابعة تحتوي على هذا IP في اسمها
      final printerByIP = _windowsPrinters.where((p) => 
          p.name.toLowerCase().contains(printerIP.toLowerCase())).firstOrNull;
      if (printerByIP != null) {
        debugPrint('  ✅ SUCCESS: Found cashier printer by IP: ${printerByIP.name}');
        debugPrint('  🎯 Method: IP Address Match');
        debugPrint('  🌐 IP: $printerIP');
        return printerByIP;
      } else {
        debugPrint('  ❌ No printer found by IP: $printerIP');
      }

      // إذا لم توجد، ابحث عن طابعة تحتوي على "epson" في اسمها
      debugPrint('  🔍 Step 2: Searching for EPSON printer...');
      final epsonPrinter = _windowsPrinters.where((p) => 
          p.name.toLowerCase().contains('epson')).firstOrNull;
      if (epsonPrinter != null) {
        debugPrint('  ✅ SUCCESS: Found EPSON printer for cashier: ${epsonPrinter.name}');
        debugPrint('  🎯 Method: EPSON Name Match');
        return epsonPrinter;
      } else {
        debugPrint('  ❌ No EPSON printer found');
      }
    } else {
      debugPrint('  ⚠️ No cashier printer IP configured in POS Config');
    }

    // 2. استخدام الطابعة الافتراضية
    debugPrint('  🔍 Step 3: Using default printer...');
    try {
      final defaultPrinter = _windowsPrinters.firstWhere((printer) => printer.isDefault);
      debugPrint('  ✅ SUCCESS: Using default printer for cashier: ${defaultPrinter.name}');
      debugPrint('  🎯 Method: Default Windows Printer');
      return defaultPrinter;
    } catch (e) {
      if (_windowsPrinters.isNotEmpty) {
        final firstPrinter = _windowsPrinters.first;
        debugPrint('  ⚠️ No default printer, using first available: ${firstPrinter.name}');
        debugPrint('  🎯 Method: First Available Printer');
        return firstPrinter;
      } else {
        debugPrint('  ❌ FAILED: No Windows printers available');
        return null;
      }
    }
  }

  /// الحصول على طابعات المطبخ
  List<Printer> getKitchenPrinters() {
    debugPrint('🍳 ==========================================');
    debugPrint('🍳 SEARCHING FOR KITCHEN PRINTERS');
    debugPrint('🍳 ==========================================');
    debugPrint('  📍 POS Config Kitchen Printer IDs: ${_currentPosConfig?.printerIds ?? 'NONE'}');
    debugPrint('  🔢 Odoo Kitchen Printers: ${_odooPrinters.length}');
    debugPrint('  🔗 Mapped Printers: ${_printerMatching.length}');
    debugPrint('  🖥️ Available Windows Printers: ${_windowsPrinters.length}');
    for (int i = 0; i < _windowsPrinters.length; i++) {
      final printer = _windowsPrinters[i];
      debugPrint('    ${i + 1}. ${printer.name} ${printer.isDefault ? '(Default)' : ''}');
    }
    
    final kitchenPrinters = <Printer>[];
    
    // البحث عن طابعات المطبخ من printer_ids (استثناء الطابعة الأساسية)
    if (_currentPosConfig?.printerIds?.isNotEmpty == true) {
      debugPrint('  🔍 Searching through ${_currentPosConfig!.printerIds!.length} kitchen printer IDs...');
      
      for (int i = 0; i < _currentPosConfig!.printerIds!.length; i++) {
        final printerId = _currentPosConfig!.printerIds![i];
        debugPrint('  🔍 Checking Kitchen Printer ID ${i + 1}: $printerId');
        
        // تحقق من وجود مطابقة في _printerMatching
        final mappedPrinterName = _printerMatching[printerId];
        debugPrint('    🔗 Mapping lookup: $printerId -> ${mappedPrinterName ?? 'NOT FOUND'}');
        
        final windowsPrinter = getWindowsPrinterForOdoo(printerId);
        if (windowsPrinter != null) {
          kitchenPrinters.add(windowsPrinter);
          debugPrint('  ✅ SUCCESS: Found kitchen printer: ${windowsPrinter.name}');
          debugPrint('    🆔 Odoo ID: $printerId');
          debugPrint('    🖥️ Windows Name: ${windowsPrinter.name}');
          debugPrint('    🎯 Method: Mapped from Odoo');
        } else {
          debugPrint('  ❌ FAILED: No Windows printer found for Odoo ID: $printerId');
          debugPrint('    📍 Check printer mapping in settings');
          debugPrint('    📍 Available mappings: $_printerMatching');
        }
      }
    } else {
      debugPrint('  ⚠️ No kitchen printer IDs configured in POS Config');
      debugPrint('    📍 Check printer_ids field in pos.config');
    }

    // Fallback: إذا لم نجد طابعات مطبخ ولكن لدينا طابعات Windows متاحة
    if (kitchenPrinters.isEmpty && _windowsPrinters.length > 1) {
      debugPrint('  🔄 FALLBACK: Trying to use available Windows printers as kitchen printers...');
      
      // استخدم الطابعات الأخرى (غير طابعة الكاشير) كطابعات مطبخ
      final cashierPrinter = getCashierPrinter();
      final availableKitchenPrinters = _windowsPrinters.where((p) => 
        cashierPrinter == null || p.name != cashierPrinter.name
      ).toList();
      
      if (availableKitchenPrinters.isNotEmpty) {
        // استخدم أول طابعة متاحة كطابعة مطبخ
        kitchenPrinters.add(availableKitchenPrinters.first);
        debugPrint('  ✅ FALLBACK SUCCESS: Using ${availableKitchenPrinters.first.name} as kitchen printer');
        debugPrint('    🎯 Method: Windows Printer Fallback');
      }
    }

    debugPrint('  📊 RESULT: Found ${kitchenPrinters.length} kitchen printers');
    if (kitchenPrinters.isNotEmpty) {
      for (int i = 0; i < kitchenPrinters.length; i++) {
        debugPrint('    ${i + 1}. ${kitchenPrinters[i].name}');
      }
    }
    
    return kitchenPrinters;
  }

  /// الحصول على طابعة محددة حسب النوع
  Printer? getPrinterByType(PrinterUsageType type) {
    switch (type) {
      case PrinterUsageType.cashier:
        return getCashierPrinter();
      case PrinterUsageType.kitchen:
        final kitchenPrinters = getKitchenPrinters();
        return kitchenPrinters.isNotEmpty ? kitchenPrinters.first : null;
    }
  }

  /// طباعة الإيصال مع إعدادات Odoo
  Future<Map<String, dynamic>> printReceipt({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
    int? specificPrinterId, // طابعة محددة من Odoo
    PrinterUsageType usageType = PrinterUsageType.cashier, // نوع الاستخدام
  }) async {
    try {
      // تحديد الطابعة المستخدمة
      Printer? targetPrinter;
      
      if (specificPrinterId != null) {
        targetPrinter = getWindowsPrinterForOdoo(specificPrinterId);
      } else {
        targetPrinter = getPrinterByType(usageType);
      }

      if (targetPrinter == null) {
        return {
          'successful': false,
          'message': {
            'title': 'No Printer Available',
            'body': 'No suitable ${usageType.name} printer found',
          },
        };
      }

      // إنشاء PDF للإيصال مع إعدادات Odoo
      final pdf = await _generateReceiptPDF(
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
      );

      // طباعة PDF
      await Printing.directPrintPdf(
        printer: targetPrinter,
        onLayout: (format) => pdf,
        name: 'Receipt_${order?.name ?? DateTime.now().millisecondsSinceEpoch}',
      );

      debugPrint('✅ ${usageType.name} receipt printed successfully on "${targetPrinter.name}"');
      return {
        'successful': true,
        'message': {
          'title': 'Print Successful',
          'body': '${usageType.name} receipt printed on ${targetPrinter.name}',
        },
      };

    } catch (e) {
      debugPrint('❌ Print failed: $e');
      return {
        'successful': false,
        'message': {
          'title': 'Print Error',
          'body': 'Failed to print: $e',
        },
      };
    }
  }

  /// طباعة شاملة على جميع الطابعات (الكاشير + المطبخ)
  Future<Map<String, dynamic>> printCompleteOrder({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
  }) async {
    debugPrint('🖨️ ==========================================');
    debugPrint('🖨️ STARTING COMPLETE ORDER PRINTING');
    debugPrint('🖨️ ==========================================');
    debugPrint('  📅 Time: ${DateTime.now()}');
    debugPrint('  🆔 Order: ${order?.name ?? 'TEST ORDER'}');
    debugPrint('  📦 Order Lines: ${orderLines.length}');
    debugPrint('  💰 Payments: ${payments.length}');
    debugPrint('  👤 Customer: ${customer?.name ?? 'NONE'}');
    debugPrint('  🏢 Company: ${company?.name ?? 'NONE'}');
    
    final results = <String, dynamic>{
      'cashier_print': null,
      'kitchen_prints': [],
      'overall_success': false,
      'summary': '',
    };

    try {
      // 1. طباعة إيصال الكاشير أولاً
      debugPrint('🧾 ==========================================');
      debugPrint('🧾 STEP 1: PRINTING CASHIER RECEIPT');
      debugPrint('🧾 ==========================================');
      
      final cashierResult = await printReceipt(
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
        usageType: PrinterUsageType.cashier,
      );
      
      results['cashier_print'] = cashierResult;
      
      if (cashierResult['successful'] == true) {
        debugPrint('✅ CASHIER RECEIPT: SUCCESS');
        debugPrint('  🖨️ Printer: ${cashierResult['message']['body']}');
      } else {
        debugPrint('❌ CASHIER RECEIPT: FAILED');
        debugPrint('  🔍 Error: ${cashierResult['message']['body']}');
      }

      // 2. طباعة تذاكر المطبخ ثانياً (إذا كانت مفعلة)
      debugPrint('🍳 ==========================================');
      debugPrint('🍳 STEP 2: PRINTING KITCHEN TICKETS');
      debugPrint('🍳 ==========================================');
      
      final kitchenResults = await printKitchenTickets(
        order: order,
        orderLines: orderLines,
        customer: customer,
        company: company,
      );
      
      results['kitchen_prints'] = kitchenResults;
      
      debugPrint('🍳 KITCHEN TICKETS RESULTS:');
      debugPrint('  📊 Total Kitchen Printers: ${kitchenResults.length}');
      for (int i = 0; i < kitchenResults.length; i++) {
        final result = kitchenResults[i];
        if (result['successful'] == true) {
          debugPrint('  ✅ Kitchen ${i + 1}: SUCCESS - ${result['message']['body']}');
        } else {
          debugPrint('  ❌ Kitchen ${i + 1}: FAILED - ${result['message']['body']}');
        }
      }

      // 3. تجميع النتائج
      debugPrint('📊 ==========================================');
      debugPrint('📊 STEP 3: COMPILING RESULTS');
      debugPrint('📊 ==========================================');
      
      final cashierSuccess = cashierResult['successful'] == true;
      final kitchenSuccessCount = kitchenResults.where((r) => r['successful'] == true).length;
      final totalKitchenPrinters = kitchenResults.length;

      debugPrint('  🧾 Cashier Receipt: ${cashierSuccess ? 'SUCCESS' : 'FAILED'}');
      debugPrint('  🍳 Kitchen Tickets: $kitchenSuccessCount/$totalKitchenPrinters SUCCESS');
      debugPrint('  📈 Success Rate: ${totalKitchenPrinters > 0 ? (kitchenSuccessCount / totalKitchenPrinters * 100).toStringAsFixed(1) : 0}%');

      if (cashierSuccess && kitchenSuccessCount == totalKitchenPrinters) {
        results['overall_success'] = true;
        results['summary'] = 'Printed successfully on cashier + $kitchenSuccessCount kitchen printers';
        debugPrint('✅ ==========================================');
        debugPrint('✅ COMPLETE ORDER PRINTING: SUCCESS');
        debugPrint('✅ ==========================================');
        debugPrint('  🎯 All printers worked successfully!');
      } else if (cashierSuccess && kitchenSuccessCount > 0) {
        results['overall_success'] = true;
        results['summary'] = 'Cashier printed ✓, Kitchen: $kitchenSuccessCount/$totalKitchenPrinters';
        debugPrint('⚠️ Partial printing success');
      } else if (cashierSuccess && totalKitchenPrinters == 0) {
        results['overall_success'] = true;
        results['summary'] = 'Cashier printed ✓ (No kitchen printers configured)';
        debugPrint('✅ Cashier printing successful (no kitchen printers)');
      } else {
        results['overall_success'] = false;
        results['summary'] = 'Cashier: ${cashierSuccess ? '✓' : '✗'}, Kitchen: $kitchenSuccessCount/$totalKitchenPrinters';
        debugPrint('❌ Complete order printing failed');
      }

      return {
        'successful': results['overall_success'],
        'message': {
          'title': results['overall_success'] ? 'Print Complete' : 'Print Partial/Failed',
          'body': results['summary'],
        },
        'details': results,
      };

    } catch (e) {
      debugPrint('❌ Complete order printing error: $e');
      return {
        'successful': false,
        'message': {
          'title': 'Print Error',
          'body': 'Failed to complete order printing: $e',
        },
        'details': results,
      };
    }
  }

  /// طباعة تذكرة المطبخ على جميع طابعات المطبخ
  Future<List<Map<String, dynamic>>> printKitchenTickets({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    ResPartner? customer,
    ResCompany? company,
  }) async {
    final results = <Map<String, dynamic>>[];
    final kitchenPrinters = getKitchenPrinters();
    
    if (kitchenPrinters.isEmpty) {
      debugPrint('ℹ️ No kitchen printers configured');
      return [{
        'printer': 'N/A',
        'successful': false,
        'message': {
          'title': 'No Kitchen Printers',
          'body': 'No kitchen printers configured',
        },
      }];
    }

    // طباعة على جميع طابعات المطبخ
    for (var printer in kitchenPrinters) {
      try {
        final pdf = await _generateKitchenTicketPDF(
          order: order,
          orderLines: orderLines,
          customer: customer,
          company: company,
        );

        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => pdf,
          name: 'Kitchen_Ticket_${order?.name ?? DateTime.now().millisecondsSinceEpoch}',
        );

        results.add({
          'printer': printer.name,
          'successful': true,
          'message': {
            'title': 'Kitchen Print Successful',
            'body': 'Kitchen ticket printed on ${printer.name}',
          },
        });

        debugPrint('🍳 Kitchen ticket printed successfully on "${printer.name}"');

      } catch (e) {
        results.add({
          'printer': printer.name,
          'successful': false,
          'message': {
            'title': 'Kitchen Print Error',
            'body': 'Failed to print kitchen ticket on ${printer.name}: $e',
          },
        });

        debugPrint('❌ Kitchen print failed on "${printer.name}": $e');
      }
    }

    return results;
  }

    /// إنشاء PDF للإيصال مع تصميم مبسط يطابق receipt_screen.dart
  Future<Uint8List> _generateReceiptPDF({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
  }) async {
    final pdf = pw.Document();
    
    // حساب المبالغ
    final calculatedTotal = orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotalIncl);
    final totalAmount = order?.amountTotal ?? calculatedTotal;
    final subtotalAmount = orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotal);
    final taxAmount = order?.amountTax ?? (totalAmount - subtotalAmount);
    
    // معلومات الطلب
    final orderNumber = _getOrderNumber(order);
    final orderId = order?.name ?? 'Order $orderNumber';
    final orderDate = order?.dateOrder ?? DateTime.now();
    
    // معلومات الشركة
    final companyInfo = _getCompanyInfo(company);
    
    // QR Code data
    final qrData = _generateQRData(order, company, totalAmount, taxAmount, orderNumber);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Company Logo/Name Section - بسيط مثل receipt_screen.dart
              pw.Container(
                height: 80,
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Column(
                        children: [
                          // اسم الشركة
                          _fontService.createCenteredText(
                            companyInfo['name']!.toUpperCase(),
                            fontSize: 16,
                            isBold: true,
                            color: PdfColors.black,
                          ),
                          // الشريط البرتقالي
                          pw.Container(
                            margin: const pw.EdgeInsets.only(top: 2),
                            width: 60,
                            height: 3,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey800,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // QR Code - مثل receipt_screen.dart
              pw.Container(
                width: 100,
                height: 100,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 100,
                  height: 100,
                ),
              ),
              pw.SizedBox(height: 20),
              
              // معلومات الشركة - مبسطة
              _fontService.createCenteredText(
                companyInfo['name']!,
                fontSize: 14,
                isBold: true,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 4),
              _fontService.createCenteredText(
                companyInfo['phone']!,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              pw.SizedBox(height: 2),
              _fontService.createCenteredText(
                'VAT: ${companyInfo['vat']!.replaceAll('ض.ب: ', '')}',
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              pw.SizedBox(height: 2),
              _fontService.createCenteredText(
                companyInfo['email']!,
                fontSize: 10,
                color: PdfColors.grey600,
              ),

              // معلومات العميل (إذا وجد)
              if (customer != null) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      _fontService.createCenteredText(
                        'العميل: ${customer.name}',
                        fontSize: 11,
                        isBold: true,
                        color: PdfColors.black,
                      ),
                      if (customer.phone != null || customer.mobile != null) ...[
                        pw.SizedBox(height: 2),
                        _fontService.createCenteredText(
                          'هاتف: ${customer.phone ?? customer.mobile}',
                          fontSize: 9,
                          color: PdfColors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              pw.SizedBox(height: 6),
              _fontService.createCenteredText(
                'Served by Administrator',
                fontSize: 9,
                color: PdfColors.grey,
              ),
              pw.SizedBox(height: 30),

              // رقم الطلب - مثل receipt_screen.dart
              _fontService.createCenteredText(
                orderNumber,
                fontSize: 32,
                isBold: true,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 4),
              _fontService.createCenteredText(
                orderId,
                fontSize: 10,
                color: PdfColors.grey,
              ),
              pw.SizedBox(height: 20),

              // عنوان الفاتورة
              _fontService.createCenteredText(
                'Simplified Tax Invoice',
                fontSize: 12,
                isBold: true,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 2),
              _fontService.createCenteredText(
                'فاتورة ضريبية مبسطة',
                fontSize: 11,
                color: PdfColors.grey,
              ),
              pw.SizedBox(height: 30),

              // التاريخ
              _fontService.createCenteredText(
                '${orderDate.day.toString().padLeft(2, '0')}/${orderDate.month.toString().padLeft(2, '0')}/${orderDate.year} ${orderDate.hour.toString().padLeft(2, '0')}:${orderDate.minute.toString().padLeft(2, '0')}',
                fontSize: 10,
                color: PdfColors.grey,
              ),
              pw.SizedBox(height: 30),

              // العناصر - تصميم بسيط مثل receipt_screen.dart
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  children: [
                    // قائمة العناصر بدون رؤوس
                    for (int index = 0; index < orderLines.length; index++)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // اسم المنتج
                            _fontService.createText(
                              orderLines[index].fullProductName ?? 'Unknown Product',
                              fontSize: 11,
                              isBold: true,
                              color: PdfColors.black,
                            ),
                            // الخصائص إذا وجدت
                            if (orderLines[index].attributeNames != null && orderLines[index].attributeNames!.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 1),
                                child: _fontService.createText(
                                  '(${orderLines[index].attributeNames!.join(', ')})',
                                  fontSize: 9,
                                  color: PdfColors.grey,
                                ),
                              ),
                            pw.SizedBox(height: 2),
                            // الكمية والسعر والإجمالي
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                _fontService.createText(
                                  '${orderLines[index].qty.toStringAsFixed(0)} x ${orderLines[index].priceUnit.toStringAsFixed(2)} SR',
                                  fontSize: 10,
                                  color: PdfColors.grey600,
                                ),
                                _fontService.createText(
                                  '${orderLines[index].priceSubtotalIncl.toStringAsFixed(2)} SR',
                                  fontSize: 11,
                                  isBold: true,
                                  color: PdfColors.black,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    pw.SizedBox(height: 20),

                    // خط منقط
                    pw.Container(
                      width: double.infinity,
                      height: 1,
                      margin: const pw.EdgeInsets.symmetric(vertical: 10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.grey,
                            width: 1,
                            style: pw.BorderStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                    
                    // المبلغ قبل الضريبة
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _fontService.createText(
                          'Untaxed Amount',
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                        _fontService.createText(
                          '${subtotalAmount.toStringAsFixed(2)} SR',
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    
                    // ضريبة القيمة المضافة
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _fontService.createText(
                          'VAT Taxes',
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                        _fontService.createText(
                          '${taxAmount.toStringAsFixed(2)} SR',
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                    
                    // خط منقط آخر
                    pw.Container(
                      width: double.infinity,
                      height: 1,
                      margin: const pw.EdgeInsets.symmetric(vertical: 10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.grey,
                            width: 1,
                            style: pw.BorderStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                    
                    // الإجمالي
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _fontService.createText(
                          'TOTAL / الإجمالي',
                          fontSize: 16,
                          isBold: true,
                          color: PdfColors.black,
                        ),
                        _fontService.createText(
                          '${totalAmount.toStringAsFixed(2)} SR',
                          fontSize: 16,
                          isBold: true,
                          color: PdfColors.black,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // طرق الدفع - مبسطة
              if (payments.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Column(
                    children: [
                      _fontService.createCenteredText(
                        '✅ تم الدفع بنجاح',
                        fontSize: 11,
                        isBold: true,
                        color: PdfColors.green700,
                      ),
                      pw.SizedBox(height: 6),
                      for (var entry in payments.entries)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _fontService.createText(
                              entry.key,
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                            _fontService.createText(
                              '${entry.value.toStringAsFixed(2)} SR',
                              fontSize: 10,
                              isBold: true,
                              color: PdfColors.black,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              pw.SizedBox(height: 20),
              
              // Footer بسيط
              _fontService.createCenteredText(
                'Powered by Odoo',
                fontSize: 9,
                color: PdfColors.grey,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }



  /// الحصول على رقم الطلب المختصر
  String _getOrderNumber(POSOrder? order) {
    if (order?.name != null) {
      final orderName = order!.name;
      
      // إذا كان الاسم يحتوي على '/' - مثل 'POS/2023/001'
      if (orderName.contains('/')) {
        final parts = orderName.split('/');
        if (parts.length >= 2) {
          // الحصول على آخر جزء وتحسينه
          final lastPart = parts.last;
          // إذا كان رقماً، اجعله 3 أرقام على الأقل
          if (RegExp(r'^\d+$').hasMatch(lastPart)) {
            return lastPart.padLeft(3, '0');
          }
          return lastPart;
        }
      }
      
      // إذا كان الاسم رقماً فقط
      if (RegExp(r'^\d+$').hasMatch(orderName)) {
        return orderName.padLeft(3, '0');
      }
      
      // إذا كان نص عادي، استخدم آخر 6 أحرف
      return orderName.length >= 6 ? orderName.substring(orderName.length - 6) : orderName;
    }
    
    // Fallback - رقم بناءً على الوقت
    final now = DateTime.now();
    return (now.hour * 100 + now.minute).toString().padLeft(4, '0');
  }

  /// الحصول على معلومات الشركة
  Map<String, String> _getCompanyInfo(ResCompany? company) {
    if (company != null) {
      return {
        'name': company.name,
        'address': company.fullAddress.isNotEmpty ? company.fullAddress : 'الرياض، المملكة العربية السعودية',
        'phone': company.phone ?? '+966 11 123 4567',
        'email': company.email ?? 'info@company.com',
        'website': company.website ?? 'https://company.com',
        'vat': company.formattedVatNumber.isNotEmpty ? company.formattedVatNumber : 'ض.ب: 123456789012345',
        'cr': company.formattedCompanyRegistry.isNotEmpty ? company.formattedCompanyRegistry : 'س.ت: 1010123456',
      };
    }
    
    // Fallback إذا لم تكن هناك بيانات شركة
    return {
      'name': 'متجر نقطة البيع',
      'address': 'الرياض، المملكة العربية السعودية',
      'phone': '+966 11 123 4567',
      'email': 'info@company.com',
      'website': 'https://company.com',
      'vat': 'ض.ب: 123456789012345',
      'cr': 'س.ت: 1010123456',
    };
  }

  /// إنتاج بيانات QR Code (متوافق مع ZATCA للسعودية)
  String _generateQRData(POSOrder? order, ResCompany? company, double totalAmount, double taxAmount, String orderNumber) {
    final now = DateTime.now();
    final dateFormat = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    // إنشاء بيانات QR مع معلومات الفاتورة الحقيقية (تنسيق متوافق مع ZATCA للسعودية)
    final qrData = {
      'seller': company?.name ?? 'POS System',
      'vat_number': company?.vatNumber ?? '123456789012345',
      'timestamp': order?.dateOrder != null ? 
        '${order!.dateOrder.year}-${order.dateOrder.month.toString().padLeft(2, '0')}-${order.dateOrder.day.toString().padLeft(2, '0')} ${order.dateOrder.hour.toString().padLeft(2, '0')}:${order.dateOrder.minute.toString().padLeft(2, '0')}:${order.dateOrder.second.toString().padLeft(2, '0')}' : 
        dateFormat,
      'total': totalAmount.toStringAsFixed(2),
      'vat': taxAmount.toStringAsFixed(2),
      'order_id': order?.name ?? orderNumber,
    };
    
    // تحويل إلى تنسيق string للـ QR
    return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  /// إنشاء PDF لتذكرة المطبخ
  Future<Uint8List> _generateKitchenTicketPDF({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    ResPartner? customer,
    ResCompany? company,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // عنوان تذكرة المطبخ
              pw.Center(
                child: pw.Text(
                  'تذكرة المطبخ',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'KITCHEN TICKET',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              // معلومات الطلب
              if (order != null) ...[
                pw.Text('Order: ${order.name}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Time: ${order.dateOrder.toString().substring(11, 16)}'),
                pw.SizedBox(height: 8),
              ],

              // معلومات العميل (إذا وُجد)
              if (customer != null) ...[
                pw.Text('Customer: ${customer.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
              ],

              // خط فاصل
              pw.Divider(thickness: 2),

              // العناصر المطلوب تحضيرها
              pw.Text('Items to Prepare:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              
              for (var line in orderLines) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              line.fullProductName ?? 'Product',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey300,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Text(
                              'x${line.qty.toInt()}',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (line.customerNote?.isNotEmpty == true) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Note: ${line.customerNote}',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.red),
                        ),
                      ],
                      if (line.hasCustomAttributes) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Options: ${line.attributesDisplay}',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.blue),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),

              // معلومات إضافية
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Items: ${orderLines.length}'),
                  pw.Text('Total Qty: ${orderLines.fold<double>(0, (sum, line) => sum + line.qty).toInt()}'),
                ],
              ),

              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text(
                  'Printed: ${DateTime.now().toString().substring(0, 19)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// طباعة اختبار لطابعة محددة
  Future<Map<String, dynamic>> printTest(int odooPrinterId) async {
    try {
      final windowsPrinter = getWindowsPrinterForOdoo(odooPrinterId);
      if (windowsPrinter == null) {
        return {
          'successful': false,
          'message': {'title': 'Printer Not Found', 'body': 'No Windows printer mapped to this Odoo printer'},
        };
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('TEST PRINT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Odoo Printer ID: $odooPrinterId'),
                pw.Text('Windows Printer: ${windowsPrinter.name}'),
                pw.Text('Date: ${DateTime.now()}'),
                pw.SizedBox(height: 20),
                pw.Text('Mapping test successful!'),
              ],
            ),
          ),
        ),
      );

      await Printing.directPrintPdf(
        printer: windowsPrinter,
        onLayout: (format) => pdf.save(),
        name: 'Test_Print_$odooPrinterId',
      );

      return {
        'successful': true,
        'message': {'title': 'Test Successful', 'body': 'Test printed on ${windowsPrinter.name}'},
      };
    } catch (e) {
      return {
        'successful': false,
        'message': {'title': 'Test Failed', 'body': 'Error: $e'},
      };
    }
  }

  /// الحصول على معلومات المطابقة
  List<Map<String, dynamic>> getPrinterMappingInfo() {
    final mappings = <Map<String, dynamic>>[];
    
    for (var odooPrinter in _odooPrinters) {
      final windowsPrinterName = _printerMatching[odooPrinter.id];
      final windowsPrinter = windowsPrinterName != null 
          ? _windowsPrinters.where((p) => p.name == windowsPrinterName).firstOrNull
          : null;
      
      mappings.add({
        'odoo_printer': odooPrinter,
        'windows_printer_name': windowsPrinterName,
        'windows_printer_available': windowsPrinter != null,
        'is_mapped': windowsPrinterName != null,
      });
    }
    
    return mappings;
  }

  /// تحديث قائمة الطابعات
  Future<void> refreshPrinters() async {
    await _loadWindowsPrinters();
    await _loadOdooPrinters();
    await _performAutomaticMatching();
  }

  /// إعادة تعيين جميع المطابقات
  Future<void> resetAllMappings() async {
    _printerMatching.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('odoo_windows_printer_matching');
    debugPrint('🔄 All printer mappings reset');
  }

  // Getters
  List<Printer> get windowsPrinters => List.unmodifiable(_windowsPrinters);
  List<PosPrinter> get odooPrinters => List.unmodifiable(_odooPrinters);
  POSConfig? get currentPosConfig => _currentPosConfig;
  bool get isInitialized => _isInitialized;
}

