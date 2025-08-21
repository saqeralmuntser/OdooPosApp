import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../services/pos_backend_service.dart';
import '../services/session_manager.dart';
import '../services/hybrid_auth_service.dart';

import '../models/pos_config.dart';
import '../models/pos_session.dart';
import '../models/product_product.dart';
import '../models/pos_category.dart';
import '../models/res_partner.dart';
import '../models/res_company.dart';
import '../models/pos_order.dart';
import '../models/pos_order_line.dart';
import '../models/pos_payment.dart';
import '../models/pos_payment_method.dart';
import '../models/product_pricelist.dart';
import '../models/product_pricelist_item.dart';
import '../models/product_combo.dart';
import '../services/pricing_service.dart';
import '../services/printer_service.dart';
import '../services/windows_printer_service.dart';
import '../services/enhanced_windows_printer_service.dart';
import '../services/printer_configuration_service.dart';

/// Enhanced POS Provider
/// Integrates the existing Flutter UI with the new Odoo 18 backend
/// Provides a smooth migration path from the old provider to the new backend
class EnhancedPOSProvider with ChangeNotifier {
  final POSBackendService _backendService = POSBackendService();
  final HybridAuthService _hybridAuth = HybridAuthService();
  final PricingService _pricingService = PricingService();
  final PrinterService _printerService = PrinterService();
  final WindowsPrinterService _windowsPrinterService = WindowsPrinterService();
  final EnhancedWindowsPrinterService _enhancedWindowsPrinterService = EnhancedWindowsPrinterService();
  final PrinterConfigurationService _printerConfigService = PrinterConfigurationService();

  // Connection and authentication state
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String _statusMessage = '';

  // Getters for backend services
  POSBackendService get backendService => _backendService;
  PrinterService get printerService => _printerService;
  WindowsPrinterService get windowsPrinterService => _windowsPrinterService;
  PrinterConfigurationService get printerConfigService => _printerConfigService;
  String? _currentUser;
  
  // Hybrid authentication state
  AuthMode _currentAuthMode = AuthMode.none;
  bool _isOnlineMode = false;

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

  // Pricelists
  List<ProductPricelist> _availablePricelists = [];
  ProductPricelist? _currentPricelist;
  List<ProductPricelistItem> _pricelistItems = [];

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
  
  // Hybrid authentication getters
  AuthMode get currentAuthMode => _currentAuthMode;
  bool get isOnlineMode => _isOnlineMode;
  bool get isOfflineMode => !_isOnlineMode && _isAuthenticated;

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

  // Combo getters
  List<ProductCombo> get combos => _backendService.combos;
  List<ProductComboItem> get comboItems => _backendService.comboItems;

  // Payment methods getters
  List<POSPaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);
  
  // Company getter
  ResCompany? get company => _backendService.company;
  
  /// Get payment methods for the selected config
  List<POSPaymentMethod> get availablePaymentMethods {
    if (_selectedConfig == null) {
      print('No POS config selected, returning all payment methods');
      return List.unmodifiable(_paymentMethods);
    }
    
    print('Selected config: ${_selectedConfig!.name} (ID: ${_selectedConfig!.id})');
    print('Config payment method IDs: ${_selectedConfig!.paymentMethodIds}');
    print('Available payment methods: ${_paymentMethods.map((m) => '${m.id}:${m.name}').toList()}');
    
    // If config has specific payment method IDs, filter by them
    if (_selectedConfig!.paymentMethodIds != null && _selectedConfig!.paymentMethodIds!.isNotEmpty) {
      final filteredMethods = _paymentMethods.where((method) => 
        _selectedConfig!.paymentMethodIds!.contains(method.id)
      ).toList();
      
      print('Filtered payment methods: ${filteredMethods.map((m) => '${m.id}:${m.name}').toList()}');
      return filteredMethods;
    }
    
    // If no specific payment methods configured, return all available
    print('No payment methods configured for this config, returning all available methods');
    return List.unmodifiable(_paymentMethods);
  }
  
  /// Get payment method by ID
  POSPaymentMethod? getPaymentMethodById(int id) {
    try {
      return _paymentMethods.firstWhere((method) => method.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get payment method by name
  POSPaymentMethod? getPaymentMethodByName(String name) {
    try {
      return _paymentMethods.firstWhere((method) => 
        method.name.toLowerCase() == name.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }

  // Pricelist getters
  List<ProductPricelist> get availablePricelists => List.unmodifiable(_availablePricelists);
  ProductPricelist? get currentPricelist => _currentPricelist;
  bool get hasPricelistFeature => _selectedConfig?.usePricelist == true;

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
      
      // Initialize hybrid authentication service
      await _hybridAuth.initialize();

      // Setup listeners
      _setupListeners();

      // Initialize printer with web fallback
      // In a real implementation, you would get the IoT Box URL from configuration
      await initializePrinter(); // This will use web fallback by default
      
      // Initialize the new printer configuration service
      await _printerConfigService.initialize();

      _isInitialized = true;
      _setLoading(false, 'POS system ready');
    } catch (e) {
      _setLoading(false, 'Initialization failed: $e');
      throw Exception('Failed to initialize POS provider: $e');
    }
  }

  /// Configure connection to Odoo server
  Future<bool> configureConnection({
    required String serverUrl,
    required String database,
  }) async {
    try {
      // Ensure provider is initialized first
      if (!_isInitialized) {
        await initialize();
      }
      
      _setLoading(true, 'Configuring connection...');
      print('POS Backend: Configuring connection...');
      
      // Configure the API client
      final result = await _backendService.configureConnection(
        serverUrl: serverUrl,
        database: database,
      );

      if (result.success) {
        _isConnected = true;
        _setLoading(false, 'Connection configured successfully');
        print('POS Backend: Connection configured successfully');
      } else {
        _isConnected = false;
        _setLoading(false, 'Failed to configure connection');
        print('POS Backend: Failed to configure connection');
      }

      return result.success;
    } catch (e) {
      _isConnected = false;
      _setLoading(false, 'Connection configuration failed: $e');
      print('POS Backend: Failed to configure connection: $e');
      return false;
    }
  }

  /// Hybrid login - tries online first, falls back to offline
  Future<bool> loginHybrid({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      // Ensure provider is initialized first
      if (!_isInitialized) {
        await initialize();
      }
      
      _setLoading(true, 'جاري تسجيل الدخول...');
      
      final result = await _hybridAuth.login(
        serverUrl: serverUrl,
        database: database,
        username: username,
        password: password,
      );

      if (result.success) {
        _isAuthenticated = true;
        _currentUser = username;
        _currentAuthMode = result.mode;
        _isOnlineMode = result.mode == AuthMode.online;
        
        if (_isOnlineMode) {
          // Load initial data from server
          await _loadInitialData();
          _setLoading(false, 'تم تسجيل الدخول - الوضع الأونلاين');
          print('POS Backend: Login completed - Online mode with ${_availableConfigs.length} configurations');
        } else {
          // Load data from local storage
          await _loadOfflineData();
          _setLoading(false, 'تم تسجيل الدخول - الوضع الأوفلاين');
          print('POS Backend: Login completed - Offline mode');
        }
        
        print('POS Backend: Hybrid authentication successful - Mode: ${result.mode}');
      } else {
        _isAuthenticated = false;
        _currentUser = null;
        _currentAuthMode = AuthMode.failed;
        _isOnlineMode = false;
        _setLoading(false, result.error ?? 'فشل في تسجيل الدخول');
        print('POS Backend: Hybrid authentication failed: ${result.error}');
      }

      return result.success;
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      _currentAuthMode = AuthMode.failed;
      _isOnlineMode = false;
      _setLoading(false, 'خطأ في تسجيل الدخول: $e');
      print('POS Backend: Hybrid authentication error: $e');
      return false;
    }
  }

  /// Login to Odoo server (Legacy method - kept for compatibility)
  Future<bool> login(String username, String password) async {
    try {
      // Ensure provider is initialized first
      if (!_isInitialized) {
        await initialize();
      }
      
      _setLoading(true, 'Authenticating...');
      print('POS Backend: Authenticating...');
      
      final result = await _backendService.apiClient.authenticate(
        username: username,
        password: password,
      );

      if (result.success) {
        _isAuthenticated = true;
        _currentUser = username;
        _currentAuthMode = AuthMode.online;
        _isOnlineMode = true;
        _setLoading(false, 'Authentication successful');
        print('POS Backend: Authentication successful');
        
        // Load initial data after successful login
        await _loadInitialData();
      } else {
        _isAuthenticated = false;
        _currentUser = null;
        _currentAuthMode = AuthMode.failed;
        _isOnlineMode = false;
        _setLoading(false, 'Authentication failed');
        print('POS Backend: Authentication failed');
      }

      return result.success;
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      _currentAuthMode = AuthMode.failed;
      _isOnlineMode = false;
      _setLoading(false, 'Authentication error: $e');
      print('POS Backend: Authentication error: $e');
      return false;
    }
  }

  /// Load initial data after successful authentication (Online mode)
  Future<void> _loadInitialData() async {
    try {
      _setLoading(true, 'جاري تحميل البيانات...');
      
      // Load POS configurations from server
      await _backendService.loadAvailableConfigs();
      _availableConfigs = List.from(_backendService.availableConfigs);
      
      print('POS Backend: Loaded ${_availableConfigs.length} POS configurations');
      for (final config in _availableConfigs) {
        print('  - Config: ${config.name} (ID: ${config.id})');
      }
      
      // البيانات محملة من الخادم - لا حاجة لإنشاء بيانات تجريبية
      
      // Notify listeners about the updated configs
      notifyListeners();
      
      _setLoading(false, 'تم تحميل البيانات بنجاح');
    } catch (e) {
      _setLoading(false, 'فشل في تحميل البيانات: $e');
      print('Failed to load initial data: $e');
    }
  }

  /// Load data from local storage (Offline mode)
  Future<void> _loadOfflineData() async {
    try {
      _setLoading(true, 'Loading offline data...');
      
      // Load cached data from local storage
      // This would load configurations, products, customers, etc. from SQLite
      
      _setLoading(false, 'Offline data loaded');
    } catch (e) {
      _setLoading(false, 'Failed to load offline data: $e');
      print('Failed to load offline data: $e');
    }
  }

  /// Reload POS configurations from server (public method)
  Future<void> reloadConfigurations() async {
    if (_isOnlineMode) {
      await _loadInitialData();
    } else {
      await _loadOfflineData();
    }
  }

  /// Logout from Odoo server
  Future<void> logout() async {
    try {
      _setLoading(true, 'Logging out...');
      
      await _backendService.logout();
      
      // Clear all data
      _clearAllData();
      
      _setLoading(false, 'Logged out successfully');
    } catch (e) {
      _setLoading(false, 'Logout error: $e');
      print('Logout error: $e');
    }
  }

  /// Open new POS session
  Future<bool> openSession({
    SessionOpeningData? openingData,
  }) async {
    // Ensure provider is initialized first
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_selectedConfig == null) {
      print('No config selected to open session');
      return false;
    }

    try {
      _setLoading(true, 'Opening session...');
      
      // Open session through backend service
      final result = await _backendService.openSession(
        configId: _selectedConfig!.id,
        openingData: openingData,
      );

      if (result.success) {
        _setLoading(false, 'Session opened successfully');
        return true;
      } else {
        _setLoading(false, 'Failed to open session: ${result.error ?? 'Unknown error'}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Error opening session: $e');
      print('Error opening session: $e');
      return false;
    }
  }

  /// Check if there's an existing open session for a specific config
  Future<SessionStatusResult?> checkExistingSession(int configId) async {
    try {
      if (!_isInitialized || !_isAuthenticated) {
        return null;
      }

      final result = await _backendService.sessionManager.getSessionStatus(
        configId,
        _backendService.apiClient.userId!,
      );
      
      return result;
    } catch (e) {
      print('Error checking existing session: $e');
      return null;
    }
  }

  /// Complete existing session (continue without creating new one)
  Future<bool> completeExistingSession(int configId) async {
    try {
      if (!_isInitialized || !_isAuthenticated) {
        return false;
      }

      _setLoading(true, 'استكمال الجلسة الموجودة...');
      
      // Select the config first
      final config = _availableConfigs.firstWhere((c) => c.id == configId);
      selectConfig(config);
      
      // Get the existing session status
      final sessionStatus = await _backendService.sessionManager.getSessionStatus(
        configId,
        _backendService.apiClient.userId!,
      );

      if (sessionStatus.hasActiveSession != true || sessionStatus.session == null) {
        _setLoading(false, 'لا توجد جلسة مفتوحة لاستكمالها');
        return false;
      }

      // Set the current session
      _currentSession = sessionStatus.session;
      
      // Load data for the existing session
      await _backendService.loadPosDataForExistingSession(_currentSession!);
      
      // Update the products and categories from the backend service
      _products = List.from(_backendService.products);
      _categories = List.from(_backendService.categories);
      _customers = List.from(_backendService.customers);
      _paymentMethods = List.from(_backendService.paymentMethods);
      
      // Update pricelists from backend service
      _loadPricelists();
      
      // البيانات محملة من الجلسة - لا حاجة لإنشاء بيانات تجريبية
      
      // Force a UI update
      notifyListeners();
      
      // Mark session as active (the getter will automatically return true now)
      
      _setLoading(false, 'تم استكمال الجلسة بنجاح');
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false, 'خطأ في استكمال الجلسة: $e');
      print('Error completing existing session: $e');
      return false;
    }
  }

  /// Get complete product information including attributes
  Future<Map<String, dynamic>> getProductCompleteInfo(int productId) async {
    try {
      return await _backendService.getProductCompleteInfo(productId);
    } catch (e) {
      print('Error getting product complete info: $e');
      // Return basic info as fallback
      final product = _products.firstWhere((p) => p.id == productId);
      return {
        'productId': product.id,
        'productName': product.displayName,
        'basePrice': product.lstPrice,
        'finalPrice': product.lstPrice,
        'taxIds': product.taxesId,
        'attributeGroups': <Map<String, dynamic>>[],
      };
    }
  }

  /// Close existing session for a specific config
  Future<bool> closeExistingSession(
    int configId, {
    double? cashBalance,
    String? notes,
  }) async {
    try {
      if (!_isInitialized || !_isAuthenticated) {
        return false;
      }

      _setLoading(true, 'إغلاق الجلسة الموجودة...');

      // Get session status to verify there's an existing session
      final sessionStatus = await _backendService.sessionManager.getSessionStatus(
        configId,
        _backendService.apiClient.userId!,
      );

      if (sessionStatus.hasActiveSession != true || sessionStatus.session == null) {
        _setLoading(false, 'لا توجد جلسة مفتوحة');
        return false;
      }

      // Prepare closing data
      final closingData = SessionClosingData(
        cashRegisterBalanceEndReal: cashBalance,
        closingNotes: notes,
      );

      // Close the session using the session manager
      final result = await _backendService.sessionManager.closeSessionWithValidation(
        sessionStatus.session!.id,
        closingData,
      );

      if (result.success) {
        // If this was the current session, clear it
        if (_currentSession?.id == sessionStatus.session!.id) {
          _currentSession = null;
        }
        _setLoading(false, 'تم إغلاق الجلسة بنجاح');
        notifyListeners();
        return true;
      } else {
        _setLoading(false, 'فشل في إغلاق الجلسة: ${result.errors.join(', ')}');
        return false;
      }
    } catch (e) {
      print('Error closing existing session: $e');
      _setLoading(false, 'خطأ في إغلاق الجلسة: $e');
      return false;
    }
  }

  /// Close current POS session
  Future<bool> closeSession({
    double? cashBalance,
    String? notes,
  }) async {
    if (_currentSession == null) {
      print('No active session to close');
      return false;
    }

    try {
      _setLoading(true, 'Closing session...');
      
      // Prepare closing data
      final closingData = SessionClosingData(
        cashRegisterBalanceEndReal: cashBalance,
        closingNotes: notes,
      );

      // Close session through session manager
      final result = await _backendService.sessionManager.closeSessionWithValidation(
        _currentSession!.id,
        closingData,
      );

      if (result.success) {
        // Clear current session data
        _clearSessionData();
        _setLoading(false, 'Session closed successfully');
        return true;
      } else {
        _setLoading(false, 'Failed to close session: ${result.errors.join(', ')}');
        return false;
      }
    } catch (e) {
      _setLoading(false, 'Error closing session: $e');
      print('Error closing session: $e');
      return false;
    }
  }

  /// Setup stream listeners for real-time updates
  void _setupListeners() {
    // Backend service streams
    _backendService.loadingStream.listen((loading) {
      _isLoading = loading;
      _safeNotifyListeners();
    });

    _backendService.statusStream.listen((status) {
      _statusMessage = status;
      _safeNotifyListeners();
    });

    _backendService.productsStream.listen((products) {
      _products = products;
      _safeNotifyListeners();
    });

    _backendService.categoriesStream.listen((categories) {
      _categories = categories;
      _safeNotifyListeners();
    });

    _backendService.customersStream.listen((customers) {
      _customers = customers;
      _safeNotifyListeners();
    });

    // API client streams
    _backendService.apiClient.connectionStream.listen((connected) {
      _isConnected = connected;
      _safeNotifyListeners();
    });

    _backendService.apiClient.authStream.listen((authenticated) {
      _isAuthenticated = authenticated;
      _safeNotifyListeners();
    });

    // Hybrid authentication streams
    _hybridAuth.authModeStream.listen((mode) {
      _currentAuthMode = mode;
      _isOnlineMode = mode == AuthMode.online;
      _safeNotifyListeners();
    });

    _hybridAuth.authStateStream.listen((authenticated) {
      _isAuthenticated = authenticated;
      _safeNotifyListeners();
    });

    _hybridAuth.authStatusStream.listen((status) {
      _statusMessage = status;
      _safeNotifyListeners();
    });

    // Session manager streams
    _backendService.sessionManager.sessionStream.listen((session) {
      _currentSession = session;
      _safeNotifyListeners();
    });

    // Order manager streams
    _backendService.orderManager.orderStream.listen((order) {
      _currentOrder = order;
      _safeNotifyListeners();
    });

    _backendService.orderManager.linesStream.listen((lines) {
      _orderLines = lines;
      _safeNotifyListeners();
    });

    _backendService.orderManager.paymentsStream.listen((payments) {
      _payments = payments;
      _safeNotifyListeners();
    });
  }

  /// Select POS configuration
  void selectConfig(POSConfig config) {
    _selectedConfig = config;
    
    // Load pricelists for this configuration
    _loadPricelists();
    
    // عرض معلومات الطابعات للـ POS Config المحدد
    _displayPrinterInfo(config);
    
    // طباعة تفاصيل POS Config للتشخيص
    printPosConfigDetails();
    
    // تهيئة إعدادات الطابعات للـ config المحدد
    _initializePrinterConfig(config);
    
    _safeNotifyListeners();
  }

  /// تهيئة إعدادات الطابعات للـ config المحدد
  Future<void> _initializePrinterConfig(POSConfig config) async {
    try {
      debugPrint('🔄 Initializing printer configuration for POS Config: ${config.name}');
      await _printerConfigService.initialize(posConfigId: config.id);
      debugPrint('✅ Printer configuration initialized for ${config.name}');
      
      // تهيئة نظام الطباعة المحسن مع إعدادات POS الجديدة
      await _enhancedWindowsPrinterService.initialize(posConfig: config);
      debugPrint('✅ Enhanced Windows printer system re-initialized for ${config.name}');
    } catch (e) {
      debugPrint('❌ Error initializing printer configuration: $e');
    }
  }

  /// عرض معلومات الطابعات للـ POS Config
  void _displayPrinterInfo(POSConfig config) {
    debugPrint('\n🏪 POS Config Selected: ${config.name} (ID: ${config.id})');
    
    // عرض الطابعات المتاحة في Windows
    final availablePrinters = _windowsPrinterService.availablePrinters;
    debugPrint('🖨️ Available Windows Printers: ${availablePrinters.length}');
    for (var printer in availablePrinters) {
      final status = printer.isDefault ? '(Default)' : '';
      debugPrint('  - ${printer.name} $status');
    }
    
    // عرض الطابعة المرتبطة بهذا الـ Config
    final assignedPrinter = _windowsPrinterService.getPrinterForConfig(config.id);
    if (assignedPrinter != null) {
      debugPrint('✅ Assigned Printer for ${config.name}: $assignedPrinter');
    } else {
      debugPrint('⚠️ No printer assigned to ${config.name}');
      if (availablePrinters.isNotEmpty) {
        debugPrint('💡 Available printers to assign: ${availablePrinters.map((p) => p.name).join(', ')}');
      }
    }
    debugPrint(''); // سطر فارغ للتنظيم
  }

  /// طباعة تفاصيل كاملة عن POS Config للتشخيص
  void printPosConfigDetails() {
    if (_selectedConfig == null) {
      debugPrint('❌ No POS Config selected');
      return;
    }

    final config = _selectedConfig!;
    debugPrint('\n🔍 ==========================================');
    debugPrint('🔍 DETAILED POS CONFIG ANALYSIS');
    debugPrint('🔍 ==========================================');
    debugPrint('📋 Basic Info:');
    debugPrint('  🏷️ Name: ${config.name}');
    debugPrint('  🆔 ID: ${config.id}');
    debugPrint('  ✅ Active: ${config.active}');
    debugPrint('  🏢 Company ID: ${config.companyId}');
    
    debugPrint('\n🖨️ PRINTER SETTINGS:');
    debugPrint('  💰 epson_printer_ip: "${config.epsonPrinterIp ?? 'NULL'}"');
    debugPrint('  🍳 printer_ids: ${config.printerIds ?? 'NULL'}');
    debugPrint('  🌐 proxy_ip: "${config.proxyIp ?? 'NULL'}"');
    debugPrint('  🍳 is_order_printer: ${config.isOrderPrinter ?? 'NULL'}');
    
    debugPrint('\n🔧 INTERFACE SETTINGS:');
    debugPrint('  🖨️ iface_print_auto: ${config.ifacePrintAuto ?? 'NULL'}');
    debugPrint('  ⏭️ iface_print_skip_screen: ${config.ifacePrintSkipScreen ?? 'NULL'}');
    debugPrint('  🌉 iface_print_via_proxy: ${config.ifacePrintViaProxy ?? 'NULL'}');
    debugPrint('  💰 iface_cashdrawer: ${config.ifaceCashdrawer ?? 'NULL'}');
    
    debugPrint('\n📄 RECEIPT SETTINGS:');
    debugPrint('  📄 receipt_header: "${config.receiptHeader ?? 'NULL'}"');
    debugPrint('  📄 receipt_footer: "${config.receiptFooter ?? 'NULL'}"');
    
    debugPrint('\n💳 PAYMENT SETTINGS:');
    debugPrint('  💳 payment_method_ids: ${config.paymentMethodIds ?? 'NULL'}');
    
    debugPrint('\n🏪 OTHER SETTINGS:');
    debugPrint('  📦 other_devices: "${config.otherDevices ?? 'NULL'}"');
    debugPrint('🔍 ==========================================');
  }

  /// Clear session data
  void _clearSessionData() {
    _currentSession = null;
    _currentOrder = null;
    _orderLines.clear();
    _payments.clear();
    _paymentMethods.clear();
    _availablePricelists.clear();
    _currentPricelist = null;
    _pricelistItems.clear();
    _safeNotifyListeners();
  }

  /// Clear all provider data
  void _clearAllData() {
    _isConnected = false;
    _isAuthenticated = false;
    _currentUser = null;
    _availableConfigs.clear();
    _selectedConfig = null;
    _products.clear();
    _categories.clear();
    _customers.clear();
    _selectedCategory = '';
    _searchQuery = '';
    _selectedCustomer = null;
    _clearSessionData();
  }

  /// Utility methods
  void _setLoading(bool loading, String status) {
    _isLoading = loading;
    _statusMessage = status;
    _safeNotifyListeners();
  }

  /// Add product to current order
  Future<bool> addProductToCurrentOrder(ProductProduct product, double quantity) async {
    try {
      // Calculate the correct price using current pricelist
      final correctPrice = getProductPrice(product, quantity: quantity);
      
      final result = await _backendService.orderManager.addProductToOrder(
        product: product,
        quantity: quantity,
        customPrice: correctPrice,
      );

      if (result.success) {
        return true;
      } else {
        print('Failed to add product to order: ${result.error}');
        return false;
      }
    } catch (e) {
      print('Error adding product to order: $e');
      return false;
    }
  }

  /// Select category for filtering products
  void selectCategory(POSCategory? category) {
    _selectedCategory = category?.name ?? '';
    _safeNotifyListeners();
  }

  /// Get selected category name
  String get selectedCategoryName => _selectedCategory;

  /// Get filtered products based on selected category
  List<ProductProduct> getFilteredProducts() {
    if (_selectedCategory.isEmpty || _selectedCategory == 'الكل') {
      return _products;
    }
    
    // Find the selected category ID
    try {
      final selectedCat = _categories.firstWhere(
        (cat) => cat.name == _selectedCategory,
      );
      
      // Filter products by category
      return _products.where((product) {
        // Check if product belongs to the selected category
        return product.posCategIds.contains(selectedCat.id);
      }).toList();
    } catch (e) {
      // If category not found, return all products
      print('Warning: Category "$_selectedCategory" not found. Returning all products.');
      return _products;
    }
  }

  /// ========================
  /// PRICELIST MANAGEMENT
  /// ========================

  /// Select a pricelist for the current session
  Future<void> selectPricelist(ProductPricelist pricelist) async {
    try {
      _currentPricelist = pricelist;
      
      // Recalculate all product prices with the new pricelist
      await _recalculateProductPrices();
      
      // Recalculate current order if exists
      if (_orderLines.isNotEmpty) {
        await _recalculateOrderPrices();
      }
      
      _safeNotifyListeners();
    } catch (e) {
      print('Error selecting pricelist: $e');
    }
  }

  /// Get the price of a product according to the current pricelist
  double getProductPrice(ProductProduct product, {double quantity = 1.0, List<double>? extraPrices}) {
    if (_currentPricelist == null) {
      final extraAmount = extraPrices?.fold(0.0, (sum, price) => sum + price) ?? 0.0;
      return product.lstPrice + extraAmount;
    }

    try {
      final basePrice = _pricingService.calculateProductPrice(
        product: product,
        pricelist: _currentPricelist!,
        pricelistItems: _pricelistItems,
        quantity: quantity,
        categories: _categories,
      );
      
      // Add extra prices from attributes
      final attributeExtra = extraPrices?.fold(0.0, (sum, price) => sum + price) ?? 0.0;
      return basePrice + attributeExtra;
    } catch (e) {
      print('Error calculating product price: $e');
      final extraAmount = extraPrices?.fold(0.0, (sum, price) => sum + price) ?? 0.0;
      return product.lstPrice + extraAmount;
    }
  }

  /// Recalculate all product prices with current pricelist
  Future<void> _recalculateProductPrices() async {
    if (_currentPricelist == null) return;

    try {
      // Product prices are calculated on-demand in getProductPrice
      // This method ensures UI refresh after pricelist change
      _safeNotifyListeners();
    } catch (e) {
      print('Error recalculating product prices: $e');
    }
  }

  /// Recalculate current order prices with new pricelist
  Future<void> _recalculateOrderPrices() async {
    if (_currentPricelist == null || _orderLines.isEmpty) {
      return;
    }

    try {
      // Update each order line with new prices
      for (int i = 0; i < _orderLines.length; i++) {
        final orderLine = _orderLines[i];
        
        // Find the product for this order line
        final product = _products.firstWhere(
          (p) => p.id == orderLine.productId,
          orElse: () => throw StateError('Product not found for order line'),
        );
        
        // Calculate new price
        final newPrice = getProductPrice(product, quantity: orderLine.qty);
        
        // Update the order line with new price
        await updateOrderLinePrice(i, newPrice);
      }
      
      _safeNotifyListeners();
    } catch (e) {
      print('Error recalculating order prices: $e');
    }
  }

  /// Update order line price (helper method)
  Future<void> updateOrderLinePrice(int index, double newPrice) async {
    try {
      // This would typically call the backend to update the price
      // For now, we'll update it locally
      if (index >= 0 && index < _orderLines.length) {
        final orderLine = _orderLines[index];
        final newSubtotal = newPrice * orderLine.qty;
        
        // Create updated order line
        final updatedOrderLine = POSOrderLine(
          id: orderLine.id,
          orderId: orderLine.orderId,
          productId: orderLine.productId,
          uuid: orderLine.uuid,
          fullProductName: orderLine.fullProductName,
          companyId: orderLine.companyId,
          qty: orderLine.qty,
          priceUnit: newPrice,
          priceSubtotal: newSubtotal,
          priceSubtotalIncl: newSubtotal * 1.15, // Assuming 15% tax
          discount: orderLine.discount,
          customerNote: orderLine.customerNote,
          totalCost: orderLine.totalCost,
          taxIds: orderLine.taxIds,
        );
        
        _orderLines[index] = updatedOrderLine;
      }
    } catch (e) {
      print('Error updating order line price: $e');
    }
  }

  /// Load pricelists for current configuration
  Future<void> _loadPricelists() async {
    try {
      if (_selectedConfig == null) return;

      _availablePricelists = _backendService.getPricelistsForConfig(_selectedConfig!);
      _pricelistItems = _backendService.pricelistItems;

      // Set default pricelist
      if (_availablePricelists.isNotEmpty) {
        final defaultPricelist = _backendService.getDefaultPricelistForConfig(_selectedConfig!);
        if (defaultPricelist != null) {
          _currentPricelist = defaultPricelist;
        } else {
          _currentPricelist = _availablePricelists.first;
        }
      }

      print('Loaded ${_availablePricelists.length} pricelists. Current: ${_currentPricelist?.name}');
    } catch (e) {
      print('Error loading pricelists: $e');
      _availablePricelists = [];
      _currentPricelist = null;
    }
  }

  /// ========================
  /// COMBO PRODUCT MANAGEMENT
  /// ========================

  /// Check if a product is a combo product
  bool isComboProduct(ProductProduct product) {
    // استخدام البيانات الحقيقية من Odoo فقط
    return _backendService.isComboProduct(product);
  }

  /// Get combo details for a product
  Future<Map<String, dynamic>?> getComboDetails(int productId) async {
    try {
      // استخدام البيانات الحقيقية من Odoo فقط
      return await _backendService.getComboDetails(productId);
    } catch (e) {
      print('Error getting combo details: $e');
      return null;
    }
  }

  /// Get combo by ID
  ProductCombo? getComboById(int comboId) {
    try {
      return _backendService.combos.firstWhere((combo) => combo.id == comboId);
    } catch (e) {
      return null;
    }
  }

  /// Get combo items for a specific combo
  List<ProductComboItem> getComboItems(int comboId) {
    return _backendService.comboItems.where((item) => item.comboId == comboId).toList();
  }

  /// ========================
  /// ORDER MANAGEMENT
  /// ========================

  /// Remove order line by index
  Future<bool> removeOrderLine(int index) async {
    if (index < 0 || index >= _orderLines.length) {
      print('Invalid order line index: $index');
      return false;
    }

    try {
      final result = await _backendService.orderManager.removeOrderLine(index);
      
      if (result.success) {
        print('Order line removed successfully');
        return true;
      } else {
        print('Failed to remove order line: ${result.error}');
        return false;
      }
    } catch (e) {
      print('Error removing order line: $e');
      return false;
    }
  }

  /// Update order line quantity
  Future<bool> updateOrderLineQuantity(int index, double quantity) async {
    if (index < 0 || index >= _orderLines.length) {
      print('Invalid order line index: $index');
      return false;
    }

    if (quantity <= 0) {
      return removeOrderLine(index);
    }

    try {
      final result = await _backendService.orderManager.updateOrderLineQuantity(
        index,
        quantity,
      );
      
      if (result.success) {
        print('Order line quantity updated successfully');
        return true;
      } else {
        print('Failed to update order line quantity: ${result.error}');
        return false;
      }
    } catch (e) {
      print('Error updating order line quantity: $e');
      return false;
    }
  }

  /// Add payment to current order
  Future<bool> addPayment(String methodName, double amount) async {
    if (_currentOrder == null) {
      print('No active order to add payment to');
      return false;
    }

    try {
      // Find payment method by name from available methods for this config
      final availableMethods = availablePaymentMethods;
      final paymentMethod = availableMethods.firstWhere(
        (method) => method.name.toLowerCase() == methodName.toLowerCase(),
        orElse: () {
          // If not found in config-specific methods, try all methods
          final allMethodsMatch = getPaymentMethodByName(methodName);
          if (allMethodsMatch != null) {
            return allMethodsMatch;
          }
          
          // Create temporary method for offline mode
          return POSPaymentMethod(
            id: 0, // Temporary ID for offline mode
            name: methodName,
            companyId: 1,
          );
        },
      );

      final result = await _backendService.orderManager.addPayment(
        paymentMethodId: paymentMethod.id,
        amount: amount,
      );

      if (result.success) {
        print('Payment added successfully: $methodName - $amount');
        return true;
      } else {
        print('Failed to add payment: ${result.error}');
        return false;
      }
    } catch (e) {
      print('Error adding payment: $e');
      return false;
    }
  }

  /// Remove payment from current order
  Future<bool> removePayment(String methodName) async {
    if (_currentOrder == null) {
      print('No active order to remove payment from');
      return false;
    }

    try {
      // Find the payment index by method name
      int paymentIndex = -1;
      for (int i = 0; i < _payments.length; i++) {
        // Assuming we need to match by payment method name
        // This might need adjustment based on actual POSPayment structure
        if (_payments[i].amount > 0) { // Simplified logic for now
          paymentIndex = i;
          break;
        }
      }

      if (paymentIndex == -1) {
        print('Payment not found for method: $methodName');
        return false;
      }

      final result = await _backendService.orderManager.removePayment(paymentIndex);

      if (result.success) {
        print('Payment removed successfully: $methodName');
        return true;
      } else {
        print('Failed to remove payment: ${result.error}');
        return false;
      }
    } catch (e) {
      print('Error removing payment: $e');
      return false;
    }
  }

  /// Get payments as a map for compatibility with old payment screen
  Map<String, double> get paymentsMap {
    final Map<String, double> paymentsByMethod = {};
    
    for (final payment in _payments) {
      // Find the payment method name for this payment
      final methodName = _getPaymentMethodName(payment);
      paymentsByMethod[methodName] = (paymentsByMethod[methodName] ?? 0.0) + payment.amount;
    }
    
    return paymentsByMethod;
  }

  /// Helper method to get payment method name from payment
  String _getPaymentMethodName(POSPayment payment) {
    try {
      final method = getPaymentMethodById(payment.paymentMethodId);
      if (method != null) {
        return method.name;
      }
      
      // Fallback to unknown method
      return 'Unknown Method';
    } catch (e) {
      return 'Unknown Method';
    }
  }

  /// Validate and finalize order (send to Odoo backend)
  Future<OrderValidationResult> validateOrder({
    bool generateInvoice = false,
    int? customerId,
  }) async {
    try {
      // Ensure provider is initialized and authenticated
      if (!_isInitialized || !_isAuthenticated) {
        return OrderValidationResult(
          success: false,
          error: 'System not ready. Please login first.',
        );
      }

      // Check if there's an active order
      if (_currentOrder == null) {
        return OrderValidationResult(
          success: false,
          error: 'لا يوجد طلب نشط للمعالجة',
        );
      }

      // Check if order has items
      if (_orderLines.isEmpty) {
        return OrderValidationResult(
          success: false,
          error: 'الطلب فارغ. يرجى إضافة منتجات قبل المعالجة',
        );
      }

      // Check if payment is complete
      final totalPaid = _payments.fold(0.0, (sum, payment) => sum + payment.amount);
      if (totalPaid < _currentOrder!.amountTotal) {
        return OrderValidationResult(
          success: false,
          error: 'الدفعة غير مكتملة. المطلوب: ${_currentOrder!.amountTotal.toStringAsFixed(2)}, المدفوع: ${totalPaid.toStringAsFixed(2)}',
        );
      }

      _setLoading(true, 'جاري معالجة الطلب وإرساله إلى Odoo...');

      // Update order with customer and invoice settings if provided
      if (customerId != null || generateInvoice) {
        _currentOrder = _currentOrder!.copyWith(
          partnerId: customerId ?? _currentOrder!.partnerId,
          toInvoice: generateInvoice,
        );
      }

      // Get current order data directly from OrderManager BEFORE finalizing
      final orderReceiptData = _backendService.orderManager.getCurrentOrderDataForReceipt();
      final savedCustomer = _selectedCustomer;

      if (orderReceiptData == null) {
        return OrderValidationResult(
          success: false,
          error: 'لا توجد بيانات طلب لمعالجة الدفع',
        );
      }

      // Finalize order through order manager
      final result = await _backendService.orderManager.finalizeOrder();

      if (result.success) {
        _setLoading(false, 'تم إرسال الطلب بنجاح إلى Odoo');
        
        // Use the receipt data from the finalize result (which was saved before clearing)
        final receiptData = result.receiptData ?? orderReceiptData;
        
        print('ValidateOrder - Data saved for receipt:');
        print('  Order Lines Count: ${receiptData.orderLines.length}');
        print('  Payments: ${receiptData.paymentsMap}');
        print('  Customer: ${savedCustomer?.name}');
        print('  Order: ${receiptData.order.name}');
        
        // Create result with saved data from OrderManager
        final validationResult = OrderValidationResult(
          success: true,
          message: 'تم إرسال الطلب بنجاح إلى النظام',
          order: receiptData.order,
          savedOrderLines: receiptData.orderLines,
          savedPayments: receiptData.paymentsMap,
          savedCustomer: savedCustomer,
        );
        
        // Clear selected customer since order is completed
        _selectedCustomer = null;
        _safeNotifyListeners();

        return validationResult;
      } else {
        _setLoading(false, 'فشل في إرسال الطلب إلى Odoo');
        return OrderValidationResult(
          success: false,
          error: result.error ?? 'فشل في معالجة الطلب',
        );
      }
    } catch (e) {
      _setLoading(false, 'خطأ في معالجة الطلب');
      print('Error validating order: $e');
      return OrderValidationResult(
        success: false,
        error: 'حدث خطأ غير متوقع: $e',
      );
    }
  }

  /// Get attribute names from attribute value IDs
  Future<List<String>> getAttributeValueNames(List<int> attributeValueIds) async {
    if (attributeValueIds.isEmpty) return [];
    
    try {
      // This is a simplified implementation for demo purposes
      // In a real implementation, you would fetch from the backend service
      List<String> names = [];
      
      // Map some common attribute value IDs to names for demo
      final Map<int, String> demoAttributeNames = {
        1: 'البطاطس المقلية البلجيكية',
        2: 'بطاطس حلوة مقلية',
        3: 'البطاطس الحلوة المهروسة',
        4: 'البطاطس بالزعتر',
        5: 'خضروات مشوية',
        6: 'صغير',
        7: 'متوسط',
        8: 'كبير',
        9: 'أحمر',
        10: 'أزرق',
        11: 'أخضر',
        12: 'أسود',
        13: 'أبيض',
      };
      
      for (int id in attributeValueIds) {
        if (demoAttributeNames.containsKey(id)) {
          names.add(demoAttributeNames[id]!);
        } else {
          names.add('خاصية $id');
        }
      }
      
      return names;
    } catch (e) {
      print('Error getting attribute names: $e');
      return attributeValueIds.map((id) => 'خاصية $id').toList();
    }
  }

  /// Get formatted attribute text for display
  Future<String> getFormattedAttributeText(List<int> attributeValueIds) async {
    if (attributeValueIds.isEmpty) return '';
    
    final names = await getAttributeValueNames(attributeValueIds);
    if (names.isEmpty) return '';
    
    // Join names with comma for display
    return ' (${names.join(', ')})';
  }

  /// ========================
  /// CUSTOMER MANAGEMENT
  /// ========================

  /// Select customer for the current order
  void selectCustomer(ResPartner customer) {
    _selectedCustomer = customer;
    print('Customer selected: ${customer.name}');
    _safeNotifyListeners();
  }

  /// Clear selected customer
  void clearSelectedCustomer() {
    if (_selectedCustomer != null) {
      print('Clearing selected customer: ${_selectedCustomer!.name}');
      _selectedCustomer = null;
      _safeNotifyListeners();
    }
  }

  /// Add new customer
  Future<bool> addCustomer(ResPartner customer) async {
    try {
      // Convert customer to Map for backend service
      final customerData = {
        'name': customer.name,
        'is_company': customer.isCompany,
        'customer_rank': customer.customerRank,
        'email': customer.email,
        'phone': customer.phone,
        'mobile': customer.mobile,
        'website': customer.website,
        'vat': customer.vatNumber,
        'function': customer.jobPosition,
        'title': customer.title,
        'street': customer.street,
        'street2': customer.street2,
        'city': customer.city,
        'state_id': customer.state,
        'zip': customer.zip,
        'country_id': customer.countryId,
        'lang': customer.lang,
        'tz': customer.tz,
        'active': customer.active,
      };
      
      // Remove null values to avoid sending them to Odoo
      customerData.removeWhere((key, value) => value == null);
      
      // Try to create customer in Odoo backend
      final result = await _backendService.createCustomer(customerData);
      
      if (result.success && result.customer != null) {
        // Add the customer with the server-assigned ID to local list
        _customers.add(result.customer!);
        print('Customer added successfully: ${result.customer!.name} (ID: ${result.customer!.id})');
        _safeNotifyListeners();
        return true;
      } else {
        print('Failed to create customer on server: ${result.error}');
        
        // Fallback: Add to local list with temporary negative ID for offline sync
        final localCustomer = customer.copyWith(
          id: -DateTime.now().millisecondsSinceEpoch, // Negative ID indicates pending sync
        );
        _customers.add(localCustomer);
        print('Customer added locally for later sync: ${localCustomer.name}');
        _safeNotifyListeners();
        return true;
      }
    } catch (e) {
      print('Error adding customer: $e');
      
      // Fallback: Add to local list for offline sync
      try {
        final localCustomer = customer.copyWith(
          id: -DateTime.now().millisecondsSinceEpoch, // Negative ID indicates pending sync
        );
        _customers.add(localCustomer);
        print('Customer added locally due to error: ${localCustomer.name}');
        _safeNotifyListeners();
        return true;
      } catch (fallbackError) {
        print('Complete failure adding customer: $fallbackError');
        return false;
      }
    }
  }

  /// Update existing customer
  Future<bool> updateCustomer(ResPartner customer) async {
    try {
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index == -1) {
        print('Customer not found for update: ${customer.name}');
        return false;
      }
      
      // If customer has positive ID, try to update on server
      if (customer.id > 0) {
        // Convert customer to Map for backend service
        final customerData = {
          'name': customer.name,
          'is_company': customer.isCompany,
          'customer_rank': customer.customerRank,
          'email': customer.email,
          'phone': customer.phone,
          'mobile': customer.mobile,
          'website': customer.website,
          'vat': customer.vatNumber,
          'function': customer.jobPosition,
          'title': customer.title,
          'street': customer.street,
          'street2': customer.street2,
          'city': customer.city,
          'state_id': customer.state,
          'zip': customer.zip,
          'country_id': customer.countryId,
          'lang': customer.lang,
          'tz': customer.tz,
          'active': customer.active,
        };
        
        // Remove null values
        customerData.removeWhere((key, value) => value == null);
        
        try {
          // Update customer on server via API
          if (_backendService.apiClient.isConnected && _backendService.apiClient.isAuthenticated) {
            await _backendService.apiClient.write('res.partner', customer.id, customerData);
            print('Customer updated on server: ${customer.name}');
          } else {
            print('Not connected to server, customer will be synced later');
          }
        } catch (serverError) {
          print('Failed to update customer on server: $serverError');
          // Continue with local update for offline sync later
        }
      }
      
      // Update local customer
      _customers[index] = customer;
      
      // Update selected customer if it's the same one
      if (_selectedCustomer?.id == customer.id) {
        _selectedCustomer = customer;
      }
      
      print('Customer updated locally: ${customer.name}');
      _safeNotifyListeners();
      return true;
    } catch (e) {
      print('Error updating customer: $e');
      return false;
    }
  }

  /// Initialize printer system
  Future<void> initializePrinter({String? iotBoxUrl}) async {
    // تهيئة نظام طابعات Windows
    await _windowsPrinterService.initialize();
    debugPrint('✅ Windows printer system initialized');
    
    // تهيئة نظام الطباعة المحسن مع إعدادات POS
    await _enhancedWindowsPrinterService.initialize(posConfig: _selectedConfig);
    debugPrint('✅ Enhanced Windows printer system initialized');
    
    // إبقاء النظام القديم كـ fallback
    await _printerService.initialize();
    debugPrint('📄 Fallback printer system ready');
  }

  /// Start printer discovery manually
  Future<void> startPrinterDiscovery({bool continuous = false}) async {
    await _printerService.startDiscovery(continuous: continuous);
  }

  /// Stop printer discovery
  void stopPrinterDiscovery() {
    _printerService.stopDiscovery();
  }

  /// Get discovered printers
  List<dynamic> get discoveredPrinters => _printerService.discoveredPrinters;

  /// Get configured printers
  List<dynamic> get configuredPrinters => _printerService.configuredPrinters;

  /// Get printers for current POS config
  List<dynamic> get currentConfigPrinters {
    if (_selectedConfig != null) {
      return _printerService.getPrintersForConfig(_selectedConfig!.id);
    }
    return [];
  }

  /// Configure a printer for current POS config
  Future<bool> configurePrinter(dynamic printer) async {
    if (_selectedConfig != null) {
      return await _printerService.configurePrinter(printer, posConfigId: _selectedConfig!.id);
    }
    return false;
  }

  /// Remove printer configuration
  Future<bool> unconfigurePrinter(String printerId) async {
    return await _printerService.unconfigurePrinter(printerId);
  }

  /// Test printer
  Future<bool> testPrinter(dynamic printer) async {
    return await _printerService.testPrinter(printer);
  }

  /// Check if printer is available
  bool get isPrinterAvailable => _printerService.isAvailable;

  /// Check if currently printing
  bool get isPrinting => _printerService.isPrinting;

  /// Get print jobs
  List<dynamic> get printJobs => _printerService.allJobs;

  /// Get pending jobs count
  int get pendingJobsCount => _printerService.pendingJobsCount;

  /// Print receipt with advanced queue system
  Future<Map<String, dynamic>> printReceipt({
    POSOrder? order,
    List<POSOrderLine>? orderLines,
    Map<String, double>? payments,
    ResPartner? customer,
    ResCompany? company,
    bool webPrintFallback = true,
  }) async {
    try {
      // Use provided data or fall back to current state
      final actualOrderLines = orderLines ?? _orderLines;
      final actualPayments = payments ?? paymentsMap;
      final actualCustomer = customer ?? _selectedCustomer;
      final actualCompany = company ?? this.company;
      final actualOrder = order ?? _currentOrder;

      // طباعة تفاصيل POS Config قبل الطباعة للتشخيص
      printPosConfigDetails();
      
      // استخدم نظام الطباعة المحسن الذي يدعم طابعات متعددة (كاشير + مطبخ)
      final result = await _enhancedWindowsPrinterService.printCompleteOrder(
        order: actualOrder,
        orderLines: actualOrderLines,
        payments: actualPayments,
        customer: actualCustomer,
        company: actualCompany,
      );

      if (result['successful'] == true) {
        print('Receipt printed successfully: ${result['message']['body']}');
      } else {
        print('Print failed: ${result['message']['body']}');
      }

      return result;
    } catch (e) {
      print('Error printing receipt: $e');
      return {
        'successful': false,
        'message': {
          'title': 'Print Error',
          'body': 'An error occurred while printing: $e',
        },
      };
    }
  }

  /// Print current order receipt
  Future<Map<String, dynamic>> printCurrentOrderReceipt({bool webPrintFallback = true}) async {
    return await printReceipt(webPrintFallback: webPrintFallback);
  }

  /// Print test page
  Future<Map<String, dynamic>> printTest(String printerId) async {
    return await _printerService.printTest(printerId);
  }

  /// Open cash drawer
  Future<Map<String, dynamic>> openCashDrawer(String printerId) async {
    return await _printerService.openCashDrawer(printerId);
  }

  /// Cancel print job
  Future<bool> cancelPrintJob(String jobId) async {
    return await _printerService.cancelPrintJob(jobId);
  }

  /// Retry print job
  Future<bool> retryPrintJob(String jobId) async {
    return await _printerService.retryPrintJob(jobId);
  }

  /// Clear completed print jobs
  Future<void> clearCompletedJobs() async {
    await _printerService.clearCompletedJobs();
  }

  /// طباعة تفاصيل POS Config (دالة عامة للاستخدام من UI)
  void debugPrintPosConfig() {
    printPosConfigDetails();
  }

  // === Windows Printer Management ===

  /// الحصول على جميع طابعات Windows المتاحة
  List<dynamic> get availableWindowsPrinters => _windowsPrinterService.availablePrinters;

  /// ربط طابعة بـ POS Config
  Future<void> setPrinterForConfig(int posConfigId, String printerName) async {
    await _windowsPrinterService.setPrinterForConfig(posConfigId, printerName);
    notifyListeners();
    debugPrint('✅ Printer "$printerName" assigned to POS Config $posConfigId');
  }

  /// إزالة ربط طابعة من POS Config
  Future<void> removePrinterForConfig(int posConfigId) async {
    await _windowsPrinterService.removePrinterForConfig(posConfigId);
    notifyListeners();
    debugPrint('🗑️ Printer removed from POS Config $posConfigId');
  }

  /// الحصول على اسم الطابعة المرتبطة بـ POS Config
  String? getPrinterForConfig(int posConfigId) {
    return _windowsPrinterService.getPrinterForConfig(posConfigId);
  }

  /// طباعة اختبار على طابعة Windows
  Future<Map<String, dynamic>> printWindowsTest(String printerName) async {
    return await _windowsPrinterService.printTest(printerName);
  }

  /// تحديث قائمة طابعات Windows
  Future<void> refreshWindowsPrinters() async {
    await _windowsPrinterService.refreshPrinters();
    notifyListeners();
    debugPrint('🔄 Windows printers refreshed');
  }

  /// Printer service streams for real-time updates
  Stream<List<dynamic>> get printersStream => _printerService.printersStream;
  Stream<List<dynamic>> get printJobsStream => _printerService.jobsStream;
  Stream<String> get printerDiscoveryStatusStream => _printerService.discoveryStatusStream;
  Stream<String> get printQueueStatusStream => _printerService.queueStatusStream;

  /// Create demo combo data for testing when Odoo combo tables don't exist
  Future<bool> createDemoCombos() async {
    try {
      print('🎯 Creating demo combos via provider...');
      await _backendService.createDemoCombos();
      
      // Force refresh products to pick up updated combo data
      notifyListeners();
      
      print('✅ Demo combos created successfully');
      return true;
    } catch (e) {
      print('❌ Error creating demo combos: $e');
      return false;
    }
  }

  /// Refresh combo data automatically when needed
  Future<bool> refreshComboData() async {
    try {
      print('🔄 Refreshing combo data via provider...');
      await _backendService.refreshComboData();
      
      // Force refresh to pick up updated combo data
      notifyListeners();
      
      print('✅ Combo data refreshed successfully');
      return true;
    } catch (e) {
      print('❌ Error refreshing combo data: $e');
      return false;
    }
  }

  void _safeNotifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}

/// Result of order validation operation
class OrderValidationResult {
  final bool success;
  final String? error;
  final String? message;
  final POSOrder? order;
  final List<POSOrderLine>? savedOrderLines;
  final Map<String, double>? savedPayments;
  final ResPartner? savedCustomer;

  OrderValidationResult({
    required this.success,
    this.error,
    this.message,
    this.order,
    this.savedOrderLines,
    this.savedPayments,
    this.savedCustomer,
  });
}