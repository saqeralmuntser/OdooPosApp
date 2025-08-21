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
        width: MediaQuery.of(context).size.width * 0.65, // تصغير أكثر
        height: MediaQuery.of(context).size.height * 0.6, // تصغير أكثر
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // زوايا أكثر انسيابية
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with improved design
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dining,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.combo.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اختر العناصر المفضلة',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _handleCancel,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content with improved spacing
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
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

                    // Selection status hint with improved design
                    if (!_isSelectionComplete) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.orange[700],
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'أكمل الاختيار للمتابعة',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons with improved design
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: OutlinedButton(
                              onPressed: _handleCancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade400),
                                foregroundColor: Colors.grey[700],
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Add to order button
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _isSelectionComplete 
                                      ? AppTheme.primaryColor.withOpacity(0.4)
                                      : Colors.grey.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSelectionComplete ? _handleConfirm : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSelectionComplete 
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade400,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'أضف للطلب',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_totalExtraPrice > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+ ${currencyFormat.format(_totalExtraPrice)}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with improved design
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  section.groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (section.required) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'مطلوب',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section items with improved grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 منتجات في كل صف للتصميم الأفضل
              childAspectRatio: 0.8, // نسبة محسنة
              crossAxisSpacing: 12, // مسافات محسنة
              mainAxisSpacing: 12, // مسافات محسنة
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.2)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Item image with improved design
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: item.image != null && item.image!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.memory(
                                    base64Decode(item.image!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.fastfood,
                                          size: 32,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.fastfood,
                                    size: 32,
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                      ),

                      // Item details
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item name
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Extra price with improved design
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.extraPrice > 0 
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: item.extraPrice > 0 
                                        ? Colors.orange.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  item.extraPrice > 0 
                                      ? '+ ${currencyFormat.format(item.extraPrice)}'
                                      : 'مجاني',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: item.extraPrice > 0 
                                        ? Colors.orange[700]
                                        : Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              // Selection indicator
                              if (isSelected) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'محدد',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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
