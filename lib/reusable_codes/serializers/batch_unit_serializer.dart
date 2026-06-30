import 'dart:convert';
import 'package:zitf_system/database/projects/unitbatching.dart';
import 'package:zitf_system/reusable_codes/serializers/packaging_level_serializer.dart';

// ==================== BATCH UNIT SERIALIZER ====================

Map<String, dynamic> batchUnitToJson(BatchUnit batchUnit) => {
      'unitBatchCode': batchUnit.unitBatchCode,
      'level': packagingLevelToString(batchUnit.level),
      'unitsPerPackage': batchUnit.unitsPerPackage,
      'quantity': batchUnit.quantity,
      'buyingPrice': batchUnit.buyingPrice,
      'syncStatus': batchUnit.syncStatus,
      'lastModified': batchUnit.lastModified?.toIso8601String(),
      'operationType': batchUnit.operationType,
      'modifiedFields': batchUnit.modifiedFields != null
          ? jsonEncode(batchUnit.modifiedFields)
          : null,
    };

BatchUnit batchUnitFromJson(Map<String, dynamic> json) => BatchUnit(
      level: stringToPackagingLevel(json['level']),
      unitsPerPackage: _toDouble(json['unitsPerPackage']),
      quantity: json['quantity'] ?? 0,
      buyingPrice: _toDouble(json['buyingPrice']),
      syncStatus: json['syncStatus'] ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'] ?? 'sync',
      modifiedFields: json['modifiedFields'] != null
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : null,
      unitBatchCode: json['unitBatchCode'],
    );

// List serializers
String batchUnitListToJson(List<BatchUnit> units) {
  return jsonEncode(units.map((unit) => batchUnitToJson(unit)).toList());
}

List<BatchUnit> batchUnitListFromJson(String jsonStr) {
  final List<dynamic> jsonList = jsonDecode(jsonStr);
  return jsonList
      .map((json) => batchUnitFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
