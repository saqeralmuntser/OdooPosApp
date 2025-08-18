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
        title: const Text('Customer Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCustomerDialog(context),
            tooltip: 'Add Customer',
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
                    hintText: 'Search customers...',
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
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppTheme.secondaryColor,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No customers found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add your first customer using the + button',
                              style: TextStyle(
                                color: AppTheme.secondaryColor,
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
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
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
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (customer.email != null)
                                    Text(customer.email!),
                                  if (customer.phone != null)
                                    Text(customer.phone!),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showCustomerDialog(context, customer),
                                    tooltip: 'Edit Customer',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check),
                                    onPressed: () {
                                      // Select this customer and go back
                                      Navigator.of(context).pop(customer);
                                    },
                                    tooltip: 'Select Customer',
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

  void _showCustomerDialog(BuildContext context, [customer]) {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        customer: customer,
        onSave: (newCustomer) {
          // Handle customer save if needed
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
