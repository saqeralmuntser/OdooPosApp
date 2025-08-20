import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/network_printer.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/res_partner.dart';
import '../models/res_company.dart';
import 'network_printer_discovery.dart';
import 'print_queue_manager.dart';
// ESC-POS service integrated into queue manager

/// Base Printer Service
/// Implements basic printer functions similar to Odoo's BasePrinter
abstract class BasePrinter {
  List<String> receiptQueue = [];

  /// Add the receipt to the queue and process it
  /// Returns {successful: bool, message?: {title: String, body?: String}}
  Future<Map<String, dynamic>> printReceipt(Widget receiptWidget) async {
    try {
      // Convert widget to image
      final image = await processWidget(receiptWidget);
      
      // Process the image
      final base64Image = processCanvas(image);
      
      // Send to printer
      final printResult = await sendPrintingJob(base64Image);
      
      if (printResult == null || printResult['result'] == false) {
        return getResultsError(printResult);
      }
      
      return {'successful': true};
    } catch (e) {
      print('Error in printReceipt: $e');
      return getActionError();
    }
  }

  /// Convert widget to image bytes
  /// For now, we'll create a simple placeholder image
  /// In a real implementation, you would use a proper widget-to-image conversion
  Future<Uint8List> processWidget(Widget widget) async {
    try {
      // Create a simple image placeholder for now
      // In production, you would use proper widget rendering libraries
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw a white background
      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 384, 800), backgroundPaint);
      
      // Add some basic text to indicate this is a receipt
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Receipt\nPrint Placeholder\n\nThis is a simplified\nreceipt representation.\n\nUse proper widget\nrendering for production.',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout(maxWidth: 350);
      textPainter.paint(canvas, const Offset(20, 50));
      
      final picture = recorder.endRecording();
      final img = await picture.toImage(384, 800);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      
      return bytes!.buffer.asUint8List();
    } catch (e) {
      print('Error creating receipt image: $e');
      // Return minimal fallback
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 384, 800), paint);
      final picture = recorder.endRecording();
      final img = await picture.toImage(384, 800);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    }
  }

  /// Generate a JPEG base64 image from image bytes
  String processCanvas(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  /// Send printing job to printer - to be implemented by subclasses
  Future<Map<String, dynamic>?> sendPrintingJob(String base64Image);

  /// Open cash drawer - to be implemented by subclasses
  Future<Map<String, dynamic>?> openCashbox();

  /// Return error when connection to printer fails
  Map<String, dynamic> getActionError() {
    return {
      'successful': false,
      'message': {
        'title': 'Connection to Printer failed',
        'body': 'Please check if the printer is still connected.',
      },
    };
  }

  /// Return error when print result is empty or failed
  Map<String, dynamic> getResultsError(Map<String, dynamic>? printResult) {
    return {
      'successful': false,
      'message': {
        'title': 'Connection to the printer failed',
        'body': 'Please check if the printer is still connected.\n'
               'Some systems don\'t allow network calls to devices (for security reasons).\n'
               'If it is the case, you will need to configure your printer connection properly.',
      },
    };
  }
}

/// HW Printer
/// Printer that sends print requests through /hw_proxy endpoints
/// Doesn't require pos_iot to be installed - similar to Odoo's HWPrinter
class HWPrinter extends BasePrinter {
  final String url;
  
  HWPrinter({required this.url});

  /// Send action to hw_proxy
  Future<Map<String, dynamic>?> sendAction(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$url/hw_proxy/default_printer_action'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'params': data}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error sending action to hw_proxy: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> openCashbox() async {
    return await sendAction({'action': 'cashbox'});
  }

  @override
  Future<Map<String, dynamic>?> sendPrintingJob(String base64Image) async {
    return await sendAction({
      'action': 'print_receipt',
      'receipt': base64Image,
    });
  }
}

/// Web Printer
/// Fallback printer that uses browser's print functionality
class WebPrinter extends BasePrinter {
  @override
  Future<Map<String, dynamic>?> sendPrintingJob(String base64Image) async {
    // For web/desktop fallback - would show print dialog
    return {'successful': true, 'result': true};
  }

  @override
  Future<Map<String, dynamic>?> openCashbox() async {
    // Web printer can't open cashbox
    return {'successful': false, 'result': false};
  }
}

/// Advanced Network Printer Service
/// Manages network printers, discovery, and print queues
class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final NetworkPrinterDiscovery _printerDiscovery = NetworkPrinterDiscovery();
  final PrintQueueManager _queueManager = PrintQueueManager();
  
  bool _isInitialized = false;

  /// Initialize the printer service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _printerDiscovery.initialize();
      await _queueManager.initialize();
      _isInitialized = true;
      debugPrint('PrinterService: Advanced printer service initialized');
    } catch (e) {
      debugPrint('PrinterService: Initialization failed: $e');
    }
  }

  /// Start printer discovery
  Future<void> startDiscovery({bool continuous = false}) async {
    await _printerDiscovery.startDiscovery(continuous: continuous);
  }

  /// Stop printer discovery
  void stopDiscovery() {
    _printerDiscovery.stopDiscovery();
  }

  /// Get discovered printers
  List<NetworkPrinter> get discoveredPrinters => _printerDiscovery.discoveredPrinters;

  /// Get configured printers
  List<NetworkPrinter> get configuredPrinters => _printerDiscovery.configuredPrinters;

  /// Check if any printer is available
  bool get isAvailable => configuredPrinters.any((p) => p.isOnline);

  /// Check if currently printing
  bool get isPrinting => _queueManager.isProcessing;

  /// Get printers for specific POS config
  List<NetworkPrinter> getPrintersForConfig(int posConfigId) {
    return _printerDiscovery.getPrintersForConfig(posConfigId);
  }

  /// Configure a printer
  Future<bool> configurePrinter(NetworkPrinter printer, {int? posConfigId}) async {
    return await _printerDiscovery.configurePrinter(printer, posConfigId: posConfigId);
  }

  /// Remove printer configuration
  Future<bool> unconfigurePrinter(String printerId) async {
    return await _printerDiscovery.unconfigurePrinter(printerId);
  }

  /// Test printer
  Future<bool> testPrinter(NetworkPrinter printer) async {
    return await _printerDiscovery.testPrinter(printer);
  }

  /// Print receipt using queue system
  Future<Map<String, dynamic>> printReceipt({
    POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
    int? posConfigId,
    bool webPrintFallback = false,
  }) async {
    try {
      // Get printers for POS config
      List<NetworkPrinter> availablePrinters;
      
      if (posConfigId != null) {
        availablePrinters = getPrintersForConfig(posConfigId)
            .where((p) => p.isOnline)
            .toList();
      } else {
        availablePrinters = configuredPrinters
            .where((p) => p.isOnline)
            .toList();
      }

      if (availablePrinters.isEmpty) {
        if (webPrintFallback) {
          // Use web print fallback
          return await _printWithWebFallback();
        }
        
        return {
          'successful': false,
          'message': {
            'title': 'No Printer Available',
            'body': 'Please configure and connect a printer first.',
          },
        };
      }

      // Use the first available printer (you could implement load balancing here)
      final printer = availablePrinters.first;
      
      // Add to print queue
      final jobId = await _queueManager.addReceiptPrintJob(
        printerId: printer.id,
        order: order,
        orderLines: orderLines,
        payments: payments,
        customer: customer,
        company: company,
        priority: 5,
      );

      return {
        'successful': true,
        'message': {
          'title': 'Print Job Added',
          'body': 'Receipt sent to printer: ${printer.displayName}',
        },
        'jobId': jobId,
        'printer': printer.displayName,
      };

    } catch (e) {
      debugPrint('PrinterService: Error printing receipt: $e');
      return {
        'successful': false,
        'message': {
          'title': 'Print Error',
          'body': 'An error occurred while printing: $e',
        },
      };
    }
  }

  /// Print test page
  Future<Map<String, dynamic>> printTest(String printerId) async {
    try {
      final jobId = await _queueManager.addTestPrintJob(printerId);
      
      return {
        'successful': true,
        'message': {
          'title': 'Test Print Sent',
          'body': 'Test page sent to printer',
        },
        'jobId': jobId,
      };
    } catch (e) {
      debugPrint('PrinterService: Error printing test: $e');
      return {
        'successful': false,
        'message': {
          'title': 'Test Print Error',
          'body': 'Failed to send test print: $e',
        },
      };
    }
  }

  /// Open cash drawer
  Future<Map<String, dynamic>> openCashDrawer(String printerId) async {
    try {
      final jobId = await _queueManager.addPrintJob(
        printerId: printerId,
        jobName: 'Open Cash Drawer',
        type: PrintJobType.cashboxOpen,
        data: {},
        priority: 1, // High priority
      );
      
      return {
        'successful': true,
        'message': {
          'title': 'Cash Drawer',
          'body': 'Cash drawer opening command sent',
        },
        'jobId': jobId,
      };
    } catch (e) {
      debugPrint('PrinterService: Error opening cash drawer: $e');
      return {
        'successful': false,
        'message': {
          'title': 'Cash Drawer Error',
          'body': 'Failed to open cash drawer: $e',
        },
      };
    }
  }

  /// Get print jobs
  List<PrintJob> get allJobs => _queueManager.allJobs;

  /// Get jobs for specific printer
  List<PrintJob> getJobsForPrinter(String printerId) {
    return _queueManager.getJobsForPrinter(printerId);
  }

  /// Cancel print job
  Future<bool> cancelPrintJob(String jobId) async {
    return await _queueManager.cancelPrintJob(jobId);
  }

  /// Retry print job
  Future<bool> retryPrintJob(String jobId) async {
    return await _queueManager.retryPrintJob(jobId);
  }

  /// Clear completed jobs
  Future<void> clearCompletedJobs() async {
    await _queueManager.clearCompletedJobs();
  }

  /// Get pending jobs count
  int get pendingJobsCount => _queueManager.getPendingJobsCount();

  /// Streams for real-time updates
  Stream<List<NetworkPrinter>> get printersStream => _printerDiscovery.printersStream;
  Stream<List<PrintJob>> get jobsStream => _queueManager.jobsStream;
  Stream<String> get discoveryStatusStream => _printerDiscovery.statusStream;
  Stream<String> get queueStatusStream => _queueManager.statusStream;

  /// Web print fallback
  Future<Map<String, dynamic>> _printWithWebFallback() async {
    // Simplified web print fallback
    return {
      'successful': true,
      'message': {
        'title': 'Web Print',
        'body': 'Receipt prepared for web printing',
      },
    };
  }

  /// Legacy compatibility methods

  /// Initialize printer (legacy method)
  void initializePrinter({String? iotBoxUrl}) async {
    await initialize();
    if (iotBoxUrl != null) {
      // Start discovery to find network printers instead of using IoT Box
      await startDiscovery();
    }
  }

  /// Print widget (legacy method)
  Future<Map<String, dynamic>> print(Widget widget, {bool webPrintFallback = false}) async {
    // This is a simplified implementation for legacy compatibility
    // In practice, you would extract receipt data from the widget
    try {
      // For legacy compatibility, attempt to print with default empty data
      return await printReceipt(
        order: null,
        orderLines: [],
        payments: {},
        webPrintFallback: webPrintFallback,
      );
    } catch (e) {
      return {
        'successful': false,
        'message': {
          'title': 'Legacy Print Error',
          'body': 'Widget printing not supported in advanced mode. Use printReceipt() instead.',
        },
      };
    }
  }

  /// Set printer (legacy method - no longer needed)
  void setPrinter(dynamic printer) {
    // No-op - printers are now managed through discovery and configuration
    debugPrint('PrinterService: setPrinter is deprecated. Use configurePrinter instead.');
  }

  /// Dispose resources
  void dispose() {
    _printerDiscovery.dispose();
    _queueManager.dispose();
  }
}
