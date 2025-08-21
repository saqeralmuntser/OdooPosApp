import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/models/product_product.dart';
import '../backend/models/product_combo.dart';
import '../theme/app_theme.dart';

/// Combo Selection Popup Widget
/// Allows users to select items from different combo sections (e.g., "Burgers Choice", "Drinks Choice")
/// Follows the JSON schema design specifications provided
class ComboSelectionPopup extends StatefulWidget {
  final ProductProduct product;
  final ProductCombo combo;
  final List<ComboSection> sections;
  final Function(ComboSelectionResult) onConfirm;
  final VoidCallback? onCancel;

  const ComboSelectionPopup({
    super.key,
    required this.product,
    required this.combo,
    required this.sections,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  State<ComboSelectionPopup> createState() => _ComboSelectionPopupState();
}

class _ComboSelectionPopupState extends State<ComboSelectionPopup> {
  final Map<String, ComboSectionItem?> _selectedItems = {};
  late List<ComboSection> _sections;

  @override
  void initState() {
    super.initState();
    _sections = List.from(widget.sections);
    
    // Initialize selected items map
    for (final section in _sections) {
      _selectedItems[section.groupName] = null;
    }
  }

  /// Check if all required selections are made
  bool get _isSelectionComplete {
    for (final section in _sections) {
      if (section.required && _selectedItems[section.groupName] == null) {
        return false;
      }
    }
    return true;
  }

  /// Calculate total extra price from selections
  double get _totalExtraPrice {
    double total = 0.0;
    for (final selectedItem in _selectedItems.values) {
      if (selectedItem != null) {
        total += selectedItem.extraPrice;
      }
    }
    return total;
  }

  /// Handle item selection in a section
  void _selectItem(String groupName, ComboSectionItem item) {
    setState(() {
      final section = _sections.firstWhere((s) => s.groupName == groupName);
      
      if (section.selectionType == 'single') {
        // Single selection - replace current selection
        _selectedItems[groupName] = item;
        
        // Update the section items to reflect selection
        final sectionIndex = _sections.indexWhere((s) => s.groupName == groupName);
        if (sectionIndex >= 0) {
          _sections[sectionIndex] = ComboSection(
            groupName: section.groupName,
            selectionType: section.selectionType,
            required: section.required,
            items: section.items.map((sectionItem) => 
              sectionItem.copyWith(isSelected: sectionItem.productId == item.productId)
            ).toList(),
          );
        }
      } else {
        // Multiple selection - toggle selection (future enhancement)
        // For now, treat as single selection
        _selectedItems[groupName] = item;
      }
    });
  }

  /// Handle confirmation
  void _handleConfirm() {
    if (!_isSelectionComplete) return;

    final result = ComboSelectionResult(
      combo: widget.combo,
      selectedItems: Map<String, ComboSectionItem>.fromEntries(
        _selectedItems.entries.where((entry) => entry.value != null).map(
          (entry) => MapEntry(entry.key, entry.value!)
        )
      ),
      totalExtraPrice: _totalExtraPrice,
      isComplete: _isSelectionComplete,
    );

    widget.onConfirm(result);
    Navigator.of(context).pop();
  }

  /// Handle cancel/discard
  void _handleCancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75, // تصغير العرض
        height: MediaQuery.of(context).size.height * 0.7, // تصغير الارتفاع
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16), // تقليل padding
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.combo.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18, // تصغير حجم العنوان
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _handleCancel,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20, // تصغير حجم الأيقونة
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16), // تقليل padding
                child: Column(
                  children: [
                    // Sections
                    Expanded(
                      child: ListView.builder(
                        itemCount: _sections.length,
                        itemBuilder: (context, index) {
                          final section = _sections[index];
                          return _buildSection(section);
                        },
                      ),
                    ),

                    // Selection status hint
                    if (!_isSelectionComplete) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // تقليل padding
                        margin: const EdgeInsets.only(bottom: 12), // تقليل المسافة
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6), // تصغير الزوايا
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange[700],
                              size: 16, // تصغير حجم الأيقونة
                            ),
                            const SizedBox(width: 6), // تقليل المسافة
                            Expanded(
                              child: Text(
                                'أكمل الاختيار للمتابعة',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 11, // تصغير حجم الخط
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12), // تقليل padding
                              side: BorderSide(color: Colors.grey.shade400),
                              foregroundColor: Colors.grey[700],
                            ),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(
                                fontSize: 12, // تصغير حجم الخط
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8), // تقليل المسافة
                        
                        // Add to order button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSelectionComplete ? _handleConfirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSelectionComplete 
                                  ? const Color(0xFF5D377B) 
                                  : Colors.grey.shade400,
                              padding: const EdgeInsets.symmetric(vertical: 12), // تقليل padding
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: _isSelectionComplete ? 2 : 0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'أضف للطلب',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12, // تصغير حجم الخط
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_totalExtraPrice > 0)
                                  Text(
                                    '+ ${currencyFormat.format(_totalExtraPrice)}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 9, // تصغير حجم الخط
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a combo section (e.g., "Burgers Choice", "Drinks Choice")
  Widget _buildSection(ComboSection section) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // تقليل أكثر في المسافة بين الأقسام
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Text(
                section.groupName,
                style: const TextStyle(
                  fontSize: 12, // تصغير أكثر في حجم العنوان
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              if (section.required) ...[
                const SizedBox(width: 6), // تقليل المسافة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // تقليل padding
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3), // تصغير الزوايا
                  ),
                  child: const Text(
                    'مطلوب',
                    style: TextStyle(
                      fontSize: 6, // تصغير أكثر في حجم الخط
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4), // تقليل أكثر في المسافة

          // Section items
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // 5 منتجات في كل صف
              childAspectRatio: 0.6, // تصغير أكثر في نسبة العرض إلى الارتفاع
              crossAxisSpacing: 4, // تقليل أكثر في المسافة بين العناصر
              mainAxisSpacing: 4, // تقليل أكثر في المسافة بين الصفوف
            ),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              final isSelected = _selectedItems[section.groupName]?.productId == item.productId;
              
              return GestureDetector(
                onTap: () => _selectItem(section.groupName, item),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4), // تقليل أكثر في padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item image
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: item.image != null && item.image!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      base64Decode(item.image!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.fastfood,
                                            size: 16, // تصغير أكثر للأيقونة
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.fastfood,
                                      size: 16, // تصغير أكثر للأيقونة
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 2), // تقليل أكثر في المسافة

                        // Item name
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 9, // تصغير أكثر في حجم الخط
                            color: isSelected ? AppTheme.primaryColor : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 0), // إزالة المسافة

                        // Extra price
                        Text(
                          item.extraPrice > 0 
                              ? '+ ${currencyFormat.format(item.extraPrice)}'
                              : 'مجاني',
                          style: TextStyle(
                            fontSize: 7, // تصغير أكثر في حجم الخط
                            color: item.extraPrice > 0 
                                ? Colors.orange[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Selection indicator
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4), // تقليل المسافة
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, // تقليل padding
                              vertical: 2, // تقليل padding
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8), // تصغير الزوايا
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 10, // تصغير حجم الأيقونة
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2), // تقليل المسافة
                                Text(
                                  'محدد',
                                  style: TextStyle(
                                    fontSize: 8, // تصغير حجم الخط
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
