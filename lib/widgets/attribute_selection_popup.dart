import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class AttributeSelectionPopup extends StatefulWidget {
  final Product product;
  final Function(Product, List<AttributeGroup>) onConfirm;

  const AttributeSelectionPopup({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  @override
  State<AttributeSelectionPopup> createState() => _AttributeSelectionPopupState();
}

class _AttributeSelectionPopupState extends State<AttributeSelectionPopup> {
  late List<AttributeGroup> selectedAttributes;

  @override
  void initState() {
    super.initState();
    // Create a copy of attributes to modify
    selectedAttributes = widget.product.attributes.map(
      (group) => AttributeGroup(
        groupName: group.groupName,
        options: group.options.map(
          (option) => ProductAttribute(
            name: option.name,
            isSelected: option.isSelected,
            additionalCost: option.additionalCost,
          ),
        ).toList(),
      ),
    ).toList();
  }

  void _toggleAttribute(int groupIndex, int optionIndex) {
    setState(() {
      // For single selection groups, deselect others first
      for (int i = 0; i < selectedAttributes[groupIndex].options.length; i++) {
        selectedAttributes[groupIndex].options[i] = 
            selectedAttributes[groupIndex].options[i].copyWith(isSelected: false);
      }
      
      // Select the chosen option
      selectedAttributes[groupIndex].options[optionIndex] = 
          selectedAttributes[groupIndex].options[optionIndex].copyWith(isSelected: true);
    });
  }

  double _calculateTotalPrice() {
    double basePrice = widget.product.price;
    double additionalCost = 0;
    
    for (var group in selectedAttributes) {
      for (var option in group.options) {
        if (option.isSelected && option.additionalCost != null) {
          additionalCost += option.additionalCost!;
        }
      }
    }
    
    return basePrice + additionalCost;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    final totalPrice = _calculateTotalPrice();
    final vatAmount = totalPrice * widget.product.vatRate;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with product info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF4F7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Attribute selection',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blackColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.blackColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(totalPrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VAT: ${(widget.product.vatRate * 100).toInt()}% (= ${currencyFormat.format(vatAmount)})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Attributes content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedAttributes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.tune,
                                size: 48,
                                color: AppTheme.secondaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No attributes available for this product',
                                style: TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...selectedAttributes.asMap().entries.map(
                        (groupEntry) => _buildAttributeGroup(
                          groupEntry.key,
                          groupEntry.value,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(widget.product, selectedAttributes);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeGroup(int groupIndex, AttributeGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.groupName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.5),
            ),
          ),
          child: Column(
            children: group.options.asMap().entries.map(
              (optionEntry) => _buildAttributeOption(
                groupIndex,
                optionEntry.key,
                optionEntry.value,
                isLast: optionEntry.key == group.options.length - 1,
              ),
            ).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAttributeOption(
    int groupIndex,
    int optionIndex,
    ProductAttribute option,
    {bool isLast = false}
  ) {
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    
    return Column(
      children: [
        InkWell(
          onTap: () => _toggleAttribute(groupIndex, optionIndex),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: option.isSelected ? true : null,
                  onChanged: (_) => _toggleAttribute(groupIndex, optionIndex),
                  activeColor: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (option.additionalCost != null && option.additionalCost! > 0)
                        Text(
                          '+ ${currencyFormat.format(option.additionalCost)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: AppTheme.borderColor.withOpacity(0.3),
            height: 1,
          ),
      ],
    );
  }
}
