import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/models/product_product.dart';
import '../theme/app_theme.dart';

class ProductInformationPopup extends StatelessWidget {
  final ProductProduct product;
  final bool showAddToOrderButton;
  final VoidCallback? onAddToOrder;

  const ProductInformationPopup({
    super.key,
    required this.product,
    this.showAddToOrderButton = false,
    this.onAddToOrder,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'SR ');
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: Colors.white,
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Product information',
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
              const SizedBox(height: 24),

              // Inventory Section - matching popup.json structure
              _buildSection(
                context,
                title: 'Inventory',
                children: [
                  _buildDetailRow(
                    label: 'My Company :',
                    value: '${product.qtyAvailable.toStringAsFixed(0)} Units available.',
                  ),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    label: '',
                    value: '${product.virtualAvailable.toStringAsFixed(0)} forecasted',
                    isSecondary: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Financials Section - matching popup.json structure  
              _buildSection(
                context,
                title: 'Financials',
                children: [
                  _buildDetailRow(
                    label: 'Price excl. tax:',
                    value: currencyFormat.format(product.lstPrice),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'Cost:',
                    value: currencyFormat.format(product.standardPrice),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'Margin:',
                    value: '${currencyFormat.format(_calculateMargin(product))} (${_calculateMarginPercentage(product).toStringAsFixed(1)}%)',
                    valueColor: _calculateMargin(product) >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Order Section - matching popup.json structure
              _buildSection(
                context,
                title: 'Order',
                children: [
                  _buildDetailRow(
                    label: 'Total price excl. tax:',
                    value: '0.00 SR', // Placeholder as per JSON
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'Total cost:',
                    value: '0.00 SR', // Placeholder as per JSON
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'Total margin:',
                    value: '0.00 SR (0%)', // Placeholder as per JSON
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Buttons - matching popup.json structure
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit Button (secondary style)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit functionality not implemented'),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 12),
                  // Ok Button (primary style with color #5D377B as per JSON)
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D377B), // Color from JSON
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 2,
                    ),
                    child: const Text('Ok'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isSecondary = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSecondary ? AppTheme.secondaryColor : AppTheme.blackColor,
                fontWeight: isSecondary ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
        ],
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? (isSecondary ? AppTheme.secondaryColor : AppTheme.blackColor),
              fontWeight: isSecondary ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Calculate margin (Final Price - Cost)
  double _calculateMargin(ProductProduct product) {
    return product.finalPrice - product.standardPrice;
  }

  /// Calculate margin percentage
  double _calculateMarginPercentage(ProductProduct product) {
    if (product.finalPrice == 0) return 0.0;
    return ((_calculateMargin(product) / product.finalPrice) * 100);
  }
}