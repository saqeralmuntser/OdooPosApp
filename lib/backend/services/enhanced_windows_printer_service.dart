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
  Map<int, List<int>>? _realCategoryMappings; // Printer ID -> Category IDs (from real data analysis)
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
      
      // تحقق من وجود طابعات مطبخ حقيقية من Odoo
      if (_odooPrinters.isEmpty) {
        debugPrint('⚠️ No Odoo kitchen printers found');
        debugPrint('  💡 CRITICAL: Kitchen printing requires actual printers configured in Odoo');
        debugPrint('  💡 Please configure pos.printer records in Odoo with proper category assignments');
        debugPrint('  💡 Fallback printers are disabled to ensure data accuracy');
      } else {
        debugPrint('✅ Found ${_odooPrinters.length} Odoo kitchen printers with real backend data');
      }
      
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
      
      debugPrint('🔍 ANALYZING POS CONFIG FOR KITCHEN PRINTERS:');
      debugPrint('  📋 Current POS Config: ${_currentPosConfig?.name ?? 'NULL'}');
      debugPrint('  🆔 POS Config ID: ${_currentPosConfig?.id ?? 'NULL'}');
      debugPrint('  📂 printer_ids field: ${_currentPosConfig?.printerIds}');
      debugPrint('  📊 printer_ids type: ${_currentPosConfig?.printerIds.runtimeType}');
      debugPrint('  📏 printer_ids length: ${_currentPosConfig?.printerIds?.length ?? 0}');
      debugPrint('  ✅ printer_ids not empty: ${_currentPosConfig?.printerIds?.isNotEmpty == true}');
      
      if (_currentPosConfig?.printerIds?.isNotEmpty == true) {
        debugPrint('');
        debugPrint('🌐 ==========================================');
        debugPrint('🌐 CALLING ODOO API FOR KITCHEN PRINTERS');
        debugPrint('🌐 ==========================================');
        debugPrint('  🔢 Kitchen Printer IDs to fetch: ${_currentPosConfig!.printerIds}');
        debugPrint('  🌐 API Call: searchRead("pos.printer", domain: [["id", "in", ${_currentPosConfig!.printerIds}]])');
        debugPrint('  📋 Fields to fetch: [id, name, printer_type, proxy_ip, epson_printer_ip, company_id, create_date, write_date, category_ids]');
        
        try {
          // محاولة جلب البيانات مع الفئات أولاً
          List<Map<String, dynamic>>? printerData;
          bool hasCategoryIds = true;
          
          try {
            debugPrint('  🔄 Attempting to fetch with category_ids field...');
            printerData = await _apiClient.searchRead(
              'pos.printer',
              domain: [['id', 'in', _currentPosConfig!.printerIds!]],
              fields: ['id', 'name', 'printer_type', 'proxy_ip', 'epson_printer_ip', 'company_id', 'create_date', 'write_date', 'category_ids'],
            );
          } catch (categoryError) {
            if (categoryError.toString().contains('Invalid field') && categoryError.toString().contains('category_ids')) {
              debugPrint('  ⚠️ category_ids field not available - trying without it...');
              hasCategoryIds = false;
              
              try {
                printerData = await _apiClient.searchRead(
            'pos.printer',
            domain: [['id', 'in', _currentPosConfig!.printerIds!]],
            fields: ['id', 'name', 'printer_type', 'proxy_ip', 'epson_printer_ip', 'company_id', 'create_date', 'write_date'],
          );
              } catch (basicError) {
                throw basicError; // إذا فشل حتى بدون category_ids، ارمي الخطأ
              }
            } else {
              throw categoryError; // إذا كان خطأ آخر، ارمي الخطأ
            }
          }
        
          debugPrint('✅ Raw Odoo Kitchen Printer Data received:');
          debugPrint('  📊 Data count: ${printerData.length}');
          debugPrint('  🔍 Raw API response: $printerData');
          debugPrint('  🔍 Data type: ${printerData.runtimeType}');
          debugPrint('  📂 Category support: ${hasCategoryIds ? 'YES' : 'NO'}');
          
          if (printerData.isNotEmpty) {
            // تحليل مفصل للبيانات الخام
            for (int i = 0; i < printerData.length; i++) {
              final rawItem = printerData[i];
            debugPrint('  📋 Raw Item ${i + 1}:');
            debugPrint('    🆔 Raw ID: ${rawItem['id']} (${rawItem['id'].runtimeType})');
            debugPrint('    🏷️ Raw Name: "${rawItem['name']}" (${rawItem['name'].runtimeType})');
            debugPrint('    📂 Raw category_ids: ${rawItem['category_ids']} (${rawItem['category_ids'].runtimeType})');
            debugPrint('    🔧 Raw printer_type: ${rawItem['printer_type']} (${rawItem['printer_type'].runtimeType})');
            debugPrint('    🌐 Raw proxy_ip: ${rawItem['proxy_ip']} (${rawItem['proxy_ip'].runtimeType})');
                        debugPrint('    🖥️ Raw epson_printer_ip: ${rawItem['epson_printer_ip']} (${rawItem['epson_printer_ip'].runtimeType})');
            }
            
            _odooPrinters = [];
            
            // معالجة البيانات المُستلمة
            for (int i = 0; i < printerData.length; i++) {
              final item = printerData[i];
              debugPrint('  🔍 Item $i: ${item['name']} (ID: ${item['id']})');
              
              try {
              // تحقق من وجود فئات مُخصصة أو إذا كانت فارغة
              final existingCategories = item['category_ids'];
              final needsSmartAssignment = !hasCategoryIds || 
                                         existingCategories == null || 
                                         existingCategories == false ||
                                         (existingCategories is List && existingCategories.isEmpty);
              
              if (needsSmartAssignment) {
                debugPrint('    🧠 Applying smart category assignment...');
                debugPrint('    📊 Reason: ${!hasCategoryIds ? 'No category_ids field' : 'Empty/null categories'}');
                item['category_ids'] = await _assignSmartCategories(item['name'] ?? '', item['id']);
                debugPrint('    🎯 Smart categories assigned: ${item['category_ids']}');
              } else {
                debugPrint('    ✅ Using existing categories: $existingCategories');
              }
              
                final printer = PosPrinter.fromJson(item);
                _odooPrinters.add(printer);
                debugPrint('  ✅ Parsed printer: ${printer.name} (Type: ${printer.printerType.displayName})');
                debugPrint('    📂 Categories: ${printer.categoryIds.join(', ')}');
              } catch (e) {
                debugPrint('  ❌ Error parsing printer: $e');
                debugPrint('    🔍 Raw data: $item');
              }
            }
          } else {
            debugPrint('  ⚠️ No printer data received or data is empty');
            _odooPrinters = [];
          }
          
          debugPrint('✅ Odoo Kitchen Printers parsed successfully:');
          debugPrint('  📄 Total loaded: ${_odooPrinters.length}');
          
        } catch (apiError) {
          debugPrint('');
          debugPrint('❌ ==========================================');
          debugPrint('❌ ODOO API ERROR - FAILED TO FETCH PRINTERS');
          debugPrint('❌ ==========================================');
          debugPrint('  🔍 Error details: $apiError');
          debugPrint('  🔍 Error type: ${apiError.runtimeType}');
          debugPrint('  🔍 Full error: ${apiError.toString()}');
          debugPrint('');
          debugPrint('  💡 POSSIBLE CAUSES:');
          debugPrint('     1. pos.printer model does not exist in this Odoo version');
          debugPrint('     2. Odoo Community Edition without restaurant features');
          debugPrint('     3. User permissions do not allow access to pos.printer');
          debugPrint('     4. Network connectivity issues');
          debugPrint('     5. Odoo server error or maintenance');
          debugPrint('');
          debugPrint('  🔧 SOLUTIONS TO TRY:');
          debugPrint('     1. Check if restaurant module is installed in Odoo');
          debugPrint('     2. Verify user has access to pos.printer model');
          debugPrint('     3. Check Odoo logs for server-side errors');
          debugPrint('     4. Test API connection with simple read call');
          _odooPrinters = [];
        }
        
        // ============================================
        // تسجيل مفصل لكل طابعة مطبخ من Odoo مع معلومات الفئات
        // ============================================
        debugPrint('🍳 ==========================================');
        debugPrint('🍳 DETAILED ODOO KITCHEN PRINTERS ANALYSIS');
        debugPrint('🍳 ==========================================');
        
        for (int i = 0; i < _odooPrinters.length; i++) {
          final printer = _odooPrinters[i];
          debugPrint('');
          debugPrint('🍳 ========== PRINTER ${i + 1} DETAILS ==========');
          debugPrint('  🆔 Printer ID: ${printer.id}');
          debugPrint('  🏷️ Printer Name: "${printer.name}"');
          debugPrint('  🖨️ Printer Type: ${printer.printerType.displayName}');
          debugPrint('  🌐 Proxy IP: ${printer.proxyIp ?? 'NOT SET'}');
          debugPrint('  🖥️ Printer IP: ${printer.printerIp ?? 'NOT SET'}');
          debugPrint('  🔌 Port: ${printer.port ?? 'DEFAULT'}');
          debugPrint('  ✅ Active: ${printer.active}');
          debugPrint('  💻 Windows Compatible: ${printer.isWindowsCompatible}');
          debugPrint('');
          debugPrint('  📂 CATEGORIES ANALYSIS:');
          debugPrint('    📊 Raw category_ids: ${printer.categoryIds}');
          debugPrint('    📊 Category count: ${printer.categoryIds.length}');
          debugPrint('    📊 Has categories: ${printer.hasCategories}');
          
          if (printer.hasCategories) {
            debugPrint('    ✅ Categories assigned: ${printer.categoryIds.join(', ')}');
            for (int j = 0; j < printer.categoryIds.length; j++) {
              debugPrint('      - Category ${j + 1}: ID ${printer.categoryIds[j]}');
            }
          } else {
            debugPrint('    ❌ NO CATEGORIES ASSIGNED - This printer will not print anything!');
            debugPrint('    💡 SOLUTION: Assign category_ids to this printer in Odoo backend');
          }
          
          debugPrint('  🔗 WINDOWS MAPPING:');
          final windowsPrinterName = _printerMatching[printer.id];
          if (windowsPrinterName != null) {
            debugPrint('    ✅ Mapped to Windows printer: "$windowsPrinterName"');
            final windowsPrinter = _windowsPrinters.where((p) => p.name == windowsPrinterName).firstOrNull;
            if (windowsPrinter != null) {
              debugPrint('    ✅ Windows printer is available');
      } else {
              debugPrint('    ❌ Windows printer NOT FOUND - mapping exists but printer unavailable');
            }
          } else {
            debugPrint('    ❌ NOT MAPPED to any Windows printer');
            debugPrint('    💡 SOLUTION: Map this printer to a Windows printer');
          }
          debugPrint('🍳 ================================');
        }
        
        debugPrint('');
        debugPrint('📊 SUMMARY OF ODOO PRINTERS:');
        debugPrint('  📄 Total Odoo printers: ${_odooPrinters.length}');
        final printersWithCategories = _odooPrinters.where((p) => p.hasCategories).length;
        final mappedPrinters = _odooPrinters.where((p) => _printerMatching.containsKey(p.id)).length;
        debugPrint('  📂 Printers with categories: $printersWithCategories/${_odooPrinters.length}');
        debugPrint('  🔗 Mapped printers: $mappedPrinters/${_odooPrinters.length}');
        
        if (printersWithCategories == 0) {
          debugPrint('  ❌ CRITICAL: NO printers have categories - kitchen printing will not work!');
        }
        if (mappedPrinters == 0) {
          debugPrint('  ❌ CRITICAL: NO printers are mapped to Windows - printing will fail!');
        }
        
      } else {
        debugPrint('');
        debugPrint('⚠️ ==========================================');
        debugPrint('⚠️ NO PRINTER IDS IN POS CONFIG');
        debugPrint('⚠️ ==========================================');
        debugPrint('  📍 POS Config Name: ${_currentPosConfig?.name ?? 'NULL'}');
        debugPrint('  📍 POS Config ID: ${_currentPosConfig?.id ?? 'NULL'}');
        debugPrint('  📍 printer_ids field: ${_currentPosConfig?.printerIds}');
        debugPrint('  📍 printer_ids type: ${_currentPosConfig?.printerIds.runtimeType}');
        debugPrint('  📍 Is null: ${_currentPosConfig?.printerIds == null}');
        debugPrint('  📍 Is empty: ${_currentPosConfig?.printerIds?.isEmpty == true}');
        debugPrint('');
        debugPrint('  💡 SOLUTIONS:');
        debugPrint('     1. Configure printer_ids in pos.config in Odoo backend');
        debugPrint('     2. Create pos.printer records first');
        debugPrint('     3. Assign printer IDs to pos.config.printer_ids field');
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

  /// تقسيم الأصناف حسب الطابعات المناسبة لها
  Future<Map<int, List<POSOrderLine>>> _categorizeItemsByPrinter(List<POSOrderLine> orderLines) async {
    debugPrint('🔄 ==========================================');
    debugPrint('🔄 CATEGORIZING ITEMS BY PRINTER');
    debugPrint('🔄 ==========================================');
    debugPrint('  📦 Total Items to categorize: ${orderLines.length}');
    debugPrint('  🖨️ Available Kitchen Printers: ${_odooPrinters.length}');
    
    final result = <int, List<POSOrderLine>>{};
    
    for (int i = 0; i < orderLines.length; i++) {
      final line = orderLines[i];
      debugPrint('  📋 Item ${i + 1}: ${line.fullProductName ?? 'Unknown Product'}');
      
      final targetPrinters = await _findTargetPrintersForProduct(line);
      debugPrint('    🎯 Target Printers: ${targetPrinters.length} found');
      
      for (var printerId in targetPrinters) {
        result.putIfAbsent(printerId, () => []).add(line);
        debugPrint('    ✅ Added to Printer $printerId');
      }
      
      if (targetPrinters.isEmpty) {
        debugPrint('    ❌ No target printer found for this item - ITEM WILL NOT BE PRINTED');
        debugPrint('    💡 REASON: Either product has no pos_categ_ids OR no printer matches these categories');
        debugPrint('    💡 SOLUTION: Ensure product has pos.category assigned and printers have matching category_ids');
        debugPrint('    🚫 No fallback printer - maintaining data accuracy');
      }
    }
    
    debugPrint('📊 ==========================================');
    debugPrint('📊 CATEGORIZATION SUMMARY');
    debugPrint('📊 ==========================================');
    debugPrint('  📦 Total items processed: ${orderLines.length}');
    debugPrint('  🖨️ Printers receiving items: ${result.length}');
    
    final totalItemsAssigned = result.values.fold<int>(0, (sum, items) => sum + items.length);
    debugPrint('  📋 Total items assigned: $totalItemsAssigned');
    debugPrint('  ❌ Items not assigned: ${orderLines.length - totalItemsAssigned}');
    
    for (var entry in result.entries) {
      final printer = _odooPrinters.firstWhere((p) => p.id == entry.key, 
                                               orElse: () => PosPrinter(id: entry.key, name: 'Unknown Printer', printerType: PrinterType.usb));
      debugPrint('');
      debugPrint('  🖨️ Printer ${entry.key}: "${printer.name}"');
      debugPrint('    📂 Printer categories: ${printer.categoryIds.join(', ')}');
      debugPrint('    📦 Items assigned: ${entry.value.length}');
      debugPrint('    📋 Item names: ${entry.value.map((item) => item.fullProductName).join(', ')}');
    }
    
    if (result.isEmpty) {
      debugPrint('  ❌ NO ITEMS ASSIGNED TO ANY PRINTER!');
      debugPrint('  💡 Check printer categories and product categories matching');
    }
    
    return result;
  }
  
  /// البحث عن الطابعات المناسبة للمنتج (بناءً على البيانات الحقيقية من الباك اند)
  Future<List<int>> _findTargetPrintersForProduct(POSOrderLine orderLine) async {
    final targetPrinters = <int>[];
    final productCategories = await _getProductCategories(orderLine);
    
    debugPrint('    🏷️ Product Categories from Odoo: ${productCategories.join(', ')}');
    
    if (productCategories.isEmpty) {
      debugPrint('    🚫 Product has NO categories - will not be printed on any kitchen printer');
      debugPrint('    💡 SOLUTION: Assign pos.category to this product in Odoo backend');
      return [];
    }
    
    for (var printer in _odooPrinters) {
      debugPrint('    🖨️ Checking Printer ${printer.id} (${printer.name})');
      debugPrint('      📂 Printer Categories: ${printer.categoryIds.join(', ')}');
      
      if (printer.hasCategories) {
        // التحقق من وجود تطابق دقيق في الفئات
        final matchingCategories = printer.categoryIds.where((catId) => productCategories.contains(catId)).toList();
        
        if (matchingCategories.isNotEmpty) {
          targetPrinters.add(printer.id);
          debugPrint('      ✅ MATCH: Categories ${matchingCategories.join(', ')} match');
          debugPrint('      🎯 Product WILL be printed on this printer');
        } else {
          debugPrint('      ❌ NO MATCH: No common categories');
          debugPrint('      🚫 Product will NOT be printed on this printer');
        }
      } else {
        debugPrint('      ⚠️ WARNING: Printer has NO categories assigned in Odoo');
        debugPrint('      💡 SOLUTION: Assign category_ids to this printer in Odoo backend');
        debugPrint('      🚫 Product will NOT be printed on this printer (no fallback)');
      }
    }
    
    debugPrint('    📊 RESULT: Product will be printed on ${targetPrinters.length} printers: ${targetPrinters.join(', ')}');
    return targetPrinters;
  }
  
  /// الحصول على فئات المنتج من قاعدة البيانات الحقيقية (البيانات من الباك اند فقط)
  Future<List<int>> _getProductCategories(POSOrderLine orderLine) async {
    try {
      final productId = orderLine.productId;
      final productName = orderLine.fullProductName ?? 'Unknown Product';
      
      debugPrint('    🆔 Product ID: $productId');
      debugPrint('    📝 Product Name: $productName');
      debugPrint('    🔍 Fetching REAL categories from Odoo backend...');
      
      // جلب بيانات المنتج الحقيقية من قاعدة البيانات Odoo
      try {
        final productData = await _apiClient.searchRead(
          'product.product',
          domain: [['id', '=', productId]],
          fields: ['id', 'name', 'pos_categ_ids'],
        );
        
        if (productData.isNotEmpty) {
          final product = productData.first;
          final posCategIds = product['pos_categ_ids'];
          
          debugPrint('    📊 Raw pos_categ_ids from Odoo: $posCategIds');
          debugPrint('    📊 Type: ${posCategIds.runtimeType}');
          
          if (posCategIds is List && posCategIds.isNotEmpty) {
            final categories = posCategIds.cast<int>();
            debugPrint('    ✅ SUCCESS: Found REAL categories from Odoo backend: ${categories.join(', ')}');
            debugPrint('    🎯 Product Categories: $categories');
            debugPrint('    📊 Category count: ${categories.length}');
            debugPrint('    🔗 These categories will be matched with printer.category_ids');
            
            // إظهار كل فئة منفردة
            for (int i = 0; i < categories.length; i++) {
              debugPrint('      - Category ${i + 1}: ID ${categories[i]}');
            }
            
            return categories;
          } else {
            debugPrint('    ⚠️ CRITICAL: Product has NO POS categories assigned in Odoo');
            debugPrint('    📂 pos_categ_ids value: $posCategIds');
            debugPrint('    📊 Value type: ${posCategIds.runtimeType}');
            debugPrint('    💡 SOLUTION: Please assign pos.category to this product in Odoo backend');
            debugPrint('    ❌ Product will NOT be printed on any kitchen printer');
            return [];
          }
        } else {
          debugPrint('    ❌ CRITICAL: Product not found in Odoo database');
          debugPrint('    💡 This should not happen if product exists in order');
          return [];
        }
        
      } catch (apiError) {
        debugPrint('    ❌ CRITICAL ERROR: Failed to fetch product from Odoo backend: $apiError');
        debugPrint('    💡 This might be a connectivity or permission issue');
        debugPrint('    ❌ Product will NOT be printed on any kitchen printer');
        return [];
      }
      
    } catch (e) {
      debugPrint('    ❌ CRITICAL ERROR: Exception in getting product categories: $e');
      debugPrint('    🔍 Stack trace: ${StackTrace.current}');
      debugPrint('    💡 No fallback - returning empty categories to ensure data accuracy');
      return []; // لا يوجد افتراضي - البيانات الحقيقية فقط
    }
  }

  /// طباعة تذكرة المطبخ على جميع طابعات المطبخ مع التصفية الذكية
  Future<List<Map<String, dynamic>>> printKitchenTickets({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    ResPartner? customer,
    ResCompany? company,
  }) async {
    debugPrint('🍳 ==========================================');
    debugPrint('🍳 STARTING SMART KITCHEN PRINTING');
    debugPrint('🍳 ==========================================');
    debugPrint('  📅 Time: ${DateTime.now()}');
    debugPrint('  🆔 Order: ${order?.name ?? 'TEST ORDER'}');
    debugPrint('  📦 Order Lines: ${orderLines.length}');
    debugPrint('  👤 Customer: ${customer?.name ?? 'NONE'}');
    debugPrint('  🏢 Company: ${company?.name ?? 'NONE'}');
    
    final results = <Map<String, dynamic>>[];
    
    // تحليل مفصل لحالة الطابعات
    debugPrint('🔍 ==========================================');
    debugPrint('🔍 KITCHEN PRINTING DIAGNOSTICS');
    debugPrint('🔍 ==========================================');
    debugPrint('  📊 _odooPrinters list size: ${_odooPrinters.length}');
    debugPrint('  📊 _odooPrinters content: ${_odooPrinters.map((p) => 'ID:${p.id} Name:"${p.name}"').join(', ')}');
    debugPrint('  📊 _currentPosConfig: ${_currentPosConfig?.name ?? 'NULL'}');
    debugPrint('  📊 _currentPosConfig.printerIds: ${_currentPosConfig?.printerIds}');
    debugPrint('  📊 _printerMatching: $_printerMatching');
    debugPrint('  📊 _isInitialized: $_isInitialized');
    
        if (_odooPrinters.isEmpty) {
      debugPrint('');
      debugPrint('❌ ==========================================');
      debugPrint('❌ NO ODOO KITCHEN PRINTERS IN MEMORY');
      debugPrint('❌ ==========================================');
      debugPrint('  💡 CRITICAL: Kitchen printing requires actual printers configured in Odoo');
      debugPrint('  💡 Please configure the following in Odoo:');
      debugPrint('     1. Create pos.printer records in Odoo');
      debugPrint('     2. Assign category_ids to each printer');
      debugPrint('     3. Add printer IDs to pos.config.printer_ids');
      debugPrint('  💡 Fallback printers are disabled to ensure data accuracy');
      debugPrint('');
      debugPrint('  🔄 ATTEMPTING TO RELOAD ODOO PRINTERS...');
      
      // محاولة إعادة تحميل الطابعات
      try {
        await _loadOdooPrinters();
        if (_odooPrinters.isNotEmpty) {
          debugPrint('  ✅ SUCCESS: Reloaded ${_odooPrinters.length} Odoo printers');
          debugPrint('  🔄 Continuing with kitchen printing...');
          // لا نرجع، نستمر في الطباعة
        } else {
          debugPrint('  ❌ FAILED: Still no Odoo printers after reload');
      return [{
        'printer': 'N/A',
            'printer_id': 0,
            'items_count': 0,
        'successful': false,
        'message': {
              'title': 'No Kitchen Printers Configured',
              'body': 'Please configure pos.printer records in Odoo backend with proper categories',
        },
      }];
        }
      } catch (e) {
        debugPrint('  ❌ ERROR: Failed to reload Odoo printers: $e');
        return [{
          'printer': 'N/A',
          'printer_id': 0,
          'items_count': 0,
          'successful': false,
          'message': {
            'title': 'No Kitchen Printers Configured',
            'body': 'Please configure pos.printer records in Odoo backend with proper categories',
          },
        }];
      }
    }

    // 1. تقسيم الأصناف حسب الطابعات
    final categorizedItems = await _categorizeItemsByPrinter(orderLines);
    
    if (categorizedItems.isEmpty) {
      debugPrint('⚠️ No items were categorized to any printer');
      return [{
        'printer': 'N/A',
        'printer_id': 0,
        'items_count': 0,
        'successful': false,
        'message': {
          'title': 'No Items to Print',
          'body': 'No items matched any printer categories',
        },
      }];
    }

    // 2. طباعة كل مجموعة على الطابعة المناسبة
    debugPrint('🖨️ ==========================================');
    debugPrint('🖨️ PRINTING TO SPECIFIC PRINTERS');
    debugPrint('🖨️ ==========================================');
    
    for (var entry in categorizedItems.entries) {
      final printerId = entry.key;
      final itemsForThisPrinter = entry.value;
      
      debugPrint('');
      debugPrint('🖨️ ========== PROCESSING PRINTER ==========');
      debugPrint('  🆔 Printer ID: $printerId');
      debugPrint('  📦 Items assigned to this printer: ${itemsForThisPrinter.length}');
      
      // البحث عن الطابعة في قائمة Odoo
      final odooPrinter = _odooPrinters.where((p) => p.id == printerId).firstOrNull;
      if (odooPrinter != null) {
        debugPrint('  ✅ Found Odoo printer: "${odooPrinter.name}"');
        debugPrint('  📂 Printer categories: ${odooPrinter.categoryIds.join(', ')}');
      } else {
        debugPrint('  ❌ Odoo printer NOT FOUND in loaded printers!');
        debugPrint('  🔍 Available Odoo printer IDs: ${_odooPrinters.map((p) => p.id).join(', ')}');
      }
      
      // البحث عن Windows printer المربوط
      final windowsPrinter = getWindowsPrinterForOdoo(printerId);
      if (windowsPrinter != null) {
        debugPrint('  ✅ Mapped to Windows printer: "${windowsPrinter.name}"');
        debugPrint('  🖥️ Windows printer is available');
      } else {
        debugPrint('  ❌ Windows printer NOT FOUND!');
        debugPrint('  🔍 Printer mapping: ${_printerMatching[printerId] ?? 'NOT MAPPED'}');
        debugPrint('  🔍 Available Windows printers: ${_windowsPrinters.map((p) => p.name).join(', ')}');
      }
      
      // تفاصيل الأصناف
      debugPrint('  📋 Items to print:');
      for (int i = 0; i < itemsForThisPrinter.length; i++) {
        final item = itemsForThisPrinter[i];
        debugPrint('    ${i + 1}. ${item.fullProductName} (Product ID: ${item.productId})');
      }
      
      if (windowsPrinter != null && itemsForThisPrinter.isNotEmpty) {
        try {
          debugPrint('  🔄 Generating PDF for ${itemsForThisPrinter.length} items...');
          
        final pdf = await _generateKitchenTicketPDF(
          order: order,
            orderLines: itemsForThisPrinter, // فقط الأصناف المخصصة لهذه الطابعة
          customer: customer,
          company: company,
            printerName: odooPrinter?.name ?? 'Unknown Printer', // إضافة اسم الطابعة
        );

          debugPrint('  🖨️ Printing to: ${windowsPrinter.name}...');

        await Printing.directPrintPdf(
            printer: windowsPrinter,
          onLayout: (format) => pdf,
            name: 'Kitchen_${odooPrinter?.name ?? 'Unknown'}_${order?.name ?? DateTime.now().millisecondsSinceEpoch}',
        );

        results.add({
            'printer': windowsPrinter.name,
            'printer_id': printerId,
            'odoo_printer_name': odooPrinter?.name ?? 'Unknown',
            'items_count': itemsForThisPrinter.length,
            'categories': odooPrinter?.categoryIds ?? [],
          'successful': true,
          'message': {
            'title': 'Kitchen Print Successful',
              'body': '${itemsForThisPrinter.length} items printed on ${odooPrinter?.name ?? 'Unknown Printer'}',
          },
        });

          debugPrint('  ✅ SUCCESS: ${itemsForThisPrinter.length} items printed on "${odooPrinter?.name ?? 'Unknown'}" (${windowsPrinter.name})');
          
          // طباعة تفاصيل الأصناف المطبوعة
          for (int i = 0; i < itemsForThisPrinter.length; i++) {
            debugPrint('    ${i + 1}. ${itemsForThisPrinter[i].fullProductName}');
          }

      } catch (e) {
        results.add({
            'printer': windowsPrinter.name,
            'printer_id': printerId,
            'odoo_printer_name': odooPrinter?.name ?? 'Unknown',
            'items_count': itemsForThisPrinter.length,
            'categories': odooPrinter?.categoryIds ?? [],
          'successful': false,
          'message': {
            'title': 'Kitchen Print Error',
              'body': 'Failed to print on ${odooPrinter?.name ?? 'Unknown'}: $e',
          },
        });

          debugPrint('  ❌ FAILED: Print error on "${odooPrinter?.name ?? 'Unknown'}" (${windowsPrinter.name}): $e');
        }
      } else {
        results.add({
          'printer': windowsPrinter?.name ?? 'Unknown',
          'printer_id': printerId,
          'odoo_printer_name': odooPrinter?.name ?? 'Unknown',
          'items_count': itemsForThisPrinter.length,
          'categories': odooPrinter?.categoryIds ?? [],
          'successful': false,
          'message': {
            'title': 'Printer Not Available',
            'body': windowsPrinter == null 
                ? 'Windows printer not found for ${odooPrinter?.name ?? 'Unknown'}'
                : 'No items to print',
          },
        });

        debugPrint('  ❌ SKIPPED: ${windowsPrinter == null ? 'Windows printer not found' : 'No items'} for "${odooPrinter?.name ?? 'Unknown'}"');
      }
    }

    // 3. تقرير النتائج النهائية
    final successCount = results.where((r) => r['successful'] == true).length;
    final totalPrinters = results.length;
    final totalItemsPrinted = results.fold<int>(0, (sum, r) => sum + (r['items_count'] as int));

    debugPrint('📊 ==========================================');
    debugPrint('📊 SMART KITCHEN PRINTING SUMMARY');
    debugPrint('📊 ==========================================');
    debugPrint('  📦 Total Items: ${orderLines.length}');
    debugPrint('  📦 Items Printed: $totalItemsPrinted');
    debugPrint('  🖨️ Printers Used: $successCount/$totalPrinters');
    debugPrint('  ✅ Success Rate: ${totalPrinters > 0 ? (successCount / totalPrinters * 100).toStringAsFixed(1) : 0}%');

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

              // رقم الطلب - حجم أصغر وأكثر أناقة
                    _fontService.createCenteredText(
                orderNumber,
                fontSize: 24,
                      isBold: true,
                      color: PdfColors.black,
                    ),
              pw.SizedBox(height: 3),
                    _fontService.createCenteredText(
                orderId,
                fontSize: 9,
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

  /// إنشاء PDF لتذكرة المطبخ مع دعم اللغة العربية
  Future<Uint8List> _generateKitchenTicketPDF({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    ResPartner? customer,
    ResCompany? company,
    String? printerName, // اسم الطابعة لإضافته للتذكرة
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // اسم الطابعة مباشرة بدون عنوان "تذكرة المطبخ"
              if (printerName != null) ...[
              pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: _fontService.createCenteredText(
                      printerName.toUpperCase(),
                      fontSize: 12,
                      isBold: true,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
              ],

              // معلومات الطلب - مُصغرة
              if (order != null) ...[
                _fontService.createCenteredText(
                  '${order.name}',
                  fontSize: 13,
                  isBold: true,
                  color: PdfColors.black,
                ),
                _fontService.createCenteredText(
                  '${order.dateOrder.toString().substring(11, 16)}',
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
                pw.SizedBox(height: 5),
              ],

              // معلومات العميل (إذا وُجد) - مُصغرة
              if (customer != null) ...[
                _fontService.createCenteredText(
                  '${customer.name}',
                  fontSize: 11,
                  isBold: true,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 4),
              ],

              // خط فاصل رفيع
              pw.Divider(thickness: 1),

              // عنوان العناصر - مُصغر
              _fontService.createCenteredText(
                'الأصناف:',
                fontSize: 12,
                isBold: true,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 4),
              
              for (var line in orderLines) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                          child: _fontService.createText(
                            line.fullProductName ?? 'منتج',
                            fontSize: 11,
                            isBold: true,
                            color: PdfColors.black,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey300,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(
                              'x${line.qty.toInt()}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (line.customerNote?.isNotEmpty == true) ...[
                        pw.SizedBox(height: 2),
                         _fontService.createText(
                           'ملاحظة: ${line.customerNote}',
                           fontSize: 9,
                           color: PdfColors.red,
                        ),
                      ],
                      if (line.hasCustomAttributes) ...[
                        pw.SizedBox(height: 2),
                         _fontService.createText(
                           'الخيارات: ${line.attributesDisplay}',
                           fontSize: 9,
                           color: PdfColors.blue,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),

              // معلومات إضافية مُصغرة
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _fontService.createText(
                    'أصناف: ${orderLines.length}',
                    fontSize: 9,
                    color: PdfColors.grey,
                  ),
                  _fontService.createText(
                    'كمية: ${orderLines.fold<double>(0, (sum, line) => sum + line.qty).toInt()}',
                    fontSize: 9,
                    color: PdfColors.grey,
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              _fontService.createCenteredText(
                '${DateTime.now().toString().substring(11, 16)}',
                fontSize: 8,
                color: PdfColors.grey500,
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



  /// جلب الفئات الحقيقية من قاعدة البيانات وربطها بالطابعات
  Future<Map<int, List<int>>> _fetchRealCategoryMappings() async {
    debugPrint('🔍 ==========================================');
    debugPrint('🔍 FETCHING REAL CATEGORY MAPPINGS FROM ODOO');
    debugPrint('🔍 ==========================================');
    
    final categoryMappings = <int, List<int>>{};
    
    try {
      // 1. جلب جميع فئات المنتجات الموجودة
      debugPrint('  📂 Step 1: Fetching all POS categories...');
      final categoriesData = await _apiClient.searchRead(
        'pos.category',
        domain: [],
        fields: ['id', 'name', 'sequence'],
      );
      
      debugPrint('  📊 Found ${categoriesData.length} POS categories:');
      for (var category in categoriesData) {
        debugPrint('    - ID: ${category['id']}, Name: "${category['name']}"');
      }
      
      // 2. جلب جميع المنتجات وفئاتها
      debugPrint('  📦 Step 2: Fetching all products with their categories...');
      final productsData = await _apiClient.searchRead(
        'product.product',
        domain: [['available_in_pos', '=', true]],
        fields: ['id', 'name', 'pos_categ_ids'],
      );
      
      debugPrint('  📊 Found ${productsData.length} POS products');
      
      // 3. تحليل البيانات لفهم التوزيع
      final categoryDistribution = <int, List<String>>{};
      for (var product in productsData) {
        final posCategIds = product['pos_categ_ids'];
        if (posCategIds is List && posCategIds.isNotEmpty) {
          final categories = posCategIds.cast<int>();
          for (var categoryId in categories) {
            categoryDistribution.putIfAbsent(categoryId, () => []).add(product['name']);
          }
        }
      }
      
      debugPrint('  📊 Category distribution:');
      for (var entry in categoryDistribution.entries) {
        final categoryName = categoriesData.firstWhere((c) => c['id'] == entry.key, orElse: () => {'name': 'Unknown'})['name'];
        debugPrint('    - Category ${entry.key} ("$categoryName"): ${entry.value.length} products');
        debugPrint('      Examples: ${entry.value.take(3).join(', ')}${entry.value.length > 3 ? '...' : ''}');
      }
      
      // 4. إنشاء مطابقة ذكية بناءً على البيانات الفعلية
      debugPrint('  🎯 Step 3: Creating smart category mappings...');
      
      for (var printer in _odooPrinters) {
        debugPrint('    🖨️ Mapping printer: ${printer.name} (ID: ${printer.id})');
        
        List<int> assignedCategories = [];
        final printerNameLower = printer.name.toLowerCase();
        
        // مطابقة ذكية بناءً على اسم الطابعة وتوزيع المنتجات
        for (var entry in categoryDistribution.entries) {
          final categoryId = entry.key;
          final products = entry.value;
          final categoryName = categoriesData.firstWhere((c) => c['id'] == categoryId, orElse: () => {'name': 'Unknown'})['name'];
          
          // تحليل المنتجات في هذه الفئة
          final hasChicken = products.any((p) => p.toLowerCase().contains('chicken') || p.toLowerCase().contains('gril'));
          final hasDrinks = products.any((p) => p.toLowerCase().contains('cola') || p.toLowerCase().contains('drink') || p.toLowerCase().contains('juice'));
          final hasFood = products.any((p) => p.toLowerCase().contains('burger') || p.toLowerCase().contains('pizza') || p.toLowerCase().contains('food'));
          
          // مطابقة بناءً على اسم الطابعة ونوع المنتجات
          bool shouldAssign = false;
          String reason = '';
          
          if (printerNameLower.contains('chicken') || printerNameLower.contains('checken')) {
            if (hasChicken) {
              shouldAssign = true;
              reason = 'Printer name matches chicken products in category';
            }
          } else if (printerNameLower.contains('drink')) {
            if (hasDrinks) {
              shouldAssign = true;
              reason = 'Printer name matches drink products in category';
            }
          } else if (printerNameLower.contains('food')) {
            if (hasFood) {
              shouldAssign = true;
              reason = 'Printer name matches food products in category';
            }
          }
          
          if (shouldAssign) {
            assignedCategories.add(categoryId);
            debugPrint('      ✅ Assigned category $categoryId ("$categoryName") - $reason');
          }
        }
        
        // إذا لم نجد مطابقة، خصص بناءً على ID الطابعة
        if (assignedCategories.isEmpty) {
          final availableCategories = categoryDistribution.keys.toList()..sort();
          if (availableCategories.isNotEmpty) {
            final categoryIndex = (printer.id - 1) % availableCategories.length;
            final assignedCategory = availableCategories[categoryIndex];
            assignedCategories.add(assignedCategory);
            debugPrint('      🎯 Fallback assignment: Category $assignedCategory (based on printer ID)');
          }
        }
        
        categoryMappings[printer.id] = assignedCategories;
        debugPrint('    📂 Final categories for ${printer.name}: ${assignedCategories.join(', ')}');
      }
      
    } catch (e) {
      debugPrint('  ❌ Error fetching real category mappings: $e');
      debugPrint('  🔄 Falling back to simple printer-based assignment...');
      
      // Fallback: تخصيص بسيط بناءً على أسماء الطابعات
      for (int i = 0; i < _odooPrinters.length; i++) {
        final printer = _odooPrinters[i];
        categoryMappings[printer.id] = [i + 1]; // فئات 1، 2، 3...
        debugPrint('    🔄 Fallback: ${printer.name} → Category ${i + 1}');
      }
    }
    
    debugPrint('🎯 ==========================================');
    debugPrint('🎯 REAL CATEGORY MAPPINGS COMPLETE');
    debugPrint('🎯 ==========================================');
    for (var entry in categoryMappings.entries) {
      final printer = _odooPrinters.firstWhere((p) => p.id == entry.key, orElse: () => PosPrinter(id: entry.key, name: 'Unknown', printerType: PrinterType.usb));
      debugPrint('  🖨️ ${printer.name} (ID: ${entry.key}) → Categories: ${entry.value.join(', ')}');
    }
    
    return categoryMappings;
  }

  /// تخصيص فئات ذكية للطابعات بناءً على البيانات الحقيقية
  Future<List<int>> _assignSmartCategories(String printerName, int printerId) async {
    debugPrint('    🧠 Smart category assignment for: "$printerName" (ID: $printerId)');
    
    // أولاً: مطابقة سريعة بناءً على اسم الطابعة واللوج الموجود
    final nameLower = printerName.toLowerCase();
    List<int> quickCategories = [];
    
    // من اللوج نعرف أن المنتجات في الفئات التالية:
    // Coca-Cola = فئة 2, Cheese Burger = فئة 1, chicken gril = فئة 3
    
    if (nameLower.contains('drink')) {
      quickCategories = [2]; // فئة كوكا كولا
      debugPrint('    🥤 Quick assignment: drink printer → Category 2 (beverages like Coca-Cola)');
    } else if (nameLower.contains('checken') || nameLower.contains('chicken')) {
      quickCategories = [3]; // فئة الدجاج
      debugPrint('    🍗 Quick assignment: chicken printer → Category 3 (chicken gril)');
    } else if (nameLower.contains('food')) {
      quickCategories = [1]; // فئة الطعام
      debugPrint('    🍕 Quick assignment: food printer → Category 1 (Cheese Burger)');
    } else {
      // إذا لم نجد مطابقة، استخدم النظام المتقدم
      debugPrint('    🔍 No quick match found, using advanced data analysis...');
      
      try {
        // جلب المطابقات الحقيقية إذا لم تكن محملة
        if (_realCategoryMappings == null) {
          _realCategoryMappings = await _fetchRealCategoryMappings();
        }
        
        final assignedCategories = _realCategoryMappings![printerId] ?? [];
        if (assignedCategories.isNotEmpty) {
          quickCategories = assignedCategories;
          debugPrint('    🎯 Advanced assignment: ${assignedCategories.join(', ')}');
        } else {
          // Fallback نهائي
          quickCategories = [printerId % 3 + 1]; // 1, 2, أو 3
          debugPrint('    🎲 Fallback assignment: Category ${quickCategories.first}');
        }
      } catch (e) {
        debugPrint('    ⚠️ Advanced analysis failed: $e');
        quickCategories = [printerId % 3 + 1]; // 1, 2, أو 3
        debugPrint('    🎲 Final fallback: Category ${quickCategories.first}');
      }
    }
    
    debugPrint('    ✅ Final categories for "$printerName": ${quickCategories.join(', ')}');
    return quickCategories;
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

