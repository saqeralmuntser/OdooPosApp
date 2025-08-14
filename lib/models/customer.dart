class Customer {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? website;
  final String? vatNumber;
  final String? jobPosition;
  final String? title;
  final List<String> tags;
  final Address? address;
  final String type; // 'Individual' or 'Company'
  final String? companyName;

  Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.mobile,
    this.website,
    this.vatNumber,
    this.jobPosition,
    this.title,
    this.tags = const [],
    this.address,
    this.type = 'Individual',
    this.companyName,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      mobile: json['mobile'],
      website: json['website'],
      vatNumber: json['vatNumber'],
      jobPosition: json['jobPosition'],
      title: json['title'],
      tags: List<String>.from(json['tags'] ?? []),
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      type: json['type'] ?? 'Individual',
      companyName: json['companyName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'mobile': mobile,
      'website': website,
      'vatNumber': vatNumber,
      'jobPosition': jobPosition,
      'title': title,
      'tags': tags,
      'address': address?.toJson(),
      'type': type,
      'companyName': companyName,
    };
  }
}

class Address {
  final String? street;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String? buildingNumber;
  final String? plotIdentification;

  Address({
    this.street,
    this.neighborhood,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.buildingNumber,
    this.plotIdentification,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      neighborhood: json['neighborhood'],
      city: json['city'],
      state: json['state'],
      zip: json['zip'],
      country: json['country'],
      buildingNumber: json['buildingNumber'],
      plotIdentification: json['plotIdentification'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'buildingNumber': buildingNumber,
      'plotIdentification': plotIdentification,
    };
  }
}
