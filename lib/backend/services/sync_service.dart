import 'dart:async';
import 'dart:math';
import '../api/odoo_api_client.dart';
import '../storage/local_storage.dart';

/// Sync Service
/// Handles synchronization between local storage and Odoo server
/// Manages offline/online data consistency and conflict resolution
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OdooApiClient _apiClient = OdooApiClient();
  final LocalStorage _localStorage = LocalStorage();

  // Sync state
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 30);

  /// Sync status stream
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Initialize sync service
  Future<void> initialize() async {
    await _localStorage.initialize();
    
    // Listen for connection changes
    _apiClient.connectionStream.listen(_onConnectionChanged);
    _apiClient.authStream.listen(_onAuthChanged);
  }

  /// Start periodic sync
  void startPeriodicSync() {
    stopPeriodicSync();
    
    _periodicSyncTimer = Timer.periodic(_syncInterval, (_) {
      if (!_isSyncing) {
        syncPendingChanges();
      }
    });
    
    // Initial sync
    if (_apiClient.isConnected && _apiClient.isAuthenticated) {
      syncPendingChanges();
    }
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Handle connection changes
  void _onConnectionChanged(bool isConnected) {
    if (isConnected && _apiClient.isAuthenticated && !_isSyncing) {
      // Connection restored, sync pending changes
      syncPendingChanges();
    }
  }

  /// Handle authentication changes
  void _onAuthChanged(bool isAuthenticated) {
    if (isAuthenticated && _apiClient.isConnected && !_isSyncing) {
      // Authentication successful, sync pending changes
      syncPendingChanges();
    }
  }

  /// Sync all pending changes
  Future<SyncResult> syncPendingChanges() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }

    if (!_apiClient.isConnected || !_apiClient.isAuthenticated) {
      return SyncResult(
        success: false,
        error: 'Not connected or authenticated',
      );
    }

    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);

    try {
      final startTime = DateTime.now();
      
      // Get pending changes
      final pendingChanges = await _localStorage.getPendingChanges();
      
      if (pendingChanges.isEmpty) {
        _updateSyncStatus(SyncStatus.upToDate);
        return SyncResult(success: true, message: 'No pending changes');
      }

      int successCount = 0;
      int errorCount = 0;
      final errors = <String>[];

      // Process each pending change
      for (final change in pendingChanges) {
        try {
          await _processPendingChange(change);
          await _localStorage.removePendingChange(change['id']);
          successCount++;
        } catch (e) {
          errorCount++;
          errors.add('${change['model']}.${change['method']}: $e');
          
          // Update retry count
          final retryCount = (change['retry_count'] as int) + 1;
          if (retryCount < _maxRetryAttempts) {
            await _localStorage.updatePendingChangeRetryCount(change['id'], retryCount);
          } else {
            // Max retries reached, remove the change
            await _localStorage.removePendingChange(change['id']);
            print('Max retries reached for change ${change['id']}, removing');
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      
      if (errorCount == 0) {
        _updateSyncStatus(SyncStatus.upToDate);
        return SyncResult(
          success: true,
          message: 'Synced $successCount changes in ${duration.inSeconds}s',
          syncedCount: successCount,
        );
      } else {
        _updateSyncStatus(SyncStatus.error);
        return SyncResult(
          success: false,
          error: 'Sync completed with errors: ${errors.join(', ')}',
          syncedCount: successCount,
          errorCount: errorCount,
        );
      }
    } catch (e) {
      _updateSyncStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        error: 'Sync failed: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Process a single pending change
  Future<void> _processPendingChange(Map<String, dynamic> change) async {
    final method = change['method'] as String;
    final model = change['model'] as String;
    final args = change['args'] as List<dynamic>;
    final kwargs = change['kwargs'] as Map<String, dynamic>?;

    switch (method) {
      case 'create':
        await _syncCreate(model, args, kwargs);
        break;
      case 'write':
        await _syncWrite(model, args, kwargs);
        break;
      case 'unlink':
        await _syncUnlink(model, args, kwargs);
        break;
      default:
        await _apiClient.callMethod(model, method, args, kwargs);
    }
  }

  /// Sync create operation
  Future<void> _syncCreate(String model, List<dynamic> args, Map<String, dynamic>? kwargs) async {
    final values = args.first as Map<String, dynamic>;
    
    // Remove local ID if present
    final localId = values.remove('id');
    
    // Create on server
    final serverId = await _apiClient.create(model, values);
    
    // Update local references if needed
    if (localId != null && localId is int && localId < 0) {
      await _updateLocalReferences(model, localId, serverId);
    }
    
    print('Created $model with server ID: $serverId');
  }

  /// Sync write operation
  Future<void> _syncWrite(String model, List<dynamic> args, Map<String, dynamic>? kwargs) async {
    final ids = args[0] as List<int>;
    final values = args[1] as Map<String, dynamic>;
    
    // Filter out negative IDs (local only records)
    final serverIds = ids.where((id) => id > 0).toList();
    
    if (serverIds.isNotEmpty) {
      await _apiClient.write(model, serverIds.first, values);
      print('Updated $model IDs: $serverIds');
    }
  }

  /// Sync unlink operation
  Future<void> _syncUnlink(String model, List<dynamic> args, Map<String, dynamic>? kwargs) async {
    final ids = args.first as List<int>;
    
    // Filter out negative IDs (local only records)
    final serverIds = ids.where((id) => id > 0).toList();
    
    if (serverIds.isNotEmpty) {
      await _apiClient.unlink(model, serverIds);
      print('Deleted $model IDs: $serverIds');
    }
  }

  /// Update local references after sync
  Future<void> _updateLocalReferences(String model, int localId, int serverId) async {
    try {
      switch (model) {
        case 'pos.order':
          await _updateOrderReferences(localId, serverId);
          break;
        case 'res.partner':
          await _updateCustomerReferences(localId, serverId);
          break;
        // Add more models as needed
      }
    } catch (e) {
      print('Error updating local references: $e');
    }
  }

  /// Update order references
  Future<void> _updateOrderReferences(int localId, int serverId) async {
    // Mark order as synced
    await _localStorage.markOrderSynced(localId, serverId);
    
    // Update related order lines and payments
    // This would require more complex logic in a real implementation
  }

  /// Update customer references
  Future<void> _updateCustomerReferences(int localId, int serverId) async {
    // Update any orders that reference this customer
    // This would require updating the local database
  }

  /// Sync master data from server
  Future<MasterDataSyncResult> syncMasterData() async {
    if (!_apiClient.isConnected || !_apiClient.isAuthenticated) {
      return MasterDataSyncResult(
        success: false,
        error: 'Not connected or authenticated',
      );
    }

    _updateSyncStatus(SyncStatus.syncing);

    try {
      final startTime = DateTime.now();
      int updatedCount = 0;

      // Sync products
      final products = await _syncProducts();
      updatedCount += products;

      // Sync categories
      final categories = await _syncCategories();
      updatedCount += categories;

      // Sync customers
      final customers = await _syncCustomers();
      updatedCount += customers;

      // Sync payment methods
      final paymentMethods = await _syncPaymentMethods();
      updatedCount += paymentMethods;

      final duration = DateTime.now().difference(startTime);
      
      _updateSyncStatus(SyncStatus.upToDate);
      
      return MasterDataSyncResult(
        success: true,
        message: 'Updated $updatedCount records in ${duration.inSeconds}s',
        updatedCount: updatedCount,
      );
    } catch (e) {
      _updateSyncStatus(SyncStatus.error);
      return MasterDataSyncResult(
        success: false,
        error: 'Master data sync failed: $e',
      );
    }
  }

  /// Sync products from server
  Future<int> _syncProducts() async {
    try {
      final products = await _apiClient.searchRead(
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

      await _localStorage.saveProducts(products);
      return products.length;
    } catch (e) {
      print('Error syncing products: $e');
      return 0;
    }
  }

  /// Sync categories from server
  Future<int> _syncCategories() async {
    try {
      final categories = await _apiClient.searchRead(
        'pos.category',
        fields: ['id', 'name', 'parent_id', 'sequence', 'color', 'image_128'],
      );

      await _localStorage.saveCategories(categories);
      return categories.length;
    } catch (e) {
      print('Error syncing categories: $e');
      return 0;
    }
  }

  /// Sync customers from server
  Future<int> _syncCustomers() async {
    try {
      final customers = await _apiClient.searchRead(
        'res.partner',
        domain: [
          ['customer_rank', '>', 0],
          ['active', '=', true],
        ],
        fields: [
          'id', 'name', 'display_name', 'email', 'phone', 'mobile',
          'street', 'city', 'country_id', 'is_company', 'active'
        ],
        limit: 1000,
      );

      await _localStorage.saveCustomers(customers);
      return customers.length;
    } catch (e) {
      print('Error syncing customers: $e');
      return 0;
    }
  }

  /// Sync payment methods from server
  Future<int> _syncPaymentMethods() async {
    try {
      // Payment methods are typically loaded once and cached
      // They don't change frequently
      return 0;
    } catch (e) {
      print('Error syncing payment methods: $e');
      return 0;
    }
  }

  /// Force sync with conflict resolution
  Future<SyncResult> forceSyncWithConflictResolution() async {
    if (!_apiClient.isConnected || !_apiClient.isAuthenticated) {
      return SyncResult(
        success: false,
        error: 'Not connected or authenticated',
      );
    }

    _updateSyncStatus(SyncStatus.syncing);

    try {
      // First, sync master data
      await syncMasterData();

      // Then, sync pending changes with conflict resolution
      final pendingChanges = await _localStorage.getPendingChanges();
      
      for (final change in pendingChanges) {
        try {
          await _processPendingChangeWithConflictResolution(change);
          await _localStorage.removePendingChange(change['id']);
        } catch (e) {
          print('Error syncing change ${change['id']}: $e');
          // In case of conflict, prefer server data
          await _localStorage.removePendingChange(change['id']);
        }
      }

      _updateSyncStatus(SyncStatus.upToDate);
      
      return SyncResult(
        success: true,
        message: 'Force sync completed successfully',
      );
    } catch (e) {
      _updateSyncStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        error: 'Force sync failed: $e',
      );
    }
  }

  /// Process pending change with conflict resolution
  Future<void> _processPendingChangeWithConflictResolution(Map<String, dynamic> change) async {
    try {
      await _processPendingChange(change);
    } catch (e) {
      // If there's a conflict, try to resolve it
      final model = change['model'] as String;
      final method = change['method'] as String;
      
      if (method == 'write') {
        // For write operations, check if record still exists on server
        final args = change['args'] as List<dynamic>;
        final ids = args[0] as List<int>;
        final serverIds = ids.where((id) => id > 0).toList();
        
        if (serverIds.isNotEmpty) {
          try {
            await _apiClient.read(model, serverIds.first);
            // Record exists, conflict might be due to concurrent modification
            // Skip this change and use server data
            print('Conflict resolved by skipping local change for $model ${serverIds.first}');
          } catch (e) {
            // Record doesn't exist on server, might have been deleted
            print('Record $model ${serverIds.first} not found on server, skipping update');
          }
        }
      } else {
        // For other operations, just skip
        print('Skipping conflicted change: $model.$method');
      }
    }
  }

  /// Update sync status
  void _updateSyncStatus(SyncStatus status) {
    _syncStatusController.add(status);
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    try {
      final pendingChanges = await _localStorage.getPendingChanges();
      final databaseSize = await _localStorage.getDatabaseSize();
      
      return SyncStatistics(
        pendingChangesCount: pendingChanges.length,
        databaseSize: databaseSize,
        lastSyncTime: DateTime.now(), // This should be stored and retrieved
        isOnline: _apiClient.isConnected && _apiClient.isAuthenticated,
      );
    } catch (e) {
      return SyncStatistics(
        pendingChangesCount: 0,
        databaseSize: 0,
        lastSyncTime: null,
        isOnline: false,
      );
    }
  }

  /// Clear all local data and resync
  Future<SyncResult> resetAndResync() async {
    if (!_apiClient.isConnected || !_apiClient.isAuthenticated) {
      return SyncResult(
        success: false,
        error: 'Not connected or authenticated',
      );
    }

    try {
      _updateSyncStatus(SyncStatus.syncing);
      
      // Clear all local data
      await _localStorage.clearAllData();
      
      // Resync master data
      final result = await syncMasterData();
      
      if (result.success) {
        _updateSyncStatus(SyncStatus.upToDate);
        return SyncResult(
          success: true,
          message: 'Reset and resync completed successfully',
        );
      } else {
        _updateSyncStatus(SyncStatus.error);
        return SyncResult(
          success: false,
          error: 'Reset and resync failed: ${result.error}',
        );
      }
    } catch (e) {
      _updateSyncStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        error: 'Reset and resync failed: $e',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
    _syncStatusController.close();
  }
}

/// Sync status enumeration
enum SyncStatus {
  idle,
  syncing,
  upToDate,
  error,
  offline,
}

/// Extension for SyncStatus
extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.upToDate:
        return 'Up to date';
      case SyncStatus.error:
        return 'Sync error';
      case SyncStatus.offline:
        return 'Offline';
    }
  }

  String get iconCode {
    switch (this) {
      case SyncStatus.idle:
        return '⏸️';
      case SyncStatus.syncing:
        return '🔄';
      case SyncStatus.upToDate:
        return '✅';
      case SyncStatus.error:
        return '❌';
      case SyncStatus.offline:
        return '📴';
    }
  }
}

/// Data classes for sync results

class SyncResult {
  final bool success;
  final String? message;
  final String? error;
  final int syncedCount;
  final int errorCount;

  SyncResult({
    required this.success,
    this.message,
    this.error,
    this.syncedCount = 0,
    this.errorCount = 0,
  });
}

class MasterDataSyncResult {
  final bool success;
  final String? message;
  final String? error;
  final int updatedCount;

  MasterDataSyncResult({
    required this.success,
    this.message,
    this.error,
    this.updatedCount = 0,
  });
}

class SyncStatistics {
  final int pendingChangesCount;
  final int databaseSize;
  final DateTime? lastSyncTime;
  final bool isOnline;

  SyncStatistics({
    required this.pendingChangesCount,
    required this.databaseSize,
    this.lastSyncTime,
    required this.isOnline,
  });

  String get formattedDatabaseSize {
    if (databaseSize < 1024) return '${databaseSize}B';
    if (databaseSize < 1024 * 1024) return '${(databaseSize / 1024).toStringAsFixed(1)}KB';
    return '${(databaseSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
