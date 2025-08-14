import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../storage/local_storage.dart';

/// Odoo API Client
/// Handles all communication with Odoo 18 server using JSON-RPC
/// Supports both online and offline modes with automatic sync
class OdooApiClient {
  static final OdooApiClient _instance = OdooApiClient._internal();
  factory OdooApiClient() => _instance;
  OdooApiClient._internal();

  late Dio _dio;
  final LocalStorage _localStorage = LocalStorage();
  final Connectivity _connectivity = Connectivity();

  // Connection details
  String? _serverUrl;
  String? _database;
  String? _username;
  String? _password;
  String? _apiKey;
  int? _userId;
  String? _sessionId;

  // Connection state
  bool _isConnected = false;
  bool _isAuthenticated = false;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<bool> _authController = StreamController<bool>.broadcast();

  /// Connection status stream
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Authentication status stream
  Stream<bool> get authStream => _authController.stream;

  /// Check if client is connected to server
  bool get isConnected => _isConnected;

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Current user ID
  int? get userId => _userId;

  /// Initialize the API client
  Future<void> initialize() async {
    await _localStorage.initialize();
    _setupDio();
    await _loadStoredCredentials();
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  /// Setup Dio HTTP client
  void _setupDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors for logging and error handling
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Handle authentication errors
          await _handleAuthenticationError();
        }
        handler.next(error);
      },
    ));
  }

  /// Load stored credentials
  Future<void> _loadStoredCredentials() async {
    try {
      final credentials = await _localStorage.getCredentials();
      if (credentials != null) {
        _serverUrl = credentials['server_url'];
        _database = credentials['database'];
        _username = credentials['username'];
        _password = credentials['password'];
        _apiKey = credentials['api_key'];
        _userId = credentials['user_id'];
        _sessionId = credentials['session_id'];
        
        if (_sessionId != null) {
          _isAuthenticated = true;
          _authController.add(true);
        }
      }
    } catch (e) {
      print('Error loading stored credentials: $e');
    }
  }

  /// Check network connectivity
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final wasConnected = _isConnected;
      _isConnected = connectivityResult != ConnectivityResult.none;
      
      if (_isConnected && !wasConnected) {
        // Connection restored
        _connectionController.add(true);
        if (_isAuthenticated) {
          await _validateSession();
        }
      } else if (!_isConnected && wasConnected) {
        // Connection lost
        _connectionController.add(false);
      }
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (_isConnected != wasConnected) {
      _connectionController.add(_isConnected);
      
      if (_isConnected && _isAuthenticated) {
        _validateSession();
      }
    }
  }

  /// Configure connection
  Future<void> configure({
    required String serverUrl,
    required String database,
    String? apiKey,
  }) async {
    _serverUrl = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
    _database = database;
    _apiKey = apiKey;
    
    await _localStorage.saveCredentials({
      'server_url': _serverUrl,
      'database': _database,
      'api_key': _apiKey,
    });
  }

  /// Authenticate with Odoo server
  Future<AuthResult> authenticate({
    required String username,
    required String password,
  }) async {
    if (!_isConnected) {
      return AuthResult(success: false, error: 'No internet connection');
    }

    if (_serverUrl == null || _database == null) {
      return AuthResult(success: false, error: 'Server not configured');
    }

    try {
      _username = username;
      _password = password;

      // Perform authentication using JSON-RPC
      final result = await _jsonRpcCall(
        'common',
        'authenticate',
        [_database, username, password, {}],
      );

      if (result is int && result > 0) {
        _userId = result;
        _isAuthenticated = true;
        
        // Generate session ID (simplified approach)
        _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        
        await _localStorage.saveCredentials({
          'server_url': _serverUrl,
          'database': _database,
          'username': username,
          'password': password,
          'api_key': _apiKey,
          'user_id': _userId,
          'session_id': _sessionId,
        });

        _authController.add(true);
        
        return AuthResult(success: true, userId: _userId);
      } else {
        return AuthResult(success: false, error: 'Invalid credentials');
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Authentication failed: $e');
    }
  }

  /// Validate current session
  Future<bool> _validateSession() async {
    if (!_isAuthenticated || _userId == null) {
      return false;
    }

    try {
      // Try to read user record to validate session
      await read('res.users', _userId!);
      return true;
    } catch (e) {
      // Session invalid, need to re-authenticate
      await _handleAuthenticationError();
      return false;
    }
  }

  /// Handle authentication errors
  Future<void> _handleAuthenticationError() async {
    _isAuthenticated = false;
    _sessionId = null;
    _authController.add(false);
    
    // Clear stored session
    await _localStorage.saveCredentials({
      'server_url': _serverUrl,
      'database': _database,
      'username': _username,
      'password': _password,
      'api_key': _apiKey,
    });
  }

  /// Logout
  Future<void> logout() async {
    _isAuthenticated = false;
    _userId = null;
    _sessionId = null;
    _username = null;
    _password = null;
    
    _authController.add(false);
    await _localStorage.clearCredentials();
  }

  /// JSON-RPC call to Odoo
  Future<dynamic> _jsonRpcCall(
    String service,
    String method,
    List<dynamic> params, {
    Map<String, dynamic>? kwargs,
  }) async {
    if (!_isConnected) {
      throw OdooApiException('No internet connection');
    }

    if (_serverUrl == null) {
      throw OdooApiException('Server URL not configured');
    }

    final url = '${_serverUrl}jsonrpc';
    final payload = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        'service': service,
        'method': method,
        'args': params,
        if (kwargs != null) ...kwargs,
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final response = await _dio.post(url, data: payload);
      
      if (response.statusCode != 200) {
        throw OdooApiException('HTTP ${response.statusCode}: ${response.statusMessage}');
      }

      final result = response.data;
      
      if (result['error'] != null) {
        final error = result['error'];
        throw OdooApiException('${error['message']}: ${error['data']['message']}');
      }

      return result['result'];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw OdooApiException('Connection timeout');
      } else if (e.type == DioExceptionType.connectionError) {
        _isConnected = false;
        _connectionController.add(false);
        throw OdooApiException('Connection error');
      }
      throw OdooApiException('Network error: ${e.message}');
    } catch (e) {
      throw OdooApiException('API call failed: $e');
    }
  }

  /// Execute method with authentication
  Future<dynamic> _execute(
    String model,
    String method,
    List<dynamic> args, {
    Map<String, dynamic>? kwargs,
  }) async {
    if (!_isAuthenticated) {
      throw OdooApiException('Not authenticated');
    }

    return await _jsonRpcCall(
      'object',
      'execute_kw',
      [_database, _userId, _password, model, method, args, kwargs ?? {}],
    );
  }

  /// Create record
  Future<int> create(String model, Map<String, dynamic> values) async {
    final result = await _execute(model, 'create', [values]);
    return result as int;
  }

  /// Read record(s)
  Future<Map<String, dynamic>> read(String model, int id, {List<String>? fields}) async {
    final result = await _execute(model, 'read', [id], kwargs: {'fields': fields});
    if (result is List && result.isNotEmpty) {
      return result.first as Map<String, dynamic>;
    }
    throw OdooApiException('Record not found');
  }

  /// Update record(s)
  Future<bool> write(String model, int id, Map<String, dynamic> values) async {
    final result = await _execute(model, 'write', [[id], values]);
    return result as bool;
  }

  /// Delete record(s)
  Future<bool> unlink(String model, List<int> ids) async {
    final result = await _execute(model, 'unlink', [ids]);
    return result as bool;
  }

  /// Search records
  Future<List<int>> search(String model, {List<dynamic>? domain, int? limit, int? offset, String? order}) async {
    final kwargs = <String, dynamic>{};
    if (limit != null) kwargs['limit'] = limit;
    if (offset != null) kwargs['offset'] = offset;
    if (order != null) kwargs['order'] = order;

    final result = await _execute(model, 'search', [domain ?? []], kwargs: kwargs);
    return List<int>.from(result);
  }

  /// Search and read records
  Future<List<Map<String, dynamic>>> searchRead(
    String model, {
    List<dynamic>? domain,
    List<String>? fields,
    int? limit,
    int? offset,
    String? order,
  }) async {
    final kwargs = <String, dynamic>{};
    if (fields != null) kwargs['fields'] = fields;
    if (limit != null) kwargs['limit'] = limit;
    if (offset != null) kwargs['offset'] = offset;
    if (order != null) kwargs['order'] = order;

    final result = await _execute(model, 'search_read', [domain ?? []], kwargs: kwargs);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Call method on model
  Future<dynamic> callMethod(String model, String method, List<dynamic> args, [Map<String, dynamic>? kwargs]) async {
    return await _execute(model, method, args, kwargs: kwargs);
  }

  /// Load POS data (specific to POS)
  Future<Map<String, dynamic>> loadPosData(int sessionId, {List<String>? modelsToLoad}) async {
    try {
      final result = await callMethod(
        'pos.session',
        'load_pos_data',
        [sessionId],
        {'models_to_load': modelsToLoad},
      );
      return result as Map<String, dynamic>;
    } catch (e) {
      throw OdooApiException('Failed to load POS data: $e');
    }
  }

  /// Get product complete info (specific to POS)
  Future<Map<String, dynamic>> getProductCompleteInfo(int productId, int configId) async {
    try {
      final result = await callMethod(
        'product.product',
        'get_product_complete_info',
        [productId, configId],
      );
      return result as Map<String, dynamic>;
    } catch (e) {
      throw OdooApiException('Failed to get product info: $e');
    }
  }

  /// Sync pending changes when connection is restored
  Future<void> syncPendingChanges() async {
    if (!_isConnected || !_isAuthenticated) {
      return;
    }

    try {
      final pendingChanges = await _localStorage.getPendingChanges();
      
      for (final change in pendingChanges) {
        try {
          await _processPendingChange(change);
          await _localStorage.removePendingChange(change['id']);
        } catch (e) {
          print('Failed to sync change ${change['id']}: $e');
          // Keep the change for later retry
        }
      }
    } catch (e) {
      print('Error syncing pending changes: $e');
    }
  }

  /// Process a pending change
  Future<void> _processPendingChange(Map<String, dynamic> change) async {
    final method = change['method'] as String;
    final model = change['model'] as String;
    final args = change['args'] as List<dynamic>;
    final kwargs = change['kwargs'] as Map<String, dynamic>?;

    switch (method) {
      case 'create':
        await _execute(model, 'create', args, kwargs: kwargs);
        break;
      case 'write':
        await _execute(model, 'write', args, kwargs: kwargs);
        break;
      case 'unlink':
        await _execute(model, 'unlink', args, kwargs: kwargs);
        break;
      default:
        await _execute(model, method, args, kwargs: kwargs);
    }
  }

  /// Store change for offline sync
  Future<void> _storePendingChange(
    String method,
    String model,
    List<dynamic> args, {
    Map<String, dynamic>? kwargs,
  }) async {
    final change = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'method': method,
      'model': model,
      'args': args,
      'kwargs': kwargs,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _localStorage.addPendingChange(change);
  }

  /// Create record with offline support
  Future<int> createOffline(String model, Map<String, dynamic> values) async {
    if (_isConnected && _isAuthenticated) {
      return await create(model, values);
    } else {
      // Store for offline sync
      await _storePendingChange('create', model, [values]);
      // Return temporary ID (negative to indicate offline)
      return -DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Update record with offline support
  Future<bool> writeOffline(String model, int id, Map<String, dynamic> values) async {
    if (_isConnected && _isAuthenticated) {
      return await write(model, id, values);
    } else {
      // Store for offline sync
      await _storePendingChange('write', model, [[id], values]);
      return true; // Assume success for offline
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionController.close();
    _authController.close();
    _dio.close();
  }
}

/// Authentication result
class AuthResult {
  final bool success;
  final int? userId;
  final String? error;

  AuthResult({
    required this.success,
    this.userId,
    this.error,
  });
}

/// Odoo API exception
class OdooApiException implements Exception {
  final String message;
  OdooApiException(this.message);
  
  @override
  String toString() => 'OdooApiException: $message';
}
