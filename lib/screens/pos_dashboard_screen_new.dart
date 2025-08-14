import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';
import '../models/pos_register.dart';
import '../theme/app_theme.dart';

class POSDashboardScreen extends StatelessWidget {
  const POSDashboardScreen({super.key});

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
        child: Consumer<POSProvider>(
          builder: (context, posProvider, _) {
            return CustomScrollView(
              slivers: [
                // Modern App Bar
                SliverAppBar(
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
                                    Icons.dashboard_outlined,
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
                                        'لوحة التحكم',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: _getTitleFontSize(isLargeScreen, isTablet, isSmallMobile),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'مرحباً، ${posProvider.currentUser ?? 'المستخدم'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: isSmallMobile ? 14 : 16,
                                          fontWeight: FontWeight.w500,
                                        ),
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
                                          _showLogoutDialog(context);
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
                ),

                // Statistics Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 16 : 24,
                      vertical: isSmallMobile ? 16 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إحصائيات سريعة',
                          style: TextStyle(
                            fontSize: _getSectionTitleSize(isLargeScreen, isTablet, isSmallMobile),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.blackColor,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 12 : 16),
                        _buildStatsRow(context, posProvider, isLargeScreen, isTablet, isSmallMobile),
                        SizedBox(height: isSmallMobile ? 24 : 32),

                        Text(
                          'اختر نقطة البيع',
                          style: TextStyle(
                            fontSize: _getSectionTitleSize(isLargeScreen, isTablet, isSmallMobile),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.blackColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'اختر نقطة البيع المناسبة لبدء معالجة الطلبات',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: isSmallMobile ? 14 : 16,
                          ),
                        ),
                        SizedBox(height: isSmallMobile ? 16 : 24),
                      ],
                    ),
                  ),
                ),

                // Registers Grid
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 16 : 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(screenSize.width),
                      childAspectRatio: _getChildAspectRatio(screenSize.width),
                      crossAxisSpacing: isSmallMobile ? 12 : 16,
                      mainAxisSpacing: isSmallMobile ? 12 : 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final register = posProvider.registers[index];
                        return ResponsiveRegisterCard(
                          register: register,
                          onPressed: () {
                            posProvider.selectRegister(register);
                            Navigator.of(context).pushNamed('/pos');
                          },
                        );
                      },
                      childCount: posProvider.registers.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 1;
  }

  double _getChildAspectRatio(double width) {
    if (width < 600) return 1.1;
    if (width < 900) return 1.2;
    return 1.3;
  }

  double _getTitleFontSize(bool isLargeScreen, bool isTablet, bool isSmallMobile) {
    if (isSmallMobile) return 20;
    if (isTablet) return 28;
    if (isLargeScreen) return 36;
    return 32;
  }

  double _getSectionTitleSize(bool isLargeScreen, bool isTablet, bool isSmallMobile) {
    if (isSmallMobile) return 18;
    if (isTablet) return 22;
    if (isLargeScreen) return 26;
    return 24;
  }

  Widget _buildStatsRow(BuildContext context, POSProvider posProvider, bool isLargeScreen, bool isTablet, bool isSmallMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = isSmallMobile ? 2 : 4;
        double childAspectRatio = isSmallMobile ? 1.1 : 1.5;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: isSmallMobile ? 12 : 16,
          mainAxisSpacing: isSmallMobile ? 12 : 16,
          children: [
            _buildStatCard(
              'إجمالي النقاط',
              '${posProvider.registers.length}',
              Icons.store_outlined,
              AppTheme.primaryColor,
            ),
            _buildStatCard(
              'نشطة',
              '${posProvider.registers.where((r) => r.status.toLowerCase() == 'open').length}',
              Icons.check_circle_outline,
              Colors.green,
            ),
            _buildStatCard(
              'في انتظار الإغلاق',
              '${posProvider.registers.where((r) => r.status.toLowerCase() == 'closing').length}',
              Icons.pending_outlined,
              Colors.orange,
            ),
            _buildStatCard(
              'المبيعات اليوم',
              'SR 0',
              Icons.trending_up_outlined,
              Colors.blue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 120;
        
        return Container(
          padding: EdgeInsets.all(isSmall ? 12 : 16),
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
                padding: EdgeInsets.all(isSmall ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon, 
                  color: color, 
                  size: isSmall ? 20 : 24,
                ),
              ),
              SizedBox(height: isSmall ? 6 : 8),
              FittedBox(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmall ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.blackColor,
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 2 : 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmall ? 10 : 12,
                  color: AppTheme.secondaryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
              onPressed: () {
                Provider.of<POSProvider>(context, listen: false).logout();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );
  }
}

class ResponsiveRegisterCard extends StatefulWidget {
  final POSRegister register;
  final VoidCallback onPressed;

  const ResponsiveRegisterCard({
    super.key,
    required this.register,
    required this.onPressed,
  });

  @override
  State<ResponsiveRegisterCard> createState() => _ResponsiveRegisterCardState();
}

class _ResponsiveRegisterCardState extends State<ResponsiveRegisterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    final statusColor = _getStatusColor(widget.register.status);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallCard = constraints.maxWidth < 200;
        final cardPadding = isSmallCard ? 16.0 : 20.0;
        
        return MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _animationController.forward();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _animationController.reverse();
          },
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        _isHovered ? statusColor.withOpacity(0.05) : Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.15 : 0.08),
                        blurRadius: _isHovered ? 20 : 10,
                        offset: Offset(0, _isHovered ? 8 : 4),
                      ),
                    ],
                    border: Border.all(
                      color: _isHovered ? statusColor.withOpacity(0.3) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isSmallCard ? 8 : 10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(widget.register.status),
                                    color: statusColor,
                                    size: isSmallCard ? 20 : 24,
                                  ),
                                ),
                                SizedBox(width: isSmallCard ? 8 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.register.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.blackColor,
                                          fontSize: isSmallCard ? 16 : 18,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallCard ? 6 : 8, 
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _getStatusText(widget.register.status),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: isSmallCard ? 9 : 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallCard ? 16 : 20),

                            // Details
                            Expanded(
                              child: Column(
                                children: [
                                  if (widget.register.closingDate != null)
                                    _buildInfoRow(
                                      Icons.schedule_outlined,
                                      'تاريخ الإغلاق',
                                      dateFormat.format(widget.register.closingDate!),
                                      isSmallCard,
                                    ),
                                  SizedBox(height: isSmallCard ? 8 : 12),
                                  _buildInfoRow(
                                    Icons.account_balance_wallet_outlined,
                                    'الرصيد الختامي',
                                    currencyFormat.format(widget.register.closingBalance),
                                    isSmallCard,
                                  ),
                                  const Spacer(),

                                  // Action button
                                  Container(
                                    width: double.infinity,
                                    height: isSmallCard ? 40 : 45,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [statusColor, statusColor.withOpacity(0.8)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: widget.onPressed,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: FittedBox(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.launch_outlined,
                                              size: isSmallCard ? 16 : 18,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: isSmallCard ? 6 : 8),
                                            Text(
                                              'فتح النقطة',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: isSmallCard ? 12 : 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isSmallCard) {
    return Row(
      children: [
        Icon(
          icon,
          size: isSmallCard ? 14 : 16,
          color: AppTheme.secondaryColor,
        ),
        SizedBox(width: isSmallCard ? 6 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallCard ? 9 : 11,
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallCard ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blackColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'opening control':
        return Colors.orange;
      case 'closing':
        return Colors.red;
      case 'open':
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'opening control':
        return Icons.hourglass_empty;
      case 'closing':
        return Icons.close_outlined;
      case 'open':
        return Icons.check_circle_outline;
      default:
        return Icons.store_outlined;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'opening control':
        return 'في انتظار الفتح';
      case 'closing':
        return 'جاري الإغلاق';
      case 'open':
        return 'مفتوحة';
      default:
        return status;
    }
  }
}
