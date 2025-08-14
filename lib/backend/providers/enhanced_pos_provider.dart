import 'package:flutter/foundation.dart';
import '../services/pos_backend_service.dart';
import '../services/session_manager.dart';
import '../services/order_manager.dart';
import '../models/pos_config.dart';
import '../models/pos_session.dart';
import '../models/product_product.dart';
import '../models/pos_category.dart';
import '../models/res_partner.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/pos_payment.dart';
import '../models/pos_payment_method.dart';

/// Enhanced POS Provider
/// Integrates the existing Flutter UI with the new Odoo 18 backend
/// Provides a smooth migration path from the old provider to the new backend
class EnhancedPOSProvider with ChangeNotifier {
  final POSBackendService _backendService = POSBackendService();

  // Connection and authentication state
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String _statusMessage = '';
  String? _currentUser;

  // POS configuration and session
  List<POSConfig> _availableConfigs = [];
  POSConfig? _selectedConfig;
  POSSession? _currentSession;

  // Products and categories
  List<ProductProduct> _products = [];
  List<POSCategory> _categories = [];
  String _selectedCategory = '';
  String _searchQuery = '';

  // Customers
  List<ResPartner> _customers = [];
  ResPartner? _selectedCustomer;

  // Payment methods
  List<POSPaymentMethod> _paymentMethods = [];

  // Order state
  POSOrder? _currentOrder;
  List<POSOrderLine> _orderLines = [];
  List<POSPayment> _payments = [];

  // Connection and authentication getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  String? get currentUser => _currentUser;

  // POS configuration and session getters
  List<POSConfig> get availableConfigs => List.unmodifiable(_availableConfigs);
  POSConfig? get selectedConfig => _selectedConfig;
  POSSession? get currentSession => _currentSession;
  bool get hasActiveSession => _currentSession != null && _currentSession!.isOpen;

  // Products and categories getters
  List<ProductProduct> get products => List.unmodifiable(_products);
  List<POSCategory> get categories => List.unmodifiable(_categories);
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  // Customers getters
  List<ResPartner> get customers => List.unmodifiable(_customers);
  ResPartner? get selectedCustomer => _selectedCustomer;

  // Payment methods getters
  List<POSPaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);

  // Order getters
  POSOrder? get currentOrder => _currentOrder;
  List<POSOrderLine> get orderLines => List.unmodifiable(_orderLines);
  List<POSPayment> get payments => List.unmodifiable(_payments);
  bool get hasActiveOrder => _currentOrder != null;

  // Order calculations
  double get subtotal => _orderLines.fold(0.0, (sum, line) => sum + line.priceSubtotal);
  double get taxAmount => _orderLines.fold(0.0, (sum, line) => sum + (line.priceSubtotalIncl - line.priceSubtotal));
  double get total => subtotal + taxAmount;
  double get totalPaid => _payments.fold(0.0, (sum, payment) => sum + payment.amount);
  double get remainingAmount => total - totalPaid;
  double get changeAmount => totalPaid > total ? totalPaid - total : 0.0;
  bool get isFullyPaid => remainingAmount <= 0.0;

  /// Initialize the enhanced provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true, 'Initializing POS system...');

      // Initialize backend service
      await _backendService.initialize();

      // Setup listeners
      _setupListeners();

      _isInitialized = true;
      _setLoading(false, 'POS system ready');
    } catch (e) {
      _setLoading(false, 'Initialization failed: $e');
      throw Exception('Failed to initialize POS provider: $e');
    }
  }

  /// Setup stream listeners for real-time updates
  void _setupListeners() {
    // Backend service streams
    _backendService.loadingStream.listen((loading) {
      _isLoading = loading;
      notifyListeners();
    });

    _backendService.statusStream.listen((status) {
      _statusMessage = status;
      notifyListeners();
    });

    _backendService.productsStream.listen((products) {
      _products = products;
      notifyListeners();
    });

    _backendService.categoriesStream.listen((categories) {
      _categories = categories;
      notifyListeners();
    });

    _backendService.customersStream.listen((customers) {
      _customers = customers;
      notifyListeners();
    });

    // API client streams
    _backendService.apiClient.connectionStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });

    _backendService.apiClient.authStream.listen((authenticated) {
      _isAuthenticated = authenticated;
      notifyListeners();
    });

    // Session manager streams
    _backendService.sessionManager.sessionStream.listen((session) {
      _currentSession = session;
      notifyListeners();
    });

    // Order manager streams
    _backendService.orderManager.orderStream.listen((order) {
      _currentOrder = order;
      notifyListeners();
    });

    _backendService.orderManager.linesStream.listen((lines) {
      _orderLines = lines;
      notifyListeners();
    });

    _backendService.orderManager.paymentsStream.listen((payments) {
      _payments = payments;
      notifyListeners();
    });
  }

  /// Configure connection to Odoo server
  Future<bool> configureConnection({
    required String serverUrl,
    required String database,
    String? apiKey,
  }) async {
    try {
      final result = await _backendService.configureConnection(
        serverUrl: serverUrl,
        database: database,
        apiKey: apiKey,
      );
      return result.success;
    } catch (e) {
      _setLoading(false, 'Configuration failed: $e');
      return false;
    }
  }

  /// Authenticate user
  Future<bool> login(String username, String password) async {
    try {
      _setLoading(true, 'Authenticating...');

      final result = await _backendService.authenticate(
        username: username,
        password: password,
      );

      if (result.success) {
        _currentUser = username;
        _availableConfigs = _backendService.availableConfigs;
        _setLoading(false, 'Authentication successful');
        return true;
      } else {
        _setLoading(false, 'Authentication failed: ${result.error}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Authentication error: $e');
      return false;
    }
  }

  /// Select POS configuration
  void selectConfig(POSConfig config) {
    _selectedConfig = config;
    notifyListeners();
  }

  /// Open POS session
  Future<bool> openSession({SessionOpeningData? openingData}) async {
    if (_selectedConfig == null) {
      _setLoading(false, 'No configuration selected');
      return false;
    }

    try {
      _setLoading(true, 'Opening session...');

      final result = await _backendService.openSession(
        configId: _selectedConfig!.id,
        openingData: openingData,
      );

      if (result.success) {
        _paymentMethods = _backendService.paymentMethods;
        _setLoading(false, 'Session opened successfully');
        return true;
      } else {
        _setLoading(false, 'Failed to open session: ${result.error}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Session opening error: $e');
      return false;
    }
  }

  /// Close POS session
  Future<bool> closeSession({
    double? cashBalance,
    String? notes,
  }) async {
    if (_currentSession == null) {
      _setLoading(false, 'No active session to close');
      return false;
    }

    try {
      _setLoading(true, 'Closing session...');

      final closingData = SessionClosingData(
        cashRegisterBalanceEndReal: cashBalance,
        closingNotes: notes,
      );

      final result = await _backendService.closeSession(closingData);

      if (result.success) {
        _clearSessionData();
        _setLoading(false, 'Session closed successfully');
        return true;
      } else {
        _setLoading(false, 'Failed to close session: ${result.errors.join(', ')}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Session closing error: $e');
      return false;
    }
  }

  /// Create new order
  Future<bool> createOrder({ResPartner? customer, String? note}) async {
    if (_currentSession == null) {
      _setLoading(false, 'No active session');
      return false;
    }

    try {
      final result = await _backendService.orderManager.createOrder(
        session: _currentSession!,
        partnerId: customer?.id,
        note: note,
      );

      if (result.success) {
        _selectedCustomer = customer;
        notifyListeners();
        return true;
      } else {
        _setLoading(false, 'Failed to create order: ${result.error}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Order creation error: $e');
      return false;
    }
  }

  /// Add product to order
  Future<bool> addProductToOrder(
    ProductProduct product, {
    double quantity = 1.0,
    double? customPrice,
    double discount = 0.0,
    String? note,
  }) async {
    if (!hasActiveOrder) {
      // Create order if none exists
      final orderCreated = await createOrder();
      if (!orderCreated) return false;
    }

    try {
      final result = await _backendService.orderManager.addProductToOrder(
        product: product,
        quantity: quantity,
        customPrice: customPrice,
        discount: discount,
        customerNote: note,
      );

      return result.success;
    } catch (e) {
      _setLoading(false, 'Failed to add product: $e');
      return false;
    }
  }

  /// Update order line quantity
  Future<bool> updateOrderLineQuantity(int lineIndex, double quantity) async {
    try {
      final result = await _backendService.orderManager.updateOrderLineQuantity(
        lineIndex,
        quantity,
      );
      return result.success;
    } catch (e) {
      _setLoading(false, 'Failed to update quantity: $e');
      return false;
    }
  }

  /// Remove order line
  Future<bool> removeOrderLine(int lineIndex) async {
    return await updateOrderLineQuantity(lineIndex, 0);
  }

  /// Apply discount to order line
  Future<bool> applyLineDiscount(int lineIndex, double discount) async {
    try {
      final result = await _backendService.orderManager.applyLineDiscount(
        lineIndex,
        discount,
      );
      return result.success;
    } catch (e) {
      _setLoading(false, 'Failed to apply discount: $e');
      return false;
    }
  }

  /// Add payment to order
  Future<bool> addPayment({
    required POSPaymentMethod paymentMethod,
    required double amount,
    String? reference,
    Map<String, String>? cardInfo,
  }) async {
    try {
      final result = await _backendService.orderManager.addPayment(
        paymentMethodId: paymentMethod.id,
        amount: amount,
        paymentRefNo: reference,
        cardType: cardInfo?['type'],
        cardBrand: cardInfo?['brand'],
        cardNo: cardInfo?['number'],
        cardholderName: cardInfo?['holder'],
      );
      return result.success;
    } catch (e) {
      _setLoading(false, 'Failed to add payment: $e');
      return false;
    }
  }

  /// Remove payment
  Future<bool> removePayment(int paymentIndex) async {
    try {
      final result = await _backendService.orderManager.removePayment(paymentIndex);
      return result.success;
    } catch (e) {
      _setLoading(false, 'Failed to remove payment: $e');
      return false;
    }
  }

  /// Finalize order
  Future<bool> finalizeOrder() async {
    try {
      _setLoading(true, 'Finalizing order...');

      final result = await _backendService.orderManager.finalizeOrder();

      if (result.success) {
        _setLoading(false, 'Order completed successfully');
        return true;
      } else {
        _setLoading(false, 'Failed to finalize order: ${result.error}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Order finalization error: $e');
      return false;
    }
  }

  /// Cancel current order
  Future<bool> cancelOrder() async {
    try {
      final result = await _backendService.orderManager.cancelOrder();
      if (result.success) {
        _selectedCustomer = null;
        notifyListeners();
      }
      return result.success;
    } catch (e) {
      _setLoading(false, 'Failed to cancel order: $e');
      return false;
    }
  }

  /// Select category for filtering products
  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Set search query for products
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Get filtered products based on category and search
  List<ProductProduct> getFilteredProducts() {
    List<ProductProduct> filtered = _products;

    // Filter by category
    if (_selectedCategory.isNotEmpty && _selectedCategory != 'All') {
      // Note: This would require category filtering logic based on product categories
      // For now, return all products
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
        product.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (product.barcode?.contains(_searchQuery) ?? false)
      ).toList();
    }

    return filtered;
  }

  /// Search products
  Future<List<ProductProduct>> searchProducts(String query) async {
    return await _backendService.searchProducts(query);
  }

  /// Get product by barcode
  Future<ProductProduct?> getProductByBarcode(String barcode) async {
    return await _backendService.getProductByBarcode(barcode);
  }

  /// Select customer
  void selectCustomer(ResPartner? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Search customers
  Future<List<ResPartner>> searchCustomers(String query) async {
    return await _backendService.searchCustomers(query);
  }

  /// Create new customer
  Future<ResPartner?> createCustomer(Map<String, dynamic> customerData) async {
    try {
      final result = await _backendService.createCustomer(customerData);
      if (result.success) {
        return result.customer;
      }
      return null;
    } catch (e) {
      _setLoading(false, 'Failed to create customer: $e');
      return null;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _setLoading(true, 'Logging out...');

      await _backendService.logout();

      // Clear all state
      _clearAllData();
      
      _setLoading(false, 'Logged out successfully');
    } catch (e) {
      _setLoading(false, 'Logout error: $e');
    }
  }

  /// Clear session data
  void _clearSessionData() {
    _currentSession = null;
    _currentOrder = null;
    _orderLines.clear();
    _payments.clear();
    _selectedCustomer = null;
    _products.clear();
    _categories.clear();
    _customers.clear();
    _paymentMethods.clear();
    notifyListeners();
  }

  /// Clear all data
  void _clearAllData() {
    _currentUser = null;
    _availableConfigs.clear();
    _selectedConfig = null;
    _clearSessionData();
  }

  /// Set loading state and status
  void _setLoading(bool loading, String status) {
    _isLoading = loading;
    _statusMessage = status;
    notifyListeners();
  }

  /// Get order summary
  OrderSummary getOrderSummary() {
    return OrderSummary(
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      paid: totalPaid,
      change: changeAmount,
      remaining: remainingAmount > 0 ? remainingAmount : 0.0,
      itemCount: _orderLines.fold(0.0, (sum, line) => sum + line.qty).round(),
    );
  }

  /// Dispose resources
  @override
  void dispose() {
    _backendService.dispose();
    super.dispose();
  }
}

/// Order summary class for UI display
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
