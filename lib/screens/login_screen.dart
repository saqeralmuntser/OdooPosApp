import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate login delay
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      final posProvider = Provider.of<POSProvider>(context, listen: false);
      posProvider.login(_emailController.text, _passwordController.text);
      
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }

    setState(() {
      _isLoading = false;
    });
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
                              SizedBox(height: isMobile ? 32 : 40),

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
        // Email field with enhanced styling
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          decoration: InputDecoration(
            labelText: 'البريد الإلكتروني',
            hintText: 'ادخل بريدك الإلكتروني',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.email_outlined,
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
              return 'الرجاء إدخال البريد الإلكتروني';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'الرجاء إدخال بريد إلكتروني صحيح';
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
            if (value.length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
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

        // Superuser login button
        OutlinedButton.icon(
          onPressed: () {
            _emailController.text = 'admin@example.com';
            _passwordController.text = 'admin123';
          },
          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
          label: Text(
            'دخول كمدير عام',
            style: TextStyle(fontSize: isMobile ? 14 : 15),
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

        // Sign up option
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
