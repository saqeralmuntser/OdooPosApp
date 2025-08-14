import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/pos_session.dart';
import '../models/pos_config.dart';
import '../models/pos_order.dart';
import '../api/odoo_api_client.dart';
import '../storage/local_storage.dart';

/// Session Manager
/// Handles the complete lifecycle of POS sessions according to Odoo 18 specification
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final OdooApiClient _apiClient = OdooApiClient();
  final LocalStorage _localStorage = LocalStorage();
  final _uuid = const Uuid();

  POSSession? _currentSession;
  POSConfig? _currentConfig;
  final StreamController<POSSession?> _sessionController = StreamController<POSSession?>.broadcast();

  /// Current session stream
  Stream<POSSession?> get sessionStream => _sessionController.stream;

  /// Current active session
  POSSession? get currentSession => _currentSession;

  /// Current POS configuration
  POSConfig? get currentConfig => _currentConfig;

  /// Check if there's an active session
  bool get hasActiveSession => _currentSession != null && _currentSession!.isOpen;

  /// Initialize session manager
  Future<void> initialize() async {
    await _localStorage.initialize();
    await _loadStoredSession();
  }

  /// Load stored session from local storage
  Future<void> _loadStoredSession() async {
    try {
      final sessionData = await _localStorage.getSession();
      if (sessionData != null) {
        _currentSession = POSSession.fromJson(sessionData);
        final configData = await _localStorage.getConfig();
        if (configData != null) {
          _currentConfig = POSConfig.fromJson(configData);
        }
        _sessionController.add(_currentSession);
      }
    } catch (e) {
      print('Error loading stored session: $e');
    }
  }

  /// Get session status for a specific config and user
  Future<SessionStatusResult> getSessionStatus(int configId, int userId) async {
    try {
      // Check for existing open session
      final existingSession = await _searchOpenSession(configId, userId);
      
      if (existingSession != null) {
        return SessionStatusResult(
          hasActiveSession: true,
          session: existingSession,
          canContinue: existingSession.userId == userId || await _userHasManagerRights(userId),
        );
      } else {
        final lastSessionInfo = await _getLastSessionInfo(configId);
        return SessionStatusResult(
          hasActiveSession: false,
          canCreateSession: await _userCanCreateSession(userId, configId),
          lastSessionInfo: lastSessionInfo,
        );
      }
    } catch (e) {
      throw SessionException('Failed to get session status: $e');
    }
  }

  /// Search for open session
  Future<POSSession?> _searchOpenSession(int configId, int userId) async {
    try {
      final domain = [
        ['state', 'in', ['opening_control', 'opened']],
        ['user_id', '=', userId],
        ['rescue', '=', false],
        ['config_id', '=', configId],
      ];

      final sessions = await _apiClient.searchRead(
        'pos.session',
        domain: domain,
        limit: 1,
      );

      if (sessions.isNotEmpty) {
        return POSSession.fromJson(sessions.first);
      }
      return null;
    } catch (e) {
      print('Error searching for open session: $e');
      return null;
    }
  }

  /// Open or continue session
  Future<SessionResult> openOrContinueSession(
    int configId,
    int userId,
    {SessionOpeningData? openingData}
  ) async {
    try {
      final sessionStatus = await getSessionStatus(configId, userId);

      if (sessionStatus.hasActiveSession) {
        // Continue existing session
        final session = sessionStatus.session!;
        
        if (session.state == POSSessionState.openingControl && openingData != null) {
          // Complete opening control
          await _setOpeningControl(session, openingData);
        }

        // Update login number
        final updatedSession = await _updateLoginNumber(session);
        await _setCurrentSession(updatedSession);

        return SessionResult(
          success: true,
          session: updatedSession,
          action: SessionAction.continued,
        );
      } else {
        // Create new session
        if (!sessionStatus.canCreateSession) {
          throw SessionException('User cannot create session for this config');
        }

        final config = await _getConfig(configId);
        final newSession = await _createNewSession(config, userId);
        
        if (openingData != null && newSession.cashControl) {
          await _setOpeningControl(newSession, openingData);
        } else {
          // Auto-open if no cash control required
          await _openSession(newSession);
        }

        await _setCurrentSession(newSession);

        return SessionResult(
          success: true,
          session: newSession,
          action: SessionAction.created,
        );
      }
    } catch (e) {
      return SessionResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create new session following Odoo algorithm
  Future<POSSession> _createNewSession(POSConfig config, int userId) async {
    try {
      // Generate session name
      final sessionName = await _generateSessionName(config);
      
      // Get last session for cash balance
      double startingBalance = 0.0;
      if (config.cashControl) {
        final lastSession = await _getLastSession(config.id);
        startingBalance = lastSession?.cashRegisterBalanceEndReal ?? 0.0;
      }

      final sessionData = {
        'name': sessionName,
        'config_id': config.id,
        'user_id': userId,
        'company_id': config.companyId,
        'currency_id': config.currencyId,
        'state': 'opening_control',
        'sequence_number': 1,
        'login_number': 0,
        'cash_control': config.cashControl,
        'cash_register_balance_start': startingBalance,
        'start_at': DateTime.now().toIso8601String(),
      };

      final sessionId = await _apiClient.create('pos.session', sessionData);
      final createdSession = await _apiClient.read('pos.session', sessionId);
      
      return POSSession.fromJson(createdSession);
    } catch (e) {
      throw SessionException('Failed to create session: $e');
    }
  }

  /// Generate session name according to Odoo pattern
  Future<String> _generateSessionName(POSConfig config) async {
    try {
      final sessionCounter = await _getNextSessionCounter(config.name);
      return '${config.name}/${sessionCounter.toString().padLeft(5, '0')}';
    } catch (e) {
      // Fallback naming
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${config.name}/$timestamp';
    }
  }

  /// Set opening control for session
  Future<POSSession> _setOpeningControl(POSSession session, SessionOpeningData openingData) async {
    try {
      final updateData = {
        'cash_register_balance_start': openingData.cashboxValue,
        'opening_notes': openingData.notes,
      };

      await _apiClient.write('pos.session', session.id, updateData);
      
      // Open the session
      await _openSession(session);
      
      // Return updated session
      final updatedSession = await _apiClient.read('pos.session', session.id);
      return POSSession.fromJson(updatedSession);
    } catch (e) {
      throw SessionException('Failed to set opening control: $e');
    }
  }

  /// Open session (transition from opening_control to opened)
  Future<void> _openSession(POSSession session) async {
    try {
      await _apiClient.callMethod(
        'pos.session',
        'action_pos_session_open',
        [session.id],
      );
    } catch (e) {
      throw SessionException('Failed to open session: $e');
    }
  }

  /// Update login number for session continuation
  Future<POSSession> _updateLoginNumber(POSSession session) async {
    try {
      final newLoginNumber = session.loginNumber + 1;
      await _apiClient.write('pos.session', session.id, {
        'login_number': newLoginNumber,
      });

      final updatedSession = await _apiClient.read('pos.session', session.id);
      return POSSession.fromJson(updatedSession);
    } catch (e) {
      throw SessionException('Failed to update login number: $e');
    }
  }

  /// Close session with validation
  Future<SessionCloseResult> closeSessionWithValidation(
    int sessionId,
    SessionClosingData closingData,
  ) async {
    try {
      final session = await _getSession(sessionId);
      
      // Validate user permissions
      if (!await _userCanCloseSession(session)) {
        throw SessionException('User does not have permission to close this session');
      }

      // Validate session for closing
      final validation = await _validateSessionForClosing(session);
      if (!validation.canClose) {
        return SessionCloseResult(
          success: false,
          errors: validation.errors,
          warnings: validation.warnings,
        );
      }

      // Process cash control
      if (session.cashControl && closingData.cashRegisterBalanceEndReal != null) {
        await _processCashControl(session, closingData);
      }

      // Set closing notes
      if (closingData.closingNotes != null) {
        await _apiClient.write('pos.session', session.id, {
          'closing_notes': closingData.closingNotes,
        });
      }

      // Close the session
      await _apiClient.callMethod(
        'pos.session',
        'action_pos_session_closing_control',
        [session.id],
        {'bank_payment_method_diffs': closingData.bankPaymentMethodDiffs ?? {}},
      );

      // Get final session state
      final finalSession = await _getSession(sessionId);
      
      // Clear current session if it's the one being closed
      if (_currentSession?.id == sessionId) {
        await _clearCurrentSession();
      }

      return SessionCloseResult(
        success: true,
        session: finalSession,
        cashDifference: finalSession.cashRegisterDifference ?? 0.0,
      );
    } catch (e) {
      return SessionCloseResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Process cash control during closing
  Future<void> _processCashControl(POSSession session, SessionClosingData closingData) async {
    try {
      // Calculate theoretical balance
      final theoreticalBalance = await _calculateTheoreticalBalance(session);
      
      // Get actual balance from closing data
      final actualBalance = closingData.cashRegisterBalanceEndReal!;
      
      // Calculate difference
      final difference = actualBalance - theoreticalBalance;

      // Update session with cash control data
      await _apiClient.write('pos.session', session.id, {
        'cash_register_balance_end_real': actualBalance,
        'cash_register_balance_end': theoreticalBalance,
        'cash_register_difference': difference,
      });

      // Record cash difference if significant
      if (difference.abs() > 0.01) {
        await _recordCashDifference(session, difference);
      }
    } catch (e) {
      throw SessionException('Failed to process cash control: $e');
    }
  }

  /// Set current active session
  Future<void> _setCurrentSession(POSSession session) async {
    _currentSession = session;
    _sessionController.add(session);
    
    // Store session locally
    await _localStorage.saveSession(session.toJson());
    
    // Load and store config if not already loaded
    if (_currentConfig?.id != session.configId) {
      final config = await _getConfig(session.configId);
      _currentConfig = config;
      await _localStorage.saveConfig(config.toJson());
    }
  }

  /// Clear current session
  Future<void> _clearCurrentSession() async {
    _currentSession = null;
    _currentConfig = null;
    _sessionController.add(null);
    
    await _localStorage.clearSession();
    await _localStorage.clearConfig();
  }

  /// Validate session for closing
  Future<SessionValidationResult> _validateSessionForClosing(POSSession session) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check for draft orders
      final draftOrders = await _getDraftOrders(session);
      if (draftOrders.isNotEmpty) {
        errors.add('There are ${draftOrders.length} draft orders that must be completed');
      }

      // Check for unposted invoices
      final unpostedInvoices = await _getUnpostedInvoices(session);
      if (unpostedInvoices.isNotEmpty) {
        errors.add('There are ${unpostedInvoices.length} unposted invoices');
      }

      // Check session state
      if (!session.canClose) {
        errors.add('Session is not in a state that allows closing');
      }

      return SessionValidationResult(
        canClose: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      errors.add('Validation error: $e');
      return SessionValidationResult(
        canClose: false,
        errors: errors,
        warnings: warnings,
      );
    }
  }

  /// Get draft orders for session
  Future<List<POSOrder>> _getDraftOrders(POSSession session) async {
    try {
      final domain = [
        ['session_id', '=', session.id],
        ['state', '=', 'draft'],
      ];

      final orders = await _apiClient.searchRead('pos.order', domain: domain);
      return orders.map((order) => POSOrder.fromJson(order)).toList();
    } catch (e) {
      print('Error getting draft orders: $e');
      return [];
    }
  }

  /// Get unposted invoices for session
  Future<List<Map<String, dynamic>>> _getUnpostedInvoices(POSSession session) async {
    try {
      // This would query for unposted invoices related to the session
      // Implementation depends on specific invoice handling requirements
      return [];
    } catch (e) {
      print('Error getting unposted invoices: $e');
      return [];
    }
  }

  /// Helper methods
  Future<POSConfig> _getConfig(int configId) async {
    final config = await _apiClient.read('pos.config', configId);
    return POSConfig.fromJson(config);
  }

  Future<POSSession> _getSession(int sessionId) async {
    final session = await _apiClient.read('pos.session', sessionId);
    return POSSession.fromJson(session);
  }

  Future<POSSession?> _getLastSession(int configId) async {
    try {
      final domain = [
        ['config_id', '=', configId],
        ['state', '=', 'closed'],
      ];

      final sessions = await _apiClient.searchRead(
        'pos.session',
        domain: domain,
        order: 'id desc',
        limit: 1,
      );

      if (sessions.isNotEmpty) {
        return POSSession.fromJson(sessions.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> _getNextSessionCounter(String configName) async {
    // Implementation would get the next session counter from Odoo
    // For now, return a timestamp-based counter
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }

  Future<Map<String, dynamic>?> _getLastSessionInfo(int configId) async {
    final lastSession = await _getLastSession(configId);
    if (lastSession != null) {
      return {
        'id': lastSession.id,
        'name': lastSession.name,
        'stop_at': lastSession.stopAt?.toIso8601String(),
        'cash_register_balance_end_real': lastSession.cashRegisterBalanceEndReal,
      };
    }
    return null;
  }

  Future<bool> _userHasManagerRights(int userId) async {
    // Implementation would check user's POS manager rights
    return true; // Placeholder
  }

  Future<bool> _userCanCreateSession(int userId, int configId) async {
    // Implementation would check user's permissions for this config
    return true; // Placeholder
  }

  Future<bool> _userCanCloseSession(POSSession session) async {
    // Implementation would check user's permissions to close this session
    return true; // Placeholder
  }

  Future<double> _calculateTheoreticalBalance(POSSession session) async {
    // Implementation would calculate the theoretical cash balance
    // based on starting balance and cash transactions
    return session.cashRegisterBalanceStart; // Placeholder
  }

  Future<void> _recordCashDifference(POSSession session, double difference) async {
    // Implementation would record the cash difference in appropriate journal
    print('Cash difference recorded: $difference');
  }

  /// Dispose resources
  void dispose() {
    _sessionController.close();
  }
}

/// Data classes for session management

class SessionOpeningData {
  final double cashboxValue;
  final String? notes;

  SessionOpeningData({
    required this.cashboxValue,
    this.notes,
  });
}

class SessionClosingData {
  final double? cashRegisterBalanceEndReal;
  final String? closingNotes;
  final Map<String, double>? bankPaymentMethodDiffs;

  SessionClosingData({
    this.cashRegisterBalanceEndReal,
    this.closingNotes,
    this.bankPaymentMethodDiffs,
  });
}

class SessionStatusResult {
  final bool hasActiveSession;
  final POSSession? session;
  final bool canContinue;
  final bool canCreateSession;
  final Map<String, dynamic>? lastSessionInfo;

  SessionStatusResult({
    required this.hasActiveSession,
    this.session,
    this.canContinue = false,
    this.canCreateSession = false,
    this.lastSessionInfo,
  });
}

class SessionResult {
  final bool success;
  final POSSession? session;
  final SessionAction? action;
  final String? error;

  SessionResult({
    required this.success,
    this.session,
    this.action,
    this.error,
  });
}

class SessionCloseResult {
  final bool success;
  final POSSession? session;
  final List<String> errors;
  final List<String> warnings;
  final double cashDifference;
  final String? error;

  SessionCloseResult({
    required this.success,
    this.session,
    this.errors = const [],
    this.warnings = const [],
    this.cashDifference = 0.0,
    this.error,
  });
}

class SessionValidationResult {
  final bool canClose;
  final List<String> errors;
  final List<String> warnings;

  SessionValidationResult({
    required this.canClose,
    required this.errors,
    required this.warnings,
  });
}

enum SessionAction {
  created,
  continued,
}

class SessionException implements Exception {
  final String message;
  SessionException(this.message);
  
  @override
  String toString() => 'SessionException: $message';
}
