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

/// خدمة طباعة Windows بسيطة
/// تستخدم طابعات Windows العادية المتصلة بالنظام
class WindowsPrinterService {
  static final WindowsPrinterService _instance = WindowsPrinterService._internal();
  factory WindowsPrinterService() => _instance;
  WindowsPrinterService._internal();

  List<Printer> _availablePrinters = [];
  Map<int, String> _posConfigPrinters = {}; // POS Config ID -> Printer Name

  /// تهيئة الخدمة وجلب الطابعات المتاحة
  Future<void> initialize() async {
    await _loadAvailablePrinters();
    await _loadPosConfigPrinters();
  }

  /// جلب جميع الطابعات المتاحة في Windows
  Future<void> _loadAvailablePrinters() async {
    try {
      _availablePrinters = await Printing.listPrinters();
      debugPrint('🖨️ Windows Printers Found: ${_availablePrinters.length}');
      for (var printer in _availablePrinters) {
        debugPrint('  - ${printer.name} (${printer.isDefault ? 'Default' : 'Available'})');
      }
    } catch (e) {
      debugPrint('❌ Error loading Windows printers: $e');
      _availablePrinters = [];
    }
  }

  /// تحميل ربط الطابعات بـ POS Configs من التخزين المحلي
  Future<void> _loadPosConfigPrinters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPrintersJson = prefs.getString('pos_config_printers');
      if (savedPrintersJson != null) {
        final Map<String, dynamic> savedPrinters = jsonDecode(savedPrintersJson);
        _posConfigPrinters = savedPrinters.map((key, value) => MapEntry(int.parse(key), value as String));
      }
      debugPrint('🔗 POS Config Printers loaded: $_posConfigPrinters');
    } catch (e) {
      debugPrint('❌ Error loading POS config printers: $e');
      _posConfigPrinters = {};
    }
  }

  /// حفظ ربط طابعة بـ POS Config
  Future<void> setPrinterForConfig(int posConfigId, String printerName) async {
    _posConfigPrinters[posConfigId] = printerName;
    final stringMap = _posConfigPrinters.map((key, value) => MapEntry(key.toString(), value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_config_printers', jsonEncode(stringMap));
    debugPrint('✅ Printer "$printerName" assigned to POS Config $posConfigId');
  }

  /// إزالة ربط طابعة من POS Config
  Future<void> removePrinterForConfig(int posConfigId) async {
    _posConfigPrinters.remove(posConfigId);
    final stringMap = _posConfigPrinters.map((key, value) => MapEntry(key.toString(), value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_config_printers', jsonEncode(stringMap));
    debugPrint('🗑️ Printer removed from POS Config $posConfigId');
  }

  /// الحصول على اسم الطابعة المرتبطة بـ POS Config
  String? getPrinterForConfig(int posConfigId) {
    return _posConfigPrinters[posConfigId];
  }

  /// الحصول على جميع الطابعات المتاحة
  List<Printer> get availablePrinters => List.unmodifiable(_availablePrinters);

  /// الحصول على الطابعة الافتراضية
  Printer? get defaultPrinter {
    try {
      return _availablePrinters.firstWhere((printer) => printer.isDefault);
    } catch (e) {
      return _availablePrinters.isNotEmpty ? _availablePrinters.first : null;
    }
  }

  /// طباعة الإيصال
  Future<Map<String, dynamic>> printReceipt({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
    int? posConfigId,
  }) async {
    try {
      // تحديد الطابعة المستخدمة
      String? targetPrinterName;
      if (posConfigId != null) {
        targetPrinterName = getPrinterForConfig(posConfigId);
      }

      // إذا لم توجد طابعة مرتبطة، استخدم الافتراضية
      if (targetPrinterName == null) {
        final defaultPrinter = this.defaultPrinter;
        if (defaultPrinter == null) {
          return {
            'successful': false,
            'message': {
              'title': 'No Printer Available',
              'body': 'No Windows printers found',
            },
          };
        }
        targetPrinterName = defaultPrinter.name;
      }

      // البحث عن الطابعة
      final targetPrinter = _availablePrinters.where((p) => p.name == targetPrinterName).firstOrNull;
      if (targetPrinter == null) {
        return {
          'successful': false,
          'message': {
            'title': 'Printer Not Found',
            'body': 'Printer "$targetPrinterName" not available',
          },
        };
      }

      // إنشاء PDF للإيصال
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

      debugPrint('✅ Receipt printed successfully on "${targetPrinter.name}"');
      return {
        'successful': true,
        'message': {
          'title': 'Print Successful',
          'body': 'Receipt printed on ${targetPrinter.name}',
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

  /// إنشاء PDF للإيصال
  Future<Uint8List> _generateReceiptPDF({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
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
              // رأس الشركة
              pw.Center(
                child: pw.Text(
                  company?.name ?? 'POS Receipt',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              // معلومات الطلب
              if (order != null) ...[
                pw.Text('Order: ${order.name}'),
                pw.Text('Date: ${order.dateOrder.toString()}'),
                pw.SizedBox(height: 10),
              ],

              // معلومات العميل
              if (customer != null) ...[
                pw.Text('Customer: ${customer.name}'),
                if (customer.email != null && customer.email!.isNotEmpty) 
                  pw.Text('Email: ${customer.email}'),
                pw.SizedBox(height: 10),
              ],

              // خط فاصل
              pw.Divider(),

              // قائمة المنتجات
              pw.Text('Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              
              for (var line in orderLines)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text('${line.fullProductName ?? 'Product'} x ${line.qty}'),
                    ),
                    pw.Text('${line.priceSubtotal.toStringAsFixed(2)}'),
                  ],
                ),

              pw.SizedBox(height: 10),
              pw.Divider(),

              // الإجماليات
              if (order != null) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:'),
                    pw.Text('${(order.amountTotal - order.amountTax).toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax:'),
                    pw.Text('${order.amountTax.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${order.amountTotal.toStringAsFixed(2)}', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(),

              // طرق الدفع
              pw.Text('Payments:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              for (var payment in payments.entries)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(payment.key),
                    pw.Text(payment.value.toStringAsFixed(2)),
                  ],
                ),

              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Thank you for your business!'),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// طباعة اختبار
  Future<Map<String, dynamic>> printTest(String printerName) async {
    try {
      final printer = _availablePrinters.where((p) => p.name == printerName).firstOrNull;
      if (printer == null) {
        return {
          'successful': false,
          'message': {'title': 'Printer Not Found', 'body': 'Printer not available'},
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
                pw.Text('Printer: ${printer.name}'),
                pw.Text('Date: ${DateTime.now()}'),
                pw.SizedBox(height: 20),
                pw.Text('Print test successful!'),
              ],
            ),
          ),
        ),
      );

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) => pdf.save(),
        name: 'Test_Print',
      );

      return {
        'successful': true,
        'message': {'title': 'Test Successful', 'body': 'Test printed on $printerName'},
      };
    } catch (e) {
      return {
        'successful': false,
        'message': {'title': 'Test Failed', 'body': 'Error: $e'},
      };
    }
  }

  /// تحديث قائمة الطابعات
  Future<void> refreshPrinters() async {
    await _loadAvailablePrinters();
  }
}
