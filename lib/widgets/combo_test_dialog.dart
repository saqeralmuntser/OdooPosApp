import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../theme/app_theme.dart';

/// Dialog for testing combo functionality
/// Provides options to create demo combo data and test combo features
class ComboTestDialog extends StatefulWidget {
  const ComboTestDialog({super.key});

  @override
  State<ComboTestDialog> createState() => _ComboTestDialogState();
}

class _ComboTestDialogState extends State<ComboTestDialog> {
  bool _isCreatingDemo = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedPOSProvider>(
      builder: (context, posProvider, _) {
        final combos = posProvider.combos;
        final comboItems = posProvider.comboItems;
        final products = posProvider.products;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.fastfood,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'اختبار وظيفة الكومبو',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Current status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الحالة الحالية:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('• عدد المنتجات: ${products.length}'),
                      Text('• عدد الكومبوهات: ${combos.length}'),
                      Text('• عدد عناصر الكومبو: ${comboItems.length}'),
                      Text('• منتجات كومبو متاحة: ${products.where((p) => posProvider.isComboProduct(p)).length}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                if (combos.isEmpty) ...[
                  const Text(
                    'لا توجد بيانات كومبو! قم بإنشاء بيانات تجريبية للاختبار:',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingDemo ? null : _createDemoCombo,
                      icon: _isCreatingDemo 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle),
                      label: Text(_isCreatingDemo ? 'جاري الإنشاء...' : 'إنشاء كومبو تجريبي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    '✅ تم العثور على بيانات كومبو! يمكنك الآن اختبار الوظيفة.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List combo products
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'منتجات الكومبو المتاحة:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...products
                            .where((p) => posProvider.isComboProduct(p))
                            .map((product) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.fastfood,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          product.displayName,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'COMBO',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                        if (products.where((p) => posProvider.isComboProduct(p)).isEmpty)
                          const Text(
                            'لا توجد منتجات كومبو مُعرفة حالياً',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نمط ربط الكومبو الحالي:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'نظام اكتشاف الكومبو الجديد:\n'
                        '• المنتجات التي لها combo_ids من Odoo تظهر كـ combo\n'
                        '• إذا لم توجد منتجات combo حقيقية، المنتج الأول يُستخدم للاختبار\n'
                        '• هذا يحاكي النظام الحقيقي في Odoo',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'كيفية الاختبار:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. إذا كان لديك منتجات combo حقيقية من Odoo، ستظهر بعلامة "COMBO"\n'
                        '2. إذا لم توجد، المنتج الأول سيُستخدم للاختبار\n'
                        '3. انقر على منتج الكومبو لفتح شاشة الاختيار\n'
                        '4. اختر العناصر من كل قسم حسب تصميم الكومبو\n'
                        '5. انقر "أضف للطلب" عند اكتمال الاختيار',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Create demo combo data
  Future<void> _createDemoCombo() async {
    setState(() {
      _isCreatingDemo = true;
    });

    try {
      final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      
      // Force creation of demo combo data through provider
      final success = await posProvider.createDemoCombos();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? '✅ تم إنشاء بيانات كومبو تجريبية بنجاح! المنتج الأول أصبح كومبو.'
            : '❌ فشل في إنشاء البيانات التجريبية'
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
      if (success) {
        // Close dialog after successful creation
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في إنشاء البيانات التجريبية: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingDemo = false;
        });
      }
    }
  }
}
