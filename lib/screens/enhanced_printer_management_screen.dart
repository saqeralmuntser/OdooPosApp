import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../backend/models/pos_printer.dart';
import '../backend/services/printer_configuration_service.dart';
import '../backend/services/enhanced_windows_printer_service.dart';

/// شاشة إدارة الطابعات المحسنة
/// تعرض مطابقة طابعات Odoo مع طابعات Windows وتسمح بالإدارة اليدوية
class EnhancedPrinterManagementScreen extends StatefulWidget {
  const EnhancedPrinterManagementScreen({super.key});

  @override
  State<EnhancedPrinterManagementScreen> createState() => _EnhancedPrinterManagementScreenState();
}

class _EnhancedPrinterManagementScreenState extends State<EnhancedPrinterManagementScreen> {
  final PrinterConfigurationService _configService = PrinterConfigurationService();
  final EnhancedWindowsPrinterService _windowsService = EnhancedWindowsPrinterService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _printerMappings = [];
  List<Printer> _windowsPrinters = [];
  Map<String, dynamic> _systemInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      // تهيئة الخدمات
      await _configService.initialize();
      await _windowsService.initialize(posConfig: _configService.currentPosConfig);
      
      // جلب البيانات
      await _refreshData();
      
    } catch (e) {
      _showErrorDialog('خطأ في التهيئة', 'فشل في تهيئة الخدمات: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    _printerMappings = _configService.getPrinterMappingInfo();
    _windowsPrinters = _windowsService.windowsPrinters;
    _systemInfo = _configService.getSystemCompatibilityInfo();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطابعات المتقدمة'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshSystem,
            tooltip: 'تحديث النظام',
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: _isLoading ? null : _resetAllMappings,
            tooltip: 'إعادة تعيين جميع المطابقات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSystemOverview(),
                    const SizedBox(height: 24),
                    _buildPrinterMappingsSection(),
                    const SizedBox(height: 24),
                    _buildWindowsPrintersSection(),
                    const SizedBox(height: 24),
                    _buildTestSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSystemOverview() {
    final bool systemReady = _systemInfo['system_ready'] ?? false;
    final int windowsPrintersCount = _systemInfo['windows_printers_count'] ?? 0;
    final int odooPrintersCount = _systemInfo['odoo_printers_count'] ?? 0;
    final int mappedCount = _systemInfo['mapped_printers_count'] ?? 0;
    final bool autoPrintEnabled = _systemInfo['auto_print_enabled'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  systemReady ? Icons.check_circle : Icons.warning,
                  color: systemReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'نظرة عامة على النظام',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('طابعات Windows المتاحة', '$windowsPrintersCount'),
            _buildInfoRow('طابعات Odoo المكونة', '$odooPrintersCount'),
            _buildInfoRow('الطابعات المربوطة', '$mappedCount / $odooPrintersCount'),
            _buildInfoRow('الطباعة التلقائية', autoPrintEnabled ? 'مفعلة' : 'معطلة'),
            if (_configService.currentPosConfig != null) ...[
              const Divider(),
              _buildInfoRow('إعدادات POS', _configService.currentPosConfig!.name),
              if (_configService.currentPosConfig!.epsonPrinterIp?.isNotEmpty == true)
                _buildInfoRow('طابعة الكاشير الأساسية', _configService.currentPosConfig!.epsonPrinterIp!),
              if (_configService.printingSettings.receiptHeader?.isNotEmpty == true)
                _buildInfoRow('رأس الإيصال', 'مكون'),
              if (_configService.printingSettings.receiptFooter?.isNotEmpty == true)
                _buildInfoRow('تذييل الإيصال', 'مكون'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPrinterMappingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مطابقة الطابعات',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_printerMappings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد طابعات مكونة في Odoo'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _printerMappings.length,
                itemBuilder: (context, index) {
                  final mapping = _printerMappings[index];
                  return _buildPrinterMappingCard(mapping);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterMappingCard(Map<String, dynamic> mapping) {
    final PosPrinter odooPrinter = mapping['odoo_printer'];
    final String? windowsPrinterName = mapping['windows_printer_name'];
    final bool isAvailable = mapping['windows_printer_available'] ?? false;
    final bool isMapped = mapping['is_mapped'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        odooPrinter.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        odooPrinter.printerType.displayName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (odooPrinter.connectionDescription.isNotEmpty)
                        Text(
                          odooPrinter.connectionDescription,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(isMapped, isAvailable),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: isMapped
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAvailable ? Colors.green[50] : Colors.red[50],
                            border: Border.all(
                              color: isAvailable ? Colors.green : Colors.red,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAvailable ? Icons.print : Icons.error,
                                size: 16,
                                color: isAvailable ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  windowsPrinterName!,
                                  style: TextStyle(
                                    color: isAvailable ? Colors.green[800] : Colors.red[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.link_off, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'غير مربوط',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                if (isMapped) ...[
                  IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () => _testPrinter(odooPrinter.id),
                    tooltip: 'اختبار الطباعة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () => _removePrinterMapping(odooPrinter.id),
                    tooltip: 'إلغاء الربط',
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showPrinterMappingDialog(odooPrinter),
                  tooltip: 'تعديل الربط',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isMapped, bool isAvailable) {
    String text;
    Color color;
    IconData icon;

    if (isMapped && isAvailable) {
      text = 'متصل';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (isMapped && !isAvailable) {
      text = 'غير متاح';
      color = Colors.red;
      icon = Icons.error;
    } else {
      text = 'غير مربوط';
      color = Colors.orange;
      icon = Icons.link_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsPrintersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'طابعات Windows المتاحة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_windowsPrinters.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد طابعات متاحة في Windows'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _windowsPrinters.length,
                itemBuilder: (context, index) {
                  final printer = _windowsPrinters[index];
                  return ListTile(
                    leading: Icon(
                      Icons.print,
                      color: printer.isDefault ? Colors.blue : Colors.grey,
                    ),
                    title: Text(printer.name),
                    subtitle: Text(printer.isDefault ? 'طابعة افتراضية' : 'متاحة'),
                    trailing: IconButton(
                      icon: const Icon(Icons.print),
                      onPressed: () => _testWindowsPrinter(printer.name),
                      tooltip: 'اختبار الطباعة',
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختبارات النظام',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testCashierPrinter,
                    icon: const Icon(Icons.receipt),
                    label: const Text('اختبار طابعة الكاشير'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testKitchenPrinters,
                    icon: const Icon(Icons.restaurant),
                    label: const Text('اختبار طابعات المطبخ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // زر الطباعة الشاملة الجديد
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testCompleteOrderPrinting,
                icon: const Icon(Icons.print_outlined),
                label: const Text('اختبار الطباعة الشاملة (كاشير + مطبخ)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testAllPrinters,
                    icon: const Icon(Icons.print),
                    label: const Text('اختبار جميع الطابعات'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshSystem,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث النظام'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPrinterMappingDialog(PosPrinter odooPrinter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ربط الطابعة: ${odooPrinter.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('اختر طابعة Windows للربط مع ${odooPrinter.name}:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'طابعة Windows',
                border: OutlineInputBorder(),
              ),
              items: _windowsPrinters.map((printer) {
                return DropdownMenuItem(
                  value: printer.name,
                  child: Text(printer.name),
                );
              }).toList(),
              onChanged: (selectedPrinter) {
                if (selectedPrinter != null) {
                  Navigator.pop(context);
                  _setPrinterMapping(odooPrinter.id, selectedPrinter);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _setPrinterMapping(int odooPrinterId, String windowsPrinterName) async {
    try {
      await _configService.setManualPrinterMapping(odooPrinterId, windowsPrinterName);
      await _refreshData();
      _showSuccessMessage('تم ربط الطابعة بنجاح');
    } catch (e) {
      _showErrorDialog('خطأ في الربط', 'فشل في ربط الطابعة: $e');
    }
  }

  Future<void> _removePrinterMapping(int odooPrinterId) async {
    try {
      await _configService.removePrinterMapping(odooPrinterId);
      await _refreshData();
      _showSuccessMessage('تم إلغاء ربط الطابعة');
    } catch (e) {
      _showErrorDialog('خطأ في إلغاء الربط', 'فشل في إلغاء ربط الطابعة: $e');
    }
  }

  Future<void> _testPrinter(int odooPrinterId) async {
    try {
      final result = await _windowsService.printTest(odooPrinterId);
      if (result['successful']) {
        _showSuccessMessage(result['message']['body']);
      } else {
        _showErrorDialog('فشل الاختبار', result['message']['body']);
      }
    } catch (e) {
      _showErrorDialog('خطأ في الاختبار', 'فشل في اختبار الطابعة: $e');
    }
  }

  Future<void> _testWindowsPrinter(String printerName) async {
    // هذا تحتاج لتطويره في WindowsPrinterService العادي
    _showSuccessMessage('اختبار طابعة $printerName (قريباً)');
  }

  Future<void> _testCashierPrinter() async {
    try {
      final result = await _windowsService.printReceipt(
        order: null,
        orderLines: [],
        payments: {'Test Payment': 0.0},
        usageType: PrinterUsageType.cashier,
      );
      
      if (result['successful']) {
        _showSuccessMessage('تم اختبار طابعة الكاشير بنجاح');
      } else {
        _showErrorDialog('فشل اختبار طابعة الكاشير', result['message']['body']);
      }
    } catch (e) {
      _showErrorDialog('خطأ في اختبار طابعة الكاشير', 'فشل في الاختبار: $e');
    }
  }

  Future<void> _testKitchenPrinters() async {
    try {
      final results = await _windowsService.printKitchenTickets(
        order: null,
        orderLines: [],
      );
      
      final successful = results.where((r) => r['successful'] == true).length;
      final total = results.length;
      
      if (successful > 0) {
        _showSuccessMessage('تم اختبار $successful من أصل $total طابعة مطبخ بنجاح');
      } else {
        _showErrorDialog('فشل اختبار طابعات المطبخ', 'فشل في جميع طابعات المطبخ');
      }
    } catch (e) {
      _showErrorDialog('خطأ في اختبار طابعات المطبخ', 'فشل في الاختبار: $e');
    }
  }

  Future<void> _testCompleteOrderPrinting() async {
    try {
      final result = await _windowsService.printCompleteOrder(
        order: null,
        orderLines: [],
        payments: {'Test Payment': 0.0},
      );
      
      if (result['successful']) {
        _showSuccessMessage('✅ الطباعة الشاملة نجحت: ${result['message']['body']}');
        
        // عرض التفاصيل إذا كانت متاحة
        final details = result['details'];
        if (details != null) {
          debugPrint('📊 Printing Details:');
          debugPrint('  Cashier: ${details['cashier_print']}');
          debugPrint('  Kitchen: ${details['kitchen_prints']}');
          debugPrint('  Summary: ${details['summary']}');
        }
      } else {
        _showErrorDialog('فشل الطباعة الشاملة', result['message']['body']);
      }
    } catch (e) {
      _showErrorDialog('خطأ في الطباعة الشاملة', 'فشل في الاختبار: $e');
    }
  }

  Future<void> _testAllPrinters() async {
    try {
      final results = await _configService.testAllPrinters();
      final successful = results.where((r) => r['result']['successful']).length;
      final total = results.length;
      
      _showSuccessMessage('تم اختبار $successful من أصل $total طابعة بنجاح');
    } catch (e) {
      _showErrorDialog('خطأ في الاختبار', 'فشل في اختبار الطابعات: $e');
    }
  }

  Future<void> _refreshSystem() async {
    await _configService.refreshPrinterConfiguration();
    await _refreshData();
    _showSuccessMessage('تم تحديث النظام');
  }

  Future<void> _resetAllMappings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إعادة التعيين'),
        content: const Text('هل أنت متأكد من رغبتك في إعادة تعيين جميع مطابقات الطابعات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _windowsService.resetAllMappings();
        await _refreshData();
        _showSuccessMessage('تم إعادة تعيين جميع المطابقات');
      } catch (e) {
        _showErrorDialog('خطأ في إعادة التعيين', 'فشل في إعادة تعيين المطابقات: $e');
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}
