import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/migration/backend_migration.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController(text: 'http://localhost:8069');
  final _databaseController = TextEditingController(text: 'odoo18');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  // إزالة خيار التبديل - النظام يستخدم النمط الهجين دائماً

  @override
  void initState() {
    super.initState();
    // تأجيل التهيئة حتى انتهاء عملية البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBackend();
    });
  }

  Future<void> _initializeBackend() async {
    try {
      await BackendMigration.initializeEnhancedBackend();
    } catch (e) {
      print('Error initializing backend: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في تهيئة النظام: $e';
        });
      }
    }
  }

  Future<void> _configureLocalOdoo() async {
    setState(() {
      // ملء الحقول بالإعدادات المحلية
      _serverUrlController.text = 'http://localhost:8069';
      _databaseController.text = 'odoo18';
      _usernameController.text = 'admin';
      _passwordController.text = '1';
      _errorMessage = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم ملء الحقول بإعدادات الخادم المحلي (admin/1)'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _configureDemo() async {
    setState(() {
      // ملء الحقول بإعدادات الخادم التجريبي
      _serverUrlController.text = 'https://demo.odoo.com';
      _databaseController.text = 'demo';
      _usernameController.text = 'admin';
      _passwordController.text = '1';
      _errorMessage = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم ملء الحقول بإعدادات الخادم التجريبي (admin/1)'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (_serverUrlController.text.isEmpty || _databaseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء رابط الخادم واسم قاعدة البيانات أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final enhancedProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      
      final success = await enhancedProvider.configureConnection(
        serverUrl: _serverUrlController.text.trim(),
        database: _databaseController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'الاتصال ناجح! ✅' : 'فشل في الاتصال ❌'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        
        if (!success) {
          setState(() {
            _errorMessage = enhancedProvider.statusMessage.isNotEmpty 
              ? enhancedProvider.statusMessage 
              : 'فشل في الاتصال بالخادم';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في اختبار الاتصال: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختبار الاتصال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Use Hybrid authentication (Online first, offline fallback)
      final enhancedProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      
      // Use hybrid login - automatically tries online first, falls back to offline
      final success = await enhancedProvider.loginHybrid(
        serverUrl: _serverUrlController.text.trim(),
        database: _databaseController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        // Show mode indicator
        final mode = enhancedProvider.isOnlineMode ? 'الأونلاين' : 'الأوفلاين';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسجيل الدخول بنجاح - الوضع: $mode'),
            backgroundColor: enhancedProvider.isOnlineMode ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else if (mounted) {
        setState(() {
          _errorMessage = enhancedProvider.statusMessage.isNotEmpty 
            ? enhancedProvider.statusMessage
            : 'فشل في تسجيل الدخول - تحقق من البيانات أو الاتصال';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في الاتصال: $e';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isMobile = screenSize.width < 480;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 24.0,
              vertical: 24.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 500 : (isMobile ? screenSize.width - 32 : 400),
                minHeight: screenSize.height - 48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top spacer for better centering
                    const Spacer(),
                    
                    // Main login card
                    Card(
                      elevation: 12,
                      shadowColor: AppTheme.primaryColor.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Logo section with better spacing
                              Container(
                                height: isMobile ? 70 : 90,
                                width: isMobile ? 180 : 220,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withOpacity(0.1),
                                      AppTheme.primaryColor.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.store,
                                        size: isMobile ? 28 : 32,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'نظام نقاط البيع',
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Welcome section with better typography
                              Text(
                                'مرحباً بك',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 24 : 28,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'الرجاء تسجيل الدخول للمتابعة',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.secondaryColor,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isMobile ? 16 : 20),

                              // Connection Status Info
                              Consumer<EnhancedPOSProvider>(
                                builder: (context, enhancedProvider, child) {
                                  return Card(
                                    color: Colors.blue[50],
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.cloud_sync,
                                                color: Colors.blue,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'نظام النقطة الذكي',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: AppTheme.blackColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'يعمل أونلاين مع Odoo أو أوفلاين بالبيانات المحلية',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (_serverUrlController.text.isNotEmpty && _databaseController.text.isNotEmpty)
                                                IconButton(
                                                  onPressed: _isLoading ? null : _testConnection,
                                                  icon: const Icon(Icons.wifi_find, size: 20),
                                                  tooltip: 'اختبار الاتصال',
                                                  color: Colors.orange,
                                                ),
                                            ],
                                          ),
                                          if (enhancedProvider.isInitialized) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey[300]!),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    enhancedProvider.isConnected ? Icons.check_circle : Icons.info,
                                                    size: 16,
                                                    color: enhancedProvider.isConnected ? Colors.green : Colors.orange,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      enhancedProvider.isConnected 
                                                        ? 'متصل بالخادم - سيتم المزامنة الفورية' 
                                                        : 'سيتم المحاولة أونلاين ثم الانتقال للوضع الأوفلاين',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: enhancedProvider.isConnected ? Colors.green[700] : Colors.orange[700],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: isMobile ? 16 : 20),

                              // Form fields with consistent spacing
                              _buildFormFields(isMobile),
                              
                              SizedBox(height: isMobile ? 24 : 32),

                              // Login button with better styling
                              _buildLoginButton(isMobile),
                              
                              SizedBox(height: isMobile ? 20 : 24),

                              // Additional options with better layout
                              _buildAdditionalOptions(isMobile),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom spacer for better centering
                    const Spacer(),
                    
                    // Footer
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'تم تطويره باستخدام Flutter',
                        style: TextStyle(
                          color: AppTheme.secondaryColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(bool isMobile) {
    return Column(
      children: [
        // Server Configuration Fields
          TextFormField(
            controller: _serverUrlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            decoration: InputDecoration(
              labelText: 'رابط الخادم',
              hintText: 'http://localhost:8069',
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dns_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال رابط الخادم';
              }
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'الرابط يجب أن يبدأ بـ http:// أو https://';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Database field
          TextFormField(
            controller: _databaseController,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            decoration: InputDecoration(
              labelText: 'اسم قاعدة البيانات',
              hintText: 'odoo18',
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storage_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال اسم قاعدة البيانات';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

        // Info message for hybrid system
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سيتم محاولة تسجيل الدخول أونلاين أولاً، ثم الانتقال للوضع الأوفلاين إذا لزم الأمر',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Username/Email field with enhanced styling
        TextFormField(
          controller: _usernameController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          decoration: InputDecoration(
            labelText: 'اسم المستخدم',
            hintText: 'ادخل اسم المستخدم',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isMobile ? 16 : 18,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال اسم المستخدم';
            }
            return null;
          },
        ),
        SizedBox(height: isMobile ? 16 : 20),

        // Password field with enhanced styling
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          onFieldSubmitted: (_) => _login(),
          decoration: InputDecoration(
              labelText: 'كلمة المرور',
              hintText: 'ادخل كلمة المرور',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppTheme.secondaryColor,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isMobile ? 16 : 18,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
            }
            // إزالة شرط طول كلمة المرور للسماح بأي كلمة مرور صحيحة في Odoo
            return null;
          },
        ),
        
        // Error message display (handled in the build method)
        _buildErrorMessage(),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(bool isMobile) {
    return Container(
      width: double.infinity,
      height: isMobile ? 50 : 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'تسجيل الدخول',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildAdditionalOptions(bool isMobile) {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: TextStyle(
                  color: AppTheme.secondaryColor,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.borderColor)),
          ],
        ),
        SizedBox(height: isMobile ? 16 : 20),

        // Quick setup buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _configureLocalOdoo,
                  icon: const Icon(Icons.computer, size: 16),
                  label: Text(
                    'خادم محلي',
                    style: TextStyle(fontSize: isMobile ? 12 : 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _configureDemo,
                  icon: const Icon(Icons.cloud_outlined, size: 16),
                  label: Text(
                    'خادم تجريبي',
                    style: TextStyle(fontSize: isMobile ? 12 : 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        SizedBox(height: isMobile ? 12 : 16),

        // Superuser login button
        OutlinedButton.icon(
          onPressed: () {
            // إذا لم تكن الحقول مملوءة، املأها بالقيم الافتراضية
            if (_serverUrlController.text.isEmpty) {
              _serverUrlController.text = 'http://localhost:8069';
            }
            if (_databaseController.text.isEmpty) {
              _databaseController.text = 'odoo18';
            }
            _usernameController.text = 'admin';
            _passwordController.text = '1';
          },
          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
          label: Text(
            'ملء بيانات المدير (admin/1)',
            style: TextStyle(fontSize: isMobile ? 13 : 14),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isMobile ? 12 : 14,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // Server configuration button for Odoo backend

          TextButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/backend-config');
            },
            icon: const Icon(Icons.settings, size: 16),
            label: Text(
              'إعدادات الخادم',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          ),
        
        // Sign up option for local system (placeholder)
        TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('وظيفة التسجيل غير متاحة حالياً'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
            child: Text(
              'ليس لديك حساب؟ سجل الآن',
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: isMobile ? 13 : 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}
