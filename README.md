# Flutter POS Application

A comprehensive Point of Sale (POS) application built with Flutter, implementing the design and functionality specified in the JSON schema provided. This application faithfully recreates the Odoo POS interface with modern Flutter widgets and best practices.

## Features

### 🔐 Authentication
- **Login Screen**: Email/password authentication with validation
- **User Management**: Current user display and logout functionality
- **Session Management**: Maintains user state throughout the application

### 🏪 POS Dashboard
- **Register Selection**: Visual cards showing different POS registers
- **Status Indicators**: Color-coded status displays (Opening Control, Closing, etc.)
- **Register Information**: Closing dates, balances, and register details

### 🛒 Main POS Interface
- **Product Catalog**: Grid view of products with categories and attribute indicators
- **Category Filtering**: Tab-based category selection (Food, Drinks, etc.)
- **Search Functionality**: Real-time product search
- **Product Interactions**:
  - **Main Card Tap**: Opens attribute selection popup for customizable products
  - **Info Icon Tap**: Shows detailed product information popup
  - **Attribute Selection**: Dynamic product customization with pricing updates
- **Order Management**: Add/remove items, quantity controls with attribute support
- **Price Calculation**: Automatic tax calculation (15% VAT) including attribute costs
- **Customer Selection**: Link customers to orders
- **Table Management**: Table number display and management

### 💳 Payment Processing
- **Multiple Payment Methods**: Card, Cash, Mobile Payment, Bank Transfer
- **Payment Validation**: Real-time payment amount calculation
- **Remaining Balance**: Clear display of payment status
- **Invoice Options**: Optional invoice generation
- **Payment History**: Track multiple payment methods per order

### 🧾 Receipt Generation
- **Professional Receipt Layout**: Tax invoice format with QR code placeholder
- **Order Details**: Complete itemized breakdown
- **Tax Information**: Untaxed amount, VAT breakdown, total
- **Payment Information**: Payment method and amount details
- **Email Functionality**: Send receipts via email
- **Print Support**: Print receipt functionality

### 👥 Customer Management
- **Customer Database**: Complete customer information management
- **Contact Details**: Phone, email, address information
- **Business Information**: Company details, VAT numbers, job positions
- **Address Management**: Complete address fields including Saudi-specific fields
- **Customer Search**: Real-time search through customer database
- **Customer Selection**: Easy customer selection for orders

### ⚙️ Advanced Features
- **Actions Menu**: Complete actions dialog with order management options
- **Product Information Popups**: Detailed inventory, financial, and order data
- **Attribute Selection System**: Dynamic product customization with real-time pricing
- **Numpad Widget**: Professional calculator-style numpad
- **Responsive Design**: Optimized for desktop and tablet interfaces
- **State Management**: Provider pattern for robust state management
- **Navigation**: Structured routing between all screens

### 🎯 Product Interaction Features
- **Dual Interaction Points**: Main card tap for selection, info icon for details
- **Visual Indicators**: Attribute availability indicators on product cards
- **Dynamic Pricing**: Real-time price calculation with attribute costs
- **Comprehensive Product Data**: Inventory levels, costs, margins, and forecasting
- **Customization Options**: Multi-group attribute selection (sizes, sides, etc.)
- **VAT Integration**: Automatic tax calculation with attribute modifications

## Technical Implementation

### Architecture
- **State Management**: Provider pattern for reactive state updates
- **Navigation**: Named routes with proper screen transitions
- **Theme System**: Consistent styling matching Odoo's design language
- **Data Models**: Strongly typed models for all entities

### Design System
- **Primary Color**: #5D377B (Odoo purple)
- **Secondary Color**: #A0A0A0 (Gray)
- **Background**: #F5F5F5 (Light gray)
- **Typography**: OpenSans-like font family
- **Components**: Rounded corners, consistent padding, modern shadows

### Key Dependencies
- `provider`: State management
- `intl`: Internationalization and formatting
- `flutter/material`: Material Design components

## 📦 New Features - Product Interaction System

### 🔍 Product Information Popup
Based on the `product_information_popup` specification in popup.json:
- **Inventory Section**: Real-time stock levels and forecasting
- **Financials Section**: Cost analysis, pricing, and margin calculations
- **Order Section**: Current order totals and profitability
- **Professional Layout**: Clean, organized information display
- **Action Buttons**: Ok/Edit functionality

### 🎛️ Attribute Selection Popup
Following the `attribute_selection_popup` design from popup.json:
- **Header Section**: Product name, price, and VAT information with special background
- **Attribute Groups**: Organized selection options (Sides, Drinks, Sizes, etc.)
- **Radio Button Selection**: Single-choice attribute selection
- **Dynamic Pricing**: Real-time price updates with attribute costs
- **Visual Feedback**: Clear selection states and additional cost display

### 🃏 Enhanced Product Cards
- **Information Icon**: Top-right corner info button for product details
- **Attribute Indicator**: Visual badge showing products with customization options
- **Dual Interaction**: Main card tap vs. info icon tap functionality
- **Professional Styling**: Elevated design with shadows and proper spacing

## Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Windows, macOS, or Linux development environment

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flutter_pos
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run -d windows  # For Windows
   flutter run -d macos    # For macOS
   flutter run -d linux    # For Linux
   ```

### Testing

Run the test suite:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── theme/
│   └── app_theme.dart                 # Theme configuration
├── models/
│   ├── product.dart                   # Product data model
│   ├── order_item.dart               # Order item model
│   ├── customer.dart                 # Customer and address models
│   └── pos_register.dart             # POS register model
├── providers/
│   └── pos_provider.dart             # State management
├── screens/
│   ├── login_screen.dart             # Authentication screen
│   ├── pos_dashboard_screen.dart     # Register selection
│   ├── main_pos_screen.dart          # Main POS interface
│   ├── payment_screen.dart           # Payment processing
│   ├── receipt_screen.dart           # Receipt display
│   └── customer_management_screen.dart # Customer management
└── widgets/
    ├── numpad_widget.dart            # Calculator numpad
    ├── actions_menu_dialog.dart      # Actions menu
    └── customer_form_dialog.dart     # Customer form
```

## Sample Data

The application includes comprehensive sample data:
- **Products**: Green Tea, Spicy Tuna Sandwich, Bacon Burger, etc.
- **Categories**: Food, Drinks, الدجاج (Arabic category)
- **Customers**: Administrator, Ali Naji, John Doe, Saqer
- **Registers**: Restaurant (Opening Control), shop1 (Closing)

## Features Matching JSON Schema

✅ **Login Screen**: Complete implementation with logo, fields, and styling  
✅ **POS Dashboard**: Register cards with status indicators and actions  
✅ **Main POS Screen**: Product grid, categories, order summary, numpad  
✅ **Payment Screen**: Multiple payment methods, amount calculation  
✅ **Receipt Screen**: Professional receipt layout with all details  
✅ **Customer Management**: Full CRUD operations with tabbed form  
✅ **Actions Menu**: Complete actions dialog with all specified options  
✅ **Styling**: Exact color scheme and UI elements from JSON  

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Design based on Odoo POS system
- Built with Flutter framework
- Uses Material Design principles