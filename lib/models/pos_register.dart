class POSRegister {
  final String id;
  final String name;
  final String status;
  final DateTime? closingDate;
  final double closingBalance;

  POSRegister({
    required this.id,
    required this.name,
    required this.status,
    this.closingDate,
    this.closingBalance = 0.0,
  });

  factory POSRegister.fromJson(Map<String, dynamic> json) {
    return POSRegister(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      closingDate: json['closingDate'] != null 
          ? DateTime.parse(json['closingDate']) 
          : null,
      closingBalance: json['closingBalance']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'closingDate': closingDate?.toIso8601String(),
      'closingBalance': closingBalance,
    };
  }
}
