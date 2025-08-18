import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/numpad_widget.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPaymentMethod = 'Card';
  double _currentAmount = 0.0;
  final _amountController = TextEditingController();
  bool _invoiceEnabled = false;

  final List<String> _paymentMethods = [
    'Card',
    'Cash',
    'Mobile Payment',
    'Bank Transfer',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final posProvider = Provider.of<EnhancedPOSProvider>(context, listen: false);
      _currentAmount = posProvider.remainingAmount;
      _amountController.text = _currentAmount.toStringAsFixed(2);
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
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'تم إرسال الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to receipt screen
          Navigator.of(context).pushNamed('/receipt');
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
                              const Text(
                                'Select Payment Method',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _paymentMethods.map((method) {
                                  final isSelected = _selectedPaymentMethod == method;
                                  return ChoiceChip(
                                    label: Text(method),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedPaymentMethod = method;
                                        });
                                      }
                                    },
                                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: isSelected ? AppTheme.primaryColor : AppTheme.blackColor,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              // Amount input
                              TextField(
                                controller: _amountController,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  prefixText: 'SR ',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  _currentAmount = double.tryParse(value) ?? 0.0;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Add payment button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _currentAmount > 0 ? _addPayment : null,
                                  child: Text('Add ${currencyFormat.format(_currentAmount)}'),
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
