import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/services/hybrid_auth_service.dart';
import '../theme/app_theme.dart';

/// Connection Status Widget
/// Shows current authentication mode (Online/Offline) and allows mode switching
class ConnectionStatusWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const ConnectionStatusWidget({
    super.key,
    this.showDetails = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, provider, child) {
        final isAuthenticated = provider.isAuthenticated;
        
        if (!isAuthenticated) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(provider.currentAuthMode).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColor(provider.currentAuthMode).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(provider.currentAuthMode),
                  size: 16,
                  color: _getStatusColor(provider.currentAuthMode),
                ),
                if (showDetails) ...[
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(provider.currentAuthMode),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(provider.currentAuthMode),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(AuthMode mode) {
    switch (mode) {
      case AuthMode.online:
        return Colors.green;
      case AuthMode.offline:
        return Colors.orange;
      case AuthMode.failed:
        return Colors.red;
      case AuthMode.none:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(AuthMode mode) {
    switch (mode) {
      case AuthMode.online:
        return Icons.cloud_done;
      case AuthMode.offline:
        return Icons.cloud_off;
      case AuthMode.failed:
        return Icons.error;
      case AuthMode.none:
        return Icons.help_outline;
    }
  }

  String _getStatusText(AuthMode mode) {
    switch (mode) {
      case AuthMode.online:
        return 'أونلاين';
      case AuthMode.offline:
        return 'أوفلاين';
      case AuthMode.failed:
        return 'خطأ';
      case AuthMode.none:
        return 'غير متصل';
    }
  }
}

/// Detailed Connection Status Card
/// Shows more information about the current connection status
class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, provider, child) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      provider.isOnlineMode ? Icons.cloud_done : Icons.cloud_off,
                      color: provider.isOnlineMode ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حالة الاتصال',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            provider.isOnlineMode ? 'متصل - الوضع الأونلاين' : 'منفصل - الوضع الأوفلاين',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: provider.isOnlineMode ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // User info
                if (provider.currentUser != null) ...[
                  _buildInfoRow(
                    Icons.person,
                    'المستخدم',
                    provider.currentUser!,
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Status message
                if (provider.statusMessage.isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.info,
                    'الحالة',
                    provider.statusMessage,
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Connection details
                _buildInfoRow(
                  Icons.devices,
                  'النمط',
                  provider.isOnlineMode 
                    ? 'خادم Odoo (مزامنة فورية)'
                    : 'قاعدة بيانات محلية (سيتم المزامنة عند الاتصال)',
                ),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    if (!provider.isOnlineMode) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _attemptReconnect(context, provider),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('محاولة الاتصال'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showSyncDialog(context),
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(provider.isOnlineMode ? 'مزامنة' : 'عرض البيانات المعلقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.secondaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blackColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _attemptReconnect(BuildContext context, EnhancedPOSProvider provider) {
    // This would trigger a reconnection attempt
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري محاولة إعادة الاتصال...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    // TODO: Implement reconnection logic
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('المزامنة'),
          content: const Text('هل تريد بدء عملية المزامنة مع الخادم؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement sync logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم بدء عملية المزامنة...'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('مزامنة'),
            ),
          ],
        );
      },
    );
  }
}
