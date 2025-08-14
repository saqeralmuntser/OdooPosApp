import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../theme/app_theme.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;
  final Function(Customer) onSave;

  const CustomerFormDialog({
    super.key,
    this.customer,
    required this.onSave,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _companyNameController;
  late TextEditingController _jobPositionController;
  late TextEditingController _phoneController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _titleController;
  late TextEditingController _tagsController;
  late TextEditingController _vatNumberController;

  // Address controllers
  late TextEditingController _streetController;
  late TextEditingController _neighborhoodController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;
  late TextEditingController _buildingNumberController;
  late TextEditingController _plotIdentificationController;

  String _selectedType = 'Individual';
  final List<String> _customerTypes = ['Individual', 'Company'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeControllers();
  }

  void _initializeControllers() {
    final customer = widget.customer;
    
    _nameController = TextEditingController(text: customer?.name ?? '');
    _companyNameController = TextEditingController(text: customer?.companyName ?? '');
    _jobPositionController = TextEditingController(text: customer?.jobPosition ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _mobileController = TextEditingController(text: customer?.mobile ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _websiteController = TextEditingController(text: customer?.website ?? '');
    _titleController = TextEditingController(text: customer?.title ?? '');
    _tagsController = TextEditingController(text: customer?.tags.join(', ') ?? '');
    _vatNumberController = TextEditingController(text: customer?.vatNumber ?? '');

    // Address
    _streetController = TextEditingController(text: customer?.address?.street ?? '');
    _neighborhoodController = TextEditingController(text: customer?.address?.neighborhood ?? '');
    _cityController = TextEditingController(text: customer?.address?.city ?? '');
    _stateController = TextEditingController(text: customer?.address?.state ?? '');
    _zipController = TextEditingController(text: customer?.address?.zip ?? '');
    _countryController = TextEditingController(text: customer?.address?.country ?? '');
    _buildingNumberController = TextEditingController(text: customer?.address?.buildingNumber ?? '');
    _plotIdentificationController = TextEditingController(text: customer?.address?.plotIdentification ?? '');

    _selectedType = customer?.type ?? 'Individual';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _companyNameController.dispose();
    _jobPositionController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _titleController.dispose();
    _tagsController.dispose();
    _vatNumberController.dispose();
    _streetController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _buildingNumberController.dispose();
    _plotIdentificationController.dispose();
    super.dispose();
  }

  void _saveCustomer() {
    if (!_formKey.currentState!.validate()) return;

    final customer = Customer(
      id: widget.customer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _selectedType,
      companyName: _companyNameController.text.trim().isNotEmpty 
          ? _companyNameController.text.trim() 
          : null,
      jobPosition: _jobPositionController.text.trim().isNotEmpty 
          ? _jobPositionController.text.trim() 
          : null,
      phone: _phoneController.text.trim().isNotEmpty 
          ? _phoneController.text.trim() 
          : null,
      mobile: _mobileController.text.trim().isNotEmpty 
          ? _mobileController.text.trim() 
          : null,
      email: _emailController.text.trim().isNotEmpty 
          ? _emailController.text.trim() 
          : null,
      website: _websiteController.text.trim().isNotEmpty 
          ? _websiteController.text.trim() 
          : null,
      title: _titleController.text.trim().isNotEmpty 
          ? _titleController.text.trim() 
          : null,
      tags: _tagsController.text.trim().isNotEmpty 
          ? _tagsController.text.split(',').map((e) => e.trim()).toList()
          : [],
      vatNumber: _vatNumberController.text.trim().isNotEmpty 
          ? _vatNumberController.text.trim() 
          : null,
      address: Address(
        street: _streetController.text.trim().isNotEmpty ? _streetController.text.trim() : null,
        neighborhood: _neighborhoodController.text.trim().isNotEmpty ? _neighborhoodController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
        zip: _zipController.text.trim().isNotEmpty ? _zipController.text.trim() : null,
        country: _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
        buildingNumber: _buildingNumberController.text.trim().isNotEmpty ? _buildingNumberController.text.trim() : null,
        plotIdentification: _plotIdentificationController.text.trim().isNotEmpty ? _plotIdentificationController.text.trim() : null,
      ),
    );

    widget.onSave(customer);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    widget.customer == null ? 'Create Customer' : 'Edit Partner',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Type selector
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Type: '),
                  ...(_customerTypes.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: type,
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                          ),
                          Text(type),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Contacts & Addresses'),
                Tab(text: 'Sales & Purchase'),
                Tab(text: 'Invoicing'),
                Tab(text: 'Internal Notes'),
              ],
            ),

            // Tab content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildContactsTab(),
                    _buildSalesPurchaseTab(),
                    _buildInvoicingTab(),
                    _buildNotesTab(),
                  ],
                ),
              ),
            ),

            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveCustomer,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Basic info
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g. Brandon Freeman',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              if (_selectedType == 'Company')
                Expanded(
                  child: TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _jobPositionController,
                  decoration: const InputDecoration(
                    labelText: 'Job Position',
                    hintText: 'e.g. Sales Director',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Mister',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact info
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    hintText: 'e.g. https://www.odoo.com',
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'e.g. "B2B", "VIP", "Consulting", ...',
            ),
          ),
          const SizedBox(height: 24),

          // Address section
          Text(
            'Address',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(
              labelText: 'Street',
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _neighborhoodController,
                  decoration: const InputDecoration(
                    labelText: 'Neighborhood',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'ZIP',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _buildingNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Building Number',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _plotIdentificationController,
            decoration: const InputDecoration(
              labelText: 'Plot Identification',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesPurchaseTab() {
    return const Center(
      child: Text(
        'Sales & Purchase settings will be implemented here',
        style: TextStyle(color: AppTheme.secondaryColor),
      ),
    );
  }

  Widget _buildInvoicingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _vatNumberController,
            decoration: const InputDecoration(
              labelText: 'VAT Number',
              hintText: '/ if not applicable',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Additional invoicing settings will be implemented here',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return const Center(
      child: Text(
        'Internal notes will be implemented here',
        style: TextStyle(color: AppTheme.secondaryColor),
      ),
    );
  }
}
