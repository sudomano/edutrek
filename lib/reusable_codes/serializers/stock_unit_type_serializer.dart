import 'dart:convert';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

// Convert enum to string
String stockUnitTypeToString(StockUnitType type) {
  return type.toString().split('.').last;
}

// Convert string to enum
StockUnitType stringToStockUnitType(String value) {
  return StockUnitType.values.firstWhere(
    (e) => e.toString().split('.').last == value,
    orElse: () => StockUnitType.piece,
  );
}

// JSON serialization
Map<String, dynamic> stockUnitTypeToJson(StockUnitType type) => {
      'value': stockUnitTypeToString(type),
    };

StockUnitType stockUnitTypeFromJson(Map<String, dynamic> json) {
  return stringToStockUnitType(json['value']);
}
