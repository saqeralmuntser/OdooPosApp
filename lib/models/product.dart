class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String? image;
  final double vatRate;
  final List<AttributeGroup> attributes;
  final ProductInventory inventory;
  final ProductFinancials financials;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.image,
    this.vatRate = 0.15, // 15% VAT
    this.attributes = const [],
    required this.inventory,
    required this.financials,
  });

  double get vatAmount => price * vatRate;
  double get priceIncludingVat => price + vatAmount;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: json['price']?.toDouble() ?? 0.0,
      category: json['category'] ?? '',
      image: json['image'],
      vatRate: json['vatRate']?.toDouble() ?? 0.15,
      attributes: (json['attributes'] as List<dynamic>?)
          ?.map((attr) => AttributeGroup.fromJson(attr))
          .toList() ?? [],
      inventory: ProductInventory.fromJson(json['inventory'] ?? {}),
      financials: ProductFinancials.fromJson(json['financials'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'image': image,
      'vatRate': vatRate,
      'attributes': attributes.map((attr) => attr.toJson()).toList(),
      'inventory': inventory.toJson(),
      'financials': financials.toJson(),
    };
  }
}

class AttributeGroup {
  final String groupName;
  final List<ProductAttribute> options;

  AttributeGroup({
    required this.groupName,
    required this.options,
  });

  factory AttributeGroup.fromJson(Map<String, dynamic> json) {
    return AttributeGroup(
      groupName: json['groupName'] ?? '',
      options: (json['options'] as List<dynamic>?)
          ?.map((option) => ProductAttribute.fromJson(option))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'options': options.map((option) => option.toJson()).toList(),
    };
  }
}

class ProductAttribute {
  final String name;
  final bool isSelected;
  final double? additionalCost;

  ProductAttribute({
    required this.name,
    this.isSelected = false,
    this.additionalCost,
  });

  ProductAttribute copyWith({
    String? name,
    bool? isSelected,
    double? additionalCost,
  }) {
    return ProductAttribute(
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      additionalCost: additionalCost ?? this.additionalCost,
    );
  }

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      name: json['name'] ?? '',
      isSelected: json['isSelected'] ?? false,
      additionalCost: json['additionalCost']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isSelected': isSelected,
      'additionalCost': additionalCost,
    };
  }
}

class ProductInventory {
  final String companyLabel;
  final int unitsAvailable;
  final int forecasted;

  ProductInventory({
    this.companyLabel = "My Company :",
    this.unitsAvailable = 0,
    this.forecasted = 0,
  });

  factory ProductInventory.fromJson(Map<String, dynamic> json) {
    return ProductInventory(
      companyLabel: json['companyLabel'] ?? "My Company :",
      unitsAvailable: json['unitsAvailable'] ?? 0,
      forecasted: json['forecasted'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyLabel': companyLabel,
      'unitsAvailable': unitsAvailable,
      'forecasted': forecasted,
    };
  }
}

class ProductFinancials {
  final double priceExclTax;
  final double cost;
  final double totalPriceExclTax;
  final double totalCost;

  ProductFinancials({
    required this.priceExclTax,
    required this.cost,
    this.totalPriceExclTax = 0.0,
    this.totalCost = 0.0,
  });

  double get margin => priceExclTax - cost;
  double get marginPercentage => priceExclTax != 0 ? (margin / priceExclTax) * 100 : 0;
  double get totalMargin => totalPriceExclTax - totalCost;
  double get totalMarginPercentage => totalPriceExclTax != 0 ? (totalMargin / totalPriceExclTax) * 100 : 0;

  factory ProductFinancials.fromJson(Map<String, dynamic> json) {
    return ProductFinancials(
      priceExclTax: json['priceExclTax']?.toDouble() ?? 0.0,
      cost: json['cost']?.toDouble() ?? 0.0,
      totalPriceExclTax: json['totalPriceExclTax']?.toDouble() ?? 0.0,
      totalCost: json['totalCost']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'priceExclTax': priceExclTax,
      'cost': cost,
      'totalPriceExclTax': totalPriceExclTax,
      'totalCost': totalCost,
    };
  }
}
