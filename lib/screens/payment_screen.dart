import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../backend/models/pos_payment_method.dart';
import '../theme/app_theme.dart';
import '../widgets/numpad_widget.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = '';
  double _currentAmount = 0.0;
  final _amountController = TextEditingController();
  bool _invoiceEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      _currentAmount = posProvider.remainingAmount;
      _amountController.text = _currentAmount.toStringAsFixed(2);
      
      // Set default payment method to first available method
      final availableMethods = posProvider.availablePaymentMethods;
      if (availableMethods.isNotEmpty) {
        _selectedPaymentMethod = availableMethods.first.name;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onNumpadPressed(String value) {
    setState(() {
      switch (value) {
        case '+10':
          _currentAmount += 10;
          break;
        case '+20':
          _currentAmount += 20;
          break;
        case '+50':
          _currentAmount += 50;
          break;
        case '-20':
          _currentAmount = (_currentAmount - 20).clamp(0.0, double.infinity);
          break;
        case '+/-':
          _currentAmount = -_currentAmount;
          break;
        case '.':
          if (!_amountController.text.contains('.')) {
            _amountController.text += '.';
          }
          return;
        default:
          if (value == '0' && _amountController.text == '0') return;
          if (_amountController.text == '0' && value != '.') {
            _amountController.text = value;
          } else {
            _amountController.text += value;
          }
          _currentAmount = double.tryParse(_amountController.text) ?? 0.0;
          return;
      }
      _amountController.text = _currentAmount.toStringAsFixed(2);
    });
  }

  void _addPayment() async {
    if (_currentAmount <= 0) return;

    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    final success = await posProvider.addPayment(_selectedPaymentMethod, _currentAmount);
    
    if (success) {
      setState(() {
        _currentAmount = posProvider.remainingAmount;
        _amountController.text = _currentAmount.toStringAsFixed(2);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _validatePayment() async {
    final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
    
    if (posProvider.remainingAmount > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إكمال الدفع قبل التأكيد'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Get selected customer ID if any
      int? customerId = posProvider.selectedCustomer?.id;
      
      // Validate and send order to Odoo
      final result = await posProvider.validateOrder(
        generateInvoice: _invoiceEnabled,
        customerId: customerId,
      );

      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        // Print receipt automatically
        try {
          print('Printing receipt automatically...');
          final printResult = await posProvider.printReceipt(
            order: result.order,
            orderLines: result.savedOrderLines ?? [],
            payments: result.savedPayments ?? {},
            customer: result.savedCustomer,
            company: posProvider.company,
            webPrintFallback: true,
          );

          if (printResult['successful'] == true) {
            print('Receipt printed successfully');
          } else {
            print('Print failed: ${printResult['message']}');
            // Show print error but don't stop the flow
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تحذير: فشل في طباعة الإيصال - ${printResult['message']?['title'] ?? 'خطأ غير معروف'}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          print('Error during automatic printing: $e');
          // Show print error but don't stop the flow
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تحذير: فشل في طباعة الإيصال - $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'تم إرسال الطلب بنجاح والطباعة'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Use saved data from result (before provider was cleared)
          final orderLines = result.savedOrderLines ?? [];
          final payments = result.savedPayments ?? {};
          final customer = result.savedCustomer;
          
          // Debug: Print data before navigation
          print('Payment Screen - Navigating to receipt with:');
          print('  Order: ${result.order?.name}');
          print('  Order Lines Count: ${orderLines.length}');
          print('  Payments: $payments');
          print('  Customer: ${customer?.name}');
          print('  Company: ${posProvider.company?.name}');
          
          // Navigate to receipt screen with the completed order
          Navigator.of(context).pushNamed('/receipt', arguments: {
            'order': result.order,
            'orderLines': orderLines,
            'payments': payments,
            'customer': customer,
            'company': posProvider.company,
          });
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'فشل في إرسال الطلب'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ غير متوقع: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  /// Get appropriate icon for payment method
  IconData _getPaymentMethodIcon(POSPaymentMethod method) {
    final methodName = method.name.toLowerCase();
    
    // Check if it's a cash method
    if (method.isCash || methodName.contains('cash') || methodName.contains('نقد')) {
      return Icons.money;
    }
    
    // Check if it's a card/terminal method
    if (method.isCard || method.requiresTerminal || 
        methodName.contains('card') || methodName.contains('بطاقة') ||
        methodName.contains('visa') || methodName.contains('mastercard')) {
      return Icons.credit_card;
    }
    
    // Check for mobile/digital payments
    if (methodName.contains('mobile') || methodName.contains('digital') ||
        methodName.contains('محفظة') || methodName.contains('جوال') ||
        methodName.contains('apple') || methodName.contains('google') ||
        methodName.contains('samsung') || methodName.contains('stc')) {
      return Icons.phone_android;
    }
    
    // Check for bank transfer
    if (methodName.contains('transfer') || methodName.contains('bank') ||
        methodName.contains('تحويل') || methodName.contains('بنك')) {
      return Icons.account_balance;
    }
    
    // Check for cheque/check
    if (methodName.contains('cheque') || methodName.contains('check') ||
        methodName.contains('شيك')) {
      return Icons.receipt_long;
    }
    
    // Default payment icon
    return Icons.payment;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<EnhancedPOSProvider>(
        builder: (context, posProvider, _) {
          final currencyFormat = NumberFormat.currency(symbol: 'SR ');

          return Row(
            children: [
              // Main payment area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total amount display
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Total Amount',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormat.format(posProvider.total),
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 48,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Payment summary
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Summary',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),

                              // Remaining amount
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Remaining:',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    currencyFormat.format(posProvider.remainingAmount),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: posProvider.remainingAmount > 0 
                                          ? Colors.red 
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Payment methods used
                              if (posProvider.paymentsMap.isNotEmpty) ...[
                                const Text(
                                  'Payment Methods:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                ...posProvider.paymentsMap.entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(entry.key),
                                        Row(
                                          children: [
                                            Text(currencyFormat.format(entry.value)),
                                            IconButton(
                                              icon: const Icon(Icons.close, size: 16),
                                              onPressed: () async {
                                                await posProvider.removePayment(entry.key);
                                              },
                                              constraints: const BoxConstraints(
                                                minWidth: 24,
                                                minHeight: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Payment method selection
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  children: [
                                    const Text(
                                      'Select Payment Method',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Consumer<EnhancedPOSProvider>(
                                      builder: (context, provider, _) {
                                        final config = provider.selectedConfig;
                                        final configName = config?.name ?? 'No Config';
                                        final availableMethods = provider.availablePaymentMethods;
                                        
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Config: $configName',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.secondaryColor,
                                              ),
                                            ),
                                            Text(
                                              '${availableMethods.length} طرق دفع متاحة',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.secondaryColor,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 12),
                              // Payment methods from POS Config
                              Consumer<EnhancedPOSProvider>(
                                builder: (context, provider, _) {
                                  final availableMethods = provider.availablePaymentMethods;
                                  
                                  if (availableMethods.isEmpty) {
                                    return Card(
                                      color: Colors.orange.shade50,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange,
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'لا توجد طرق دفع مرتبطة بـ POS Config الحالي',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'يجب إعداد طرق الدفع في Odoo لـ ${provider.selectedConfig?.name ?? "POS Config"}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  // Ensure selected method is valid
                                  if (_selectedPaymentMethod.isEmpty || 
                                      !availableMethods.any((m) => m.name == _selectedPaymentMethod)) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(() {
                                          _selectedPaymentMethod = availableMethods.first.name;
                                        });
                                      }
                                    });
                                  }
                                  
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: availableMethods.map((method) {
                                      final isSelected = _selectedPaymentMethod == method.name;
                                      return ChoiceChip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Add icon based on payment type
                                            Icon(
                                              _getPaymentMethodIcon(method),
                                              size: 16,
                                              color: isSelected ? AppTheme.primaryColor : AppTheme.blackColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(method.name),
                                          ],
                                        ),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _selectedPaymentMethod = method.name;
                                            });
                                          }
                                        },
                                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                        labelStyle: TextStyle(
                                          color: isSelected ? AppTheme.primaryColor : AppTheme.blackColor,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Amount input
                              Consumer<EnhancedPOSProvider>(
                                builder: (context, provider, _) {
                                  final remaining = provider.remainingAmount;
                                  return TextField(
                                    controller: _amountController,
                                    decoration: InputDecoration(
                                      labelText: 'Amount',
                                      prefixText: 'SR ',
                                      helperText: remaining > 0 
                                          ? 'Remaining: ${currencyFormat.format(remaining)}'
                                          : 'Order fully paid',
                                      helperStyle: TextStyle(
                                        color: remaining > 0 ? Colors.orange : Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (value) {
                                      setState(() {
                                        _currentAmount = double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Payment method info
                              Consumer<EnhancedPOSProvider>(
                                builder: (context, provider, _) {
                                  final selectedMethod = provider.getPaymentMethodByName(_selectedPaymentMethod);
                                  if (selectedMethod != null) {
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.borderColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getPaymentMethodIcon(selectedMethod),
                                            color: AppTheme.primaryColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  selectedMethod.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (selectedMethod.isCash)
                                                  const Text(
                                                    'Cash counting enabled',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.secondaryColor,
                                                    ),
                                                  ),
                                                if (selectedMethod.requiresTerminal)
                                                  const Text(
                                                    'Requires payment terminal',
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
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              const SizedBox(height: 16),

                              // Debug info (only in debug mode)
                              if (kDebugMode)
                                Consumer<EnhancedPOSProvider>(
                                  builder: (context, provider, _) {
                                    final config = provider.selectedConfig;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Debug Info:',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Config Payment IDs: ${config?.paymentMethodIds}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.blue.shade600,
                                            ),
                                          ),
                                          Text(
                                            'All Methods: ${provider.paymentMethods.map((m) => '${m.id}:${m.name}').join(', ')}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.blue.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              
                              // Add payment button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _currentAmount > 0 && _selectedPaymentMethod.isNotEmpty ? _addPayment : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(
                                    _selectedPaymentMethod.isEmpty 
                                        ? 'Select Payment Method'
                                        : 'Add ${currencyFormat.format(_currentAmount)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Options
                      Row(
                        children: [
                          Checkbox(
                            value: _invoiceEnabled,
                            onChanged: (value) {
                              setState(() {
                                _invoiceEnabled = value ?? false;
                              });
                            },
                          ),
                          const Text('Generate Invoice'),
                          const SizedBox(width: 24),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/customers');
                            },
                            child: const Text('Select Customer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Right sidebar with numpad and controls
              Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Current amount display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Current Amount',
                              style: TextStyle(
                                color: AppTheme.secondaryColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(_currentAmount),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Numpad
                      NumpadWidget(onNumberPressed: _onNumpadPressed),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _validatePayment,
                              child: const Text('Validate'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
