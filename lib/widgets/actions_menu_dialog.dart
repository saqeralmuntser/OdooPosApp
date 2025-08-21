import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import 'pricelist_selection_dialog.dart';
import 'combo_test_dialog.dart';

class ActionsMenuDialog extends StatelessWidget {
  const ActionsMenuDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      'General Note',
      'Split',
      'Transfer / Merge',
      'Edit Order Name',
      '1 Guests',
      'Customer Note',
      'Pricelist',
      'Combo Test',
      'Printer Management',
      'Refund',
      'Switch to Takeaway',
      'Cancel Order',
    ];

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Actions grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return ActionButton(
                  title: action,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleAction(context, action);
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    // Handle different actions
    switch (action) {
      case 'General Note':
        _showNoteDialog(context, 'General Note');
        break;
      case 'Customer Note':
        _showNoteDialog(context, 'Customer Note');
        break;
      case 'Edit Order Name':
        _showOrderNameDialog(context);
        break;
      case 'Pricelist':
        _showPricelistDialog(context);
        break;
      case 'Combo Test':
        _showComboTestDialog(context);
        break;
      case 'Printer Management':
        Navigator.of(context).pushNamed('/printers');
        break;
      case 'Cancel Order':
        _showCancelOrderDialog(context);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action functionality not implemented'),
          ),
        );
    }
  }

  void _showPricelistDialog(BuildContext context) {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    // Check if pricelist feature is enabled for current config
    if (!posProvider.hasPricelistFeature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خاصية التسعيرات غير مفعلة في البوس كونفج الحالي'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if there are available pricelists
    if (posProvider.availablePricelists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد تسعيرات متاحة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show pricelist selection dialog
    showDialog(
      context: context,
      builder: (context) => const PricelistSelectionDialog(),
    );
  }

  void _showComboTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ComboTestDialog(),
    );
  }

  void _showNoteDialog(BuildContext context, String title) {
    final noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Enter note...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title saved: ${noteController.text}')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showOrderNameDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Order Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter order name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order name changed to: ${nameController.text}')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order? All items will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close actions dialog too
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order cancelled')),
              );
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.all(12),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
