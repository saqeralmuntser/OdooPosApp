import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/login_screen.dart';
import 'screens/enhanced_pos_dashboard.dart';
import 'screens/main_pos_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/customer_management_screen.dart';
import 'screens/printer_management_screen.dart';

import 'backend/migration/backend_migration.dart';
import 'theme/app_theme.dart';

void main() {
  // تهيئة sqflite للـ desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BackendMigration.createHybridProvider(
      child: MaterialApp(
        title: 'Flutter POS - Enhanced',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/backend-config': (context) => const _BackendConfigScreenWrapper(),
          '/dashboard': (context) => const _DashboardWrapper(),
          '/main-pos': (context) => const MainPOSScreen(),
          '/payment': (context) => const PaymentScreen(),
          '/receipt': (context) => const ReceiptScreen(),
          '/customers': (context) => const CustomerManagementScreen(),
          '/printers': (context) => const PrinterManagementScreen(),
        },
      ),
    );
  }
}

/// Wrapper for Dashboard Screen
/// This decides which dashboard to show based on backend availability
class _DashboardWrapper extends StatelessWidget {
  const _DashboardWrapper();

  @override
  Widget build(BuildContext context) {
    return Consumer<BridgeProvider>(
      builder: (context, bridge, child) {
        // إذا كان Enhanced Backend متاح، استخدم الشاشة المحسنة
        if (bridge.useEnhancedBackend) {
          return const EnhancedPOSDashboard();
        } else {
          // استخدم الشاشة المحسنة للجميع
          return const EnhancedPOSDashboard();
        }
      },
    );
  }
}

/// Wrapper for Backend Config Screen
/// This is a simple wrapper that redirects to the enhanced backend configuration
class _BackendConfigScreenWrapper extends StatelessWidget {
  const _BackendConfigScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الخادم'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.settings_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              SizedBox(height: 24),
              Text(
                'إعدادات خادم Odoo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'للوصول إلى إعدادات الخادم المتقدمة، يرجى استخدام main_with_backend.dart',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'الإعدادات المحلية الموصى بها:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      SizedBox(height: 8),
                      Text('Server: http://localhost:8069'),
                      Text('Database: odoo18'),
                      Text('Username: admin'),
                      Text('Password: admin'),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Text(
                        'إعدادات التجريب عبر الإنترنت:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      SizedBox(height: 8),
                      Text('Server: https://demo.odoo.com'),
                      Text('Database: demo'),
                      Text('Username: admin'),
                      Text('Password: admin'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}