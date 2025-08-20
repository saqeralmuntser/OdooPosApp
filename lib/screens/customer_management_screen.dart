import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/providers/enhanced_pos_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/customer_form_dialog.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملاء'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCustomerDialog(context),
            tooltip: 'إضافة عميل',
          ),
        ],
      ),
      body: Consumer<EnhancedPOSProvider>(
        builder: (context, provider, child) {
          final filteredCustomers = provider.customers.where((customer) {
            return customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   (customer.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          }).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'البحث في العملاء...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Customer list
              Expanded(
                child: filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد عملاء',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'أضف أول عميل لك',
                              style: TextStyle(
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showCustomerDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة عميل جديد'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: customer.id < 0 ? Colors.orange : AppTheme.primaryColor,
                                    child: Text(
                                      customer.name.isNotEmpty 
                                          ? customer.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (customer.id < 0)
                                    const Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: CircleAvatar(
                                        radius: 8,
                                        backgroundColor: Colors.amber,
                                        child: Icon(
                                          Icons.sync_problem,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (customer.id < 0)
                                    const Text(
                                      'في انتظار المزامنة مع Odoo',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  if (customer.email != null)
                                    Text(customer.email!),
                                  if (customer.phone != null)
                                    Text(customer.phone!),
                                ],
                              ),

                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                    onPressed: () => _showCustomerDialog(context, customer),
                                    tooltip: 'تعديل العميل',
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Select this customer and go back
                                      Navigator.of(context).pop(customer);
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('اختيار'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: const Size(80, 36),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCustomerDialog(BuildContext context, [customer]) async {
    showDialog(
      context: context,
      builder: (dialogContext) => CustomerFormDialog(
        customer: customer,
        onSave: (newCustomer, {bool selectAfterSave = false}) async {
          final provider = Provider.of<EnhancedPOSProvider>(context, listen: false);
          
          try {
            bool success;
            
            // Check if widget is still mounted before showing SnackBar
            if (!mounted) return;
            
            // Show loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(width: 16),
                    Text(customer == null ? 'جاري حفظ العميل...' : 'جاري تحديث العميل...'),
                  ],
                ),
                duration: const Duration(seconds: 30), // Long duration for processing
                backgroundColor: Colors.blue,
              ),
            );
            
            if (customer == null) {
              // إنشاء عميل جديد
              success = await provider.addCustomer(newCustomer);
              
              // Check if widget is still mounted before proceeding
              if (!mounted) return;
              
              // Hide loading message
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              
              if (success) {
                // Get the created customer with proper ID from provider
                final createdCustomer = provider.customers.lastWhere(
                  (c) => c.name == newCustomer.name,
                  orElse: () => newCustomer,
                );
                
                if (selectAfterSave) {
                  // Show success message briefly then navigate
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حفظ العميل "${createdCustomer.name}" بنجاح ${createdCustomer.id > 0 ? 'في قاعدة بيانات Odoo' : 'محلياً (سيتم المزامنة عند الاتصال)'}'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  
                  // Wait a moment for user to see the message, then navigate
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (mounted) {
                    Navigator.of(context).pop(createdCustomer);
                  }
                  return;
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حفظ العميل "${createdCustomer.name}" بنجاح ${createdCustomer.id > 0 ? 'في قاعدة بيانات Odoo' : 'محلياً (سيتم المزامنة عند الاتصال)'}'),
                        backgroundColor: Colors.green,
                        action: SnackBarAction(
                          label: 'اختيار العميل',
                          textColor: Colors.white,
                          onPressed: () {
                            if (mounted) {
                              Navigator.of(context).pop(createdCustomer);
                            }
                          },
                        ),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }
            } else {
              // تحديث عميل موجود
              success = await provider.updateCustomer(newCustomer);
              
              // Check if widget is still mounted before proceeding
              if (!mounted) return;
              
              // Hide loading message
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تحديث العميل "${newCustomer.name}" بنجاح ${newCustomer.id > 0 ? 'في قاعدة بيانات Odoo' : 'محلياً (سيتم المزامنة عند الاتصال)'}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
            
            if (!success && mounted) {
              // Hide loading message
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فشل في ${customer == null ? 'حفظ' : 'تحديث'} العميل. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'إعادة المحاولة',
                    textColor: Colors.white,
                    onPressed: () {
                      if (mounted) {
                        // Trigger save again
                        _showCustomerDialog(context, customer);
                      }
                    },
                  ),
                ),
              );
            }
          } catch (e) {
            // Check if widget is still mounted before showing error
            if (!mounted) return;
            
            // Hide loading message
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('حدث خطأ غير متوقع: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'تفاصيل',
                  textColor: Colors.white,
                  onPressed: () {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (errorContext) => AlertDialog(
                          title: const Text('تفاصيل الخطأ'),
                          content: Text(e.toString()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(errorContext).pop(),
                              child: const Text('موافق'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
