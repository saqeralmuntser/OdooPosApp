import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class ProductInformationPopup extends StatelessWidget {
  final Product product;

  const ProductInformationPopup({
    super.key,
    required this.product,
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

            // Inventory Section
            _buildSection(
              context,
              title: 'Inventory',
              children: [
                _buildDetailRow(
                  label: product.inventory.companyLabel,
                  value: '${product.inventory.unitsAvailable} Units available.',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: '',
                  value: '${product.inventory.forecasted} forecasted',
                  isSecondary: true,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Financials Section
            _buildSection(
              context,
              title: 'Financials',
              children: [
                _buildDetailRow(
                  label: 'Price (excl. tax):',
                  value: currencyFormat.format(product.financials.priceExclTax),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Cost:',
                  value: currencyFormat.format(product.financials.cost),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Margin:',
                  value: '${currencyFormat.format(product.financials.margin)} (${product.financials.marginPercentage.toStringAsFixed(1)}%)',
                  valueColor: product.financials.margin >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Order Section
            _buildSection(
              context,
              title: 'Order',
              children: [
                _buildDetailRow(
                  label: 'Total price (excl. tax):',
                  value: currencyFormat.format(product.financials.totalPriceExclTax),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Total cost:',
                  value: currencyFormat.format(product.financials.totalCost),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Total margin:',
                  value: '${currencyFormat.format(product.financials.totalMargin)} (${product.financials.totalMarginPercentage.toStringAsFixed(1)}%)',
                  valueColor: product.financials.totalMargin >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Handle edit action
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit functionality not implemented'),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
}
