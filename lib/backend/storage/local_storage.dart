import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local Storage Manager
/// Handles offline data storage using SQLite and SharedPreferences
/// Supports complex data structures and offline sync capabilities
class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;
  Database? _database;
  bool _isInitialized = false;

  /// Initialize storage systems
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _initializeDatabase();
    _isInitialized = true;
  }

  /// Initialize SQLite database
  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'pos_offline.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  /// Create database tables
  Future<void> _createTables(Database db, int version) async {
    // Configuration table
    await db.execute('''
      CREATE TABLE pos_config (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Session table
    await db.execute('''
      CREATE TABLE pos_session (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        template_id INTEGER,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        available_in_pos INTEGER NOT NULL,
        active INTEGER NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Product templates table
    await db.execute('''
      CREATE TABLE product_templates (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        list_price REAL NOT NULL,
        available_in_pos INTEGER NOT NULL,
        active INTEGER NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE pos_categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id INTEGER,
        sequence INTEGER,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        mobile TEXT,
        is_company INTEGER NOT NULL,
        active INTEGER NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE pos_orders (
        id INTEGER PRIMARY KEY,
        uuid TEXT UNIQUE NOT NULL,
        session_id INTEGER,
        partner_id INTEGER,
        amount_total REAL NOT NULL,
        amount_tax REAL NOT NULL,
        state TEXT NOT NULL,
        date_order TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Order lines table
    await db.execute('''
      CREATE TABLE pos_order_lines (
        id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        qty REAL NOT NULL,
        price_unit REAL NOT NULL,
        price_subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES pos_orders (id)
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE pos_payments (
        id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL,
        payment_method_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES pos_orders (id)
      )
    ''');

    // Payment methods table
    await db.execute('''
      CREATE TABLE pos_payment_methods (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        is_cash_count INTEGER NOT NULL,
        active INTEGER NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Taxes table
    await db.execute('''
      CREATE TABLE account_taxes (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_type TEXT NOT NULL,
        price_include INTEGER NOT NULL,
        active INTEGER NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Pending changes for sync
    await db.execute('''
      CREATE TABLE pending_changes (
        id TEXT PRIMARY KEY,
        model TEXT NOT NULL,
        method TEXT NOT NULL,
        args TEXT NOT NULL,
        kwargs TEXT,
        timestamp TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_available_in_pos ON products(available_in_pos)');
    await db.execute('CREATE INDEX idx_orders_session_id ON pos_orders(session_id)');
    await db.execute('CREATE INDEX idx_orders_synced ON pos_orders(synced)');
    await db.execute('CREATE INDEX idx_order_lines_order_id ON pos_order_lines(order_id)');
    await db.execute('CREATE INDEX idx_payments_order_id ON pos_payments(order_id)');
    await db.execute('CREATE INDEX idx_pending_changes_timestamp ON pending_changes(timestamp)');
  }

  /// Upgrade database tables
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < newVersion) {
      // Add migration logic for future versions
    }
  }

  /// Check if storage is initialized
  void _checkInitialized() {
    if (!_isInitialized) {
      throw Exception('LocalStorage not initialized. Call initialize() first.');
    }
  }

  // ===== SharedPreferences Methods =====

  /// Save credentials
  Future<void> saveCredentials(Map<String, dynamic> credentials) async {
    _checkInitialized();
    await _prefs!.setString('credentials', jsonEncode(credentials));
  }

  /// Get credentials
  Future<Map<String, dynamic>?> getCredentials() async {
    _checkInitialized();
    final credentialsString = _prefs!.getString('credentials');
    if (credentialsString != null) {
      return jsonDecode(credentialsString);
    }
    return null;
  }

  /// Clear credentials
  Future<void> clearCredentials() async {
    _checkInitialized();
    await _prefs!.remove('credentials');
  }

  /// Save session data
  Future<void> saveSession(Map<String, dynamic> session) async {
    _checkInitialized();
    await _prefs!.setString('current_session', jsonEncode(session));
    
    // Also save to database for complex queries
    await _database!.insert(
      'pos_session',
      {
        'id': session['id'],
        'data': jsonEncode(session),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get session data
  Future<Map<String, dynamic>?> getSession() async {
    _checkInitialized();
    final sessionString = _prefs!.getString('current_session');
    if (sessionString != null) {
      return jsonDecode(sessionString);
    }
    return null;
  }

  /// Clear session data
  Future<void> clearSession() async {
    _checkInitialized();
    await _prefs!.remove('current_session');
  }

  /// Save config data
  Future<void> saveConfig(Map<String, dynamic> config) async {
    _checkInitialized();
    await _prefs!.setString('current_config', jsonEncode(config));
    
    // Also save to database
    await _database!.insert(
      'pos_config',
      {
        'id': config['id'],
        'data': jsonEncode(config),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get config data
  Future<Map<String, dynamic>?> getConfig() async {
    _checkInitialized();
    final configString = _prefs!.getString('current_config');
    if (configString != null) {
      return jsonDecode(configString);
    }
    return null;
  }

  /// Clear config data
  Future<void> clearConfig() async {
    _checkInitialized();
    await _prefs!.remove('current_config');
  }

  // ===== Database Methods for Products =====

  /// Save products to local database
  Future<void> saveProducts(List<Map<String, dynamic>> products) async {
    _checkInitialized();
    final batch = _database!.batch();
    
    for (final product in products) {
      batch.insert(
        'products',
        {
          'id': product['id'],
          'template_id': product['product_tmpl_id'],
          'name': product['display_name'] ?? product['name'],
          'barcode': product['barcode'],
          'price': product['lst_price'] ?? 0.0,
          'cost': product['standard_price'] ?? 0.0,
          'available_in_pos': product['available_in_pos'] == true ? 1 : 0,
          'active': product['active'] == true ? 1 : 0,
          'data': jsonEncode(product),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  /// Get products from local database
  Future<List<Map<String, dynamic>>> getProducts({
    bool? availableInPos,
    String? searchTerm,
    List<int>? categoryIds,
  }) async {
    _checkInitialized();
    
    String where = 'active = 1';
    List<dynamic> whereArgs = [];
    
    if (availableInPos == true) {
      where += ' AND available_in_pos = 1';
    }
    
    if (searchTerm != null && searchTerm.isNotEmpty) {
      where += ' AND (name LIKE ? OR barcode LIKE ?)';
      whereArgs.addAll(['%$searchTerm%', '%$searchTerm%']);
    }
    
    final results = await _database!.query(
      'products',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );
    
    return results.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList();
  }

  /// Get product by ID
  Future<Map<String, dynamic>?> getProduct(int id) async {
    _checkInitialized();
    
    final results = await _database!.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return jsonDecode(results.first['data'] as String);
    }
    return null;
  }

  /// Get product by barcode
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    _checkInitialized();
    
    final results = await _database!.query(
      'products',
      where: 'barcode = ? AND active = 1',
      whereArgs: [barcode],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return jsonDecode(results.first['data'] as String);
    }
    return null;
  }

  // ===== Database Methods for Categories =====

  /// Save categories to local database
  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    _checkInitialized();
    final batch = _database!.batch();
    
    for (final category in categories) {
      batch.insert(
        'pos_categories',
        {
          'id': category['id'],
          'name': category['name'],
          'parent_id': category['parent_id'],
          'sequence': category['sequence'] ?? 0,
          'data': jsonEncode(category),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  /// Get categories from local database
  Future<List<Map<String, dynamic>>> getCategories() async {
    _checkInitialized();
    
    final results = await _database!.query(
      'pos_categories',
      orderBy: 'sequence ASC, name ASC',
    );
    
    return results.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList();
  }

  // ===== Database Methods for Customers =====

  /// Save customers to local database
  Future<void> saveCustomers(List<Map<String, dynamic>> customers) async {
    _checkInitialized();
    final batch = _database!.batch();
    
    for (final customer in customers) {
      batch.insert(
        'customers',
        {
          'id': customer['id'],
          'name': customer['name'],
          'email': customer['email'],
          'phone': customer['phone'],
          'mobile': customer['mobile'],
          'is_company': customer['is_company'] == true ? 1 : 0,
          'active': customer['active'] == true ? 1 : 0,
          'data': jsonEncode(customer),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  /// Get customers from local database
  Future<List<Map<String, dynamic>>> getCustomers({String? searchTerm}) async {
    _checkInitialized();
    
    String where = 'active = 1';
    List<dynamic> whereArgs = [];
    
    if (searchTerm != null && searchTerm.isNotEmpty) {
      where += ' AND (name LIKE ? OR email LIKE ? OR phone LIKE ? OR mobile LIKE ?)';
      whereArgs.addAll(['%$searchTerm%', '%$searchTerm%', '%$searchTerm%', '%$searchTerm%']);
    }
    
    final results = await _database!.query(
      'customers',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );
    
    return results.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList();
  }

  // ===== Database Methods for Orders =====

  /// Save order to local database
  Future<int> saveOrder(Map<String, dynamic> order) async {
    _checkInitialized();
    
    final orderId = await _database!.insert(
      'pos_orders',
      {
        'uuid': order['uuid'],
        'session_id': order['session_id'],
        'partner_id': order['partner_id'],
        'amount_total': order['amount_total'] ?? 0.0,
        'amount_tax': order['amount_tax'] ?? 0.0,
        'state': order['state'] ?? 'draft',
        'date_order': order['date_order'] ?? DateTime.now().toIso8601String(),
        'synced': 0,
        'data': jsonEncode(order),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    
    return orderId;
  }

  /// Update order in local database
  Future<void> updateOrder(int orderId, Map<String, dynamic> order) async {
    _checkInitialized();
    
    await _database!.update(
      'pos_orders',
      {
        'amount_total': order['amount_total'] ?? 0.0,
        'amount_tax': order['amount_tax'] ?? 0.0,
        'state': order['state'] ?? 'draft',
        'synced': 0,
        'data': jsonEncode(order),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Get orders from local database
  Future<List<Map<String, dynamic>>> getOrders({
    int? sessionId,
    String? state,
    bool? unsynced,
  }) async {
    _checkInitialized();
    
    String where = '1=1';
    List<dynamic> whereArgs = [];
    
    if (sessionId != null) {
      where += ' AND session_id = ?';
      whereArgs.add(sessionId);
    }
    
    if (state != null) {
      where += ' AND state = ?';
      whereArgs.add(state);
    }
    
    if (unsynced == true) {
      where += ' AND synced = 0';
    }
    
    final results = await _database!.query(
      'pos_orders',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date_order DESC',
    );
    
    return results.map((row) => {
      'local_id': row['id'],
      ...jsonDecode(row['data'] as String) as Map<String, dynamic>,
    }).toList();
  }

  /// Mark order as synced
  Future<void> markOrderSynced(int localId, int serverId) async {
    _checkInitialized();
    
    await _database!.update(
      'pos_orders',
      {'synced': 1, 'id': serverId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ===== Database Methods for Order Lines =====

  /// Save order line to local database
  Future<int> saveOrderLine(int orderId, Map<String, dynamic> orderLine) async {
    _checkInitialized();
    
    final lineId = await _database!.insert(
      'pos_order_lines',
      {
        'order_id': orderId,
        'product_id': orderLine['product_id'],
        'qty': orderLine['qty'] ?? 1.0,
        'price_unit': orderLine['price_unit'] ?? 0.0,
        'price_subtotal': orderLine['price_subtotal'] ?? 0.0,
        'discount': orderLine['discount'] ?? 0.0,
        'synced': 0,
        'data': jsonEncode(orderLine),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    
    return lineId;
  }

  /// Get order lines for an order
  Future<List<Map<String, dynamic>>> getOrderLines(int orderId) async {
    _checkInitialized();
    
    final results = await _database!.query(
      'pos_order_lines',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
    
    return results.map((row) => {
      'local_id': row['id'],
      ...jsonDecode(row['data'] as String) as Map<String, dynamic>,
    }).toList();
  }

  // ===== Database Methods for Payments =====

  /// Save payment to local database
  Future<int> savePayment(int orderId, Map<String, dynamic> payment) async {
    _checkInitialized();
    
    final paymentId = await _database!.insert(
      'pos_payments',
      {
        'order_id': orderId,
        'payment_method_id': payment['payment_method_id'],
        'amount': payment['amount'] ?? 0.0,
        'payment_date': payment['payment_date'] ?? DateTime.now().toIso8601String(),
        'synced': 0,
        'data': jsonEncode(payment),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    
    return paymentId;
  }

  /// Get payments for an order
  Future<List<Map<String, dynamic>>> getPayments(int orderId) async {
    _checkInitialized();
    
    final results = await _database!.query(
      'pos_payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'payment_date ASC',
    );
    
    return results.map((row) => {
      'local_id': row['id'],
      ...jsonDecode(row['data'] as String) as Map<String, dynamic>,
    }).toList();
  }

  // ===== Pending Changes for Sync =====

  /// Add pending change for sync
  Future<void> addPendingChange(Map<String, dynamic> change) async {
    _checkInitialized();
    
    await _database!.insert(
      'pending_changes',
      {
        'id': change['id'],
        'model': change['model'],
        'method': change['method'],
        'args': jsonEncode(change['args']),
        'kwargs': change['kwargs'] != null ? jsonEncode(change['kwargs']) : null,
        'timestamp': change['timestamp'],
        'retry_count': 0,
      },
    );
  }

  /// Get pending changes for sync
  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    _checkInitialized();
    
    final results = await _database!.query(
      'pending_changes',
      orderBy: 'timestamp ASC',
    );
    
    return results.map((row) => {
      'id': row['id'],
      'model': row['model'],
      'method': row['method'],
      'args': jsonDecode(row['args'] as String),
      'kwargs': row['kwargs'] != null ? jsonDecode(row['kwargs'] as String) : null,
      'timestamp': row['timestamp'],
      'retry_count': row['retry_count'],
    }).toList();
  }

  /// Remove pending change
  Future<void> removePendingChange(String changeId) async {
    _checkInitialized();
    
    await _database!.delete(
      'pending_changes',
      where: 'id = ?',
      whereArgs: [changeId],
    );
  }

  /// Update retry count for pending change
  Future<void> updatePendingChangeRetryCount(String changeId, int retryCount) async {
    _checkInitialized();
    
    await _database!.update(
      'pending_changes',
      {'retry_count': retryCount},
      where: 'id = ?',
      whereArgs: [changeId],
    );
  }

  // ===== Database Maintenance =====

  /// Clear all local data
  Future<void> clearAllData() async {
    _checkInitialized();
    
    final tables = [
      'pos_config', 'pos_session', 'products', 'product_templates',
      'pos_categories', 'customers', 'pos_orders', 'pos_order_lines',
      'pos_payments', 'pos_payment_methods', 'account_taxes', 'pending_changes'
    ];
    
    for (final table in tables) {
      await _database!.delete(table);
    }
  }

  /// Get database size
  Future<int> getDatabaseSize() async {
    _checkInitialized();
    
    final path = _database!.path;
    final file = await File(path).stat();
    return file.size;
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _isInitialized = false;
  }
}
