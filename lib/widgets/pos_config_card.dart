import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/models/pos_config.dart';
import '../backend/services/session_manager.dart';
import '../theme/app_theme.dart';

/// POS Configuration Card Widget
/// Displays POS configuration with session management capabilities
class POSConfigCard extends StatefulWidget {
  final POSConfig config;
  final bool isSelected;
  final VoidCallback? onTap;

  const POSConfigCard({
    super.key,
    required this.config,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<POSConfigCard> createState() => _POSConfigCardState();
}

class _POSConfigCardState extends State<POSConfigCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  SessionStatusResult? _sessionStatus;
  bool _isCheckingSession = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Check for existing session when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }



  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Check if there's an existing session for this config
  Future<void> _checkExistingSession() async {
    if (_isCheckingSession) return;
    
    setState(() {
      _isCheckingSession = true;
    });

    try {
      final provider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      final sessionStatus = await provider.checkExistingSession(widget.config.id);
      
      if (mounted) {
        setState(() {
          _sessionStatus = sessionStatus;
          _isCheckingSession = false;
        });
        
        // Show feedback to user
        if (sessionStatus?.hasActiveSession == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم العثور على جلسة موجودة: ${sessionStatus!.session!.name}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد جلسات مفتوحة لهذه النقطة'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحقق من الجلسات: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('Error checking existing session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, provider, child) {
        final isActive = widget.config.id == provider.selectedConfig?.id;
        final hasActiveSession = provider.hasActiveSession && isActive;
        
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
                        isActive 
                          ? Colors.green.withOpacity(0.05)
                          : _isHovered 
                            ? AppTheme.primaryColor.withOpacity(0.03)
                            : Colors.white,
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
                      color: isActive 
                        ? Colors.green.withOpacity(0.5)
                        : _isHovered 
                          ? AppTheme.primaryColor.withOpacity(0.3) 
                          : Colors.grey.withOpacity(0.2),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap ?? () => _handleConfigTap(context, provider),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isActive 
                                      ? Colors.green.withOpacity(0.1)
                                      : AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isActive ? Icons.check_circle : Icons.point_of_sale,
                                    color: isActive ? Colors.green : AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.config.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.blackColor,
                                          fontSize: 18,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor().withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _getStatusText(hasActiveSession),
                                          style: TextStyle(
                                            color: _getStatusColor(),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Configuration Details
                                        _buildDetailRow(
              Icons.store_outlined,
              'نوع النقطة',
              (widget.config.modulePosRestaurant ?? false) ? 'مطعم' : 'نقطة بيع',
            ),
                            const SizedBox(height: 12),
                            
                            // Currency info is always available
                              _buildDetailRow(
                                Icons.attach_money,
                                'العملة',
                                'العملة الافتراضية', // يمكن تحسينها لاحقاً لعرض اسم العملة الفعلي
                              ),
                            const SizedBox(height: 12),

                                        _buildDetailRow(
              Icons.receipt_outlined,
              'تحكم النقد',
              (widget.config.cashControl ?? false) ? 'مفعل' : 'معطل',
            ),
                            
                            const SizedBox(height: 20),

                            // Session Status Check Button (if config is selected)
                            if (isActive) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isCheckingSession 
                                        ? null 
                                        : () => _checkExistingSession(),
                                      icon: _isCheckingSession
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.refresh, size: 16),
                                      label: Text(_isCheckingSession 
                                        ? 'جاري التحقق...' 
                                        : 'تحقق من الجلسات'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.secondaryColor,
                                        side: BorderSide(color: AppTheme.secondaryColor.withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Existing Session Indicator
                              if (_sessionStatus?.hasActiveSession == true) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'جلسة موجودة',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],

                            // Action Buttons
                            if (hasActiveSession) ...[
                              // الجلسة نشطة - يمكن الذهاب للنقطة أو إنهاء الجلسة
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed('/main-pos');
                                      },
                                      icon: const Icon(Icons.play_arrow, size: 18),
                                      label: const Text('فتح النقطة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _showCloseSessionDialog(context, provider),
                                    child: const Icon(Icons.stop, size: 18),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isActive) ...[
                              // النقطة محددة - تحقق من وجود جلسة موجودة
                              if (_sessionStatus?.hasActiveSession == true) ...[
                                // يوجد جلسة موجودة - يمكن استكمالها أو إغلاقها
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: provider.isLoading || _isCheckingSession
                                          ? null 
                                          : () async {
                                              final success = await provider.completeExistingSession(widget.config.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(success ? 'تم استكمال الجلسة بنجاح' : 'فشل في استكمال الجلسة'),
                                                    backgroundColor: success ? Colors.green : Colors.red,
                                                  ),
                                                );
                                                if (success) {
                                                  await Future.delayed(const Duration(milliseconds: 200));
                                                  Navigator.of(context).pushNamed('/main-pos');
                                                }
                                              }
                                            },
                                        icon: provider.isLoading || _isCheckingSession
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.play_arrow, size: 18),
                                        label: Text(_isCheckingSession 
                                          ? 'جاري التحقق...' 
                                          : 'استكمال الجلسة'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: provider.isLoading || _isCheckingSession
                                        ? null 
                                        : () => _showCloseExistingSessionDialog(context, provider),
                                      child: const Icon(Icons.stop, size: 18),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.all(14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: provider.isLoading 
                                      ? null 
                                      : () => _showOpenSessionDialog(context, provider),
                                    icon: const Icon(Icons.play_circle_outline, size: 18),
                                    label: const Text('فتح جلسة جديدة'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // لا توجد جلسة موجودة - يمكن فتح جلسة جديدة
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: provider.isLoading 
                                      ? null 
                                      : () => _showOpenSessionDialog(context, provider),
                                    icon: provider.isLoading 
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.play_circle_outline, size: 18),
                                    label: const Text('فتح جلسة جديدة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              // النقطة غير محددة - يمكن تحديدها
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectConfig(context, provider),
                                  icon: const Icon(Icons.radio_button_unchecked, size: 18),
                                  label: const Text('اختيار هذه النقطة'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
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
                  fontSize: 11,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (widget.config.id == Provider.of<EnhancedPOSProvider>(context, listen: false).selectedConfig?.id) {
      final hasSession = Provider.of<EnhancedPOSProvider>(context, listen: false).hasActiveSession;
      return hasSession ? Colors.green : Colors.orange;
    }
    return Colors.grey;
  }

  String _getStatusText(bool hasActiveSession) {
    if (widget.config.id == Provider.of<EnhancedPOSProvider>(context, listen: false).selectedConfig?.id) {
      return hasActiveSession ? 'جلسة نشطة' : 'محددة';
    }
    return 'متاحة';
  }

  void _handleConfigTap(BuildContext context, EnhancedPOSProvider provider) {
    if (!provider.hasActiveSession) {
      _selectConfig(context, provider);
    }
  }

  void _selectConfig(BuildContext context, EnhancedPOSProvider provider) {
    provider.selectConfig(widget.config);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم اختيار نقطة البيع: ${widget.config.name}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showOpenSessionDialog(BuildContext context, EnhancedPOSProvider provider) {
    final cashBalanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('فتح جلسة جديدة - ${widget.config.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تريد فتح جلسة عمل جديدة لهذه النقطة؟'),
              const SizedBox(height: 16),
              TextField(
                controller: cashBalanceController,
                decoration: const InputDecoration(
                  labelText: 'رصيد النقد الابتدائي',
                  border: OutlineInputBorder(),
                  prefixText: 'SR ',
                  hintText: '0.00',
                ),
                keyboardType: TextInputType.number,
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
                final cashBalance = double.tryParse(cashBalanceController.text) ?? 0.0;
                
                final success = await provider.openSession(
                  openingData: SessionOpeningData(
                    cashboxValue: cashBalance,
                  ),
                );
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'تم فتح الجلسة بنجاح' : 'فشل في فتح الجلسة'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  
                  if (success) {
                    // انتقال تلقائي لنقطة البيع بعد فتح الجلسة
                    Navigator.of(context).pushNamed('/main-pos');
                  }
                }
              },
              child: const Text('فتح الجلسة'),
            ),
          ],
        );
      },
    );
  }

  void _showCompleteSessionDialog(BuildContext context, EnhancedPOSProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('استكمال الجلسة الموجودة - ${widget.config.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('يوجد جلسة مفتوحة مسبقاً لهذه النقطة. هل تريد استكمالها؟'),
              const SizedBox(height: 16),
              if (_sessionStatus?.session != null) ...[
                Text('الجلسة: ${_sessionStatus!.session!.name}'),
                Text('تاريخ البداية: ${_sessionStatus!.session!.startAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(_sessionStatus!.session!.startAt!) : 'غير محدد'}'),
                const SizedBox(height: 16),
              ],
              const Text('سيتم تحميل جميع البيانات والانتقال لنقطة البيع مباشرة.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                final success = await provider.completeExistingSession(widget.config.id);
                
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم استكمال الجلسة بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Wait a bit for the session state to be fully updated
                    await Future.delayed(const Duration(milliseconds: 300));
                    
                    // الانتقال التلقائي لنقطة البيع
                    Navigator.of(context).pushNamed('/main-pos');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('فشل في استكمال الجلسة'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('استكمال الجلسة'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseExistingSessionDialog(BuildContext context, EnhancedPOSProvider provider) {
    final cashBalanceController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('إغلاق الجلسة الموجودة - ${widget.config.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تريد إغلاق الجلسة المفتوحة مسبقاً؟'),
              const SizedBox(height: 16),
              if (_sessionStatus?.session != null) ...[
                Text('الجلسة: ${_sessionStatus!.session!.name}'),
                Text('تاريخ البداية: ${_sessionStatus!.session!.startAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(_sessionStatus!.session!.startAt!) : 'غير محدد'}'),
                const SizedBox(height: 16),
              ],
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
                final notes = notesController.text.isEmpty ? null : notesController.text;
                
                Navigator.of(context).pop();
                
                final success = await provider.closeExistingSession(
                  widget.config.id,
                  cashBalance: cashBalance,
                  notes: notes,
                );
                
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إغلاق الجلسة بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // تحديث حالة الجلسة
                    _checkExistingSession();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('فشل في إغلاق الجلسة'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إغلاق الجلسة'),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إنهاء الجلسة'),
            ),
          ],
        );
      },
    );
  }
}
