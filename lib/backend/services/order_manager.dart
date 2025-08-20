import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/pos_payment.dart';
import '../models/pos_session.dart';
import '../models/product_product.dart';
import '../models/account_tax.dart';
import '../api/odoo_api_client.dart';
import '../storage/local_storage.dart';

/// Order Manager
/// Handles the complete lifecycle of POS orders including calculations,
/// line management, tax computation, and payment processing
class OrderManager {
  static final OrderManager _instance = OrderManager._internal();
  factory OrderManager() => _instance;
  OrderManager._internal();

  final OdooApiClient _apiClient = OdooApiClient();
  final LocalStorage _localStorage = LocalStorage();
  final _uuid = const Uuid();

  // Current order state
  POSOrder? _currentOrder;
  List<POSOrderLine> _currentOrderLines = [];
  List<POSPayment> _currentPayments = [];
  final StreamController<POSOrder?> _orderController = StreamController<POSOrder?>.broadcast();
  final StreamController<List<POSOrderLine>> _linesController = StreamController<List<POSOrderLine>>.broadcast();
  final StreamController<List<POSPayment>> _paymentsController = StreamController<List<POSPayment>>.broadcast();

  /// Current order stream
  Stream<POSOrder?> get orderStream => _orderController.stream;

  /// Order lines stream
  Stream<List<POSOrderLine>> get linesStream => _linesController.stream;

  /// Payments stream
  Stream<List<POSPayment>> get paymentsStream => _paymentsController.stream;

  /// Current order
  POSOrder? get currentOrder => _currentOrder;

  /// Current order lines
  List<POSOrderLine> get currentOrderLines => List.unmodifiable(_currentOrderLines);

  /// Current payments
  List<POSPayment> get currentPayments => List.unmodifiable(_currentPayments);

  /// Check if there's an active order
  bool get hasActiveOrder => _currentOrder != null;

  /// Initialize order manager
  Future<void> initialize() async {
    await _localStorage.initialize();
    await _loadDraftOrder();
  }

  /// Load any existing draft order
  Future<void> _loadDraftOrder() async {
    try {
      final draftOrders = await _localStorage.getOrders(state: 'draft');
      if (draftOrders.isNotEmpty) {
        final orderData = draftOrders.first;
        _currentOrder = POSOrder.fromJson(orderData);
        
        // Load order lines
        final lines = await _localStorage.getOrderLines(orderData['local_id']);
        _currentOrderLines = lines.map((line) => POSOrderLine.fromJson(line)).toList();
        
        // Load payments
        final payments = await _localStorage.getPayments(orderData['local_id']);
        _currentPayments = payments.map((payment) => POSPayment.fromJson(payment)).toList();
        
        _notifyListeners();
      }
    } catch (e) {
      print('Error loading draft order: $e');
    }
  }

  /// Create new order
  Future<OrderResult> createOrder({
    required POSSession session,
    required int pricelistId,
    int? partnerId,
    String? note,
  }) async {
    try {
      if (_currentOrder != null) {
        // Save current order before creating new one
        await _saveDraftOrder();
      }

      // Generate unique UUID with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderUuid = '${_uuid.v4()}-$timestamp';
      final sequenceNumber = await _getNextSequenceNumber(session.id);
      
      final order = POSOrder(
        id: -timestamp, // Temporary negative ID for offline
        name: '${session.name}-${sequenceNumber.toString().padLeft(4, '0')}',
        uuid: orderUuid,
        sessionId: session.id,
        configId: session.configId,
        companyId: session.companyId,
        partnerId: partnerId,
        userId: session.userId,
        dateOrder: DateTime.now(),
        createDate: DateTime.now(),
        amountTotal: 0.0,
        amountTax: 0.0,
        amountPaid: 0.0,
        currencyId: session.currencyId,
        sequenceNumber: sequenceNumber,
        pricelistId: pricelistId,
      );

      print('✅ Created new order with pricelist_id: $pricelistId');
      print('📅 Order date created: ${order.dateOrder.toIso8601String()}');
      
      // Test date format conversion
      final testDate = order.toServerJson()['date_order'];
      print('📅 Date format for Odoo: $testDate');
      
      // Warn if using fallback pricelist_id
      if (pricelistId == 1) {
        print('⚠️  Warning: Using fallback pricelist_id=1. Ensure this pricelist exists in your database.');
      }
      
      _currentOrder = order;
      _currentOrderLines.clear();
      _currentPayments.clear();
      
      await _saveDraftOrder();
      _notifyListeners();

      return OrderResult(success: true, order: order);
    } catch (e) {
      return OrderResult(success: false, error: 'Failed to create order: $e');
    }
  }

  /// Add product to order
  Future<OrderLineResult> addProductToOrder({
    required ProductProduct product,
    double quantity = 1.0,
    double? customPrice,
    double discount = 0.0,
    String? customerNote,
    List<int>? taxIds,
    List<String>? attributeNames,
    List<double>? attributeExtraPrices,
  }) async {
    if (_currentOrder == null) {
      return OrderLineResult(success: false, error: 'No active order');
    }

    try {
            // Check if product already exists in order with same attributes
      print('Adding product ${product.displayName}');
      
      final existingLineIndex = _currentOrderLines.indexWhere(
        (line) => line.productId == product.id && _attributesMatch(line, attributeNames),
      );
      
      print('Existing line index: $existingLineIndex');

      POSOrderLine orderLine;

      if (existingLineIndex >= 0) {
        // Update existing line (same product with same attributes)
        print('Found existing line with same product and attributes - updating quantity');
        final existingLine = _currentOrderLines[existingLineIndex];
        final newQuantity = existingLine.qty + quantity;
        
        orderLine = await _createOrderLine(
          product: product,
          quantity: newQuantity,
          customPrice: customPrice,
          discount: discount,
          customerNote: customerNote,
          taxIds: taxIds,
          attributeNames: attributeNames,
          attributeExtraPrices: attributeExtraPrices,
        );
        
        _currentOrderLines[existingLineIndex] = orderLine;
      } else {
        // Create new line for new product
        print('Creating new line for product');
        orderLine = await _createOrderLine(
          product: product,
          quantity: quantity,
          customPrice: customPrice,
          discount: discount,
          customerNote: customerNote,
          taxIds: taxIds,
          attributeNames: attributeNames,
          attributeExtraPrices: attributeExtraPrices,
        );
        
        _currentOrderLines.add(orderLine);
      }

      await _recalculateOrder();
      await _saveDraftOrder();
      _notifyListeners();

      return OrderLineResult(success: true, orderLine: orderLine);
    } catch (e) {
      return OrderLineResult(success: false, error: 'Failed to add product: $e');
    }
  }

  /// Create order line with calculations
  Future<POSOrderLine> _createOrderLine({
    required ProductProduct product,
    required double quantity,
    double? customPrice,
    double discount = 0.0,
    String? customerNote,
    List<int>? taxIds,
    List<String>? attributeNames,
    List<double>? attributeExtraPrices,
  }) async {
    // Calculate base price (attribute extras not supported in Odoo 18)
    final priceUnit = customPrice ?? product.finalPrice;
    final subtotalBeforeDiscount = priceUnit * quantity;
    final discountAmount = subtotalBeforeDiscount * (discount / 100);
    final priceSubtotal = subtotalBeforeDiscount - discountAmount;
    
    // Calculate taxes
    final taxes = await _getTaxesForProduct(product.id, taxIds);
    final taxAmount = _calculateTaxAmount(priceSubtotal, taxes);
    final priceSubtotalIncl = priceSubtotal + taxAmount;

    return POSOrderLine(
      id: -DateTime.now().microsecondsSinceEpoch, // Temporary negative ID with higher precision
      orderId: _currentOrder!.id,
      productId: product.id,
      uuid: _uuid.v4(),
      fullProductName: product.displayName,
      companyId: _currentOrder!.companyId,
      qty: quantity,
      priceUnit: priceUnit,
      priceSubtotal: priceSubtotal,
      priceSubtotalIncl: priceSubtotalIncl,
      discount: discount,
      customerNote: customerNote,
      totalCost: product.standardPrice * quantity,
      taxIds: taxes.map((tax) => tax.id).toList(),
      attributeNames: attributeNames,
      attributeExtraPrices: attributeExtraPrices,
    );
  }

  /// Check if attributes match between order line and new attributes
  bool _attributesMatch(POSOrderLine line, List<String>? newAttributes) {
    final lineAttributes = line.attributeNames;
    
    // Both null or empty
    if ((lineAttributes == null || lineAttributes.isEmpty) && 
        (newAttributes == null || newAttributes.isEmpty)) {
      return true;
    }
    
    // One is null/empty, other is not
    if ((lineAttributes == null || lineAttributes.isEmpty) != 
        (newAttributes == null || newAttributes.isEmpty)) {
      return false;
    }
    
    // Both have values - compare
    if (lineAttributes!.length != newAttributes!.length) {
      return false;
    }
    
    // Sort and compare
    final sortedLine = List<String>.from(lineAttributes)..sort();
    final sortedNew = List<String>.from(newAttributes)..sort();
    
    for (int i = 0; i < sortedLine.length; i++) {
      if (sortedLine[i] != sortedNew[i]) {
        return false;
      }
    }
    
    return true;
  }

  /// Update order line quantity
  Future<OrderLineResult> updateOrderLineQuantity(int lineIndex, double newQuantity) async {
    if (_currentOrder == null) {
      return OrderLineResult(success: false, error: 'No active order');
    }

    if (lineIndex < 0 || lineIndex >= _currentOrderLines.length) {
      return OrderLineResult(success: false, error: 'Invalid line index');
    }

    try {
      if (newQuantity <= 0) {
        // Remove line
        _currentOrderLines.removeAt(lineIndex);
      } else {
        // Update quantity
        final currentLine = _currentOrderLines[lineIndex];
        final product = await _getProduct(currentLine.productId);
        
        if (product == null) {
          return OrderLineResult(success: false, error: 'Product not found');
        }

        final updatedLine = await _createOrderLine(
          product: product,
          quantity: newQuantity,
          customPrice: currentLine.priceUnit,
          discount: currentLine.discount,
          customerNote: currentLine.customerNote,
          taxIds: currentLine.taxIds,
          attributeNames: currentLine.attributeNames,
          attributeExtraPrices: currentLine.attributeExtraPrices,
        );

        _currentOrderLines[lineIndex] = updatedLine;
      }

      await _recalculateOrder();
      await _saveDraftOrder();
      _notifyListeners();

      return OrderLineResult(success: true);
    } catch (e) {
      return OrderLineResult(success: false, error: 'Failed to update line: $e');
    }
  }

  /// Remove order line
  Future<OrderLineResult> removeOrderLine(int lineIndex) async {
    return await updateOrderLineQuantity(lineIndex, 0);
  }

  /// Apply discount to order line
  Future<OrderLineResult> applyLineDiscount(int lineIndex, double discount) async {
    if (_currentOrder == null) {
      return OrderLineResult(success: false, error: 'No active order');
    }

    if (lineIndex < 0 || lineIndex >= _currentOrderLines.length) {
      return OrderLineResult(success: false, error: 'Invalid line index');
    }

    try {
      final currentLine = _currentOrderLines[lineIndex];
      final product = await _getProduct(currentLine.productId);
      
      if (product == null) {
        return OrderLineResult(success: false, error: 'Product not found');
      }

      final updatedLine = await _createOrderLine(
        product: product,
        quantity: currentLine.qty,
        customPrice: currentLine.priceUnit,
        discount: discount,
        customerNote: currentLine.customerNote,
        taxIds: currentLine.taxIds,
      );

      _currentOrderLines[lineIndex] = updatedLine;

      await _recalculateOrder();
      await _saveDraftOrder();
      _notifyListeners();

      return OrderLineResult(success: true, orderLine: updatedLine);
    } catch (e) {
      return OrderLineResult(success: false, error: 'Failed to apply discount: $e');
    }
  }

  /// Add payment to order
  Future<PaymentResult> addPayment({
    required int paymentMethodId,
    required double amount,
    String? paymentRefNo,
    String? cardType,
    String? cardBrand,
    String? cardNo,
    String? cardholderName,
  }) async {
    if (_currentOrder == null) {
      return PaymentResult(success: false, error: 'No active order');
    }

    try {
      final payment = POSPayment(
        id: -DateTime.now().millisecondsSinceEpoch, // Temporary negative ID
        posOrderId: _currentOrder!.id,
        paymentMethodId: paymentMethodId,
        uuid: _uuid.v4(),
        amount: amount,
        currencyId: _currentOrder!.currencyId,
        paymentDate: DateTime.now(),
        paymentRefNo: paymentRefNo,
        cardType: cardType,
        cardBrand: cardBrand,
        cardNo: cardNo,
        cardholderName: cardholderName,
        sessionId: _currentOrder!.sessionId,
        userId: _currentOrder!.userId,
        companyId: _currentOrder!.companyId,
      );

      _currentPayments.add(payment);
      
      // Test payment date format conversion
      final testPaymentDate = payment.toServerJson()['payment_date'];
      print('💳 Payment date for Odoo: $testPaymentDate');

      await _recalculateOrder();
      await _saveDraftOrder();
      _notifyListeners();

      return PaymentResult(success: true, payment: payment);
    } catch (e) {
      return PaymentResult(success: false, error: 'Failed to add payment: $e');
    }
  }

  /// Remove payment
  Future<PaymentResult> removePayment(int paymentIndex) async {
    if (_currentOrder == null) {
      return PaymentResult(success: false, error: 'No active order');
    }

    if (paymentIndex < 0 || paymentIndex >= _currentPayments.length) {
      return PaymentResult(success: false, error: 'Invalid payment index');
    }

    try {
      _currentPayments.removeAt(paymentIndex);

      await _recalculateOrder();
      await _saveDraftOrder();
      _notifyListeners();

      return PaymentResult(success: true);
    } catch (e) {
      return PaymentResult(success: false, error: 'Failed to remove payment: $e');
    }
  }

  /// Get current order data for receipt (before finalizing)
  OrderReceiptData? getCurrentOrderDataForReceipt() {
    if (_currentOrder == null || _currentOrderLines.isEmpty) {
      return null;
    }

    return OrderReceiptData(
      order: _currentOrder!,
      orderLines: List<POSOrderLine>.from(_currentOrderLines),
      payments: List<POSPayment>.from(_currentPayments),
    );
  }

  /// Finalize order (mark as paid)
  Future<OrderResult> finalizeOrder() async {
    if (_currentOrder == null) {
      return OrderResult(success: false, error: 'No active order');
    }

    if (_currentOrderLines.isEmpty) {
      return OrderResult(success: false, error: 'Order has no items');
    }

    final totalPaid = _currentPayments.fold(0.0, (sum, payment) => sum + payment.amount);
    if (totalPaid < _currentOrder!.amountTotal) {
      return OrderResult(success: false, error: 'Insufficient payment');
    }

    try {
      // Calculate change if overpaid
      final change = totalPaid - _currentOrder!.amountTotal;
      if (change > 0) {
        // Add change payment (negative amount)
        final changePayment = POSPayment(
          id: -DateTime.now().millisecondsSinceEpoch,
          posOrderId: _currentOrder!.id,
          paymentMethodId: _currentPayments.first.paymentMethodId, // Use first payment method for change
          uuid: _uuid.v4(),
          amount: -change,
          currencyId: _currentOrder!.currencyId,
          paymentDate: DateTime.now(),
          isChange: true,
          sessionId: _currentOrder!.sessionId,
          userId: _currentOrder!.userId,
          companyId: _currentOrder!.companyId,
        );
        _currentPayments.add(changePayment);
      }

      // Update order state
      _currentOrder = _currentOrder!.copyWith(
        state: POSOrderState.paid,
        amountPaid: totalPaid,
        amountReturn: change,
      );

      // Save receipt data BEFORE clearing
      final receiptData = OrderReceiptData(
        order: _currentOrder!,
        orderLines: List<POSOrderLine>.from(_currentOrderLines),
        payments: List<POSPayment>.from(_currentPayments),
      );

      await _saveFinalizedOrder();
      
      // Clear current order
      await _clearCurrentOrder();

      return OrderResult(
        success: true, 
        order: receiptData.order,
        receiptData: receiptData,
      );
    } catch (e) {
      return OrderResult(success: false, error: 'Failed to finalize order: $e');
    }
  }

  /// Cancel current order
  Future<OrderResult> cancelOrder() async {
    if (_currentOrder == null) {
      return OrderResult(success: false, error: 'No active order');
    }

    try {
      // Update order state to cancelled
      _currentOrder = _currentOrder!.copyWith(state: POSOrderState.cancel);
      await _saveFinalizedOrder();
      
      // Clear current order
      await _clearCurrentOrder();

      return OrderResult(success: true);
    } catch (e) {
      return OrderResult(success: false, error: 'Failed to cancel order: $e');
    }
  }

  /// Clear current order
  Future<void> _clearCurrentOrder() async {
    _currentOrder = null;
    _currentOrderLines.clear();
    _currentPayments.clear();
    _notifyListeners();
  }

  /// Recalculate order totals
  Future<void> _recalculateOrder() async {
    if (_currentOrder == null) return;

    double subtotal = 0.0;
    double taxTotal = 0.0;

    for (final line in _currentOrderLines) {
      subtotal += line.priceSubtotal;
      taxTotal += (line.priceSubtotalIncl - line.priceSubtotal);
    }

    final totalPaid = _currentPayments.fold(0.0, (sum, payment) => sum + payment.amount);

    _currentOrder = _currentOrder!.copyWith(
      amountTotal: subtotal + taxTotal,
      amountTax: taxTotal,
      amountPaid: totalPaid,
    );
  }

  /// Save draft order to local storage
  Future<void> _saveDraftOrder() async {
    if (_currentOrder == null) return;

    try {
      // Save order
      final localOrderId = await _localStorage.saveOrder(_currentOrder!.toJson());
      
      // Clear existing lines and payments for this order
      // (In a real implementation, you'd update existing ones)
      
      // Save order lines
      for (final line in _currentOrderLines) {
        await _localStorage.saveOrderLine(localOrderId, line.toJson());
      }
      
      // Save payments
      for (final payment in _currentPayments) {
        await _localStorage.savePayment(localOrderId, payment.toJson());
      }
    } catch (e) {
      print('Error saving draft order: $e');
    }
  }

  /// Save finalized order
  Future<void> _saveFinalizedOrder() async {
    if (_currentOrder == null) return;

    try {
      // Try to sync with server if online
      if (_apiClient.isConnected && _apiClient.isAuthenticated) {
        await _syncOrderToServer();
      } else {
        // Save locally for later sync
        await _saveDraftOrder();
      }
    } catch (e) {
      print('Error saving finalized order: $e');
      // Save locally as fallback
      await _saveDraftOrder();
    }
  }

  /// Sync order to server
  Future<void> _syncOrderToServer() async {
    if (_currentOrder == null) return;

    try {
      // Create order on server using filtered data
      final orderData = _currentOrder!.toServerJson();
      
      print('=== Creating POS Order ===');
      print('Order data keys: ${orderData.keys.toList()}');
      print('Date format check: ${orderData['date_order']}');
      print('Order data: $orderData');
      
      final serverId = await _apiClient.create('pos.order', orderData);
      print('✅ Order created successfully with server ID: $serverId');
      
      // Create order lines
      print('=== Creating Order Lines (${_currentOrderLines.length}) ===');
      for (int i = 0; i < _currentOrderLines.length; i++) {
        final line = _currentOrderLines[i];
        final lineData = line.toServerJson();
        lineData['order_id'] = serverId;
        
        print('Line ${i + 1} data keys: ${lineData.keys.toList()}');
        
        // Check for problematic fields
        final problematicFields = [
          'custom_attribute_value_ids',
          'custom_attribute_value_names', 
          'custom_attribute_extra_prices'
        ];
        for (final field in problematicFields) {
          if (lineData.containsKey(field)) {
            print('⚠️  WARNING: Line ${i + 1} still contains $field: ${lineData[field]}');
          }
        }
        
        print('Line ${i + 1} data: $lineData');
        
        await _apiClient.create('pos.order.line', lineData);
        print('✅ Order line ${i + 1} created successfully');
      }
      
      // Create payments
      print('=== Creating Payments (${_currentPayments.length}) ===');
      for (int i = 0; i < _currentPayments.length; i++) {
        final payment = _currentPayments[i];
        final paymentData = payment.toServerJson();
        paymentData['pos_order_id'] = serverId;
        
        print('Payment ${i + 1} data keys: ${paymentData.keys.toList()}');
        print('Payment ${i + 1} date format check: ${paymentData['payment_date']}');
        print('Payment ${i + 1} data: $paymentData');
        
        await _apiClient.create('pos.payment', paymentData);
        print('✅ Payment ${i + 1} created successfully');
      }
      
      print('Order synced to server with ID: $serverId');
    } catch (e) {
      print('Error syncing order to server: $e');
      throw e;
    }
  }

  /// Get taxes for product
  Future<List<AccountTax>> _getTaxesForProduct(int productId, List<int>? taxIds) async {
    try {
      if (taxIds != null && taxIds.isNotEmpty) {
        // Use provided tax IDs
        final taxes = <AccountTax>[];
        for (final taxId in taxIds) {
          try {
            final taxData = await _apiClient.read('account.tax', taxId);
            
            // Validate tax data before parsing
            if (_isValidTaxData(taxData)) {
              taxes.add(AccountTax.fromJson(taxData));
            } else {
              print('Warning: Skipping invalid tax data for ID $taxId: $taxData');
            }
          } catch (taxError) {
            print('Warning: Failed to load tax $taxId: $taxError');
            // Continue with other taxes rather than failing completely
          }
        }
        return taxes;
      } else {
        // Get default taxes from product
        final productData = await _apiClient.read('product.product', productId, fields: ['taxes_id']);
        final defaultTaxIds = List<int>.from(productData['taxes_id'] ?? []);
        
        final taxes = <AccountTax>[];
        for (final taxId in defaultTaxIds) {
          try {
            final taxData = await _apiClient.read('account.tax', taxId);
            
            // Validate tax data before parsing
            if (_isValidTaxData(taxData)) {
              taxes.add(AccountTax.fromJson(taxData));
            } else {
              print('Warning: Skipping invalid tax data for ID $taxId: $taxData');
            }
          } catch (taxError) {
            print('Warning: Failed to load tax $taxId: $taxError');
            // Continue with other taxes rather than failing completely
          }
        }
        
        // If no valid taxes found, return default tax
        if (taxes.isEmpty) {
          print('Warning: No valid taxes found for product $productId, using default tax');
          return [_createDefaultTax()];
        }
        
        return taxes;
      }
    } catch (e) {
      print('Error getting taxes for product: $e');
      return [];
    }
  }

  /// Create a default tax when no valid taxes are found
  AccountTax _createDefaultTax() {
    return AccountTax(
      id: -1, // Negative ID to indicate it's a default tax
      name: 'Default Tax',
      amountType: TaxAmountType.percent,
      amount: 15.0, // Default 15% VAT rate
      typeTaxUse: TaxTypeUse.sale,
      priceInclude: false,
      includeBaseAmount: false,
      isBaseAffected: false,
      sequence: 0,
      companyId: 1,
      taxGroupId: null,
      childrenTaxIds: [],
      invoiceRepartitionLineIds: [],
      refundRepartitionLineIds: [],
    );
  }

  /// Validate tax data before parsing
  bool _isValidTaxData(Map<String, dynamic> taxData) {
    final typeTaxUse = taxData['type_tax_use'];
    final amountType = taxData['amount_type'];
    
    // Check if required fields are present and valid
    if (typeTaxUse == null || amountType == null) {
      return false;
    }
    
    // Validate enum values
    final validTypeTaxUse = ['sale', 'purchase', 'none'].contains(typeTaxUse);
    final validAmountType = ['fixed', 'percent', 'division', 'group'].contains(amountType);
    
    return validTypeTaxUse && validAmountType;
  }

  /// Calculate tax amount
  double _calculateTaxAmount(double baseAmount, List<AccountTax> taxes) {
    double taxAmount = 0.0;
    
    for (final tax in taxes) {
      if (tax.appliesToSales) {
        taxAmount += tax.calculateTaxAmount(baseAmount);
      }
    }
    
    return taxAmount;
  }

  /// Get product by ID
  Future<ProductProduct?> _getProduct(int productId) async {
    try {
      final productData = await _localStorage.getProduct(productId);
      if (productData != null) {
        return ProductProduct.fromJson(productData);
      }
      
      // Try to fetch from server if not in local storage
      if (_apiClient.isConnected && _apiClient.isAuthenticated) {
        final serverData = await _apiClient.read('product.product', productId);
        return ProductProduct.fromJson(serverData);
      }
      
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  /// Get next sequence number
  Future<int> _getNextSequenceNumber(int sessionId) async {
    try {
      final orders = await _localStorage.getOrders(sessionId: sessionId);
      return orders.length + 1;
    } catch (e) {
      return 1;
    }
  }

  /// Notify all listeners
  void _notifyListeners() {
    _orderController.add(_currentOrder);
    _linesController.add(_currentOrderLines);
    _paymentsController.add(_currentPayments);
  }

  /// Get order summary
  OrderSummary getOrderSummary() {
    if (_currentOrder == null) {
      return OrderSummary(
        subtotal: 0.0,
        taxAmount: 0.0,
        total: 0.0,
        paid: 0.0,
        change: 0.0,
        remaining: 0.0,
        itemCount: 0,
      );
    }

    final subtotal = _currentOrderLines.fold(0.0, (sum, line) => sum + line.priceSubtotal);
    final taxAmount = _currentOrder!.amountTax;
    final total = _currentOrder!.amountTotal;
    final paid = _currentPayments.fold(0.0, (sum, payment) => sum + payment.amount);
    final change = paid > total ? paid - total : 0.0;
    final remaining = total - paid;
    final itemCount = _currentOrderLines.fold(0.0, (sum, line) => sum + line.qty);

    return OrderSummary(
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      paid: paid,
      change: change,
      remaining: remaining > 0 ? remaining : 0.0,
      itemCount: itemCount.toInt(),
    );
  }

  /// Dispose resources
  void dispose() {
    _orderController.close();
    _linesController.close();
    _paymentsController.close();
  }
}

/// Data classes for order management

class OrderResult {
  final bool success;
  final POSOrder? order;
  final String? error;
  final OrderReceiptData? receiptData;

  OrderResult({
    required this.success,
    this.order,
    this.error,
    this.receiptData,
  });
}

/// Data structure for receipt information
class OrderReceiptData {
  final POSOrder order;
  final List<POSOrderLine> orderLines;
  final List<POSPayment> payments;

  OrderReceiptData({
    required this.order,
    required this.orderLines,
    required this.payments,
  });

  /// Convert payments to map format for compatibility
  Map<String, double> get paymentsMap {
    final Map<String, double> paymentsByMethod = {};
    
    for (final payment in payments) {
      String methodName;
      
      if (payment.isChange) {
        methodName = 'Change';
      } else {
        // Try to get payment method name, fallback to generic names
        switch (payment.paymentMethodId) {
          case 1:
            methodName = 'Cash';
            break;
          case 2:
            methodName = 'Card';
            break;
          case 3:
            methodName = 'Customer Account';
            break;
          case 4:
            methodName = 'Cash2';
            break;
          default:
            methodName = 'Payment Method ${payment.paymentMethodId}';
        }
      }
      
      paymentsByMethod[methodName] = (paymentsByMethod[methodName] ?? 0.0) + payment.amount;
    }
    
    return paymentsByMethod;
  }
}

class OrderLineResult {
  final bool success;
  final POSOrderLine? orderLine;
  final String? error;

  OrderLineResult({
    required this.success,
    this.orderLine,
    this.error,
  });
}

class PaymentResult {
  final bool success;
  final POSPayment? payment;
  final String? error;

  PaymentResult({
    required this.success,
    this.payment,
    this.error,
  });
}

class OrderSummary {
  final double subtotal;
  final double taxAmount;
  final double total;
  final double paid;
  final double change;
  final double remaining;
  final int itemCount;

  OrderSummary({
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.paid,
    required this.change,
    required this.remaining,
    required this.itemCount,
  });

  bool get isFullyPaid => remaining <= 0.0;
  bool get hasChange => change > 0.0;
  bool get canFinalize => itemCount > 0 && isFullyPaid;
}
