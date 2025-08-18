import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/models/pos_session.dart';
import '../widgets/pos_config_card.dart';
import '../widgets/connection_status_widget.dart';
import '../theme/app_theme.dart';

/// Enhanced POS Dashboard Screen
/// Integrates with Odoo 18 backend for real POS configurations and session management
class EnhancedPOSDashboard extends StatefulWidget {
  const EnhancedPOSDashboard({super.key});

  @override
  State<EnhancedPOSDashboard> createState() => _EnhancedPOSDashboardState();
}

class _EnhancedPOSDashboardState extends State<EnhancedPOSDashboard> {
  @override
  void initState() {
    super.initState();
    // تحديث البيانات عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    try {
      // إعادة تحميل نقاط البيع من الخادم
      await provider.reloadConfigurations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث البيانات بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 1200;
    final isTablet = screenSize.width > 800 && screenSize.width <= 1200;
    final isMobile = screenSize.width <= 800;
    final isSmallMobile = screenSize.width < 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<EnhancedPOSProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                // Modern App Bar with User Info
                _buildAppBar(context, provider, isSmallMobile, isMobile),

                // Connection Status
                _buildConnectionStatus(context, provider, isSmallMobile),

                // Statistics Section
                _buildStatisticsSection(context, provider, isLargeScreen, isTablet, isSmallMobile),

                // POS Configurations Section
                _buildPOSConfigsSection(context, provider, isLargeScreen, isTablet, isSmallMobile),

                // POS Configurations Grid
                _buildPOSConfigsGrid(context, provider, isLargeScreen, isTablet, isSmallMobile),

                // Current Session Info (if any)
                _buildCurrentSessionSection(context, provider, isSmallMobile),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, EnhancedPOSProvider provider, bool isSmallMobile, bool isMobile) {
    return SliverAppBar(
      expandedHeight: isSmallMobile ? 140 : (isMobile ? 160 : 180),
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.point_of_sale,
                        color: Colors.white,
                        size: isSmallMobile ? 24 : 32,
                      ),
                    ),
                    SizedBox(width: isSmallMobile ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة نقاط البيع',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallMobile ? 20 : 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'مرحباً، ${provider.currentUser ?? 'المستخدم'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: isSmallMobile ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ConnectionStatusWidget(
                                  showDetails: !isSmallMobile,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // User Menu
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'logout':
                              _showLogoutDialog(context, provider);
                              break;
                            case 'refresh':
                              _refreshData();
                              break;
                          }
                        },
                        icon: const Icon(
                          Icons.account_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Row(
                              children: [
                                Icon(Icons.refresh, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('تحديث البيانات'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, color: Colors.red),
                                SizedBox(width: 8),
                                Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, EnhancedPOSProvider provider, bool isSmallMobile) {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(isSmallMobile ? 16 : 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: provider.isConnected ? Colors.green[50] : Colors.orange[50],
          border: Border.all(
            color: provider.isConnected ? Colors.green : Colors.orange,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              provider.isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: provider.isConnected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isConnected ? 'متصل بخادم Odoo' : 'غير متصل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: provider.isConnected ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                  if (provider.statusMessage.isNotEmpty)
                    Text(
                      provider.statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.isConnected ? Colors.green[600] : Colors.orange[600],
                      ),
                    ),
                ],
              ),
            ),
            if (provider.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context, EnhancedPOSProvider provider, 
      bool isLargeScreen, bool isTablet, bool isSmallMobile) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallMobile ? 16 : 24,
          vertical: isSmallMobile ? 8 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إحصائيات سريعة',
              style: TextStyle(
                fontSize: isSmallMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.blackColor,
              ),
            ),
            SizedBox(height: isSmallMobile ? 12 : 16),
            _buildStatsGrid(context, provider, isSmallMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, EnhancedPOSProvider provider, bool isSmallMobile) {
    final configs = provider.availableConfigs;
    final hasActiveSession = provider.hasActiveSession;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallMobile ? 2 : 4,
      childAspectRatio: isSmallMobile ? 1.1 : 1.5,
      crossAxisSpacing: isSmallMobile ? 12 : 16,
      mainAxisSpacing: isSmallMobile ? 12 : 16,
      children: [
        _buildStatCard(
          'نقاط البيع',
          '${configs.length}',
          Icons.store_outlined,
          AppTheme.primaryColor,
        ),
        _buildStatCard(
          'جلسة نشطة',
          hasActiveSession ? '1' : '0',
          Icons.play_circle_outline,
          hasActiveSession ? Colors.green : Colors.grey,
        ),
        _buildStatCard(
          'حالة الاتصال',
          provider.isConnected ? 'متصل' : 'منقطع',
          provider.isConnected ? Icons.wifi : Icons.wifi_off,
          provider.isConnected ? Colors.green : Colors.red,
        ),
        _buildStatCard(
          'آخر تحديث',
          DateFormat('HH:mm').format(DateTime.now()),
          Icons.access_time,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.blackColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPOSConfigsSection(BuildContext context, EnhancedPOSProvider provider,
      bool isLargeScreen, bool isTablet, bool isSmallMobile) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'نقاط البيع المتاحة',
                    style: TextStyle(
                      fontSize: isSmallMobile ? 18 : 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.blackColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث البيانات',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اختر نقطة البيع لبدء جلسة عمل جديدة أو متابعة الجلسة الحالية',
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: isSmallMobile ? 14 : 16,
              ),
            ),
            SizedBox(height: isSmallMobile ? 16 : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPOSConfigsGrid(BuildContext context, EnhancedPOSProvider provider,
      bool isLargeScreen, bool isTablet, bool isSmallMobile) {
    final configs = provider.availableConfigs;
    
    if (configs.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isSmallMobile ? 16 : 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.store_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد نقاط بيع متاحة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Consumer<EnhancedPOSProvider>(
                builder: (context, provider, _) {
                  return Text(
                    provider.isConnected 
                      ? 'لا توجد نقاط بيع مفعلة في خادم Odoo' 
                      : 'تأكد من الاتصال بخادم Odoo',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 16 : 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(MediaQuery.of(context).size.width),
          childAspectRatio: _getChildAspectRatio(MediaQuery.of(context).size.width),
          crossAxisSpacing: isSmallMobile ? 12 : 16,
          mainAxisSpacing: isSmallMobile ? 12 : 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final config = configs[index];
            return POSConfigCard(
              config: config,
              isSelected: config.id == provider.selectedConfig?.id,
            );
          },
          childCount: configs.length,
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width > 1400) return 3;
    if (width > 900) return 2;
    return 1;
  }

  double _getChildAspectRatio(double width) {
    if (width < 600) return 0.85; // أطول للشاشات الصغيرة
    if (width < 900) return 0.9; // متوسط
    return 1.0; // أعرض للشاشات الكبيرة
  }

  Widget _buildCurrentSessionSection(BuildContext context, EnhancedPOSProvider provider, bool isSmallMobile) {
    if (!provider.hasActiveSession) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final session = provider.currentSession!;
    
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(isSmallMobile ? 16 : 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          border: Border.all(color: Colors.green),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'الجلسة النشطة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showCloseSessionDialog(context, provider),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('إنهاء الجلسة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSessionInfo(session),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/main-pos');
                },
                icon: const Icon(Icons.point_of_sale),
                label: const Text('الانتقال إلى نقطة البيع'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfo(POSSession session) {
    return Column(
      children: [
        _buildInfoRow('رقم الجلسة:', session.name),
        if (session.startAt != null)
          _buildInfoRow('تاريخ البداية:', DateFormat('dd/MM/yyyy HH:mm').format(session.startAt!)),
        _buildInfoRow('رصيد البداية:', 'SR ${session.cashRegisterBalanceStart.toStringAsFixed(2)}'),
        _buildInfoRow('الحالة:', session.isOpen ? 'مفتوحة' : 'مغلقة'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.blackColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, EnhancedPOSProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                await provider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseSessionDialog(BuildContext context, EnhancedPOSProvider provider) {
    final cashBalanceController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إنهاء الجلسة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تريد إنهاء الجلسة الحالية؟'),
              const SizedBox(height: 16),
              TextField(
                controller: cashBalanceController,
                decoration: const InputDecoration(
                  labelText: 'رصيد النقد الختامي',
                  border: OutlineInputBorder(),
                  prefixText: 'SR ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cashBalance = double.tryParse(cashBalanceController.text);
                final success = await provider.closeSession(
                  cashBalance: cashBalance,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'تم إنهاء الجلسة بنجاح' : 'فشل في إنهاء الجلسة'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('إنهاء الجلسة'),
            ),
          ],
        );
      },
    );
  }
}
