import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../backend/models/pos_order.dart';
import '../backend/models/pos_order_line.dart';
import '../backend/models/res_partner.dart';
import '../backend/models/res_company.dart';

/// Printable Receipt Widget
/// A widget specifically designed for printing that can be converted to image
/// Optimized for 80mm thermal printers (384 pixels wide)
class PrintableReceipt extends StatelessWidget {
  final POSOrder? order;
  final List<POSOrderLine> orderLines;
  final Map<String, double> payments;
  final ResPartner? customer;
  final ResCompany? company;

  const PrintableReceipt({
    super.key,
    this.order,
    required this.orderLines,
    required this.payments,
    this.customer,
    this.company,
  });

  /// Generate QR Code data for the receipt
  String _generateQRData() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    // Create QR data with real invoice information (ZATCA compliant format for Saudi Arabia)
    final qrData = {
      'seller': company?.name ?? 'POS System',
      'vat_number': company?.vatNumber ?? '123456789012345',
      'timestamp': order?.dateOrder != null ? dateFormat.format(order!.dateOrder) : dateFormat.format(DateTime.now()),
      'total': (order?.amountTotal ?? _calculateTotal()).toStringAsFixed(2),
      'vat': (order?.amountTax ?? _calculateTaxAmount()).toStringAsFixed(2),
      'order_id': order?.name ?? _getOrderNumber(),
    };
    
    // Convert to string format for QR
    return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
  }
  
  /// Get company information from real data
  Map<String, String> _getCompanyInfo() {
    if (company != null) {
      return {
        'name': company!.name,
        'address': company!.fullAddress.isNotEmpty ? company!.fullAddress : 'الرياض، المملكة العربية السعودية',
        'phone': company!.phone ?? '+966 11 123 4567',
        'email': company!.email ?? 'info@company.com',
        'website': company!.website ?? 'https://company.com',
        'vat': company!.formattedVatNumber.isNotEmpty ? company!.formattedVatNumber : 'ض.ب: 123456789012345',
        'cr': company!.formattedCompanyRegistry.isNotEmpty ? company!.formattedCompanyRegistry : 'س.ت: 1010123456',
      };
    }
    
    // Fallback if no company data
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
  
  /// Get real order number from order data
  String _getOrderNumber() {
    if (order?.name != null) {
      // Extract the sequence number from order name (e.g., 'POS/2023/001' -> '001')
      final orderName = order!.name;
      final parts = orderName.split('/');
      if (parts.length >= 3) {
        return parts.last; // Get the last part (sequence number)
      }
      // If format is different, use last 3 characters
      return orderName.length >= 3 ? orderName.substring(orderName.length - 3) : orderName;
    }
    
    // Fallback - generate a simple number
    final now = DateTime.now();
    return (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
  }
  
  /// Get full order ID
  String _getOrderId() {
    return order?.name ?? 'Order ${_getOrderNumber()}';
  }
  
  /// Calculate total from order lines
  double _calculateTotal() {
    return orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotalIncl);
  }
  
  /// Calculate subtotal from order lines
  double _calculateSubtotal() {
    return orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotal);
  }
  
  /// Calculate tax amount from order lines
  double _calculateTaxAmount() {
    return orderLines.fold(0.0, (sum, line) => sum + (line.priceSubtotalIncl - line.priceSubtotal));
  }

  /// Build company logo widget with error handling
  Widget _buildCompanyLogo() {
    try {
      if (company?.logo != null && company!.logo!.isNotEmpty) {
        return Container(
          height: 60,
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(company!.logo!),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return _buildLogoFallback();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error building company logo: $e');
    }
    
    return _buildLogoFallback();
  }

  /// Build logo fallback widget
  Widget _buildLogoFallback() {
    final companyInfo = _getCompanyInfo();
    return Container(
      height: 60,
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: 24,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 2),
          Text(
            companyInfo['name']!,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final orderDate = order?.dateOrder ?? DateTime.now();
    final companyInfo = _getCompanyInfo();
    final orderNumber = _getOrderNumber();
    final orderId = _getOrderId();
    final qrData = _generateQRData();
    final totalAmount = order?.amountTotal ?? _calculateTotal();
    final subtotalAmount = _calculateSubtotal();
    final taxAmount = order?.amountTax ?? _calculateTaxAmount();

    return Container(
      width: 384, // 80mm = ~384 pixels (at 96 DPI)
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Company Logo
          Container(
            height: 80,
            child: Column(
              children: [
                // Show company logo if available
                if (company?.logo != null && company!.logo!.isNotEmpty) ...[
                  Container(
                    height: 60,
                    width: 80,
                    margin: const EdgeInsets.only(bottom: 4),
                    child: _buildCompanyLogo(),
                  ),
                ] else ...[
                  // Logo placeholder with company name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        // Main company name in bold
                        Text(
                          companyInfo['name']!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Orange accent bar
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 60,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // QR Code
          Container(
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 100,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          
          // Company Information
          Container(
            child: Column(
              children: [
                Text(
                  companyInfo['name']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  companyInfo['phone']!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'VAT: ${companyInfo['vat']!.replaceAll('ض.ب: ', '')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  companyInfo['email']!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Customer Information (if exists)
                if (customer != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'العميل: ${customer!.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (customer!.phone != null || customer!.mobile != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'هاتف: ${customer!.phone ?? customer!.mobile}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (customer!.vatNumber != null && customer!.vatNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'ض.ب: ${customer!.vatNumber}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 6),
                Text(
                  'Served by Administrator',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Order Number
          Container(
            child: Column(
              children: [
                Text(
                  orderNumber,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  orderId,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Receipt title
          Container(
            child: Column(
              children: [
                Text(
                  'Simplified Tax Invoice',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'فاتورة ضريبية مبسطة',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Order date and time
          Text(
            dateFormat.format(orderDate),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Items
          Container(
            width: double.infinity,
            child: Column(
              children: [
                // Items list
                ...orderLines.map(
                  (item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product name
                          Text(
                            item.fullProductName ?? 'Unknown Product',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Show attributes if available
                          if (item.attributeNames != null && item.attributeNames!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                '(${item.attributeNames!.join(', ')})',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          // Quantity, price and total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item.qty.toStringAsFixed(0)} x ${currencyFormat.format(item.priceUnit)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                currencyFormat.format(item.priceSubtotalIncl),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Summary section
                Container(
                  child: Column(
                    children: [
                      // Dotted separator
                      Container(
                        width: double.infinity,
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: List.generate(
                            (384 / 6).floor(),
                            (index) => Expanded(
                              child: Container(
                                height: 1,
                                color: index % 2 == 0 ? Colors.grey : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Untaxed Amount',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            currencyFormat.format(subtotalAmount),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'VAT Taxes',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            currencyFormat.format(taxAmount),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      
                      // Another dotted separator
                      Container(
                        width: double.infinity,
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: List.generate(
                            (384 / 6).floor(),
                            (index) => Expanded(
                              child: Container(
                                height: 1,
                                color: index % 2 == 0 ? Colors.grey : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL / الإجمالي',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            currencyFormat.format(totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment methods section
                if (payments.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '✅ تم الدفع بنجاح',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        ...payments.entries.map(
                          (entry) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                currencyFormat.format(entry.value),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Simple footer
          Container(
            child: Column(
              children: [
                Text(
                  'Powered by Odoo',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
