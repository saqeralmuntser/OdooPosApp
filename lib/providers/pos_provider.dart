import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../models/customer.dart';
import '../models/pos_register.dart';

class POSProvider with ChangeNotifier {
  // Current user
  String? _currentUser;
  String? get currentUser => _currentUser;

  // Current register
  POSRegister? _currentRegister;
  POSRegister? get currentRegister => _currentRegister;

  // Products and categories
  List<Product> _products = [];
  List<String> _categories = [];
  String _selectedCategory = '';

  List<Product> get products => _products;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;

  // Current order
  List<OrderItem> _orderItems = [];
  Customer? _selectedCustomer;
  String _tableNumber = '801';
  
  List<OrderItem> get orderItems => _orderItems;
  Customer? get selectedCustomer => _selectedCustomer;
  String get tableNumber => _tableNumber;

  // Order calculations
  double get subtotal => _orderItems.fold(0, (sum, item) => sum + item.total);
  double get taxRate => 0.15; // 15% VAT
  double get taxAmount => subtotal * taxRate;
  double get total => subtotal + taxAmount;

  // Payment
  Map<String, double> _payments = {};
  Map<String, double> get payments => _payments;
  double get totalPaid => _payments.values.fold(0, (sum, amount) => sum + amount);
  double get remainingAmount => total - totalPaid;

  // Customers
  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  // POS Registers
  List<POSRegister> _registers = [];
  List<POSRegister> get registers => _registers;

  // Initialize with sample data
  POSProvider() {
    _initializeSampleData();
  }

  void _initializeSampleData() {
    // Sample products with attributes and detailed information
    _products = [
      Product(
        id: '1',
        name: 'Green Tea',
        price: 4.70,
        category: 'Drinks',
        inventory: ProductInventory(unitsAvailable: 25, forecasted: 5),
        financials: ProductFinancials(priceExclTax: 4.09, cost: 2.50),
      ),
      Product(
        id: '2',
        name: 'Spicy Tuna Sandwich',
        price: 12.50,
        category: 'Food',
        inventory: ProductInventory(unitsAvailable: 15, forecasted: 3),
        financials: ProductFinancials(priceExclTax: 10.87, cost: 7.50),
        attributes: [
          AttributeGroup(
            groupName: 'Bread Type',
            options: [
              ProductAttribute(name: 'White bread', isSelected: true),
              ProductAttribute(name: 'Whole wheat bread', additionalCost: 1.0),
              ProductAttribute(name: 'Sourdough bread', additionalCost: 1.5),
            ],
          ),
        ],
      ),
      Product(
        id: '3',
        name: 'Bacon Burger',
        price: 15.50,
        category: 'Food',
        inventory: ProductInventory(unitsAvailable: 8, forecasted: 2),
        financials: ProductFinancials(priceExclTax: 13.48, cost: 10.35),
        attributes: [
          AttributeGroup(
            groupName: 'Sides',
            options: [
              ProductAttribute(name: 'Belgian fresh homemade fries', isSelected: true),
              ProductAttribute(name: 'Sweet potato fries', additionalCost: 2.0),
              ProductAttribute(name: 'Smashed sweet potatoes', additionalCost: 2.5),
              ProductAttribute(name: 'Potatoes with thyme', additionalCost: 1.5),
              ProductAttribute(name: 'Grilled vegetables', additionalCost: 3.0),
            ],
          ),
        ],
      ),
      Product(
        id: '4',
        name: 'Burger Menu Combo',
        price: 18.50,
        category: 'Food',
        inventory: ProductInventory(unitsAvailable: 12, forecasted: 4),
        financials: ProductFinancials(priceExclTax: 16.09, cost: 12.00),
        attributes: [
          AttributeGroup(
            groupName: 'Drink Choice',
            options: [
              ProductAttribute(name: 'Coca-Cola', isSelected: true),
              ProductAttribute(name: 'Sprite'),
              ProductAttribute(name: 'Orange Juice', additionalCost: 1.0),
              ProductAttribute(name: 'Fresh Lemonade', additionalCost: 1.5),
            ],
          ),
          AttributeGroup(
            groupName: 'Sides',
            options: [
              ProductAttribute(name: 'Regular fries', isSelected: true),
              ProductAttribute(name: 'Sweet potato fries', additionalCost: 2.0),
              ProductAttribute(name: 'Onion rings', additionalCost: 2.5),
            ],
          ),
        ],
      ),
      Product(
        id: '5',
        name: 'Coca-Cola',
        price: 3.50,
        category: 'Drinks',
        inventory: ProductInventory(unitsAvailable: 50, forecasted: 10),
        financials: ProductFinancials(priceExclTax: 3.04, cost: 1.20),
        attributes: [
          AttributeGroup(
            groupName: 'Size',
            options: [
              ProductAttribute(name: 'Small (250ml)', isSelected: true),
              ProductAttribute(name: 'Medium (350ml)', additionalCost: 1.0),
              ProductAttribute(name: 'Large (500ml)', additionalCost: 2.0),
            ],
          ),
        ],
      ),
      Product(
        id: '6',
        name: 'Mandi',
        price: 25.00,
        category: 'الدجاج',
        inventory: ProductInventory(unitsAvailable: 6, forecasted: 1),
        financials: ProductFinancials(priceExclTax: 21.74, cost: 15.00),
        attributes: [
          AttributeGroup(
            groupName: 'Spice Level',
            options: [
              ProductAttribute(name: 'Mild', isSelected: true),
              ProductAttribute(name: 'Medium'),
              ProductAttribute(name: 'Hot'),
              ProductAttribute(name: 'Extra Hot'),
            ],
          ),
          AttributeGroup(
            groupName: 'Rice Portion',
            options: [
              ProductAttribute(name: 'Regular', isSelected: true),
              ProductAttribute(name: 'Large', additionalCost: 3.0),
              ProductAttribute(name: 'Extra Large', additionalCost: 5.0),
            ],
          ),
        ],
      ),
    ];

    _categories = ['All', 'Food', 'Drinks', 'الدجاج'];
    _selectedCategory = 'All';

    // Sample customers
    _customers = [
      Customer(id: '1', name: 'Administrator', email: 'admin@example.com'),
      Customer(id: '2', name: 'Ali Naji', phone: '0551111111'),
      Customer(id: '3', name: 'John Doe'),
      Customer(id: '4', name: 'Saqer'),
    ];

    // Sample registers
    _registers = [
      POSRegister(
        id: '1',
        name: 'Restaurant',
        status: 'Opening Control',
        closingDate: DateTime(2025, 7, 7),
        closingBalance: 0.00,
      ),
      POSRegister(
        id: '2',
        name: 'shop1',
        status: 'Closing',
        closingDate: DateTime(2025, 12, 8),
        closingBalance: 0.00,
      ),
    ];
  }

  // User authentication
  void login(String email, String password) {
    // Simple authentication - in real app, validate against server
    _currentUser = email.split('@')[0];
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _currentRegister = null;
    clearOrder();
    notifyListeners();
  }

  // Register management
  void selectRegister(POSRegister register) {
    _currentRegister = register;
    notifyListeners();
  }

  // Category selection
  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  List<Product> getFilteredProducts() {
    if (_selectedCategory == 'All' || _selectedCategory.isEmpty) {
      return _products;
    }
    return _products.where((product) => product.category == _selectedCategory).toList();
  }

  // Order management
  void addProductToOrder(Product product) {
    final existingItemIndex = _orderItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingItemIndex >= 0) {
      _orderItems[existingItemIndex].incrementQuantity();
    } else {
      _orderItems.add(OrderItem(product: product));
    }
    notifyListeners();
  }

  void removeItemFromOrder(int index) {
    if (index >= 0 && index < _orderItems.length) {
      _orderItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateItemQuantity(int index, int quantity) {
    if (index >= 0 && index < _orderItems.length) {
      if (quantity <= 0) {
        _orderItems.removeAt(index);
      } else {
        _orderItems[index].setQuantity(quantity);
      }
      notifyListeners();
    }
  }

  void clearOrder() {
    _orderItems.clear();
    _selectedCustomer = null;
    _payments.clear();
    notifyListeners();
  }

  // Customer management
  void selectCustomer(Customer customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void addCustomer(Customer customer) {
    _customers.add(customer);
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index >= 0) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  void removeCustomer(String customerId) {
    _customers.removeWhere((customer) => customer.id == customerId);
    if (_selectedCustomer?.id == customerId) {
      _selectedCustomer = null;
    }
    notifyListeners();
  }

  // Payment management
  void addPayment(String method, double amount) {
    _payments[method] = (_payments[method] ?? 0) + amount;
    notifyListeners();
  }

  void removePayment(String method) {
    _payments.remove(method);
    notifyListeners();
  }

  void clearPayments() {
    _payments.clear();
    notifyListeners();
  }

  // Table management
  void setTableNumber(String tableNumber) {
    _tableNumber = tableNumber;
    notifyListeners();
  }

  // Search functionality
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return getFilteredProducts();
    
    return getFilteredProducts().where((product) =>
      product.name.toLowerCase().contains(query.toLowerCase()) ||
      product.category.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) return _customers;
    
    return _customers.where((customer) =>
      customer.name.toLowerCase().contains(query.toLowerCase()) ||
      (customer.email?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
      (customer.phone?.contains(query) ?? false)
    ).toList();
  }
}
