import 'package:flutter/material.dart';
import 'printer_configuration_service.dart';

/// مساعد طباعة POS - واجهة سهلة للطباعة من أي مكان في التطبيق
/// يوفر طرق مبسطة للطباعة مع إدارة الأخطاء والرسائل
class POSPrintingHelper {
  static final POSPrintingHelper _instance = POSPrintingHelper._internal();
  factory POSPrintingHelper() => _instance;
  POSPrintingHelper._internal();

  final PrinterConfigurationService _printerService = PrinterConfigurationService();
  bool _isInitialized = false;

  /// تهيئة خدمة الطباعة
  Future<void> initialize({int? posConfigId}) async {
    if (!_isInitialized) {
      await _printerService.initialize(posConfigId: posConfigId);
      _isInitialized = true;
      debugPrint('✅ POSPrintingHelper initialized');
    }
  }

  /// طباعة طلب كامل (الطريقة المفضلة والأسهل)
  /// تطبع تلقائياً على الكاشير + جميع طابعات المطبخ
  static Future<Map<String, dynamic>> printOrder({
    required dynamic order,
    required List<dynamic> orderLines,
    required Map<String, double> payments,
    dynamic customer,
    dynamic company,
  }) async {
    final helper = POSPrintingHelper();
    await helper.initialize();
    
    debugPrint('🖨️ POSPrintingHelper: Starting complete order printing...');
    
    return await helper._printerService.printCompleteOrder(
      order: order,
      orderLines: orderLines,
      payments: payments,
      customer: customer,
      company: company,
    );
  }

  /// طباعة إيصال فقط (طابعة الكاشير)
  static Future<Map<String, dynamic>> printCashierReceipt({
    required dynamic order,
    required List<dynamic> orderLines,
    required Map<String, double> payments,
    dynamic customer,
    dynamic company,
  }) async {
    final helper = POSPrintingHelper();
    await helper.initialize();
    
    debugPrint('🧾 POSPrintingHelper: Printing cashier receipt only...');
    
    return await helper._printerService.printCashierReceipt(
      order: order,
      orderLines: orderLines,
      payments: payments,
      customer: customer,
      company: company,
    );
  }

  /// طباعة تذكرة المطبخ فقط
  static Future<Map<String, dynamic>> printKitchenTicket({
    required dynamic order,
    required List<dynamic> orderLines,
    dynamic customer,
    dynamic company,
  }) async {
    final helper = POSPrintingHelper();
    await helper.initialize();
    
    debugPrint('🍳 POSPrintingHelper: Printing kitchen ticket only...');
    
    return await helper._printerService.printKitchenTicket(
      order: order,
      orderLines: orderLines,
      customer: customer,
      company: company,
    );
  }

  /// طباعة مع عرض رسائل النجاح/الفشل للمستخدم
  static Future<void> printOrderWithFeedback({
    required BuildContext context,
    required dynamic order,
    required List<dynamic> orderLines,
    required Map<String, double> payments,
    dynamic customer,
    dynamic company,
  }) async {
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري الطباعة...'),
          ],
        ),
      ),
    );

    try {
      final result = await printOrder(
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
      );

      // إزالة مؤشر التحميل
      Navigator.of(context).pop();

      // عرض النتيجة
      if (result['successful']) {
        _showSuccessSnackBar(context, result['message']['body']);
      } else {
        _showErrorDialog(context, 'فشل في الطباعة', result['message']['body']);
      }

    } catch (e) {
      // إزالة مؤشر التحميل
      Navigator.of(context).pop();
      _showErrorDialog(context, 'خطأ في الطباعة', 'حدث خطأ غير متوقع: $e');
    }
  }

  /// طباعة سريعة للاختبار
  static Future<Map<String, dynamic>> printTest() async {
    final helper = POSPrintingHelper();
    await helper.initialize();
    
    debugPrint('🧪 POSPrintingHelper: Running test print...');
    
    return await helper._printerService.printCompleteOrder(
      order: null,
      orderLines: [],
      payments: {'Test Payment': 0.0},
      customer: null,
      company: null,
    );
  }

  /// فحص حالة الطابعات
  static Future<Map<String, dynamic>> getSystemStatus() async {
    final helper = POSPrintingHelper();
    await helper.initialize();
    
    return helper._printerService.getSystemCompatibilityInfo();
  }

  /// عرض رسالة نجاح
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// عرض رسالة خطأ
  static void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  /// إعادة تعيين النظام
  static Future<void> resetSystem() async {
    final helper = POSPrintingHelper();
    helper._isInitialized = false;
    debugPrint('🔄 POSPrintingHelper: System reset');
  }
}

/// مثال على الاستخدام السهل من أي مكان في التطبيق:
/// 
/// ```dart
/// // للطباعة الشاملة (الطريقة المفضلة)
/// final result = await POSPrintingHelper.printOrder(
///   order: posOrder,
///   orderLines: orderLines,
///   payments: payments,
///   customer: customer,
///   company: company,
/// );
/// 
/// // للطباعة مع عرض رسائل للمستخدم
/// await POSPrintingHelper.printOrderWithFeedback(
///   context: context,
///   order: posOrder,
///   orderLines: orderLines,
///   payments: payments,
///   customer: customer,
///   company: company,
/// );
/// 
/// // للطباعة السريعة (إيصال الكاشير فقط)
/// final result = await POSPrintingHelper.printCashierReceipt(
///   order: posOrder,
///   orderLines: orderLines,
///   payments: payments,
/// );
/// 
/// // لاختبار النظام
/// final result = await POSPrintingHelper.printTest();
/// 
/// // لفحص حالة النظام
/// final status = await POSPrintingHelper.getSystemStatus();
/// ```
