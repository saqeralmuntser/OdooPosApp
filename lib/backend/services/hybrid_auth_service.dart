import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/odoo_api_client.dart';
import '../storage/local_storage.dart';

/// Hybrid Authentication Service
/// Manages seamless switching between online (Odoo) and offline (SQLite) authentication
/// Always tries online first, falls back to offline automatically
class HybridAuthService {
  static final HybridAuthService _instance = HybridAuthService._internal();
  factory HybridAuthService() => _instance;
  HybridAuthService._internal();

  final OdooApiClient _apiClient = OdooApiClient();
  final LocalStorage _localStorage = LocalStorage();

  // Authentication state
  bool _isAuthenticated = false;
  bool _isOnlineMode = false;
  String? _currentUsername;
  int? _currentUserId;
  Map<String, dynamic>? _userProfile;
  
  // Stream controllers
  final StreamController<AuthMode> _authModeController = StreamController<AuthMode>.broadcast();
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();
  final StreamController<String> _authStatusController = StreamController<String>.broadcast();

  /// Current authentication mode stream
  Stream<AuthMode> get authModeStream => _authModeController.stream;
  
  /// Authentication state stream
  Stream<bool> get authStateStream => _authStateController.stream;
  
  /// Authentication status messages stream
  Stream<String> get authStatusStream => _authStatusController.stream;

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;
  
  /// Check if currently in online mode
  bool get isOnlineMode => _isOnlineMode;
  
  /// Get current username
  String? get currentUsername => _currentUsername;
  
  /// Get current user ID
  int? get currentUserId => _currentUserId;
  
  /// Get user profile
  Map<String, dynamic>? get userProfile => _userProfile;

  /// Initialize the hybrid authentication service
  Future<void> initialize() async {
    await _localStorage.initialize();
    await _apiClient.initialize();
    
    // Listen for connectivity changes
    _apiClient.connectionStream.listen(_onConnectivityChanged);
    
    // Check for stored session
    await _checkStoredSession();
  }

  /// Hybrid login: tries online first, falls back to offline
  Future<HybridAuthResult> login({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    _updateStatus('بدء عملية تسجيل الدخول...');
    
    try {
      // Step 1: Always try online first
      final onlineResult = await _attemptOnlineLogin(
        serverUrl: serverUrl,
        database: database,
        username: username,
        password: password,
      );
      
      if (onlineResult.success) {
        return onlineResult;
      }
      
      _updateStatus('فشل الاتصال بالخادم، جاري التحويل للوضع الأوفلاين...');
      
      // Step 2: Fallback to offline mode
      final offlineResult = await _attemptOfflineLogin(
        username: username,
        password: password,
      );
      
      return offlineResult;
      
    } catch (e) {
      _updateStatus('خطأ في عملية تسجيل الدخول: $e');
      return HybridAuthResult(
        success: false,
        mode: AuthMode.failed,
        error: 'خطأ غير متوقع: $e',
      );
    }
  }

  /// Attempt online authentication with Odoo
  Future<HybridAuthResult> _attemptOnlineLogin({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      _updateStatus('محاولة الاتصال بخادم Odoo...');
      
      // Configure API client
      await _apiClient.configure(
        serverUrl: serverUrl,
        database: database,
      );
      
      // Check connectivity
      if (!_apiClient.isConnected) {
        return HybridAuthResult(
          success: false,
          mode: AuthMode.failed,
          error: 'لا يوجد اتصال بالإنترنت',
        );
      }
      
      _updateStatus('جاري تسجيل الدخول عبر Odoo...');
      
      // Attempt authentication
      final authResult = await _apiClient.authenticate(
        username: username,
        password: password,
      );
      
      if (authResult.success) {
        // Success - save credentials and user data
        await _saveOnlineSession(username, password, serverUrl, database);
        await _loadUserProfile();
        
        _isAuthenticated = true;
        _isOnlineMode = true;
        _currentUsername = username;
        _currentUserId = _apiClient.userId;
        
        _authModeController.add(AuthMode.online);
        _authStateController.add(true);
        _updateStatus('تم تسجيل الدخول بنجاح - الوضع الأونلاين');
        
        return HybridAuthResult(
          success: true,
          mode: AuthMode.online,
          message: 'تم تسجيل الدخول بنجاح عبر خادم Odoo',
        );
      } else {
        return HybridAuthResult(
          success: false,
          mode: AuthMode.failed,
          error: authResult.error ?? 'فشل في المصادقة عبر Odoo',
        );
      }
      
    } catch (e) {
      debugPrint('Online login error: $e');
      return HybridAuthResult(
        success: false,
        mode: AuthMode.failed,
        error: 'خطأ في الاتصال بالخادم: $e',
      );
    }
  }

  /// Attempt offline authentication using local database
  Future<HybridAuthResult> _attemptOfflineLogin({
    required String username,
    required String password,
  }) async {
    try {
      _updateStatus('البحث عن بيانات محفوظة محلياً...');
      
      // Check for stored credentials
      final storedCredentials = await _localStorage.getCredentials();
      if (storedCredentials == null) {
        return HybridAuthResult(
          success: false,
          mode: AuthMode.failed,
          error: 'لا توجد بيانات محفوظة للعمل في الوضع الأوفلاين',
        );
      }
      
      final storedUsername = storedCredentials['username'];
      final storedPassword = storedCredentials['password'];
      
      // Verify credentials match
      if (storedUsername != username || !_verifyPassword(password, storedPassword)) {
        return HybridAuthResult(
          success: false,
          mode: AuthMode.failed,
          error: 'اسم المستخدم أو كلمة المرور غير صحيحة',
        );
      }
      
      _updateStatus('تحميل البيانات من قاعدة البيانات المحلية...');
      
      // Load user profile from local storage
      await _loadLocalUserProfile();
      
      _isAuthenticated = true;
      _isOnlineMode = false;
      _currentUsername = username;
      _currentUserId = storedCredentials['user_id'];
      
      _authModeController.add(AuthMode.offline);
      _authStateController.add(true);
      _updateStatus('تم تسجيل الدخول - الوضع الأوفلاين');
      
      // Start monitoring for connection to return
      _startConnectionMonitoring();
      
      return HybridAuthResult(
        success: true,
        mode: AuthMode.offline,
        message: 'تم تسجيل الدخول في الوضع الأوفلاين',
      );
      
    } catch (e) {
      debugPrint('Offline login error: $e');
      return HybridAuthResult(
        success: false,
        mode: AuthMode.failed,
        error: 'خطأ في الوضع الأوفلاين: $e',
      );
    }
  }

  /// Save online session data locally
  Future<void> _saveOnlineSession(String username, String password, String serverUrl, String database) async {
    final sessionData = {
      'username': username,
      'password': _hashPassword(password), // Store hashed password
      'user_id': _apiClient.userId,
      'server_url': serverUrl,
      'database': database,
      'last_login': DateTime.now().toIso8601String(), // Keep ISO format for local storage
      'mode': 'online',
    };
    
    await _localStorage.saveCredentials(sessionData);
  }

  /// Load user profile from Odoo
  Future<void> _loadUserProfile() async {
    try {
      if (_apiClient.userId != null) {
        final userRecord = await _apiClient.read('res.users', _apiClient.userId!);
        _userProfile = userRecord;
        
        // Save user profile locally for offline use
        await _localStorage.saveUserProfile(_userProfile!);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Load user profile from local storage
  Future<void> _loadLocalUserProfile() async {
    try {
      _userProfile = await _localStorage.getUserProfile();
    } catch (e) {
      debugPrint('Error loading local user profile: $e');
    }
  }

  /// Check for stored session on app start
  Future<void> _checkStoredSession() async {
    try {
      final credentials = await _localStorage.getCredentials();
      if (credentials != null) {
        final username = credentials['username'];
        final lastMode = credentials['mode'];
        
        if (username != null) {
          _updateStatus('تم العثور على جلسة محفوظة لـ $username');
          
          // Try to restore session based on last mode
          if (lastMode == 'online' && _apiClient.isConnected) {
            // Try to restore online session
            _updateStatus('محاولة استعادة الجلسة الأونلاين...');
            // This would involve session validation with Odoo
          } else {
            // Restore offline session
            _currentUsername = username;
            _currentUserId = credentials['user_id'];
            await _loadLocalUserProfile();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking stored session: $e');
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isConnected) {
    if (isConnected && !_isOnlineMode && _isAuthenticated) {
      _updateStatus('تم استعادة الاتصال، جاري التحويل للوضع الأونلاين...');
      _attemptOnlineResume();
    } else if (!isConnected && _isOnlineMode && _isAuthenticated) {
      _updateStatus('انقطع الاتصال، جاري التحويل للوضع الأوفلاين...');
      _switchToOfflineMode();
    }
  }

  /// Attempt to resume online mode
  Future<void> _attemptOnlineResume() async {
    try {
      final credentials = await _localStorage.getCredentials();
      if (credentials != null) {
        final serverUrl = credentials['server_url'];
        final database = credentials['database'];
        final username = credentials['username'];
        
        if (serverUrl != null && database != null && username != null) {
          await _apiClient.configure(
            serverUrl: serverUrl,
            database: database,
          );
          
          // Try to validate existing session or re-authenticate
          // This is a simplified approach - in production you might want
          // to attempt session validation first
          _isOnlineMode = true;
          _authModeController.add(AuthMode.online);
          _updateStatus('تم التحويل للوضع الأونلاين');
        }
      }
    } catch (e) {
      debugPrint('Error resuming online mode: $e');
      _updateStatus('فشل في التحويل للوضع الأونلاين');
    }
  }

  /// Switch to offline mode
  void _switchToOfflineMode() {
    _isOnlineMode = false;
    _authModeController.add(AuthMode.offline);
    _updateStatus('تم التحويل للوضع الأوفلاين');
  }

  /// Start monitoring connection for automatic resume
  void _startConnectionMonitoring() {
    // Connection monitoring is already handled by _onConnectivityChanged
    // This method can be used for additional monitoring logic if needed
  }

  /// Logout from current session
  Future<void> logout() async {
    try {
      _updateStatus('جاري تسجيل الخروج...');
      
      if (_isOnlineMode) {
        // Logout from Odoo if online
        await _apiClient.logout();
      }
      
      // Clear authentication state
      _isAuthenticated = false;
      _isOnlineMode = false;
      _currentUsername = null;
      _currentUserId = null;
      _userProfile = null;
      
      // Clear stored session (optional - you might want to keep it for offline use)
      // await _localStorage.clearCredentials();
      
      _authStateController.add(false);
      _authModeController.add(AuthMode.none);
      _updateStatus('تم تسجيل الخروج بنجاح');
      
    } catch (e) {
      _updateStatus('خطأ في تسجيل الخروج: $e');
    }
  }

  /// Update status message
  void _updateStatus(String message) {
    debugPrint('HybridAuth: $message');
    _authStatusController.add(message);
  }

  /// Simple password hashing (use a proper hashing library in production)
  String _hashPassword(String password) {
    // This is a placeholder - use proper password hashing like bcrypt
    return password.codeUnits.map((unit) => unit.toString()).join('');
  }

  /// Verify password against hash
  bool _verifyPassword(String password, String? hash) {
    if (hash == null) return false;
    return _hashPassword(password) == hash;
  }

  /// Dispose resources
  void dispose() {
    _authModeController.close();
    _authStateController.close();
    _authStatusController.close();
  }
}

/// Authentication modes
enum AuthMode {
  none,       // Not authenticated
  online,     // Authenticated via Odoo server
  offline,    // Authenticated via local storage
  failed,     // Authentication failed
}

/// Hybrid authentication result
class HybridAuthResult {
  final bool success;
  final AuthMode mode;
  final String? message;
  final String? error;

  HybridAuthResult({
    required this.success,
    required this.mode,
    this.message,
    this.error,
  });

  @override
  String toString() {
    return 'HybridAuthResult(success: $success, mode: $mode, message: $message, error: $error)';
  }
}
