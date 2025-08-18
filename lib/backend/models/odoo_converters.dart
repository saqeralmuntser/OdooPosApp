import 'package:json_annotation/json_annotation.dart';

/// Custom converter to handle Odoo's false values for string fields
/// In Odoo, empty string fields are often returned as `false` instead of `null`
class OdooStringConverter implements JsonConverter<String?, dynamic> {
  const OdooStringConverter();

  @override
  String? fromJson(dynamic json) {
    if (json == false || json == null) {
      return null;
    }
    return json as String?;
  }

  @override
  dynamic toJson(String? object) => object;
}

/// Custom converter to handle Odoo's false values for int fields  
/// In Odoo, empty int fields are often returned as `false` instead of `null`
class OdooIntConverter implements JsonConverter<int?, dynamic> {
  const OdooIntConverter();

  @override
  int? fromJson(dynamic json) {
    if (json == false || json == null) {
      return null;
    }
    return (json as num?)?.toInt();
  }

  @override
  dynamic toJson(int? object) => object;
}

/// Custom converter to handle Odoo's false values for double fields
/// In Odoo, empty double fields are often returned as `false` instead of `null`
class OdooDoubleConverter implements JsonConverter<double?, dynamic> {
  const OdooDoubleConverter();

  @override
  double? fromJson(dynamic json) {
    if (json == false || json == null) {
      return null;
    }
    return (json as num?)?.toDouble();
  }

  @override
  dynamic toJson(double? object) => object;
}

/// Custom converter to handle Odoo's false values for bool fields
/// In Odoo, empty bool fields are sometimes returned as `false`
class OdooBoolConverter implements JsonConverter<bool, dynamic> {
  const OdooBoolConverter();

  @override
  bool fromJson(dynamic json) {
    if (json == null) {
      return false;
    }
    return json as bool;
  }

  @override
  dynamic toJson(bool object) => object;
}
