import 'package:flutter/material.dart';
import '../backend/models/res_partner.dart';
import '../theme/app_theme.dart';

class CustomerFormDialog extends StatefulWidget {
  final ResPartner? customer;
  final Function(ResPartner, {bool selectAfterSave}) onSave;

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
  late TextEditingController _jobPositionController;
  late TextEditingController _phoneController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _titleController;
  late TextEditingController _vatNumberController;

  // Address controllers
  late TextEditingController _streetController;
  late TextEditingController _street2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;

  bool _isCompany = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeControllers();
  }

  void _initializeControllers() {
    final customer = widget.customer;
    
    _nameController = TextEditingController(text: customer?.name ?? '');
    _jobPositionController = TextEditingController(text: customer?.jobPosition ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _mobileController = TextEditingController(text: customer?.mobile ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _websiteController = TextEditingController(text: customer?.website ?? '');
    _titleController = TextEditingController(text: customer?.title ?? '');
    _vatNumberController = TextEditingController(text: customer?.vatNumber ?? '');

    // Address
    _streetController = TextEditingController(text: customer?.street ?? '');
    _street2Controller = TextEditingController(text: customer?.street2 ?? '');
    _cityController = TextEditingController(text: customer?.city ?? '');
    _stateController = TextEditingController(text: customer?.state ?? '');
    _zipController = TextEditingController(text: customer?.zip ?? '');

    _isCompany = customer?.isCompany ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _jobPositionController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _titleController.dispose();
    _vatNumberController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _saveCustomer({bool selectAfterSave = false}) {
    if (!_formKey.currentState!.validate()) return;

    final customer = ResPartner(
      id: widget.customer?.id ?? 0, // For new customers, backend will assign ID
      name: _nameController.text.trim(),
      isCompany: _isCompany,
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
      vatNumber: _vatNumberController.text.trim().isNotEmpty 
          ? _vatNumberController.text.trim() 
          : null,
      street: _streetController.text.trim().isNotEmpty ? _streetController.text.trim() : null,
      street2: _street2Controller.text.trim().isNotEmpty ? _street2Controller.text.trim() : null,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
      zip: _zipController.text.trim().isNotEmpty ? _zipController.text.trim() : null,
      customerRank: 1, // Mark as customer
    );

    widget.onSave(customer, selectAfterSave: selectAfterSave);
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
                    widget.customer == null ? 'إنشاء عميل جديد' : 'تعديل بيانات العميل',
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
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _isCompany,
                          onChanged: (value) {
                            setState(() {
                              _isCompany = value!;
                            });
                          },
                        ),
                        const Text('Individual'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _isCompany,
                          onChanged: (value) {
                            setState(() {
                              _isCompany = value!;
                            });
                          },
                        ),
                        const Text('Company'),
                      ],
                    ),
                  ),
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
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 16),
                  if (widget.customer == null) ...[
                    // For new customers, show "Save & Select" button
                    ElevatedButton.icon(
                      onPressed: () => _saveCustomer(selectAfterSave: true),
                      icon: const Icon(Icons.person_add),
                      label: const Text('حفظ واختيار'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton(
                    onPressed: () => _saveCustomer(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('حفظ'),
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
                  decoration: InputDecoration(
                    labelText: _isCompany ? 'Company Name *' : 'Name *',
                    hintText: _isCompany ? 'e.g. Odoo Inc.' : 'e.g. Brandon Freeman',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _isCompany ? 'Company name is required' : 'Name is required';
                    }
                    return null;
                  },
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

          TextFormField(
            controller: _street2Controller,
            decoration: const InputDecoration(
              labelText: 'Street 2',
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
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
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'ZIP',
                  ),
                ),
              ),
            ],
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
