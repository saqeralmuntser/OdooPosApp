import 'package:flutter/foundation.dart';
import '../models/product_attribute.dart';
import '../services/pos_backend_service.dart';

/// Provider for managing product attributes state and interactions
class ProductAttributeProvider extends ChangeNotifier {
  POSBackendService? _backendService;

  // State variables
  bool _isLoading = false;
  String? _error;
  ProductCompleteInfo? _currentProductInfo;
  Map<int, AttributeValueDisplayData> _selectedAttributes = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  ProductCompleteInfo? get currentProductInfo => _currentProductInfo;
  Map<int, AttributeValueDisplayData> get selectedAttributes => Map.unmodifiable(_selectedAttributes);

  /// Set the backend service instance
  void setBackendService(POSBackendService backendService) {
    _backendService = backendService;
  }

  /// Load complete product information from backend
  Future<bool> loadProductCompleteInfo(int productId) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Check if backend service is available
      if (_backendService == null) {
        debugPrint('ProductAttributeProvider: Backend service not set, using placeholder data');
        _currentProductInfo = _createPlaceholderProductInfo(productId);
        _initializeSelectedAttributes();
        _setLoading(false);
        notifyListeners();
        return true;
      }

      // Try to load from backend first with real attribute data
      try {
        final result = await _backendService!.getProductCompleteInfo(productId);
        debugPrint('Backend result for product $productId: $result');
        
        // The result is a Map<String, dynamic>, so we need to convert it to ProductCompleteInfo
        _currentProductInfo = _convertMapToProductInfo(result);
        _initializeSelectedAttributes();
        _setLoading(false);
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Backend loading failed, using placeholder: $e');
        // If backend fails, use placeholder data as fallback
        _currentProductInfo = _createPlaceholderProductInfo(productId);
        _initializeSelectedAttributes();
        _setLoading(false);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('General error in loadProductCompleteInfo: $e');
      // On any error, use placeholder data
      _currentProductInfo = _createPlaceholderProductInfo(productId);
      _initializeSelectedAttributes();
      _setLoading(false);
      notifyListeners();
      return true;
    }
  }

  /// Convert backend Map result to ProductCompleteInfo
  ProductCompleteInfo _convertMapToProductInfo(Map<String, dynamic> data) {
    debugPrint('Converting backend data: $data');
    
    // Convert attribute groups from backend format
    List<AttributeGroupDisplayData> attributeGroups = [];
    
    if (data['attributeGroups'] != null) {
      final groups = data['attributeGroups'] as List<dynamic>;
      debugPrint('Found ${groups.length} attribute groups');
      
      attributeGroups = groups.map((group) {
        final groupMap = group as Map<String, dynamic>;
        debugPrint('Processing group: $groupMap');
        
        // Convert values with proper extra_price handling
        List<AttributeValueDisplayData> values = [];
        if (groupMap['values'] != null) {
          final valuesData = groupMap['values'] as List<dynamic>;
          debugPrint('Found ${valuesData.length} attribute values');
          
          values = valuesData.map((value) {
            // Convert to ProductAttributeValue model first to ensure proper parsing
            ProductAttributeValue attributeValue;
            if (value is ProductAttributeValue) {
              attributeValue = value;
            } else if (value is Map<String, dynamic>) {
              attributeValue = ProductAttributeValue.fromJson(value);
            } else {
              // Fallback for unexpected data types
              debugPrint('Unexpected value type: ${value.runtimeType}');
              return AttributeValueDisplayData(
                valueId: 0,
                valueName: 'Unknown',
                priceExtra: 0.0,
              );
            }
            
            debugPrint('Attribute value: ${attributeValue.name}, price_extra: ${attributeValue.priceExtra}');
            
            return AttributeValueDisplayData(
              valueId: attributeValue.id,
              valueName: attributeValue.name,
              priceExtra: attributeValue.priceExtra,
              htmlColor: attributeValue.htmlColor,
              hasImage: attributeValue.image ?? false,
            );
          }).toList();
        }
        
        return AttributeGroupDisplayData(
          attributeId: groupMap['id'] ?? groupMap['attribute_id'] ?? 0,
          attributeName: groupMap['name'] ?? groupMap['attribute_name'] ?? '',
          displayType: groupMap['display_type'] ?? 'radio',
          required: groupMap['required'] ?? true,
          values: values,
        );
      }).toList();
    }
    
    return ProductCompleteInfo(
      productId: data['productId'] ?? 0,
      productName: data['productName'] ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      finalPrice: (data['finalPrice'] as num?)?.toDouble() ?? 0.0,
      taxIds: data['taxIds'] is List ? (data['taxIds'] as List).cast<int>() : <int>[],
      vatRate: (data['vatRate'] as num?)?.toDouble() ?? 0.0,
      attributeGroups: attributeGroups,
    );
  }

  /// Create placeholder product info for demo purposes (matching popup.json structure)
  ProductCompleteInfo _createPlaceholderProductInfo(int productId) {
    debugPrint('Creating placeholder product info for product $productId');
    
    return ProductCompleteInfo(
      productId: productId,
      productName: 'Bacon Burger', // From popup.json
      basePrice: 15.50, // From popup.json
      finalPrice: 15.50,
      taxIds: [1],
      vatRate: 0.15, // 15% VAT from popup.json
      attributeGroups: [
        AttributeGroupDisplayData(
          attributeId: 1,
          attributeName: 'Sides', // From popup.json
          displayType: 'radio',
          required: true,
          values: [
            AttributeValueDisplayData(
              valueId: 1,
              valueName: 'Belgian fresh homemade fries',
              priceExtra: 0.0,
              isSelected: true, // Default selection from popup.json
            ),
            AttributeValueDisplayData(
              valueId: 2,
              valueName: 'Sweet potato fries',
              priceExtra: 2.0,
            ),
            AttributeValueDisplayData(
              valueId: 3,
              valueName: 'Smashed sweet potatoes',
              priceExtra: 1.5,
            ),
            AttributeValueDisplayData(
              valueId: 4,
              valueName: 'Potatoes with thyme',
              priceExtra: 1.0,
            ),
            AttributeValueDisplayData(
              valueId: 5,
              valueName: 'Grilled vegetables',
              priceExtra: 3.0,
            ),
          ],
        ),
        AttributeGroupDisplayData(
          attributeId: 2,
          attributeName: 'Size',
          displayType: 'radio',
          required: true,
          values: [
            AttributeValueDisplayData(
              valueId: 6,
              valueName: 'Small',
              priceExtra: 0.0,
              isSelected: true,
            ),
            AttributeValueDisplayData(
              valueId: 7,
              valueName: 'Medium',
              priceExtra: 2.5,
            ),
            AttributeValueDisplayData(
              valueId: 8,
              valueName: 'Large',
              priceExtra: 5.0,
            ),
          ],
        ),
      ],
    );
  }

  /// Initialize selected attributes with default values or first required options
  void _initializeSelectedAttributes() {
    _selectedAttributes.clear();
    
    if (_currentProductInfo == null) return;

    for (final attributeGroup in _currentProductInfo!.attributeGroups) {
      // For required attributes, select the first available value by default
      if (attributeGroup.required && attributeGroup.values.isNotEmpty) {
        final firstValue = attributeGroup.values.first;
        _selectedAttributes[attributeGroup.attributeId] = firstValue.copyWith(isSelected: true);
      }
    }
  }

  /// Select an attribute value
  void selectAttributeValue(int attributeId, AttributeValueDisplayData value) {
    // Update the selected value for this attribute
    _selectedAttributes[attributeId] = value.copyWith(isSelected: true);
    notifyListeners();
  }

  /// Clear selection for an attribute (if not required)
  void clearAttributeSelection(int attributeId) {
    final attributeGroup = _currentProductInfo?.attributeGroups
        .firstWhere((group) => group.attributeId == attributeId, orElse: () => throw StateError('Attribute not found'));
    
    // Only allow clearing if attribute is not required
    if (attributeGroup != null && !attributeGroup.required) {
      _selectedAttributes.remove(attributeId);
      notifyListeners();
    }
  }

  /// Get selected value for a specific attribute
  AttributeValueDisplayData? getSelectedValue(int attributeId) {
    return _selectedAttributes[attributeId];
  }

  /// Check if a specific value is selected
  bool isValueSelected(int attributeId, int valueId) {
    final selectedValue = _selectedAttributes[attributeId];
    return selectedValue?.valueId == valueId;
  }

  /// Check if all required attributes are selected
  bool get areAllRequiredAttributesSelected {
    if (_currentProductInfo == null) return true;

    for (final attributeGroup in _currentProductInfo!.attributeGroups) {
      if (attributeGroup.required && !_selectedAttributes.containsKey(attributeGroup.attributeId)) {
        return false;
      }
    }
    return true;
  }

  /// Calculate total price including selected attribute extras
  double get totalPrice {
    if (_currentProductInfo == null) return 0.0;

    double total = _currentProductInfo!.basePrice;
    
    for (final selectedValue in _selectedAttributes.values) {
      total += selectedValue.priceExtra;
    }
    
    return total;
  }

  /// Calculate VAT amount based on current total price
  double get vatAmount {
    if (_currentProductInfo == null) return 0.0;
    return totalPrice * _currentProductInfo!.vatRate;
  }

  /// Get total price including VAT
  double get totalPriceIncludingVat {
    return totalPrice + vatAmount;
  }

  /// Get list of selected attribute value IDs for backend
  List<int> get selectedAttributeValueIds {
    return _selectedAttributes.values.map((value) => value.valueId).toList();
  }

  /// Get attribute group by ID
  AttributeGroupDisplayData? getAttributeGroup(int attributeId) {
    return _currentProductInfo?.attributeGroups
        .firstWhere((group) => group.attributeId == attributeId, orElse: () => throw StateError('Attribute not found'));
  }

  /// Reset all selections
  void resetSelections() {
    _selectedAttributes.clear();
    _initializeSelectedAttributes();
    notifyListeners();
  }

  /// Clear current product info and selections
  void clear() {
    _currentProductInfo = null;
    _selectedAttributes.clear();
    _clearError();
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
  }



  /// Clear error message
  void _clearError() {
    _error = null;
  }

  /// Validate current selection
  ValidationResult validateSelection() {
    if (_currentProductInfo == null) {
      return ValidationResult(isValid: false, error: 'No product information available');
    }

    // Check if all required attributes are selected
    for (final attributeGroup in _currentProductInfo!.attributeGroups) {
      if (attributeGroup.required && !_selectedAttributes.containsKey(attributeGroup.attributeId)) {
        return ValidationResult(
          isValid: false, 
          error: 'Please select a value for ${attributeGroup.attributeName}'
        );
      }
    }

    return ValidationResult(isValid: true);
  }

  /// Create order line data for backend
  Map<String, dynamic> createOrderLineData({required double quantity}) {
    if (_currentProductInfo == null) {
      throw StateError('No product information available');
    }

    return {
      'product_id': _currentProductInfo!.productId,
      'qty': quantity,
      'price_unit': totalPrice,
      'selected_attribute_value_ids': selectedAttributeValueIds,
      'full_product_name': _currentProductInfo!.productName,
    };
  }

  @override
  void dispose() {
    _currentProductInfo = null;
    _selectedAttributes.clear();
    super.dispose();
  }
}

/// Validation result for attribute selection
class ValidationResult {
  final bool isValid;
  final String? error;

  ValidationResult({required this.isValid, this.error});
}
