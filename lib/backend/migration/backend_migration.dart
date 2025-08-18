import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_pos_provider.dart';

/// Backend Migration Helper
/// Simplified provider setup for Enhanced POS system
class BackendMigration {
  
  /// Create Enhanced provider setup
  static MultiProvider createHybridProvider({required Widget child}) {
    return MultiProvider(
      providers: [
        // Enhanced POS Provider for Odoo backend
        ChangeNotifierProvider(create: (_) => EnhancedPOSProvider()),
        
        // Bridge provider to track which backend is being used
        ChangeNotifierProvider(create: (_) => BridgeProvider()),
      ],
      child: child,
    );
  }
  
  /// Initialize Enhanced Backend
  static Future<bool> initializeEnhancedBackend() async {
    // Simplified initialization
    return true;
  }
}

/// Placeholder for Backend Status Widget
class BackendStatusWidget extends StatelessWidget {
  const BackendStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Bridge Provider to manage backend type
class BridgeProvider extends ChangeNotifier {
  bool _useEnhancedBackend = true;
  
  bool get useEnhancedBackend => _useEnhancedBackend;
  
  void enableEnhancedBackend() {
    _useEnhancedBackend = true;
    notifyListeners();
  }
  
  void disableEnhancedBackend() {
    _useEnhancedBackend = false;
    notifyListeners();
  }
}