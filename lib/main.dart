import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/pos_dashboard_screen.dart';
import 'screens/main_pos_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/customer_management_screen.dart';
import 'providers/pos_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => POSProvider()),
      ],
      child: MaterialApp(
        title: 'Flutter POS',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
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