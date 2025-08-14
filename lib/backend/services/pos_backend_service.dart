import 'dart:async';
import '../models/pos_config.dart';
import '../models/pos_session.dart';
import '../models/product_product.dart';
import '../models/pos_category.dart';
import '../models/res_partner.dart';
import '../models/pos_payment_method.dart';
import '../models/account_tax.dart';
import '../api/odoo_api_client.dart';
import '../storage/local_storage.dart';
import 'session_manager.dart';
import 'order_manager.dart';
import 'sync_service.dart';

/// POS Backend Service
/// Main service that coordinates all backend operations and provides
/// a unified interface for the Flutter frontend
class POSBackendService {
  static final POSBackendService _instance = POSBackendService._internal();
  factory POSBackendService() => _instance;
  POSBackendService._internal();

  // Core services
  final OdooApiClient _apiClient = OdooApiClient();
  final LocalStorage _localStorage = LocalStorage();
  final SessionManager _sessionManager = SessionManager();
  final OrderManager _orderManager = OrderManager();
  final SyncService _syncService = SyncService();

  // State management
  bool _isInitialized = false;
  List<POSConfig> _availableConfigs = [];
  List<ProductProduct> _products = [];
  List<POSCategory> _categories = [];
  List<ResPartner> _customers = [];
  List<POSPaymentMethod> _paymentMethods = [];
  List<AccountTax> _taxes = [];

  // Stream controllers for real-time updates
  final StreamController<List<ProductProduct>> _productsController = StreamController<List<ProductProduct>>.broadcast();
  final StreamController<List<POSCategory>> _categoriesController = StreamController<List<POSCategory>>.broadcast();
  final StreamController<List<ResPartner>> _customersController = StreamController<List<ResPartner>>.broadcast();
  final StreamController<bool> _loadingController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  /// Streams for UI to listen to
  Stream<List<ProductProduct>> get productsStream => _productsController.stream;
  Stream<List<POSCategory>> get categoriesStream => _categoriesController.stream;
  Stream<List<ResPartner>> get customersStream => _customersController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<String> get statusStream => _statusController.stream;

  /// Service accessors
  OdooApiClient get apiClient => _apiClient;
  SessionManager get sessionManager => _sessionManager;
  OrderManager get orderManager => _orderManager;
  SyncService get syncService => _syncService;

  /// Data accessors
  List<POSConfig> get availableConfigs => List.unmodifiable(_availableConfigs);
  List<ProductProduct> get products => List.unmodifiable(_products);
  List<POSCategory> get categories => List.unmodifiable(_categories);
  List<ResPartner> get customers => List.unmodifiable(_customers);
  List<POSPaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);
  List<AccountTax> get taxes => List.unmodifiable(_taxes);

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the backend service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setStatus('Initializing backend services...');
    _setLoading(true);

    try {
      // Initialize core services
      await _localStorage.initialize();
      await _apiClient.initialize();
      await _sessionManager.initialize();
      await _orderManager.initialize();
      await _syncService.initialize();

      // Load cached data
      await _loadCachedData();

      _isInitialized = true;
      _setStatus('Backend services initialized');
    } catch (e) {
      _setStatus('Failed to initialize: $e');
      throw Exception('Backend initialization failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Configure connection to Odoo server
  Future<ConfigResult> configureConnection({
    required String serverUrl,
    required String database,
    String? apiKey,
  }) async {
    try {
      _setStatus('Configuring connection...');
      _setLoading(true);

      await _apiClient.configure(
        serverUrl: serverUrl,
        database: database,
        apiKey: apiKey,
      );

      _setStatus('Connection configured successfully');
      return ConfigResult(success: true);
    } catch (e) {
      _setStatus('Failed to configure connection: $e');
      return ConfigResult(success: false, error: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Authenticate user
  Future<AuthResult> authenticate({
    required String username,
    required String password,
  }) async {
    try {
      _setStatus('Authenticating...');
      _setLoading(true);

      final result = await _apiClient.authenticate(
        username: username,
        password: password,
      );

      if (result.success) {
        _setStatus('Authentication successful');
        // Load available configurations
        await _loadAvailableConfigs();
      } else {
        _setStatus('Authentication failed: ${result.error}');
      }

      return result;
    } catch (e) {
      _setStatus('Authentication error: $e');
      return AuthResult(success: false, error: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Load available POS configurations
  Future<void> _loadAvailableConfigs() async {
    try {
      if (!_apiClient.isConnected || !_apiClient.isAuthenticated) {
        return;
      }

      final configsData = await _apiClient.searchRead(
        'pos.config',
        domain: [['active', '=', true]],
        fields: ['id', 'name', 'company_id', 'currency_id', 'cash_control'],
      );

      _availableConfigs = configsData.map((data) => POSConfig.fromJson(data)).toList();
    } catch (e) {
      print('Error loading configurations: $e');
      _availableConfigs = [];
    }
  }

  /// Open or continue POS session
  Future<SessionResult> openSession({
    required int configId,
    SessionOpeningData? openingData,
  }) async {
    try {
      _setStatus('Opening session...');
      _setLoading(true);

      final result = await _sessionManager.openOrContinueSession(
        configId,
        _apiClient.userId!,
        openingData: openingData,
      );

      if (result.success) {
        _setStatus('Session opened successfully');
        // Load POS data for the session
        await _loadPosData(result.session!);
      } else {
        _setStatus('Failed to open session: ${result.error}');
      }

      return result;
    } catch (e) {
      _setStatus('Session opening error: $e');
      return SessionResult(success: false, error: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Load POS data for active session
  Future<void> _loadPosData(POSSession session) async {
    try {
      _setStatus('Loading POS data...');

      if (_apiClient.isConnected && _apiClient.isAuthenticated) {
        // Load from server
        await _loadDataFromServer(session);
      } else {
        // Load from local storage
        await _loadCachedData();
      }

      _setStatus('POS data loaded');
    } catch (e) {
      print('Error loading POS data: $e');
      _setStatus('Using cached data');
      await _loadCachedData();
    }
  }

  /// Load data from Odoo server
  Future<void> _loadDataFromServer(POSSession session) async {
    try {
      // Load products
      await _loadProducts();
      
      // Load categories
      await _loadCategories();
      
      // Load customers
      await _loadCustomers();
      
      // Load payment methods
      await _loadPaymentMethods();
      
      // Load taxes
      await _loadTaxes();

      // Start background sync
      _syncService.startPeriodicSync();
    } catch (e) {
      print('Error loading data from server: $e');
      throw e;
    }
  }

  /// Load products from server
  Future<void> _loadProducts() async {
    try {
      final productsData = await _apiClient.searchRead(
        'product.product',
        domain: [
          ['available_in_pos', '=', true],
          ['active', '=', true],
        ],
        fields: [
          'id', 'display_name', 'lst_price', 'standard_price', 'barcode',
          'available_in_pos', 'to_weight', 'active', 'product_tmpl_id',
          'qty_available', 'virtual_available', 'taxes_id'
        ],
      );

      _products = productsData.map((data) => ProductProduct.fromJson(data)).toList();
      
      // Cache locally
      await _localStorage.saveProducts(productsData);
      
      _productsController.add(_products);
    } catch (e) {
      print('Error loading products: $e');
      throw e;
    }
  }

  /// Load categories from server
  Future<void> _loadCategories() async {
    try {
      final categoriesData = await _apiClient.searchRead(
        'pos.category',
        fields: ['id', 'name', 'parent_id', 'sequence', 'color', 'image_128'],
      );

      _categories = categoriesData.map((data) => POSCategory.fromJson(data)).toList();
      
      // Cache locally
      await _localStorage.saveCategories(categoriesData);
      
      _categoriesController.add(_categories);
    } catch (e) {
      print('Error loading categories: $e');
      throw e;
    }
  }

  /// Load customers from server
  Future<void> _loadCustomers() async {
    try {
      final customersData = await _apiClient.searchRead(
        'res.partner',
        domain: [
          ['customer_rank', '>', 0],
          ['active', '=', true],
        ],
        fields: [
          'id', 'name', 'display_name', 'email', 'phone', 'mobile',
          'street', 'city', 'country_id', 'is_company', 'active'
        ],
        limit: 1000, // Limit to avoid loading too many customers
      );

      _customers = customersData.map((data) => ResPartner.fromJson(data)).toList();
      
      // Cache locally
      await _localStorage.saveCustomers(customersData);
      
      _customersController.add(_customers);
    } catch (e) {
      print('Error loading customers: $e');
      throw e;
    }
  }

  /// Load payment methods from server
  Future<void> _loadPaymentMethods() async {
    try {
      final paymentMethodsData = await _apiClient.searchRead(
        'pos.payment.method',
        domain: [['active', '=', true]],
        fields: ['id', 'name', 'is_cash_count', 'split_transactions', 'use_payment_terminal'],
      );

      _paymentMethods = paymentMethodsData.map((data) => POSPaymentMethod.fromJson(data)).toList();
    } catch (e) {
      print('Error loading payment methods: $e');
      throw e;
    }
  }

  /// Load taxes from server
  Future<void> _loadTaxes() async {
    try {
      final taxesData = await _apiClient.searchRead(
        'account.tax',
        domain: [
          ['type_tax_use', '=', 'sale'],
          ['active', '=', true],
        ],
        fields: ['id', 'name', 'amount', 'amount_type', 'price_include'],
      );

      _taxes = taxesData.map((data) => AccountTax.fromJson(data)).toList();
    } catch (e) {
      print('Error loading taxes: $e');
      throw e;
    }
  }

  /// Load cached data from local storage
  Future<void> _loadCachedData() async {
    try {
      // Load products
      final productsData = await _localStorage.getProducts(availableInPos: true);
      _products = productsData.map((data) => ProductProduct.fromJson(data)).toList();
      _productsController.add(_products);

      // Load categories
      final categoriesData = await _localStorage.getCategories();
      _categories = categoriesData.map((data) => POSCategory.fromJson(data)).toList();
      _categoriesController.add(_categories);

      // Load customers
      final customersData = await _localStorage.getCustomers();
      _customers = customersData.map((data) => ResPartner.fromJson(data)).toList();
      _customersController.add(_customers);
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  /// Search products
  Future<List<ProductProduct>> searchProducts(String query) async {
    try {
      if (query.isEmpty) {
        return _products;
      }

      // Search in local data first
      final localResults = _products.where((product) =>
        product.displayName.toLowerCase().contains(query.toLowerCase()) ||
        (product.barcode?.contains(query) ?? false)
      ).toList();

      // If connected, also search on server for more results
      if (_apiClient.isConnected && _apiClient.isAuthenticated && localResults.length < 10) {
        try {
          final serverResults = await _apiClient.searchRead(
            'product.product',
            domain: [
              ['available_in_pos', '=', true],
              ['active', '=', true],
              '|',
              ['display_name', 'ilike', query],
              ['barcode', 'ilike', query],
            ],
            fields: ['id', 'display_name', 'lst_price', 'barcode'],
            limit: 20,
          );

          final serverProducts = serverResults.map((data) => ProductProduct.fromJson(data)).toList();
          
          // Merge with local results, avoiding duplicates
          final allResults = <ProductProduct>[];
          allResults.addAll(localResults);
          
          for (final serverProduct in serverProducts) {
            if (!allResults.any((p) => p.id == serverProduct.id)) {
              allResults.add(serverProduct);
            }
          }
          
          return allResults;
        } catch (e) {
          print('Error searching on server: $e');
        }
      }

      return localResults;
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  /// Get product by barcode
  Future<ProductProduct?> getProductByBarcode(String barcode) async {
    try {
      // Check local storage first
      final localProduct = await _localStorage.getProductByBarcode(barcode);
      if (localProduct != null) {
        return ProductProduct.fromJson(localProduct);
      }

      // If not found locally and connected, try server
      if (_apiClient.isConnected && _apiClient.isAuthenticated) {
        try {
          final serverResults = await _apiClient.searchRead(
            'product.product',
            domain: [
              ['barcode', '=', barcode],
              ['available_in_pos', '=', true],
              ['active', '=', true],
            ],
            limit: 1,
          );

          if (serverResults.isNotEmpty) {
            return ProductProduct.fromJson(serverResults.first);
          }
        } catch (e) {
          print('Error searching product by barcode on server: $e');
        }
      }

      return null;
    } catch (e) {
      print('Error getting product by barcode: $e');
      return null;
    }
  }

  /// Search customers
  Future<List<ResPartner>> searchCustomers(String query) async {
    try {
      if (query.isEmpty) {
        return _customers;
      }

      // Search in local data
      final localResults = _customers.where((customer) =>
        customer.name.toLowerCase().contains(query.toLowerCase()) ||
        (customer.email?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
        (customer.phone?.contains(query) ?? false) ||
        (customer.mobile?.contains(query) ?? false)
      ).toList();

      return localResults;
    } catch (e) {
      print('Error searching customers: $e');
      return [];
    }
  }

  /// Create new customer
  Future<CustomerResult> createCustomer(Map<String, dynamic> customerData) async {
    try {
      if (_apiClient.isConnected && _apiClient.isAuthenticated) {
        // Create on server
        final customerId = await _apiClient.create('res.partner', customerData);
        final createdCustomer = await _apiClient.read('res.partner', customerId);
        
        final customer = ResPartner.fromJson(createdCustomer);
        _customers.add(customer);
        _customersController.add(_customers);
        
        return CustomerResult(success: true, customer: customer);
      } else {
        // Store for offline sync
        customerData['id'] = -DateTime.now().millisecondsSinceEpoch;
        final customer = ResPartner.fromJson(customerData);
        _customers.add(customer);
        _customersController.add(_customers);
        
        // Store pending change
        await _localStorage.addPendingChange({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'model': 'res.partner',
          'method': 'create',
          'args': [customerData],
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        return CustomerResult(success: true, customer: customer);
      }
    } catch (e) {
      return CustomerResult(success: false, error: e.toString());
    }
  }

  /// Close current session
  Future<SessionCloseResult> closeSession(SessionClosingData closingData) async {
    try {
      _setStatus('Closing session...');
      _setLoading(true);

      final currentSession = _sessionManager.currentSession;
      if (currentSession == null) {
        return SessionCloseResult(
          success: false,
          error: 'No active session to close',
        );
      }

      final result = await _sessionManager.closeSessionWithValidation(
        currentSession.id,
        closingData,
      );

      if (result.success) {
        _setStatus('Session closed successfully');
        // Stop sync service
        _syncService.stopPeriodicSync();
        // Clear data
        await _clearSessionData();
      } else {
        _setStatus('Failed to close session');
      }

      return result;
    } catch (e) {
      _setStatus('Session closing error: $e');
      return SessionCloseResult(success: false, error: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Clear session data
  Future<void> _clearSessionData() async {
    _products.clear();
    _categories.clear();
    _customers.clear();
    _paymentMethods.clear();
    _taxes.clear();
    
    _productsController.add(_products);
    _categoriesController.add(_categories);
    _customersController.add(_customers);
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _setStatus('Logging out...');
      _setLoading(true);

      // Stop sync service
      _syncService.stopPeriodicSync();
      
      // Logout from API client
      await _apiClient.logout();
      
      // Clear session data
      await _clearSessionData();
      
      _setStatus('Logged out successfully');
    } catch (e) {
      _setStatus('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _loadingController.add(loading);
  }

  /// Set status message
  void _setStatus(String status) {
    _statusController.add(status);
    print('POS Backend: $status');
  }

  /// Dispose resources
  void dispose() {
    _productsController.close();
    _categoriesController.close();
    _customersController.close();
    _loadingController.close();
    _statusController.close();
    
    _sessionManager.dispose();
    _orderManager.dispose();
    _syncService.dispose();
    _apiClient.dispose();
  }
}

/// Result classes

class ConfigResult {
  final bool success;
  final String? error;

  ConfigResult({required this.success, this.error});
}

class CustomerResult {
  final bool success;
  final ResPartner? customer;
  final String? error;

  CustomerResult({required this.success, this.customer, this.error});
}
