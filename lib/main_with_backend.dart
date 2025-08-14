import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import existing screens
import 'screens/login_screen.dart';
import 'screens/pos_dashboard_screen.dart';
import 'screens/main_pos_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/customer_management_screen.dart';

// Import new backend components
import 'backend/providers/enhanced_pos_provider.dart';
import 'backend/migration/backend_migration.dart';
import 'backend/screens/enhanced_login_screen.dart';
import 'backend/screens/backend_config_screen.dart';

// Import theme
import 'theme/app_theme.dart';

void main() {
  runApp(const POSAppWithBackend());
}

class POSAppWithBackend extends StatelessWidget {
  const POSAppWithBackend({super.key});

  @override
  Widget build(BuildContext context) {
    return BackendMigration.createHybridProvider(
      child: MaterialApp(
        title: 'Flutter POS - Odoo 18 Enhanced',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/backend-config',
        routes: {
          '/backend-config': (context) => const BackendConfigScreen(),
          '/enhanced-login': (context) => const EnhancedLoginScreen(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const POSDashboardScreen(),
          '/pos': (context) => const MainPOSScreen(),
          '/payment': (context) => const PaymentScreen(),
          '/receipt': (context) => const ReceiptScreen(),
          '/customers': (context) => const CustomerManagementScreen(),
        },
      ),
    );
  }
}

/// Enhanced Login Screen
/// Integrates with the new Odoo 18 backend
class EnhancedLoginScreen extends StatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  State<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends State<EnhancedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeBackend();
  }

  Future<void> _initializeBackend() async {
    await BackendMigration.initializeEnhancedBackend(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Backend Status
                        const BackendStatusWidget(),
                        const SizedBox(height: 24),
                        
                        // Logo and title
                        Icon(
                          Icons.point_of_sale,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'POS System',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Powered by Odoo 18',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Login form
                        Consumer<EnhancedPOSProvider>(
                          builder: (context, provider, child) {
                            return Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                      prefixIcon: Icon(Icons.person),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your username';
                                      }
                                      return null;
                                    },
                                    enabled: !provider.isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock),
                                      border: OutlineInputBorder(),
                                    ),
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                    enabled: !provider.isLoading,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: provider.isLoading ? null : _login,
                                      child: provider.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text('Login'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (provider.statusMessage.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: provider.isAuthenticated 
                                          ? Colors.green[50] 
                                          : Colors.red[50],
                                        border: Border.all(
                                          color: provider.isAuthenticated 
                                            ? Colors.green 
                                            : Colors.red,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            provider.isAuthenticated 
                                              ? Icons.check_circle 
                                              : Icons.error,
                                            color: provider.isAuthenticated 
                                              ? Colors.green 
                                              : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              provider.statusMessage,
                                              style: TextStyle(
                                                color: provider.isAuthenticated 
                                                  ? Colors.green[800] 
                                                  : Colors.red[800],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/backend-config'),
                          child: const Text('Configure Server Connection'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    final success = await provider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// Backend Configuration Screen
/// Allows users to configure the Odoo server connection
class BackendConfigScreen extends StatefulWidget {
  const BackendConfigScreen({super.key});

  @override
  State<BackendConfigScreen> createState() => _BackendConfigScreenState();
}

class _BackendConfigScreenState extends State<BackendConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController(text: 'https://demo.odoo.com');
  final _databaseController = TextEditingController(text: 'demo');
  final _apiKeyController = TextEditingController();

  bool _useOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _initializeBackend();
  }

  Future<void> _initializeBackend() async {
    await BackendMigration.initializeEnhancedBackend(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Configuration'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Consumer<EnhancedPOSProvider>(
            builder: (context, provider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Backend Status
                  const BackendStatusWidget(),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Server Configuration',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _serverUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Server URL',
                              hintText: 'https://your-odoo-server.com',
                              prefixIcon: Icon(Icons.cloud),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!_useOfflineMode && (value == null || value.isEmpty)) {
                                return 'Please enter the server URL';
                              }
                              return null;
                            },
                            enabled: !_useOfflineMode && !provider.isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _databaseController,
                            decoration: const InputDecoration(
                              labelText: 'Database Name',
                              hintText: 'your_database',
                              prefixIcon: Icon(Icons.storage),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!_useOfflineMode && (value == null || value.isEmpty)) {
                                return 'Please enter the database name';
                              }
                              return null;
                            },
                            enabled: !_useOfflineMode && !provider.isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _apiKeyController,
                            decoration: const InputDecoration(
                              labelText: 'API Key (Optional)',
                              hintText: 'For Odoo Enterprise',
                              prefixIcon: Icon(Icons.key),
                              border: OutlineInputBorder(),
                            ),
                            enabled: !_useOfflineMode && !provider.isLoading,
                          ),
                          const SizedBox(height: 16),
                          
                          SwitchListTile(
                            title: const Text('Offline Mode'),
                            subtitle: const Text('Use cached data without server connection'),
                            value: _useOfflineMode,
                            onChanged: provider.isLoading ? null : (value) {
                              setState(() {
                                _useOfflineMode = value;
                              });
                            },
                          ),
                          
                          const Spacer(),
                          
                          if (provider.statusMessage.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: provider.isConnected 
                                  ? Colors.green[50] 
                                  : Colors.orange[50],
                                border: Border.all(
                                  color: provider.isConnected 
                                    ? Colors.green 
                                    : Colors.orange,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                provider.statusMessage,
                                style: TextStyle(
                                  color: provider.isConnected 
                                    ? Colors.green[800] 
                                    : Colors.orange[800],
                                ),
                              ),
                            ),
                          
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: provider.isLoading ? null : _testConnection,
                                  child: provider.isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Test Connection'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: provider.isLoading ? null : _saveAndContinue,
                                  child: const Text('Continue'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (_useOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline mode enabled - no connection test needed')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    final success = await provider.configureConnection(
      serverUrl: _serverUrlController.text.trim(),
      database: _databaseController.text.trim(),
      apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Connection successful!' : 'Connection failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_useOfflineMode) {
      if (!_formKey.currentState!.validate()) return;

      final provider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      
      await provider.configureConnection(
        serverUrl: _serverUrlController.text.trim(),
        database: _databaseController.text.trim(),
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
      );
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/enhanced-login');
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _databaseController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
}
