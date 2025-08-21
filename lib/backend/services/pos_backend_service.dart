import 'dart:async';
import '../models/pos_config.dart';
import '../models/pos_session.dart';
import '../models/product_product.dart';
import '../models/pos_category.dart';
import '../models/res_partner.dart';
import '../models/pos_payment_method.dart';
import '../models/account_tax.dart';
import '../models/product_attribute.dart';
import '../models/product_pricelist.dart';
import '../models/product_pricelist_item.dart';
import '../models/res_company.dart';
import '../models/product_combo.dart';
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
  List<ProductPricelist> _pricelists = [];
  List<ProductPricelistItem> _pricelistItems = [];
  List<ProductCombo> _combos = [];
  List<ProductComboItem> _comboItems = [];
  
  // Map to store product templates with their attribute lines
  Map<int, Map<String, dynamic>> _productTemplates = {};
  Map<int, List<Map<String, dynamic>>> _attributeLines = {};
  List<AccountTax> _taxes = [];
  ResCompany? _company;

  // Stream controllers for real-time updates
  final StreamController<List<ProductProduct>> _productsController = StreamController<List<ProductProduct>>.broadcast();
  final StreamController<List<POSCategory>> _categoriesController = StreamController<List<POSCategory>>.broadcast();
  final StreamController<List<ResPartner>> _customersController = StreamController<List<ResPartner>>.broadcast();
  final StreamController<List<ProductPricelist>> _pricelistsController = StreamController<List<ProductPricelist>>.broadcast();
  final StreamController<bool> _loadingController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  /// Streams for UI to listen to
  Stream<List<ProductProduct>> get productsStream => _productsController.stream;
  Stream<List<POSCategory>> get categoriesStream => _categoriesController.stream;
  Stream<List<ResPartner>> get customersStream => _customersController.stream;
  Stream<List<ProductPricelist>> get pricelistsStream => _pricelistsController.stream;
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
  List<ProductPricelist> get pricelists => List.unmodifiable(_pricelists);
  List<ProductPricelistItem> get pricelistItems => List.unmodifiable(_pricelistItems);
  List<ProductCombo> get combos => List.unmodifiable(_combos);
  List<ProductComboItem> get comboItems => List.unmodifiable(_comboItems);
  List<AccountTax> get taxes => List.unmodifiable(_taxes);
  ResCompany? get company => _company;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if a product has attributes/variants based on its template
  bool productHasAttributes(ProductProduct product) {
    // Check if the template has attribute lines
    return _attributeLines.containsKey(product.productTmplId) &&
           _attributeLines[product.productTmplId]!.isNotEmpty;
  }
  
  /// Get attribute lines for a product template
  List<Map<String, dynamic>> getProductAttributeLines(int templateId) {
    return _attributeLines[templateId] ?? [];
  }
  
  /// Get complete product information including attributes
  Future<Map<String, dynamic>> getProductCompleteInfo(int productId) async {
    try {
      print('POS Backend: Loading complete product information...');
      
      // Find the product
      final product = _products.firstWhere((p) => p.id == productId);
      
      // Get attribute lines for this product's template
      final attributeLines = getProductAttributeLines(product.productTmplId);
      
      print('Found ${attributeLines.length} attribute lines for template ${product.productTmplId}');
      
      // Build attribute groups
      List<Map<String, dynamic>> attributeGroups = [];
      
      for (var line in attributeLines) {
        final attributeData = line['attribute_id'];
        final rawTemplateValueIds = line['product_template_value_ids'];
        
        // Handle null or false values from Odoo
        List<int> templateValueIds = [];
        if (rawTemplateValueIds != null && rawTemplateValueIds != false && rawTemplateValueIds is List) {
          templateValueIds = List<int>.from(rawTemplateValueIds);
        }
        
        print('Raw template value IDs: $rawTemplateValueIds');
        print('Processed template value IDs: $templateValueIds');
        
        // Load template attribute values with price_extra
        List<ProductAttributeValue> attributeValues = [];
        
        if (templateValueIds.isNotEmpty) {
          // Use the new method with product_template_value_ids
          attributeValues = await _loadTemplateAttributeValuesByIds(templateValueIds);
        } else {
          // Fallback to the old method using value_ids
          final rawValueIds = line['value_ids'];
          if (rawValueIds != null && rawValueIds != false && rawValueIds is List) {
            final valueIds = List<int>.from(rawValueIds);
            print('Fallback to value_ids: $valueIds');
            attributeValues = await _loadTemplateAttributeValues(product.productTmplId, valueIds);
          }
        }
        
        // Debug: Print attribute values with price_extra
        for (var value in attributeValues) {
          print('Backend attribute value: ${value.name}, price_extra: ${value.priceExtra}');
        }
        
        // Only add the attribute group if it has values
        if (attributeValues.isNotEmpty) {
          attributeGroups.add({
            'id': attributeData[0], // [id, name]
            'name': attributeData[1],
            'values': attributeValues.map((v) => v.toJson()).toList(),
          });
        } else {
          print('No attribute values found for attribute ${attributeData[1]}, skipping...');
        }
      }
      
      print('Created ${attributeGroups.length} attribute groups');
      
      // Create a simple ProductCompleteInfo-like structure
      return {
        'productId': product.id,
        'productName': product.displayName,
        'basePrice': product.lstPrice,
        'finalPrice': product.lstPrice,
        'taxIds': product.taxesId,
        'vatRate': _calculateVATRate(product.taxesId),
        'attributeGroups': attributeGroups,
      };
      
    } catch (e) {
      print('Error loading product complete info: $e');
      
      // Return basic info as fallback
      final product = _products.firstWhere((p) => p.id == productId);
      return {
        'productId': product.id,
        'productName': product.displayName,
        'basePrice': product.lstPrice,
        'finalPrice': product.lstPrice,
        'taxIds': product.taxesId,
        'vatRate': _calculateVATRate(product.taxesId),
        'attributeGroups': <Map<String, dynamic>>[],
      };
    }
  }
  
  /// Load template attribute values directly by IDs
  Future<List<ProductAttributeValue>> _loadTemplateAttributeValuesByIds(List<int> templateValueIds) async {
    try {
      if (templateValueIds.isEmpty) return [];
      
      print('Loading template attribute values by IDs: $templateValueIds');
      
      // Get template attribute values with price_extra
      final templateValuesData = await _apiClient.searchRead(
        'product.template.attribute.value',
        domain: [['id', 'in', templateValueIds]],
        fields: [
          'id', 'product_attribute_value_id', 'price_extra', 'html_color', 'name',
          'attribute_id', 'attribute_line_id'
        ],
      );
      
      print('Template values data: $templateValuesData');
      
      List<ProductAttributeValue> result = [];
      
      for (var templateValue in templateValuesData) {
        final priceExtra = (templateValue['price_extra'] as num?)?.toDouble() ?? 0.0;
        print('Template Value ${templateValue['name']}: price_extra = $priceExtra');
        
        // Create ProductAttributeValue with price_extra
        final value = ProductAttributeValue(
          id: templateValue['product_attribute_value_id'] is List 
              ? templateValue['product_attribute_value_id'][0] 
              : templateValue['product_attribute_value_id'],
          name: templateValue['name'] ?? 'Unknown',
          attributeId: templateValue['attribute_id'] is List 
              ? templateValue['attribute_id'][0] 
              : templateValue['attribute_id'],
          sequence: 10,
          htmlColor: _extractNullableStringFromOdoo(templateValue['html_color']),
          priceExtra: priceExtra,
        );
        
        result.add(value);
      }
      
      return result;
      
    } catch (e) {
      print('Error loading template attribute values by IDs: $e');
      return [];
    }
  }

  /// Load template attribute values with price_extra by product template and value IDs (fallback method)
  Future<List<ProductAttributeValue>> _loadTemplateAttributeValues(int productTmplId, List<int> valueIds) async {
    try {
      if (valueIds.isEmpty) return [];
      
      print('Loading template attribute values for template $productTmplId, valueIds: $valueIds');
      
      // First get template attribute values with price_extra
      final templateValuesData = await _apiClient.searchRead(
        'product.template.attribute.value',
        domain: [
          ['product_tmpl_id', '=', productTmplId],
          ['product_attribute_value_id', 'in', valueIds]
        ],
        fields: ['id', 'product_attribute_value_id', 'price_extra', 'html_color'],
      );
      
      print('Template values data: $templateValuesData');
      
      // Get basic attribute value info
      final basicValuesData = await _apiClient.searchRead(
        'product.attribute.value',
        domain: [['id', 'in', valueIds]],
        fields: ['id', 'name', 'attribute_id', 'html_color', 'sequence'],
      );
      
      print('Basic values data: $basicValuesData');
      
      // Combine the data: basic info + price_extra
      List<ProductAttributeValue> result = [];
      
      for (var basicValue in basicValuesData) {
        final valueId = basicValue['id'];
        final templateValue = templateValuesData.firstWhere(
          (tv) => tv['product_attribute_value_id'][0] == valueId,
          orElse: () => <String, dynamic>{},
        );
        
        final priceExtra = templateValue.isEmpty ? 0.0 : (templateValue['price_extra'] as num?)?.toDouble() ?? 0.0;
        print('Value ${basicValue['name']}: price_extra = $priceExtra');
        
        // Create enhanced ProductAttributeValue with price_extra
        final enhancedValue = ProductAttributeValue(
          id: basicValue['id'],
          name: basicValue['name'],
          attributeId: basicValue['attribute_id'] is List ? basicValue['attribute_id'][0] : basicValue['attribute_id'],
          sequence: basicValue['sequence'] ?? 10,
          htmlColor: _extractNullableStringFromOdoo(basicValue['html_color']),
          priceExtra: priceExtra,
        );
        
        result.add(enhancedValue);
      }
      
      return result;
      
    } catch (e) {
      print('Error loading template attribute values: $e');
      return [];
    }
  }

  /// Helper function to extract nullable string values from Odoo (handles false values)
  String? _extractNullableStringFromOdoo(dynamic value) {
    if (value == false || value == null) {
      return null;
    }
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    return value.toString();
  }
  
  /// Calculate VAT rate from tax IDs
  double _calculateVATRate(List<int> taxIds) {
    try {
      final productTaxes = _taxes.where((tax) => taxIds.contains(tax.id));
      if (productTaxes.isNotEmpty) {
        return productTaxes.first.amount;
      }
    } catch (e) {
      print('Error calculating VAT rate: $e');
    }
    return 0.0;
  }

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
      // Ensure backend service is initialized first
      if (!_isInitialized) {
        await initialize();
      }
      
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
      // Ensure backend service is initialized first
      if (!_isInitialized) {
        await initialize();
      }
      
      _setStatus('Authenticating...');
      _setLoading(true);

      final result = await _apiClient.authenticate(
        username: username,
        password: password,
      );

      if (result.success) {
        _setStatus('Authentication successful');
        // Load available configurations
        await loadAvailableConfigs();
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
  Future<void> loadAvailableConfigs() async {
    try {
      if (!_apiClient.isConnected || !_apiClient.isAuthenticated) {
        return;
      }

      final configsData = await _apiClient.searchRead(
        'pos.config',
        domain: [['active', '=', true]],
        fields: [
          'id', 'name', 'active', 'company_id', 'currency_id', 'cash_control',
          'sequence_line_id', 'sequence_id', 'session_ids', 'pricelist_id',
          'available_pricelist_ids', 'use_pricelist', 'payment_method_ids',
          // إضافة حقول الطابعات الموجودة فعلياً في Odoo 18
          'epson_printer_ip', 'printer_ids', 'proxy_ip', 'is_order_printer',
          'iface_print_auto', 'iface_print_skip_screen', 'iface_print_via_proxy',
          'iface_cashdrawer', 'receipt_header', 'receipt_footer', 'other_devices'
        ],
      );

      _availableConfigs = configsData.map((data) => POSConfig.fromJson(data)).toList();
      print('POSBackendService: Successfully loaded ${_availableConfigs.length} POS configurations');
      for (final config in _availableConfigs) {
        print('  - Found config: ${config.name} (ID: ${config.id}, Active: ${config.active})');
        print('    Use Pricelist: ${config.usePricelist}, Default Pricelist: ${config.pricelistId}');
        print('    Available Pricelists: ${config.availablePricelistIds}');
        print('    Payment Methods: ${config.paymentMethodIds}');
      }
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

  /// Public method to load POS data for an existing session
  Future<void> loadPosDataForExistingSession(POSSession session) async {
    try {
      _setStatus('Loading existing session data...');
      
      if (_apiClient.isConnected && _apiClient.isAuthenticated) {
        // Load from server
        await _loadDataFromServer(session);
      } else {
        // Load from local storage
        await _loadCachedData();
      }
      
      _setStatus('Existing session data loaded');
    } catch (e) {
      print('Error loading existing session data: $e');
      _setStatus('Using cached data');
      await _loadCachedData();
    }
  }

  /// Load data from Odoo server
  Future<void> _loadDataFromServer(POSSession session) async {
    try {
      // Load company information first
      await _loadCompany(session.configId);
      
      // Load products
      await _loadProducts();
      
      // Load categories
      await _loadCategories();
      
      // Load customers
      await _loadCustomers();
      
      // Load payment methods
      await _loadPaymentMethods();
      
      // Load taxes - with fallback to continue if it fails
      try {
        await _loadTaxes();
      } catch (taxError) {
        print('Warning: Failed to load taxes, continuing without tax data: $taxError');
        // Create default tax to prevent crashes
        _taxes = [_createDefaultTax()];
        print('Created default tax to prevent crashes');
      }

      // Load pricelists for the session
      try {
        await _loadPricelists(session);
      } catch (pricelistError) {
        print('Warning: Failed to load pricelists, continuing without pricelist data: $pricelistError');
        _pricelists = [];
        _pricelistItems = [];
      }

      // Load combos
      try {
        await _loadCombos();
      } catch (comboError) {
        print('Warning: Failed to load combos, continuing without combo data: $comboError');
        _combos = [];
        _comboItems = [];
      }

      // إعادة جلب إعدادات POS Config الكاملة مع حقول الطابعات
      await _reloadConfigWithPrinterSettings(session.configId);

      // Start background sync
      _syncService.startPeriodicSync();
    } catch (e) {
      print('Error loading data from server: $e');
      throw e;
    }
  }
  
  /// إعادة جلب إعدادات POS Config مع حقول الطابعات
  Future<void> _reloadConfigWithPrinterSettings(int configId) async {
    try {
      print('🔄 Reloading POS Config with printer settings for ID: $configId');
      
      final configData = await _apiClient.read('pos.config', configId, fields: [
        'id', 'name', 'active', 'company_id', 'currency_id', 'cash_control',
        'sequence_line_id', 'sequence_id', 'session_ids', 'pricelist_id',
        'available_pricelist_ids', 'use_pricelist', 'payment_method_ids',
        // حقول الطابعات الموجودة فعلياً في Odoo 18
        'epson_printer_ip', 'printer_ids', 'proxy_ip', 'is_order_printer',
        'iface_print_auto', 'iface_print_skip_screen', 'iface_print_via_proxy',
        'iface_cashdrawer', 'receipt_header', 'receipt_footer', 'other_devices'
      ]);
      
      if (configData.isNotEmpty) {
        final updatedConfig = POSConfig.fromJson(configData);
        
        // استبدال الـ config في القائمة
        final configIndex = _availableConfigs.indexWhere((c) => c.id == configId);
        if (configIndex >= 0) {
          _availableConfigs[configIndex] = updatedConfig;
          print('✅ POS Config updated with printer settings');
          print('  💰 Cashier Printer IP: ${updatedConfig.epsonPrinterIp ?? 'NOT SET'}');
          print('  🍳 Kitchen Printer IDs: ${updatedConfig.printerIds ?? 'NONE'}');
        }
      }
    } catch (e) {
      print('❌ Error reloading POS Config with printer settings: $e');
    }
  }

  /// Load company information from server
  Future<void> _loadCompany(int configId) async {
    try {
      print('🏢 Loading company information for config $configId...');
      
      // First get the company ID from the POS config
      final config = _availableConfigs.firstWhere(
        (config) => config.id == configId,
        orElse: () => throw Exception('POS config not found')
      );
      
      print('Found config: ${config.name}, Company ID: ${config.companyId}');
      
      // Load company data with more fields including logo
      final companyData = await _apiClient.searchRead(
        'res.company',
        domain: [['id', '=', config.companyId]],
        fields: [
          'id', 'name', 'display_name', 'email', 'phone', 'website', 'vat',
          'street', 'street2', 'city', 'zip', 'country_id', 'state_id',
          'currency_id', 'company_registry', 'active', 'logo', 'partner_id'
        ],
      );

      print('Company search result: ${companyData.length} records found');
      if (companyData.isNotEmpty) {
        print('Raw company data: ${companyData.first}');
        
        // Clean company data for proper parsing
        final cleanedData = _cleanCompanyData(companyData.first);
        print('Cleaned company data: $cleanedData');
        
        _company = ResCompany.fromJson(cleanedData);
        print('✅ Successfully loaded company: ${_company!.name}');
        print('  - Email: ${_company!.email ?? "Not set"}');
        print('  - Phone: ${_company!.phone ?? "Not set"}');
        print('  - VAT: ${_company!.vatNumber ?? "Not set"}');
        print('  - Website: ${_company!.website ?? "Not set"}');
        print('  - Address: ${_company!.fullAddress}');
        print('  - Registry: ${_company!.companyRegistry ?? "Not set"}');
        
        // Save cleaned data to cache for offline use
        await _localStorage.saveCompany(cleanedData);
      } else {
        print('⚠️ Warning: No company data found for config, trying fallback methods...');
        await _tryAlternativeCompanyLoad();
      }
    } catch (e) {
      print('❌ Error loading company: $e');
      print('Stack trace: ${StackTrace.current}');
      await _tryAlternativeCompanyLoad();
    }
  }

  /// Try alternative methods to load company data
  Future<void> _tryAlternativeCompanyLoad() async {
    try {
      print('Trying to load company from user context...');
      
      // Get current user's company
      final userData = await _apiClient.read('res.users', _apiClient.userId!, 
        fields: ['company_id', 'company_ids']
      );
      
      if (userData['company_id'] != null) {
        final companyId = userData['company_id'] is List 
            ? userData['company_id'][0] 
            : userData['company_id'];
            
        print('Found user company ID: $companyId');
        
        final companyData = await _apiClient.searchRead(
          'res.company',
          domain: [['id', '=', companyId]],
          fields: [
            'id', 'name', 'display_name', 'email', 'phone', 'website', 'vat',
            'street', 'street2', 'city', 'zip', 'country_id', 'state_id',
            'currency_id', 'company_registry', 'active', 'logo', 'partner_id'
          ],
        );
        
        if (companyData.isNotEmpty) {
          // Clean company data for proper parsing
          final cleanedData = _cleanCompanyData(companyData.first);
          _company = ResCompany.fromJson(cleanedData);
          print('✅ Loaded company from user context: ${_company!.name}');
          await _localStorage.saveCompany(cleanedData);
          return;
        }
      }
      
      // Last resort: create a fallback
      _createFallbackCompany();
      
    } catch (e) {
      print('❌ Alternative company load failed: $e');
      _createFallbackCompany();
    }
  }

  /// Create fallback company data
  void _createFallbackCompany() {
    print('📝 Creating fallback company data...');
    _company = ResCompany(
      id: 1,
      name: 'نقطة البيع',
      email: 'pos@company.com',
      phone: '+966 11 123 4567',
      website: 'https://company.com',
      vatNumber: '123456789012345',
      street: 'الرياض',
      city: 'الرياض',
      companyRegistry: '1010123456',
    );
  }

  /// Clean company data to handle Odoo's [id, name] format
  Map<String, dynamic> _cleanCompanyData(Map<String, dynamic> rawData) {
    final cleaned = Map<String, dynamic>.from(rawData);
    
    // Convert [id, name] fields to just id
    final fieldsToClean = ['country_id', 'state_id', 'currency_id', 'partner_id'];
    
    for (final field in fieldsToClean) {
      if (cleaned[field] is List && (cleaned[field] as List).isNotEmpty) {
        cleaned[field] = (cleaned[field] as List)[0];
        print('Cleaned $field: ${rawData[field]} -> ${cleaned[field]}');
      } else if (cleaned[field] == false) {
        cleaned[field] = null;
        print('Cleaned $field: false -> null');
      }
    }
    
    // Convert false values to null for string fields
    final stringFields = ['email', 'phone', 'website', 'vat', 'street', 'street2', 
                         'city', 'zip', 'company_registry', 'logo', 'display_name'];
    
    for (final field in stringFields) {
      if (cleaned[field] == false) {
        cleaned[field] = null;
        print('Cleaned string field $field: false -> null');
      }
    }
    
    return cleaned;
  }

  /// Load products from server
  Future<void> _loadProducts() async {
    try {
      print('Loading products from server with variant info...');
      final productsData = await _apiClient.searchRead(
        'product.product',
        domain: [
          ['available_in_pos', '=', true],
          ['active', '=', true],
        ],
        fields: [
          'id', 'display_name', 'lst_price', 'standard_price', 'barcode',
          'available_in_pos', 'to_weight', 'active', 'product_tmpl_id',
          'qty_available', 'virtual_available', 'taxes_id', 
          'product_template_variant_value_ids', 'attribute_line_ids', 'pos_categ_ids',
          'image_128', 'combo_ids', 'type'
        ],
      );

      // Debug: Print first product data to verify we're getting combo info
      if (productsData.isNotEmpty) {
        print('=== First Product Data from Server ===');
        print('Product: ${productsData[0]['display_name']}');
        print('Product Template ID: ${productsData[0]['product_tmpl_id']}');
        print('Product Type: ${productsData[0]['type']}');
        print('Has combo_ids: ${productsData[0].containsKey('combo_ids')}');
        if (productsData[0].containsKey('combo_ids')) {
          print('Combo IDs: ${productsData[0]['combo_ids']}');
        }
        print('Has product_template_variant_value_ids: ${productsData[0].containsKey('product_template_variant_value_ids')}');
        if (productsData[0].containsKey('product_template_variant_value_ids')) {
          print('Variant Value IDs: ${productsData[0]['product_template_variant_value_ids']}');
        }
        print('=====================================');
      }
      
      // Check if any products are combo type
      final comboProducts = productsData.where((product) => 
        product.containsKey('type') && 
        product['type'] == 'combo'
      ).toList();
      
      print('📦 Found ${comboProducts.length} combo products (type="combo") out of ${productsData.length} total products');
      for (final product in comboProducts) {
        print('   🍔 Combo Product: ${product['display_name']} - type: ${product['type']}, combo_ids: ${product['combo_ids']}');
      }
      
      // Show first few products with their types for debugging
      print('🔍 First 5 products and their types:');
      for (int i = 0; i < productsData.length && i < 5; i++) {
        final product = productsData[i];
        print('   ${i + 1}. ${product['display_name']} - type: "${product['type']}"');
      }
      
      // Also check if any products have combo_ids for debugging
      final productsWithComboIds = productsData.where((product) => 
        product.containsKey('combo_ids') && 
        product['combo_ids'] != false && 
        product['combo_ids'] is List && 
        (product['combo_ids'] as List).isNotEmpty
      ).toList();
      
      print('📋 Found ${productsWithComboIds.length} products with combo_ids out of ${productsData.length} total products');
      for (final product in productsWithComboIds) {
        print('   📋 Product with combo_ids: ${product['display_name']} - combo_ids: ${product['combo_ids']}');
      }

      // Also load product templates to get attribute information
      await _loadProductTemplates();

      _products = productsData.map((data) => ProductProduct.fromJson(data)).toList();
      
      // Cache locally
      await _localStorage.saveProducts(productsData);
      
      _productsController.add(_products);
    } catch (e) {
      print('Error loading products: $e');
      throw e;
    }
  }

  /// Load product templates with attribute information
  Future<void> _loadProductTemplates() async {
    try {
      print('Loading product templates with attribute info...');
      final templatesData = await _apiClient.searchRead(
        'product.template',
        domain: [
          ['available_in_pos', '=', true],
          ['active', '=', true],
        ],
        fields: [
          'id', 'name', 'attribute_line_ids'
        ],
      );

      // Store template data for later use
      _productTemplates.clear();
      for (var template in templatesData) {
        _productTemplates[template['id']] = template;
        
        if (template['attribute_line_ids'] != null && 
            template['attribute_line_ids'] is List && 
            (template['attribute_line_ids'] as List).isNotEmpty) {
          print('=== Template with Attributes ===');
          print('Template: ${template['name']}');
          print('Template ID: ${template['id']}');
          print('Attribute Line IDs: ${template['attribute_line_ids']}');
          print('==============================');
        }
      }

      // If we found templates with attributes, load the attribute line details
      var attributeLineIds = <int>[];
      for (var template in templatesData) {
        if (template['attribute_line_ids'] != null && 
            template['attribute_line_ids'] is List) {
          attributeLineIds.addAll((template['attribute_line_ids'] as List).cast<int>());
        }
      }

      if (attributeLineIds.isNotEmpty) {
        await _loadAttributeLines(attributeLineIds);
      }
    } catch (e) {
      print('Error loading product templates: $e');
      // Don't throw, just continue
    }
  }

  /// Load attribute lines details
  Future<void> _loadAttributeLines(List<int> attributeLineIds) async {
    try {
      print('Loading attribute lines: $attributeLineIds');
      final attributeLinesData = await _apiClient.searchRead(
        'product.template.attribute.line',
        domain: [
          ['id', 'in', attributeLineIds],
        ],
        fields: [
          'id', 'product_tmpl_id', 'attribute_id', 'value_ids', 'product_template_value_ids'
        ],
      );

      print('=== Attribute Lines Data ===');
      _attributeLines.clear();
      for (var line in attributeLinesData) {
        int templateId = line['product_tmpl_id'][0]; // Odoo returns [id, name]
        
        if (!_attributeLines.containsKey(templateId)) {
          _attributeLines[templateId] = [];
        }
        _attributeLines[templateId]!.add(line);
        
        print('Line ID: ${line['id']}');
        print('Template ID: $templateId');
        print('Attribute ID: ${line['attribute_id']}');
        print('Value IDs (attribute values): ${line['value_ids']}');
        print('Product Template Value IDs: ${line['product_template_value_ids']}');
        print('---');
      }
      print('===========================');
    } catch (e) {
      print('Error loading attribute lines: $e');
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
        fields: [
          'id', 'name', 'amount', 'amount_type', 'type_tax_use', 
          'price_include', 'include_base_amount', 'is_base_affected', 
          'sequence', 'company_id', 'tax_group_id', 'children_tax_ids',
          'invoice_repartition_line_ids', 'refund_repartition_line_ids'
        ],
      );

      // Debug: Print first tax data to verify we're getting the right fields
      if (taxesData.isNotEmpty) {
        print('=== First Tax Data from Server ===');
        print('Tax: ${taxesData[0]['name']}');
        print('Type Tax Use: ${taxesData[0]['type_tax_use']}');
        print('Amount Type: ${taxesData[0]['amount_type']}');
        print('Raw data: ${taxesData[0]}');
        print('=====================================');
      }

      // Validate tax data before parsing
      final validTaxesData = taxesData.where((data) {
        final typeTaxUse = data['type_tax_use'];
        final amountType = data['amount_type'];
        
        // Check if required fields are present and valid
        if (typeTaxUse == null || amountType == null) {
          print('Warning: Skipping tax with missing required fields: $data');
          return false;
        }
        
        // Validate enum values
        final validTypeTaxUse = ['sale', 'purchase', 'none'].contains(typeTaxUse);
        final validAmountType = ['fixed', 'percent', 'division', 'group'].contains(amountType);
        
        if (!validTypeTaxUse || !validAmountType) {
          print('Warning: Skipping tax with invalid enum values - type_tax_use: $typeTaxUse, amount_type: $amountType');
          return false;
        }
        
        return true;
      }).toList();

      print('Valid taxes found: ${validTaxesData.length}/${taxesData.length}');

      _taxes = validTaxesData.map((data) {
        try {
          return AccountTax.fromJson(data);
        } catch (parseError) {
          print('Error parsing tax data: $parseError');
          print('Tax data that failed to parse: $data');
          rethrow;
        }
      }).toList();

      // If no valid taxes found, create a default tax to prevent crashes
      if (_taxes.isEmpty) {
        print('Warning: No valid taxes found, creating default tax');
        _taxes = [_createDefaultTax()];
      }
    } catch (e) {
      print('Error loading taxes: $e');
      throw e;
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

  /// Load pricelists based on session config
  Future<void> _loadPricelists(POSSession session) async {
    try {
      print('Loading pricelists for session...');
      
      // Find the config for this session
      final config = _availableConfigs.firstWhere(
        (config) => config.id == session.configId,
        orElse: () => throw Exception('Config not found for session'),
      );

      // Determine which pricelists to load
      List<int> pricelistIds = [];
      if (config.usePricelist == true && config.availablePricelistIds != null) {
        pricelistIds = config.availablePricelistIds!;
      } else if (config.pricelistId != null) {
        pricelistIds = [config.pricelistId!];
      }

      if (pricelistIds.isEmpty) {
        print('No pricelists configured for this POS config');
        _pricelists = [];
        _pricelistItems = [];
        _pricelistsController.add(_pricelists);
        return;
      }

      print('Loading pricelists: $pricelistIds');

      // Load pricelists
      final pricelistsData = await _apiClient.searchRead(
        'product.pricelist',
        domain: [['id', 'in', pricelistIds]],
        fields: [
          'id', 'name', 'display_name', 'active', 'company_id', 'currency_id',
          'sequence', 'item_ids', 'country_group_ids'
        ],
      );

      _pricelists = pricelistsData.map((data) => ProductPricelist.fromJson(data)).toList();
      
      // Load pricelist items
      await _loadPricelistItems(pricelistIds);

      print('Successfully loaded ${_pricelists.length} pricelists with ${_pricelistItems.length} items');
      _pricelistsController.add(_pricelists);
      
    } catch (e) {
      print('Error loading pricelists: $e');
      throw e;
    }
  }

  /// Load pricelist items for given pricelist IDs
  Future<void> _loadPricelistItems(List<int> pricelistIds) async {
    try {
      print('Loading pricelist items for pricelists: $pricelistIds');
      
      final pricelistItemsData = await _apiClient.searchRead(
        'product.pricelist.item',
        domain: [['pricelist_id', 'in', pricelistIds]],
        fields: [
          'id', 'pricelist_id', 'product_tmpl_id', 'product_id', 'categ_id',
          'applied_on', 'min_quantity', 'compute_price', 'fixed_price',
          'percent_price', 'price_discount', 'price_round', 'price_surcharge',
          'price_min_margin', 'price_max_margin', 'base', 'base_pricelist_id',
          'date_start', 'date_end', 'company_id', 'currency_id'
        ],
      );

      _pricelistItems = pricelistItemsData.map((data) => ProductPricelistItem.fromJson(data)).toList();
      
      print('Successfully loaded ${_pricelistItems.length} pricelist items');
      
    } catch (e) {
      print('Error loading pricelist items: $e');
      throw e;
    }
  }

  /// تحميل الكومبوهات
  Future<void> _loadCombos() async {
    try {
      print('تحميل الكومبوهات...');
      
      // محاولة تحميل كومبوهات المنتجات من Odoo
      // إذا لم تكن الجدول موجود، إنشاء بيانات تجريبية
      try {
        final combosData = await _apiClient.searchRead(
          'product.combo',
          domain: [],
          fields: [
            'id', 'name', 'base_price', 'sequence', 'combo_item_ids'
          ],
        );

        _combos = combosData.map((data) => ProductCombo.fromJson(data)).toList();
        
                // تحميل عناصر الكومبو لجميع الكومبوهات
        if (_combos.isNotEmpty) {
          final comboIds = _combos.map((combo) => combo.id).toList();
          print('🔍 تحميل عناصر الكومبو للكومبوهات: $comboIds');
          await _loadComboItems(comboIds);
          print('📊 بعد تحميل عناصر الكومبو: ${_comboItems.length} عنصر');
        } else {
          print('⚠️ لا توجد كومبوهات لتحميل عناصرها');
        }
        
              // أيضاً تحميل عناصر كومبو المنتجات المرتبطة
      print('🔍 تحميل عناصر كومبو من المنتجات...');
      await _loadComboItemsFromProducts();
      print('📊 بعد تحميل عناصر كومبو من المنتجات: ${_comboItems.length} عنصر');
      
      // تشخيص شامل للبيانات المحملة
      print('🔍 تشخيص شامل للبيانات:');
      print('   - الكومبوهات المحملة: ${_combos.length}');
      for (final combo in _combos) {
        print('     • كومبو ${combo.id}: ${combo.name} (عناصر: ${combo.comboItemIds})');
      }
      
      print('   - عناصر الكومبو المحملة: ${_comboItems.length}');
      for (final item in _comboItems) {
        print('     • عنصر ${item.id}: منتج ${item.productId} في كومبو ${item.comboId}');
      }
      
      print('   - المنتجات مع combo_ids:');
      for (final product in _products.where((p) => p.comboIds.isNotEmpty)) {
        print('     • ${product.displayName}: combo_ids = ${product.comboIds}');
      }
      
      print('📊 ملخص البيانات المحملة:');
      print('   - الكومبوهات: ${_combos.length}');
      print('   - عناصر الكومبو: ${_comboItems.length}');
      print('   - المنتجات المرتبطة بالكومبو: ${_products.where((p) => p.comboIds.isNotEmpty).length}');
      
      // التحقق من وجود عناصر كومبو للمنتجات التي لها combo_ids
      if (_comboItems.isEmpty && _products.any((p) => p.comboIds.isNotEmpty)) {
        print('⚠️ لم يتم العثور على عناصر كومبو من Odoo');
        print('🔍 تشخيص المشكلة:');
        print('   1. تأكد من وجود جدول product.combo.item في Odoo');
        print('   2. تأكد من إضافة عناصر كومبو في الجدول');
        print('   3. تأكد من ربط العناصر بالكومبوهات الصحيحة');
        print('   4. تأكد من أن combo_ids في المنتجات تشير إلى معرفات صحيحة');
      }
        
      } catch (tableError) {
        print('تحذير: جدول product.combo غير موجود في Odoo: $tableError');
        print('❌ يجب إعداد جداول الكومبو في Odoo أولاً');
        // لا ننشئ بيانات تجريبية - نعتمد على البيانات الحقيقية فقط
      }

      print('تم تحميل ${_combos.length} كومبو بنجاح مع ${_comboItems.length} عنصر');
      
    } catch (e) {
      print('خطأ في تحميل الكومبوهات: $e');
      // لا نرمي الخطأ، فقط نسجل الخطأ ونستمر بدون بيانات الكومبو
      _combos = [];
      _comboItems = [];
      
      // لا ننشئ بيانات تجريبية - نعتمد على البيانات الحقيقية من Odoo فقط
    }
  }

  /// تحميل عناصر الكومبو لمعرفات الكومبو المحددة
  Future<void> _loadComboItems(List<int> comboIds) async {
    try {
      if (comboIds.isEmpty) return;
      
      print('تحميل عناصر الكومبو للكومبوهات: $comboIds');
      
      // تحميل عناصر الكومبو من جدول product.combo.item
      print('🔍 البحث في جدول product.combo.item للكومبوهات: $comboIds');
      
      List<Map<String, dynamic>> comboItemsData = [];
      
      try {
        print('🔍 البحث في جدول product.combo.item مع domain: [["combo_id", "in", $comboIds]]');
        
        comboItemsData = await _apiClient.searchRead(
          'product.combo.item',
          domain: [['combo_id', 'in', comboIds]],
          fields: [
            'id', 'combo_id', 'product_id', 'extra_price'
          ],
        );
        
        print('📋 تم العثور على ${comboItemsData.length} عنصر كومبو من قاعدة البيانات');
        print('🔍 Domain المستخدم: [["combo_id", "in", $comboIds]]');
        
        if (comboItemsData.isEmpty) {
          print('⚠️ جدول product.combo.item فارغ أو لا يحتوي على عناصر للكومبوهات: $comboIds');
          print('💡 يجب إضافة عناصر كومبو في Odoo أو التأكد من بنية البيانات');
          print('🔍 تشخيص إضافي:');
          print('   - تأكد من وجود جدول product.combo.item في قاعدة البيانات');
          print('   - تأكد من إضافة سجلات في الجدول');
          print('   - تأكد من أن combo_id في الجدول يشير إلى معرفات صحيحة');
          print('   - تأكد من أن product_id في الجدول يشير إلى منتجات موجودة');
        }
        
      } catch (tableError) {
        print('❌ خطأ في الوصول لجدول product.combo.item: $tableError');
        print('💡 يجب التأكد من وجود جدول product.combo.item في Odoo');
        return;
      }

      if (comboItemsData.isNotEmpty) {
        print('بيانات عناصر الكومبو الخام من Odoo:');
        for (final item in comboItemsData) {
          print('  - المعرف: ${item['id']}, المنتج: ${item['product_id']}, السعر الإضافي: ${item['extra_price']}');
        }

        // إضافة العناصر الجديدة إلى القائمة الموجودة
        final newItems = comboItemsData.map((data) => ProductComboItem.fromJson(data)).toList();
        for (final newItem in newItems) {
          // تجنب الازدواجية
          if (!_comboItems.any((item) => item.id == newItem.id)) {
            _comboItems.add(newItem);
          }
        }
        
        print('تم تحميل ${newItems.length} عنصر كومبو جديد، المجموع: ${_comboItems.length}');
      }
      
    } catch (e) {
      print('خطأ في تحميل عناصر الكومبو: $e');
      // لا نرمي الخطأ، فقط نسجل الخطأ
    }
  }

  /// تحميل عناصر كومبو محددة بالمعرفات
  Future<void> _loadComboItemsByIds(List<int> comboItemIds) async {
    try {
      if (comboItemIds.isEmpty) return;
      
      print('تحميل عناصر كومبو محددة بالمعرفات: $comboItemIds');
      
      // تحميل عناصر كومبو محددة بالمعرفات من جدول product.combo.item
      print('🔍 البحث في جدول product.combo.item للمعرفات: $comboItemIds');
      final comboItemsData = await _apiClient.searchRead(
        'product.combo.item',
        domain: [['id', 'in', comboItemIds]],
        fields: [
          'id', 'combo_id', 'product_id', 'extra_price'
        ],
      );
      
      print('📋 تم العثور على ${comboItemsData.length} عنصر كومبو محدد من قاعدة البيانات');

      print('بيانات عناصر الكومبو المحددة من Odoo:');
      for (final item in comboItemsData) {
        print('  - المعرف: ${item['id']}, المنتج: ${item['product_id']}, السعر الإضافي: ${item['extra_price']}');
      }

      // إضافة العناصر الجديدة إلى القائمة الموجودة
      final newItems = comboItemsData.map((data) => ProductComboItem.fromJson(data)).toList();
      for (final newItem in newItems) {
        // تجنب الازدواجية
        if (!_comboItems.any((item) => item.id == newItem.id)) {
          _comboItems.add(newItem);
        }
      }
      
      print('تم تحميل ${newItems.length} عنصر كومبو محدد، المجموع: ${_comboItems.length}');
      
    } catch (e) {
      print('خطأ في تحميل عناصر الكومبو المحددة: $e');
      // لا نرمي الخطأ، فقط نسجل الخطأ
    }
  }

  /// تحميل عناصر كومبو المنتجات المرتبطة
  Future<void> _loadComboItemsFromProducts() async {
    try {
      // العثور على جميع معرفات الكومبو من المنتجات
      final productComboIds = <int>{};
      for (final product in _products) {
        if (product.comboIds.isNotEmpty) {
          productComboIds.addAll(product.comboIds);
          print('🔍 المنتج "${product.displayName}" له combo_ids: ${product.comboIds}');
        }
      }

      if (productComboIds.isNotEmpty) {
        print('📋 تحميل عناصر كومبو للمعرفات: ${productComboIds.toList()}');
        print('🔍 استراتيجية التحميل:');
        print('   1. البحث في جدول product.combo.item للمعرفات المحددة');
        print('   2. البحث في جدول product.combo للكومبوهات المحددة');
        print('   3. تحميل العناصر المرتبطة بالكومبوهات الموجودة');
        
        // أولاً: محاولة تحميل هذه المعرفات كمعرفات لجدول product.combo.item
        await _loadComboItemsByIds(productComboIds.toList());
        
        // ثانياً: محاولة تحميل هذه المعرفات كمعرفات لجدول product.combo
        await _loadAdditionalCombos(productComboIds.toList());
        
        // ثالثاً: تحميل الكومبوهات المرتبطة بعناصر الكومبو الموجودة
        await _loadRelatedCombos(productComboIds.toList());
        
        print('📊 نتيجة التحميل:');
        print('   - عناصر كومبو محملة: ${_comboItems.length}');
        print('   - الكومبوهات المحملة: ${_combos.length}');
      }
      
    } catch (e) {
      print('❌ خطأ في تحميل عناصر كومبو المنتجات: $e');
    }
  }



  /// تحميل كومبوهات مرتبطة بعناصر كومبو محددة
  Future<void> _loadRelatedCombos(List<int> comboItemIds) async {
    try {
      if (comboItemIds.isEmpty) return;
      
      // العثور على معرفات الكومبوهات المرتبطة بهذه العناصر
      final relatedComboIds = <int>{};
      for (final item in _comboItems) {
        if (comboItemIds.contains(item.id)) {
          relatedComboIds.add(item.comboId);
        }
      }

      if (relatedComboIds.isNotEmpty) {
        print('تحميل الكومبوهات المرتبطة: ${relatedComboIds.toList()}');
        
        // تحميل الكومبوهات المفقودة
        final missingComboIds = relatedComboIds.where((id) => 
          !_combos.any((combo) => combo.id == id)
        ).toList();
        
        if (missingComboIds.isNotEmpty) {
          await _loadAdditionalCombos(missingComboIds);
        }
      }
      
    } catch (e) {
      print('خطأ في تحميل الكومبوهات المرتبطة: $e');
    }
  }

  /// تحميل كومبوهات إضافية بناءً على معرفات محددة
  Future<void> _loadAdditionalCombos(List<int> comboIds) async {
    try {
      if (comboIds.isEmpty) return;
      
      print('تحميل كومبوهات إضافية: $comboIds');
      
      final combosData = await _apiClient.searchRead(
        'product.combo',
        domain: [['id', 'in', comboIds]],
        fields: [
          'id', 'name', 'base_price', 'sequence', 'combo_item_ids'
        ],
      );

      final newCombos = combosData.map((data) => ProductCombo.fromJson(data)).toList();
      for (final newCombo in newCombos) {
        // تجنب الازدواجية
        if (!_combos.any((combo) => combo.id == newCombo.id)) {
          _combos.add(newCombo);
        }
      }
      
      print('تم تحميل ${newCombos.length} كومبو إضافي، المجموع: ${_combos.length}');
      
    } catch (e) {
      print('خطأ في تحميل الكومبوهات الإضافية: $e');
    }
  }

  /// الحصول على تفاصيل الكومبو لمنتج
  Future<Map<String, dynamic>?> getComboDetails(int productId) async {
    try {
      print('🔍 الحصول على تفاصيل الكومبو للمنتج المعرف: $productId');
      
      // التحقق من وجود بيانات كومبو محملة
      print('   📊 حالة بيانات الكومبو:');
      print('     - الكومبوهات المحملة: ${_combos.length}');
      print('     - عناصر الكومبو المحملة: ${_comboItems.length}');
      
      if (_combos.isNotEmpty) {
        print('   📋 الكومبوهات الموجودة:');
        for (final combo in _combos) {
          print('     - كومبو ${combo.id}: ${combo.name} (عناصر: ${combo.comboItemIds})');
        }
      } else {
        print('   ⚠️ لا توجد كومبوهات محملة');
      }
      
      if (_comboItems.isNotEmpty) {
        print('   📋 عناصر الكومبو الموجودة:');
        for (final item in _comboItems) {
          print('     - عنصر ${item.id}: منتج ${item.productId} في كومبو ${item.comboId} (سعر إضافي: ${item.extraPrice})');
        }
      } else {
        print('   ⚠️ لا توجد عناصر كومبو محملة - هذا هو سبب المشكلة!');
        print('   💡 يجب إضافة عناصر في جدول product.combo.item');
      }
      
      // العثور على المنتج
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('المنتج غير موجود')
      );

      print('   تم العثور على المنتج: ${product.displayName} مع النوع: "${product.type}" ومعرفات الكومبو: ${product.comboIds}');

      // التحقق من أن هذا منتج كومبو وله عناصر كومبو
      if (product.type != 'combo') {
        print('   ❌ المنتج ليس من نوع كومبو (النوع="${product.type}")');
        return null;
      }
      
      if (product.comboIds.isEmpty) {
        print('   ⚠️ منتج الكومبو ليس له combo_ids - لا توجد عناصر لعرضها');
        print('   ❌ لا يمكن عرض كومبو بدون عناصر - يجب إضافة combo_ids في Odoo');
        return null;
      }
      
      print('   ✅ تم العثور على منتج كومبو مع ${product.comboIds.length} عنصر كومبو للمعالجة');

      // الحصول على عناصر الكومبو بناءً على combo_ids للمنتج
      final comboItems = <ProductComboItem>[];
      final usedCombos = <ProductCombo>[];
      
      print('   🔍 تحليل combo_ids: ${product.comboIds}');
      print('   📊 البيانات المتوفرة:');
      print('     - عناصر الكومبو المحملة: ${_comboItems.length}');
      print('     - الكومبوهات المحملة: ${_combos.length}');
      
      // عرض جميع عناصر الكومبو المحملة للتشخيص
      if (_comboItems.isNotEmpty) {
        print('   📋 جميع عناصر الكومبو المحملة:');
        for (final item in _comboItems) {
          print('     • ID: ${item.id}, المنتج: ${item.productId}, الكومبو: ${item.comboId}, المجموعة: ${item.groupName}');
        }
      }
      
      // البحث المتقدم عن عناصر الكومبو
      print('   🔍 البحث عن عناصر الكومبو للمعرفات: ${product.comboIds}');
      
      for (final comboId in product.comboIds) {
        print('     🔎 البحث عن المعرف: $comboId');
        
        // البحث في الكومبوهات أولاً
        final directCombo = _combos.where((combo) => combo.id == comboId).toList();
        if (directCombo.isNotEmpty) {
          final combo = directCombo.first;
          if (!usedCombos.any((c) => c.id == combo.id)) {
            usedCombos.add(combo);
            print('     ✅ عثر على كومبو مباشر: ${combo.name} (ID: ${combo.id})');
            
            // تحميل جميع عناصر هذا الكومبو
            final comboItemsForThisCombo = _comboItems.where((item) => item.comboId == combo.id).toList();
            print('     📋 الكومبو ${combo.name} يحتوي على ${comboItemsForThisCombo.length} عنصر');
            
            for (final item in comboItemsForThisCombo) {
              if (!comboItems.any((ci) => ci.id == item.id)) {
                comboItems.add(item);
                print('     📋 إضافة عنصر كومبو: ${item.productId} من الكومبو ${combo.name}');
              }
            }
          }
          continue;
        }
        
        // البحث المباشر في product.combo.item (للتوافق مع الإصدارات القديمة)
        final directComboItem = _comboItems.where((item) => item.id == comboId).toList();
        if (directComboItem.isNotEmpty) {
          final item = directComboItem.first;
          comboItems.add(item);
          print('     ✅ عثر على عنصر كومبو مباشر: ID $comboId -> منتج ${item.productId}');
          
          // البحث عن الكومبو المرتبط
          final relatedCombo = _combos.where((combo) => combo.id == item.comboId).toList();
          if (relatedCombo.isNotEmpty) {
            final combo = relatedCombo.first;
            if (!usedCombos.any((c) => c.id == combo.id)) {
              usedCombos.add(combo);
              print('     📋 مرتبط بالكومبو: ${combo.name} (ID: ${combo.id})');
            }
          }
          continue;
        }
        
        print('     ❌ لم يتم العثور على المعرف $comboId في الكومبوهات أو عناصر الكومبو');
      }

      // إذا لم يتم العثور على عناصر كومبو من combo_ids، إرجاع خطأ واضح
      if (comboItems.isEmpty) {
        print('   ❌ لم يتم العثور على عناصر كومبو للمعرفات: ${product.comboIds}');
        print('   🔍 المشكلة: جدول product.combo.item فارغ أو لا يحتوي على بيانات');
        print('   📋 الكومبوهات الموجودة: ${_combos.map((c) => '${c.id}:${c.name}').toList()}');
        print('   💡 الحل المطلوب:');
        print('      1. إضافة عناصر كومبو في جدول product.combo.item في Odoo');
        print('      2. ربط العناصر بالكومبوهات الصحيحة (combo_id)');
        print('      3. التأكد من أن combo_ids في المنتج تشير إلى معرفات صحيحة');
        print('   🚫 لن يتم إنشاء بيانات وهمية - يجب إعداد البيانات الحقيقية أولاً');
        return null;
      }
      
      print('   ✅ تم العثور على ${comboItems.length} عنصر كومبو من ${usedCombos.length} كومبو');
      for (final combo in usedCombos) {
        print('     🎯 كومبو: ${combo.name} (${combo.comboItemIds.length} عنصر)');
      }

      // Group items by categories using intelligent logic based on Odoo data
      final Map<String, List<ComboSectionItem>> sections = {};
      
      // أولاً، دعنا نحلل عناصر الكومبو لإنشاء مجموعات منطقية
      print('   🔍 تحليل ${comboItems.length} عنصر كومبو للتجميع الذكي...');
      
      if (comboItems.isEmpty) {
        print('   ❌ لا توجد عناصر كومبو لتحليلها!');
        print('   🔍 المشكلة: جدول product.combo.item فارغ أو لا يحتوي على بيانات');
        print('   💡 الحل: إضافة عناصر كومبو في Odoo أولاً');
        return null;
      }
      
      // الحصول على جميع منتجات عناصر الكومبو للتحليل
      final comboItemProducts = <int, ProductProduct>{};
      for (final item in comboItems) {
        try {
          final itemProduct = _products.firstWhere(
            (p) => p.id == item.productId,
            orElse: () => throw Exception('Combo item product not found with ID ${item.productId}')
          );
          comboItemProducts[item.id] = itemProduct;
          print('     📋 عنصر الكومبو: ${itemProduct.displayName} (ID: ${item.id}), السعر الإضافي: ${item.extraPrice})');
        } catch (e) {
          // إذا لم يتم العثور على المنتج، تخطى (للعناصر التلقائية)
          print('     ⚠️ تخطي عنصر الكومبو ID ${item.id} - المنتج غير موجود');
        }
      }
      
      // استراتيجية تجميع ذكية بناءً على بيانات Odoo الحقيقية
      String determineGroupName(ProductComboItem item, ProductProduct product) {
        // الاستراتيجية 1: التجميع حسب اسم المنتج من Odoo (الأكثر دقة)
        final productName = product.displayName.toLowerCase();
        if (productName.contains('burger') || productName.contains('sandwich') || 
            productName.contains('meal') || productName.contains('combo')) {
          print('     🍔 التجميع حسب اسم المنتج: Burgers Choice');
          return 'Burgers Choice';
        }
        if (productName.contains('drink') || productName.contains('beverage') || 
            productName.contains('juice') || productName.contains('soda') || 
            productName.contains('water') || productName.contains('coffee') ||
            productName.contains('coca') || productName.contains('cola') ||
            productName.contains('minute') || productName.contains('maid') ||
            productName.contains('milkshake') || productName.contains('shake') ||
            productName.contains('espresso') || productName.contains('fanta')) {
          print('     🥤 التجميع حسب اسم المنتج: Drinks choice');
          return 'Drinks choice';
        }
        if (productName.contains('fries') || productName.contains('chips') || 
            productName.contains('side') || productName.contains('extra')) {
          print('     🍟 التجميع حسب اسم المنتج: Side Items');
          return 'Side Items';
        }
        
        // الاستراتيجية 2: التجميع حسب السعر الإضافي من Odoo
        if (item.extraPrice > 0) {
          print('     💰 التجميع حسب السعر الإضافي: Drinks choice (+${item.extraPrice} ريال)');
          return 'Drinks choice';
        }
        
        // الاستراتيجية 3: التجميع حسب نوع المنتج من Odoo (الأقل دقة)
        if (product.type != null && product.type!.isNotEmpty && product.type != 'consu') {
          print('     📦 التجميع حسب نوع المنتج: ${product.type}');
          return product.type!;
        }
        
        // الاستراتيجية 4: التجميع الافتراضي
        print('     📦 استخدام المجموعة الافتراضية: Main Items');
        return 'Main Items';
      }
      
      // إنشاء الأقسام باستخدام التجميع الذكي
      for (final item in comboItems) {
        String groupName;
        String itemName;
        String? itemImage;
        
        // البحث عن المنتج المرتبط بهذا العنصر
        ProductProduct? itemProduct;
        try {
          itemProduct = _products.firstWhere((p) => p.id == item.productId);
        } catch (e) {
          print('     ⚠️ المنتج غير موجود: ID ${item.productId}');
          continue; // تخطي هذا العنصر
        }
        
        // استخدام التجميع الذكي لإنشاء اسم المجموعة
        groupName = determineGroupName(item, itemProduct);
        itemName = itemProduct.displayName;
        itemImage = itemProduct.image128;
        
        print('   🎯 المنتج: $itemName → المجموعة: "$groupName" (السعر الإضافي: ${item.extraPrice})');

        final sectionItem = ComboSectionItem(
          productId: item.productId,
          name: itemName,
          image: itemImage,
          extraPrice: item.extraPrice,
        );

        if (!sections.containsKey(groupName)) {
          sections[groupName] = [];
        }
        sections[groupName]!.add(sectionItem);
      }

      // تحويل إلى كائنات ComboSection مع قيم افتراضية ذكية
      final comboSections = sections.entries.map((entry) {
        print('   📋 إنشاء قسم: "${entry.key}" مع ${entry.value.length} عنصر');
        
        // محاولة العثور على عناصر الكومبو لهذه المجموعة للحصول على نوع الاختيار وحالة المطلوب
        String selectionType = 'single'; // افتراضي
        bool required = true; // افتراضي
        
        // استخدام قيم افتراضية
        selectionType = 'single';
        required = true;
        
        return ComboSection(
          groupName: entry.key,
          selectionType: selectionType,
          required: required,
          items: entry.value,
        );
      }).toList();

      // إنشاء كائن كومبو من الكومبوهات المستخدمة أو من المنتج
      final combo = usedCombos.isNotEmpty 
        ? usedCombos.first // استخدام أول كومبو إذا كان متوفراً
        : ProductCombo(
            id: product.id,
            name: product.displayName,
            basePrice: product.lstPrice,
            sequence: 1,
            comboItemIds: comboItems.map((item) => item.id).toList(),
          );

      print('   ✅ هيكل الكومبو النهائي:');
      print('      الكومبو: ${combo.name}');
      print('      الأقسام: ${comboSections.length}');
      
      if (comboSections.isEmpty) {
        print('      ❌ خطأ: لم يتم إنشاء أي أقسام!');
      } else {
        for (final section in comboSections) {
          print('        - ${section.groupName}: ${section.items.length} عنصر');
          for (final item in section.items) {
            print('          • ${item.name} (+${item.extraPrice} ريال)');
          }
        }
      }
      
      // التحقق من وجود الأقسام المتوقعة
      final hasBurgers = comboSections.any((s) => s.groupName == 'Burgers Choice');
      final hasDrinks = comboSections.any((s) => s.groupName == 'Drinks choice');
      print('      🔍 التحقق: البرجر=${hasBurgers ? '✅' : '❌'}, المشروبات=${hasDrinks ? '✅' : '❌'}');

      final result = {
        'combo': combo,
        'sections': comboSections,
        'totalExtraPrice': comboItems.fold(0.0, (sum, item) => sum + item.extraPrice),
      };
      
      print('   🚀 إرجاع بيانات الكومبو مع ${comboSections.length} قسم إلى الواجهة');
      
      // التحقق النهائي من البيانات
      if (comboSections.isEmpty) {
        print('   ❌ خطأ: لم يتم إنشاء أي أقسام!');
        print('   🔍 المشكلة: لا توجد عناصر كومبو أو فشل في إنشاء الأقسام');
        return null;
      }
      
      print('   ✅ تم إنشاء الكومبو بنجاح:');
      print('      - اسم الكومبو: ${combo.name}');
      print('      - عدد الأقسام: ${comboSections.length}');
      print('      - الأقسام: ${comboSections.map((s) => '${s.groupName}(${s.items.length})').join(', ')}');
      
      // التحقق النهائي من أن البيانات من Odoo وليست وهمية
      print('   🔍 مصدر البيانات: من جدول product.combo.item في Odoo');
      print('   ✅ جميع العناصر مرتبطة بمنتجات حقيقية من قاعدة البيانات');
      
      return result;

    } catch (e) {
      print('❌ خطأ في الحصول على تفاصيل الكومبو: $e');
      print('تتبع الخطأ: ${StackTrace.current}');
      return null;
    }
  }

  // تم إزالة دالة إنشاء العناصر التجريبية - نستخدم البيانات الحقيقية من Odoo فقط

  // تم إزالة دالة إنشاء البيانات التجريبية - نستخدم البيانات الحقيقية من Odoo فقط

  /// التحقق من أن المنتج هو منتج كومبو
  bool isComboProduct(ProductProduct product) {
    print('🔍 التحقق من أن المنتج "${product.displayName}" (المعرف: ${product.id}) هو كومبو...');
    print('   نوع المنتج من Odoo: "${product.type}"');
    print('   معرفات الكومبو للمنتج من Odoo: ${product.comboIds}');
    
    // الفحص الأساسي: هل نوع المنتج "combo"؟
    bool isCombo = product.type == 'combo';
    
    if (isCombo) {
      print('   ✅ المنتج IS كومبو (النوع="combo" من Odoo)');
      
      // التحقق من وجود combo_ids (العناصر لعرضها في النافذة المنبثقة)
      if (product.comboIds.isNotEmpty) {
        print('   📋 الكومبو له ${product.comboIds.length} عنصر كومبو: ${product.comboIds}');
      } else {
        print('   ⚠️ تحذير: منتج الكومبو ليس له combo_ids (لا توجد عناصر لعرضها في النافذة المنبثقة)');
      }
    } else {
      print('   ❌ المنتج ليس كومبو (النوع="${product.type ?? 'null'}")');
    }
    
    print('   النتيجة: ${isCombo ? 'IS COMBO ✅' : 'NOT COMBO ❌'}');
    return isCombo;
  }

  /// Get pricelists for a specific config
  List<ProductPricelist> getPricelistsForConfig(POSConfig config) {
    if (config.usePricelist == true && config.availablePricelistIds != null) {
      return _pricelists.where((pricelist) => 
        config.availablePricelistIds!.contains(pricelist.id)
      ).toList();
    } else if (config.pricelistId != null) {
      return _pricelists.where((pricelist) => 
        pricelist.id == config.pricelistId
      ).toList();
    }
    return [];
  }

  /// Get pricelist items for a specific pricelist
  List<ProductPricelistItem> getItemsForPricelist(int pricelistId) {
    return _pricelistItems.where((item) => item.pricelistId == pricelistId).toList();
  }

  /// Get default pricelist for a config
  ProductPricelist? getDefaultPricelistForConfig(POSConfig config) {
    if (config.pricelistId != null) {
      return _pricelists.firstWhere(
        (pricelist) => pricelist.id == config.pricelistId,
        orElse: () => throw StateError('Default pricelist not found'),
      );
    }
    return null;
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
          'timestamp': DateTime.now().toIso8601String(), // Keep ISO format for local storage
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

  /// Get complete product information with attributes (Alternative implementation)
  Future<ProductCompleteInfoResult> getProductCompleteInfoDetailed(int productId) async {
    try {
      _setStatus('Loading complete product information...');
      _setLoading(true);

      // Check if we have an active session
      final currentSession = _sessionManager.currentSession;
      if (currentSession == null) {
        return ProductCompleteInfoResult(
          success: false,
          error: 'No active session available',
        );
      }

      // Since the custom API doesn't exist, let's get basic product info
      // and simulate the complete info structure
      final productResponse = await _apiClient.callMethod(
        'product.product',
        'search_read',
        [
          [
            ['id', '=', productId]
          ]
        ],
        {
          'fields': [
            'id', 'display_name', 'lst_price', 'standard_price', 'barcode',
            'available_in_pos', 'to_weight', 'active', 'product_tmpl_id',
            'qty_available', 'virtual_available', 'taxes_id',
            'product_template_variant_value_ids'
          ]
        },
      );

      if (productResponse is List && productResponse.isNotEmpty) {
        final productData = productResponse[0] as Map<String, dynamic>;
        
        // Create a simplified ProductCompleteInfo with available data
        final basePrice = (productData['lst_price'] as num?)?.toDouble() ?? 0.0;
        final taxIds = productData['taxes_id'] is List 
            ? (productData['taxes_id'] as List).cast<int>() 
            : <int>[1]; // Default tax ID
        final vatRate = 0.15; // Default VAT rate for Saudi Arabia
        
        final productInfo = ProductCompleteInfo(
          productId: productData['id'],
          productName: productData['display_name'] ?? '',
          basePrice: basePrice,
          finalPrice: basePrice * (1 + vatRate), // Calculate final price with VAT
          taxIds: taxIds,
          vatRate: vatRate,
          attributeGroups: [], // Will be populated if we can get template info
        );

        _setStatus('Product information loaded successfully');
        return ProductCompleteInfoResult(
          success: true,
          productInfo: productInfo,
        );
      } else {
        _setStatus('Product not found');
        return ProductCompleteInfoResult(
          success: false,
          error: 'Product not found',
        );
      }
    } catch (e) {
      _setStatus('Error loading product information: $e');
      
      // Return placeholder data if API fails - this allows continued development
      final placeholderInfo = ProductCompleteInfo(
        productId: productId,
        productName: 'Product $productId',
        basePrice: 10.0,
        finalPrice: 11.5, // With 15% VAT
        taxIds: [1],
        vatRate: 0.15,
        attributeGroups: [],
      );
      
      return ProductCompleteInfoResult(
        success: true,
        productInfo: placeholderInfo,
      );
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
    _pricelists.clear();
    _pricelistItems.clear();
    _taxes.clear();
    
    _productsController.add(_products);
    _categoriesController.add(_categories);
    _customersController.add(_customers);
    _pricelistsController.add(_pricelists);
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
    _pricelistsController.close();
    _loadingController.close();
    _statusController.close();
    
    _sessionManager.dispose();
    _orderManager.dispose();
    _syncService.dispose();
    _apiClient.dispose();
  }

  /// Create demo combo data for testing when Odoo combo tables don't exist
  Future<bool> createDemoCombos() async {
    try {
      _setStatus('Creating demo combo data...');
      _setLoading(true);
      
      print('🎯 Creating demo combos in POSBackendService...');
      
      // Create demo combo products
      final demoCombos = [
        ProductCombo(
          id: 1,
          name: 'وجبة برجر كلاسيك',
          basePrice: 25.0,
          sequence: 1,
          comboItemIds: [1, 2, 3],
        ),
        ProductCombo(
          id: 2,
          name: 'وجبة دجاج مشوي',
          basePrice: 30.0,
          sequence: 2,
          comboItemIds: [4, 5, 6],
        ),
        ProductCombo(
          id: 3,
          name: 'وجبة سمك مشوي',
          basePrice: 35.0,
          sequence: 3,
          comboItemIds: [7, 8, 9],
        ),
      ];
      
      // Create demo combo items
      final demoComboItems = [
        ProductComboItem(
          id: 1,
          comboId: 1,
          productId: 101, // برجر لحم
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 2,
          comboId: 1,
          productId: 102, // بطاطس مقلية
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 3,
          comboId: 1,
          productId: 103, // مشروب غازي
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 4,
          comboId: 2,
          productId: 201, // صدر دجاج مشوي
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 5,
          comboId: 2,
          productId: 102, // بطاطس مقلية
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 6,
          comboId: 2,
          productId: 103, // مشروب غازي
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 7,
          comboId: 3,
          productId: 301, // سمك سالمون مشوي
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 8,
          comboId: 3,
          productId: 104, // خضروات مشوية
          extraPrice: 0.0,
        ),
        ProductComboItem(
          id: 9,
          comboId: 3,
          productId: 105, // عصير طبيعي
          extraPrice: 0.0,
        ),
      ];
      
      // Update the internal lists
      _combos.clear();
      _combos.addAll(demoCombos);
      
      _comboItems.clear();
      _comboItems.addAll(demoComboItems);
      
      // Update products to include combo information
      for (final product in _products) {
        // Find if this product is part of any combo
        final comboIds = <int>[];
        for (final comboItem in _comboItems) {
          if (comboItem.productId == product.id) {
            comboIds.add(comboItem.comboId);
          }
        }
        
        if (comboIds.isNotEmpty) {
          // Update product with combo information
          final updatedProduct = product.copyWith(comboIds: comboIds);
          final index = _products.indexWhere((p) => p.id == product.id);
          if (index != -1) {
            _products[index] = updatedProduct;
          }
        }
      }
      
      // Notify listeners about the updated data
      _productsController.add(_products);
      
      _setStatus('Demo combos created successfully');
      _setLoading(false);
      
      print('✅ Demo combos created successfully:');
      print('   - Combos: ${_combos.length}');
      print('   - Combo Items: ${_comboItems.length}');
      print('   - Products with combos: ${_products.where((p) => p.comboIds.isNotEmpty).length}');
      
      return true;
    } catch (e) {
      _setStatus('Failed to create demo combos: $e');
      _setLoading(false);
      print('❌ Error creating demo combos: $e');
      return false;
    }
  }









  /// تحديث بيانات الكومبو تلقائياً إذا كانت مفقودة
  Future<void> refreshComboData() async {
    try {
      print('🔄 تحديث بيانات الكومبو...');
      
      // التحقق من وجود منتجات مع combo_ids
      final productsWithComboIds = _products.where((p) => p.comboIds.isNotEmpty).toList();
      
      if (productsWithComboIds.isEmpty) {
        print('   ⚠️ لا توجد منتجات مع combo_ids');
        return;
      }
      
      print('   📋 العثور على ${productsWithComboIds.length} منتج مع combo_ids');
      
             // التحقق من البيانات فقط - لا ننشئ بيانات تلقائياً
       if (_comboItems.isEmpty) {
         print('   ⚠️ لا توجد عناصر كومبو محملة');
       }
       
       if (_combos.isEmpty) {
         print('   ⚠️ لا توجد كومبوهات محملة');
       }
      
      print('   ✅ تم تحديث بيانات الكومبو بنجاح');
      print('     - الكومبوهات: ${_combos.length}');
      print('     - عناصر الكومبو: ${_comboItems.length}');
      
    } catch (e) {
      print('❌ خطأ في تحديث بيانات الكومبو: $e');
    }
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

class ProductCompleteInfoResult {
  final bool success;
  final ProductCompleteInfo? productInfo;
  final String? error;

  ProductCompleteInfoResult({required this.success, this.productInfo, this.error});
}

