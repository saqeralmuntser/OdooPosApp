import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_pos_provider.dart';
import '../../providers/pos_provider.dart';

/// Backend Migration Helper
/// Provides utilities to migrate from the old POSProvider to the new EnhancedPOSProvider
/// This ensures a smooth transition while maintaining existing UI compatibility
class BackendMigration {
  
  /// Create a hybrid provider that can work with both old and new UI components
  static MultiProvider createHybridProvider({required Widget child}) {
    return MultiProvider(
      providers: [
        // Keep the old provider for backward compatibility
        ChangeNotifierProvider(create: (_) => POSProvider()),
        
        // Add the new enhanced provider
        ChangeNotifierProvider(create: (_) => EnhancedPOSProvider()),
        
        // Bridge provider that syncs data between old and new providers
        ChangeNotifierProxyProvider2<POSProvider, EnhancedPOSProvider, BridgeProvider>(
          create: (_) => BridgeProvider(),
          update: (_, oldProvider, newProvider, bridge) {
            bridge?.update(oldProvider, newProvider);
            return bridge!;
          },
        ),
      ],
      child: child,
    );
  }

  /// Initialize the enhanced backend
  static Future<void> initializeEnhancedBackend(BuildContext context) async {
    final enhancedProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    if (!enhancedProvider.isInitialized) {
      await enhancedProvider.initialize();
    }
  }

  /// Migrate data from old provider to new provider
  static Future<void> migrateData(POSProvider oldProvider, EnhancedPOSProvider newProvider) async {
    // This method can be used to migrate any existing data from the old provider
    // to the new provider if needed
    
    // For example, if there's a current order in the old provider,
    // we could recreate it in the new provider
    if (oldProvider.orderItems.isNotEmpty) {
      // Create order in new provider and add items
      // This would require converting old OrderItem to new ProductProduct
      print('Migrating ${oldProvider.orderItems.length} order items...');
      // Implementation would depend on specific migration needs
    }
  }

  /// Check if enhanced backend is available and ready
  static bool isEnhancedBackendReady(BuildContext context) {
    try {
      final enhancedProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      return enhancedProvider.isInitialized;
    } catch (e) {
      return false;
    }
  }
}

/// Bridge Provider
/// Synchronizes data between the old POSProvider and new EnhancedPOSProvider
/// This ensures UI compatibility during the transition period
class BridgeProvider with ChangeNotifier {
  POSProvider? _oldProvider;
  EnhancedPOSProvider? _newProvider;
  
  bool _useEnhancedBackend = false;
  
  bool get useEnhancedBackend => _useEnhancedBackend;
  
  void update(POSProvider oldProvider, EnhancedPOSProvider newProvider) {
    _oldProvider = oldProvider;
    _newProvider = newProvider;
    
    // Enable enhanced backend if it's ready
    if (newProvider.isInitialized && !_useEnhancedBackend) {
      _useEnhancedBackend = true;
      notifyListeners();
    }
  }
  
  /// Switch to enhanced backend
  void enableEnhancedBackend() {
    if (_newProvider?.isInitialized == true) {
      _useEnhancedBackend = true;
      notifyListeners();
    }
  }
  
  /// Switch back to legacy backend
  void disableEnhancedBackend() {
    _useEnhancedBackend = false;
    notifyListeners();
  }
  
  /// Get current provider based on mode
  ChangeNotifier? get currentProvider {
    if (_useEnhancedBackend && _newProvider != null) {
      return _newProvider;
    }
    return _oldProvider;
  }
}

/// Migration Aware Widget
/// A wrapper widget that can work with both old and new providers
/// This allows existing UI components to gradually migrate to the new backend
abstract class MigrationAwareWidget extends StatelessWidget {
  const MigrationAwareWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer<BridgeProvider>(
      builder: (context, bridge, child) {
        if (bridge.useEnhancedBackend) {
          return buildWithEnhancedProvider(context);
        } else {
          return buildWithLegacyProvider(context);
        }
      },
    );
  }
  
  /// Build widget using the enhanced provider
  Widget buildWithEnhancedProvider(BuildContext context);
  
  /// Build widget using the legacy provider
  Widget buildWithLegacyProvider(BuildContext context);
}

/// Enhanced Product Grid
/// Example of a migrated widget that uses the new backend
class EnhancedProductGrid extends MigrationAwareWidget {
  final Function(dynamic product)? onProductTap;
  
  const EnhancedProductGrid({
    super.key,
    this.onProductTap,
  });
  
  @override
  Widget buildWithEnhancedProvider(BuildContext context) {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, provider, child) {
        final products = provider.getFilteredProducts();
        
        if (products.isEmpty) {
          return const Center(
            child: Text('No products available'),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            
            return Card(
              elevation: 2,
              child: InkWell(
                onTap: () => onProductTap?.call(product),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.lstPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (product.qtyAvailable <= 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  @override
  Widget buildWithLegacyProvider(BuildContext context) {
    return Consumer<POSProvider>(
      builder: (context, provider, child) {
        final products = provider.getFilteredProducts();
        
        if (products.isEmpty) {
          return const Center(
            child: Text('No products available'),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            
            return Card(
              elevation: 2,
              child: InkWell(
                onTap: () => onProductTap?.call(product),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Backend Status Widget
/// Shows the current backend status and allows switching between backends
class BackendStatusWidget extends StatelessWidget {
  const BackendStatusWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<BridgeProvider, EnhancedPOSProvider>(
      builder: (context, bridge, enhanced, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bridge.useEnhancedBackend ? Colors.green[50] : Colors.orange[50],
            border: Border.all(
              color: bridge.useEnhancedBackend ? Colors.green : Colors.orange,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                bridge.useEnhancedBackend ? Icons.cloud_done : Icons.cloud_off,
                color: bridge.useEnhancedBackend ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bridge.useEnhancedBackend ? 'Enhanced Backend Active' : 'Legacy Backend Active',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      bridge.useEnhancedBackend 
                        ? 'Connected to Odoo 18 with full sync support'
                        : 'Using local mock data',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (enhanced.isConnected)
                      Text(
                        'Online • ${enhanced.statusMessage}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      )
                    else
                      const Text(
                        'Offline • Working with cached data',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
              if (enhanced.isInitialized && !bridge.useEnhancedBackend)
                ElevatedButton(
                  onPressed: () => bridge.enableEnhancedBackend(),
                  child: const Text('Switch to Enhanced'),
                )
              else if (bridge.useEnhancedBackend)
                TextButton(
                  onPressed: () => bridge.disableEnhancedBackend(),
                  child: const Text('Switch to Legacy'),
                ),
            ],
          ),
        );
      },
    );
  }
}
