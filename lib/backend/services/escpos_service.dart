import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/res_partner.dart';
import '../models/res_company.dart';
import '../models/network_printer.dart';

/// ESC-POS Service
/// Handles ESC-POS command generation and printer communication
class ESCPOSService {
  static final ESCPOSService _instance = ESCPOSService._internal();
  factory ESCPOSService() => _instance;
  ESCPOSService._internal();

  // ESC-POS Constants
  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int lf = 0x0A;
  static const int cr = 0x0D;

  /// Generate ESC-POS commands for receipt printing
  Future<List<int>> generateReceiptCommands({
    required POSOrder? order,
    required List<POSOrderLine> orderLines,
    required Map<String, double> payments,
    ResPartner? customer,
    ResCompany? company,
    int paperWidth = 48, // characters per line for 80mm paper
  }) async {
    final commands = <int>[];
    
    try {
      // Initialize printer
      commands.addAll(_initializePrinter());
      
      // Header
      commands.addAll(_generateHeader(company, paperWidth));
      
      // QR Code (if supported)
      if (order != null) {
        final qrData = _generateQRData(order, orderLines, company);
        commands.addAll(_generateQRCode(qrData));
      }
      
      // Company Info
      commands.addAll(_generateCompanyInfo(company, paperWidth));
      
      // Customer Info
      if (customer != null) {
        commands.addAll(_generateCustomerInfo(customer, paperWidth));
      }
      
      // Order Number and Date
      commands.addAll(_generateOrderInfo(order, paperWidth));
      
      // Invoice Title
      commands.addAll(_generateInvoiceTitle(paperWidth));
      
      // Items
      commands.addAll(_generateItems(orderLines, paperWidth));
      
      // Summary
      commands.addAll(_generateSummary(orderLines, paperWidth));
      
      // Payment Info
      commands.addAll(_generatePaymentInfo(payments, paperWidth));
      
      // Footer
      commands.addAll(_generateFooter(paperWidth));
      
      // Cut paper
      commands.addAll(_cutPaper());
      
    } catch (e) {
      print('Error generating ESC-POS commands: $e');
      // Return basic test print on error
      return _generateTestPrint();
    }
    
    return commands;
  }

  /// Initialize printer
  List<int> _initializePrinter() {
    return [esc, 0x40]; // ESC @ - Initialize printer
  }

  /// Generate header
  List<int> _generateHeader(ResCompany? company, int paperWidth) {
    final commands = <int>[];
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]); // ESC a 1
    
    // Bold text
    commands.addAll([esc, 0x45, 0x01]); // ESC E 1
    
    // Double height
    commands.addAll([esc, 0x21, 0x10]); // ESC ! 16
    
    final companyName = company?.name ?? 'متجر نقطة البيع';
    commands.addAll(_addTextLine(companyName.toUpperCase(), paperWidth));
    
    // Reset text formatting
    commands.addAll([esc, 0x21, 0x00]); // ESC ! 0
    commands.addAll([esc, 0x45, 0x00]); // ESC E 0
    
    // Add spacing
    commands.addAll(_addLineFeed(2));
    
    return commands;
  }

  /// Generate QR Code
  List<int> _generateQRCode(String qrData) {
    final commands = <int>[];
    
    try {
      // Set QR code module size
      commands.addAll([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x08]);
      
      // Set QR code error correction
      commands.addAll([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
      
      // Store QR code data
      final dataBytes = utf8.encode(qrData);
      final length = dataBytes.length + 3;
      commands.addAll([gs, 0x28, 0x6B, length & 0xFF, (length >> 8) & 0xFF, 0x31, 0x50, 0x30]);
      commands.addAll(dataBytes);
      
      // Print QR code
      commands.addAll([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
      
      commands.addAll(_addLineFeed(2));
    } catch (e) {
      print('QR code generation failed: $e');
      // Skip QR code if generation fails
    }
    
    return commands;
  }

  /// Generate company information
  List<int> _generateCompanyInfo(ResCompany? company, int paperWidth) {
    final commands = <int>[];
    
    if (company == null) return commands;
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]); // ESC a 1
    
    // Company details
    if (company.phone != null) {
      commands.addAll(_addTextLine(company.phone!, paperWidth));
    }
    
    final vatNumber = company.formattedVatNumber.isNotEmpty 
        ? company.formattedVatNumber 
        : 'VAT: 123456789012345';
    commands.addAll(_addTextLine(vatNumber, paperWidth));
    
    if (company.email != null) {
      commands.addAll(_addTextLine(company.email!, paperWidth));
    }
    
    commands.addAll(_addLineFeed(2));
    
    return commands;
  }

  /// Generate customer information
  List<int> _generateCustomerInfo(ResPartner customer, int paperWidth) {
    final commands = <int>[];
    
    // Left align
    commands.addAll([esc, 0x61, 0x00]); // ESC a 0
    
    commands.addAll(_addTextLine('العميل: ${customer.name}', paperWidth));
    
    if (customer.phone != null || customer.mobile != null) {
      final phone = customer.phone ?? customer.mobile!;
      commands.addAll(_addTextLine('هاتف: $phone', paperWidth));
    }
    
    if (customer.vatNumber != null && customer.vatNumber!.isNotEmpty) {
      commands.addAll(_addTextLine('ض.ب: ${customer.vatNumber}', paperWidth));
    }
    
    commands.addAll(_addLineFeed(1));
    
    return commands;
  }

  /// Generate order information
  List<int> _generateOrderInfo(POSOrder? order, int paperWidth) {
    final commands = <int>[];
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]); // ESC a 1
    
    // Order number (large)
    commands.addAll([esc, 0x21, 0x30]); // ESC ! 48 (double width and height)
    
    final orderNumber = _getOrderNumber(order);
    commands.addAll(_addTextLine(orderNumber, paperWidth ~/ 2));
    
    // Reset text size
    commands.addAll([esc, 0x21, 0x00]); // ESC ! 0
    
    // Order ID
    final orderId = order?.name ?? 'Order $orderNumber';
    commands.addAll(_addTextLine(orderId, paperWidth));
    
    commands.addAll(_addLineFeed(2));
    
    return commands;
  }

  /// Generate invoice title
  List<int> _generateInvoiceTitle(int paperWidth) {
    final commands = <int>[];
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]); // ESC a 1
    
    // Bold text
    commands.addAll([esc, 0x45, 0x01]); // ESC E 1
    
    commands.addAll(_addTextLine('Simplified Tax Invoice', paperWidth));
    commands.addAll(_addTextLine('فاتورة ضريبية مبسطة', paperWidth));
    
    // Reset formatting
    commands.addAll([esc, 0x45, 0x00]); // ESC E 0
    
    commands.addAll(_addLineFeed(2));
    
    // Date and time
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateTime = dateFormat.format(DateTime.now());
    commands.addAll(_addTextLine(dateTime, paperWidth));
    
    commands.addAll(_addLineFeed(2));
    
    return commands;
  }

  /// Generate items list
  List<int> _generateItems(List<POSOrderLine> orderLines, int paperWidth) {
    final commands = <int>[];
    
    // Left align
    commands.addAll([esc, 0x61, 0x00]); // ESC a 0
    
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    
    for (final item in orderLines) {
      // Product name
      final productName = item.fullProductName ?? 'Unknown Product';
      commands.addAll(_addTextLine(productName, paperWidth));
      
      // Attributes (if any)
      if (item.attributeNames != null && item.attributeNames!.isNotEmpty) {
        final attributes = '(${item.attributeNames!.join(', ')})';
        commands.addAll(_addTextLine(attributes, paperWidth));
      }
      
      // Quantity, price, and total
      final qtyPrice = '${item.qty.toStringAsFixed(0)} x ${currencyFormat.format(item.priceUnit)}';
      final total = currencyFormat.format(item.priceSubtotalIncl);
      
      final line = _formatTwoColumns(qtyPrice, total, paperWidth);
      commands.addAll(_addTextLine(line, paperWidth));
      
      commands.addAll(_addLineFeed(1));
    }
    
    return commands;
  }

  /// Generate summary
  List<int> _generateSummary(List<POSOrderLine> orderLines, int paperWidth) {
    final commands = <int>[];
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    
    // Calculate totals
    final subtotal = orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotal);
    final tax = orderLines.fold(0.0, (sum, line) => sum + (line.priceSubtotalIncl - line.priceSubtotal));
    final total = orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotalIncl);
    
    // Dotted line
    commands.addAll(_addDottedLine(paperWidth));
    
    // Subtotal
    final subtotalLine = _formatTwoColumns('Untaxed Amount', currencyFormat.format(subtotal), paperWidth);
    commands.addAll(_addTextLine(subtotalLine, paperWidth));
    
    // Tax
    final taxLine = _formatTwoColumns('VAT Taxes', currencyFormat.format(tax), paperWidth);
    commands.addAll(_addTextLine(taxLine, paperWidth));
    
    // Dotted line
    commands.addAll(_addDottedLine(paperWidth));
    
    // Total (bold)
    commands.addAll([esc, 0x45, 0x01]); // ESC E 1
    final totalLine = _formatTwoColumns('TOTAL / الإجمالي', currencyFormat.format(total), paperWidth);
    commands.addAll(_addTextLine(totalLine, paperWidth));
    commands.addAll([esc, 0x45, 0x00]); // ESC E 0
    
    commands.addAll(_addLineFeed(1));
    
    return commands;
  }

  /// Generate payment information
  List<int> _generatePaymentInfo(Map<String, double> payments, int paperWidth) {
    final commands = <int>[];
    
    if (payments.isEmpty) return commands;
    
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]); // ESC a 1
    
    commands.addAll(_addTextLine('✓ تم الدفع بنجاح', paperWidth));
    
    // Left align for payment details
    commands.addAll([esc, 0x61, 0x00]); // ESC a 0
    
    commands.addAll(_addLineFeed(1));
    
    for (final payment in payments.entries) {
      final paymentLine = _formatTwoColumns(payment.key, currencyFormat.format(payment.value), paperWidth);
      commands.addAll(_addTextLine(paymentLine, paperWidth));
    }
    
    commands.addAll(_addLineFeed(1));
    
    return commands;
  }

  /// Generate footer
  List<int> _generateFooter(int paperWidth) {
    final commands = <int>[];
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]); // ESC a 1
    
    commands.addAll(_addLineFeed(1));
    commands.addAll(_addTextLine('Powered by Odoo', paperWidth));
    commands.addAll(_addLineFeed(3));
    
    return commands;
  }

  /// Cut paper
  List<int> _cutPaper() {
    return [gs, 0x56, 0x00]; // GS V 0 - Full cut
  }

  /// Add text line with line feed
  List<int> _addTextLine(String text, int maxWidth) {
    final commands = <int>[];
    
    // Split long lines
    final lines = _splitText(text, maxWidth);
    
    for (final line in lines) {
      commands.addAll(utf8.encode(line));
      commands.add(lf);
    }
    
    return commands;
  }

  /// Add line feeds
  List<int> _addLineFeed(int count) {
    return List.filled(count, lf);
  }

  /// Add dotted line
  List<int> _addDottedLine(int width) {
    final line = '-' * width;
    return _addTextLine(line, width);
  }

  /// Format two columns (left and right aligned)
  String _formatTwoColumns(String left, String right, int totalWidth) {
    final rightLength = right.length;
    final leftMaxLength = totalWidth - rightLength - 1;
    
    final leftTrimmed = left.length > leftMaxLength 
        ? left.substring(0, leftMaxLength)
        : left;
    
    final spaces = totalWidth - leftTrimmed.length - rightLength;
    return '$leftTrimmed${' ' * spaces}$right';
  }

  /// Split text into lines
  List<String> _splitText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    
    final lines = <String>[];
    var remaining = text;
    
    while (remaining.length > maxWidth) {
      var splitIndex = maxWidth;
      
      // Try to split at word boundary
      final spaceIndex = remaining.lastIndexOf(' ', splitIndex);
      if (spaceIndex > maxWidth ~/ 2) {
        splitIndex = spaceIndex;
      }
      
      lines.add(remaining.substring(0, splitIndex));
      remaining = remaining.substring(splitIndex).trim();
    }
    
    if (remaining.isNotEmpty) {
      lines.add(remaining);
    }
    
    return lines;
  }

  /// Generate QR data
  String _generateQRData(POSOrder order, List<POSOrderLine> orderLines, ResCompany? company) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final total = orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotalIncl);
    final tax = orderLines.fold(0.0, (sum, line) => sum + (line.priceSubtotalIncl - line.priceSubtotal));
    
    final qrData = {
      'seller': company?.name ?? 'POS System',
      'vat_number': company?.vatNumber ?? '123456789012345',
      'timestamp': dateFormat.format(order.dateOrder),
      'total': total.toStringAsFixed(2),
      'vat': tax.toStringAsFixed(2),
      'order_id': order.name,
    };
    
    return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  /// Get order number
  String _getOrderNumber(POSOrder? order) {
    if (order?.name != null) {
      final orderName = order!.name;
      final parts = orderName.split('/');
      if (parts.length >= 3) {
        return parts.last;
      }
      return orderName.length >= 3 ? orderName.substring(orderName.length - 3) : orderName;
    }
    
    final now = DateTime.now();
    return (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
  }

  /// Generate test print
  List<int> _generateTestPrint() {
    final commands = <int>[];
    
    // Initialize
    commands.addAll([esc, 0x40]);
    
    // Center align
    commands.addAll([esc, 0x61, 0x01]);
    
    // Bold
    commands.addAll([esc, 0x45, 0x01]);
    
    commands.addAll(utf8.encode('PRINTER TEST\n'));
    commands.addAll(utf8.encode('Flutter POS System\n'));
    
    // Normal
    commands.addAll([esc, 0x45, 0x00]);
    commands.addAll([esc, 0x61, 0x00]);
    
    commands.addAll(utf8.encode('Test Date: ${DateTime.now()}\n'));
    commands.addAll(utf8.encode('Status: Connected\n\n\n'));
    
    // Cut
    commands.addAll([gs, 0x56, 0x00]);
    
    return commands;
  }

  /// Send commands to printer
  Future<bool> sendToPrinter(NetworkPrinter printer, List<int> commands) async {
    try {
      final socket = await Socket.connect(
        printer.ipAddress, 
        printer.port, 
        timeout: const Duration(seconds: 10)
      );

      // Send commands
      socket.add(commands);
      await socket.flush();
      
      // Wait a bit for printing to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      await socket.close();
      
      print('Successfully sent ${commands.length} bytes to printer ${printer.displayName}');
      return true;
    } catch (e) {
      print('Failed to send to printer ${printer.displayName}: $e');
      return false;
    }
  }

  /// Test printer connection
  Future<bool> testPrinter(NetworkPrinter printer) async {
    final testCommands = _generateTestPrint();
    return await sendToPrinter(printer, testCommands);
  }
}
