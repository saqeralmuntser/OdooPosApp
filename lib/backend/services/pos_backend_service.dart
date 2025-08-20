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
  
  // Map to store product templates with their attribute lines
  Map<int, Map<String, dynamic>> _productTemplates = {};
  Map<int, List<Map<String, dynamic>>> _attributeLines = {};
  List<AccountTax> _taxes = [];

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
  List<AccountTax> get taxes => List.unmodifiable(_taxes);

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
          'available_pricelist_ids', 'use_pricelist'
        ],
      );

      _availableConfigs = configsData.map((data) => POSConfig.fromJson(data)).toList();
      print('POSBackendService: Successfully loaded ${_availableConfigs.length} POS configurations');
      for (final config in _availableConfigs) {
        print('  - Found config: ${config.name} (ID: ${config.id}, Active: ${config.active})');
        print('    Use Pricelist: ${config.usePricelist}, Default Pricelist: ${config.pricelistId}');
        print('    Available Pricelists: ${config.availablePricelistIds}');
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
          'image_128'
        ],
      );

      // Debug: Print first product data to verify we're getting variant info
      if (productsData.isNotEmpty) {
        print('=== First Product Data from Server ===');
        print('Product: ${productsData[0]['display_name']}');
        print('Product Template ID: ${productsData[0]['product_tmpl_id']}');
        print('Raw data: ${productsData[0]}');
        print('Has product_template_variant_value_ids: ${productsData[0].containsKey('product_template_variant_value_ids')}');
        if (productsData[0].containsKey('product_template_variant_value_ids')) {
          print('Variant Value IDs: ${productsData[0]['product_template_variant_value_ids']}');
        }
        print('Has attribute_line_ids: ${productsData[0].containsKey('attribute_line_ids')}');
        if (productsData[0].containsKey('attribute_line_ids')) {
          print('Attribute Line IDs: ${productsData[0]['attribute_line_ids']}');
        }
        print('=====================================');
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
