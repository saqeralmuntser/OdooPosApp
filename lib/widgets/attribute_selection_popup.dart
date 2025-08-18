import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/models/product_product.dart';
import '../backend/models/product_attribute.dart';
import '../backend/providers/product_attribute_provider.dart';
import '../theme/app_theme.dart';

class AttributeSelectionPopup extends StatefulWidget {
  final ProductProduct product;
  final Function(int productId, double quantity, List<int> selectedAttributeValueIds, List<String> selectedAttributeNames, List<double> selectedAttributeExtraPrices) onConfirm;

  const AttributeSelectionPopup({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  @override
  State<AttributeSelectionPopup> createState() => _AttributeSelectionPopupState();
}

class _AttributeSelectionPopupState extends State<AttributeSelectionPopup> {
  double _quantity = 1.0;
  ProductAttributeProvider? _provider;

  @override
  void initState() {
    super.initState();
    // Load complete product information when popup opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductAttributeProvider>().loadProductCompleteInfo(widget.product.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to provider to safely access it in dispose
    _provider = context.read<ProductAttributeProvider>();
  }

  @override
  void dispose() {
    // Clear the provider when popup closes using saved reference
    _provider?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
    
    return Consumer<ProductAttributeProvider>(
      builder: (context, attributeProvider, child) {
        if (attributeProvider.isLoading) {
          return _buildLoadingDialog(context);
        }

        if (attributeProvider.error != null) {
          return _buildErrorDialog(context, attributeProvider.error!);
        }

        final productInfo = attributeProvider.currentProductInfo;
        if (productInfo == null) {
          return _buildErrorDialog(context, 'Unable to load product information');
        }

        final totalPrice = attributeProvider.totalPrice * _quantity;
        final vatAmount = attributeProvider.vatAmount * _quantity;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.white,
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 700),
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
                        productInfo.productName,
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
                        'ضريبة القيمة المضافة: ${(productInfo.vatRate * 100).toInt()}% (= ${currencyFormat.format(vatAmount)})',
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
                        if (productInfo.attributeGroups.isEmpty)
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
                        else ...[
                          // Quantity selector
                          _buildQuantitySelector(context),
                          const SizedBox(height: 20),
                          // Attribute groups
                          ...productInfo.attributeGroups.map(
                            (attributeGroup) => _buildAttributeGroup(
                              context,
                              attributeGroup,
                              attributeProvider,
                            ),
                          ),
                        ],
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
                      // Discard Button (secondary style as per JSON)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.secondaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 12),
                      // Add Button (primary style with color #5D377B as per JSON)
                      ElevatedButton(
                        onPressed: attributeProvider.areAllRequiredAttributesSelected
                            ? () {
                                final validation = attributeProvider.validateSelection();
                                if (validation.isValid) {
                                  // Save the values before popping
                                  final productId = widget.product.id;
                                  final quantity = _quantity;
                                  final selectedValues = attributeProvider.selectedAttributeValueIds;
                                  
                                  // Get attribute names and extra prices from the provider
                                  List<String> selectedAttributeNames = [];
                                  List<double> selectedAttributeExtraPrices = [];
                                  
                                  if (attributeProvider.currentProductInfo != null) {
                                    for (final group in attributeProvider.currentProductInfo!.attributeGroups) {
                                      final selectedValue = attributeProvider.getSelectedValue(group.attributeId);
                                      if (selectedValue != null) {
                                        selectedAttributeNames.add(selectedValue.valueName);
                                        selectedAttributeExtraPrices.add(selectedValue.priceExtra);
                                      }
                                    }
                                  }
                                  
                                  print('Selected attribute names: $selectedAttributeNames');
                                  print('Selected attribute extra prices: $selectedAttributeExtraPrices');
                                  
                                  // Pop the dialog first
                                  Navigator.of(context).pop();
                                  
                                  // Then call the callback
                                  widget.onConfirm(
                                    productId,
                                    quantity,
                                    selectedValues,
                                    selectedAttributeNames,
                                    selectedAttributeExtraPrices,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(validation.error ?? 'Please select all required attributes'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D377B), // Color from JSON
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 2,
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
      },
    );
  }

  /// Build loading dialog
  Widget _buildLoadingDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 300,
        height: 200,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading product information...',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build error dialog
  Widget _buildErrorDialog(BuildContext context, String error) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ok'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build quantity selector
  Widget _buildQuantitySelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(
            'Quantity:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppTheme.primaryColor,
          ),
          Container(
            width: 60,
            alignment: Alignment.center,
            child: Text(
              _quantity.toStringAsFixed(0),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _quantity++),
            icon: const Icon(Icons.add_circle_outline),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// Build attribute group widget
  Widget _buildAttributeGroup(
    BuildContext context,
    AttributeGroupDisplayData attributeGroup,
    ProductAttributeProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              attributeGroup.attributeName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            if (attributeGroup.required) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
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
            children: attributeGroup.values.asMap().entries.map(
              (valueEntry) => _buildAttributeValue(
                context,
                attributeGroup,
                valueEntry.value,
                provider,
                isLast: valueEntry.key == attributeGroup.values.length - 1,
              ),
            ).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Build attribute value option
  Widget _buildAttributeValue(
    BuildContext context,
    AttributeGroupDisplayData attributeGroup,
    AttributeValueDisplayData valueData,
    ProductAttributeProvider provider,
    {bool isLast = false}
  ) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س ');
    final isSelected = provider.isValueSelected(attributeGroup.attributeId, valueData.valueId);
    
    return Column(
      children: [
        InkWell(
          onTap: () => provider.selectAttributeValue(attributeGroup.attributeId, valueData),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: isSelected ? true : null,
                  onChanged: (_) => provider.selectAttributeValue(attributeGroup.attributeId, valueData),
                  activeColor: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                // Color indicator if available
                if (valueData.htmlColor != null) ...[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(int.parse(valueData.htmlColor!.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueData.valueName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (valueData.priceExtra > 0)
                        Text(
                          '+ ${currencyFormat.format(valueData.priceExtra)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                // Image indicator
                if (valueData.hasImage)
                  Icon(
                    Icons.image,
                    size: 16,
                    color: AppTheme.secondaryColor,
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
