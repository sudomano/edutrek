import 'dart:convert';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/reusable_codes/serializers/packaging_level_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/stock_unit_type_serializer.dart';

// ==================== BATCH SELL UNIT SERIALIZER ====================

Map<String, dynamic> batchSellUnitToJson(BatchSellUnit sellUnit) => {
      'sellUnitCode': sellUnit.sellUnitCode,
      'batchCode': sellUnit.batchCode,
      'unitName': sellUnit.unitName,
      'quantityMultiplier': sellUnit.quantityMultiplier,
      'sellingPrice': sellUnit.sellingPrice,
      'active': sellUnit.active,
      'deletedAt': sellUnit.deletedAt?.toIso8601String(),
      'syncStatus': sellUnit.syncStatus,
      'lastModified': sellUnit.lastModified?.toIso8601String(),
      'operationType': sellUnit.operationType,
      'modifiedFields': sellUnit.modifiedFields != null
          ? jsonEncode(sellUnit.modifiedFields)
          : null,
      'packagingLevel': sellUnit.packagingLevel != null
          ? packagingLevelToString(sellUnit.packagingLevel!)
          : null,
      'baseUnitsPerSellUnit': sellUnit.baseUnitsPerSellUnit,
      'baseUnit': sellUnit.baseUnit,
      'baseUnitType': sellUnit.baseUnitType != null
          ? stockUnitTypeToString(sellUnit.baseUnitType!)
          : null,
    };

BatchSellUnit batchSellUnitFromJson(Map<String, dynamic> json) => BatchSellUnit(
      sellUnitCode: json['sellUnitCode'],
      batchCode: json['batchCode'],
      unitName: json['unitName'],
      quantityMultiplier: json['quantityMultiplier'] ?? 1,
      sellingPrice: _toDouble(json['sellingPrice']),
      active: json['active'] ?? true,
      deletedAt:
          json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
      syncStatus: json['syncStatus'] ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'] ?? 'sync',
      modifiedFields: json['modifiedFields'] != null
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : null,
      packagingLevel: json['packagingLevel'] != null
          ? stringToPackagingLevel(json['packagingLevel'])
          : null,
      baseUnitsPerSellUnit: _toDouble(json['baseUnitsPerSellUnit']),
      baseUnit: json['baseUnit'],
      baseUnitType: json['baseUnitType'] != null
          ? stringToStockUnitType(json['baseUnitType'])
          : null,
    );

// List serializers
String batchSellUnitListToJson(List<BatchSellUnit> sellUnits) {
  return jsonEncode(
      sellUnits.map((unit) => batchSellUnitToJson(unit)).toList());
}

List<BatchSellUnit> batchSellUnitListFromJson(String jsonStr) {
  final List<dynamic> jsonList = jsonDecode(jsonStr);
  return jsonList
      .map((json) => batchSellUnitFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

// Sync payload
Map<String, dynamic> batchSellUnitToSyncPayload(BatchSellUnit sellUnit) {
  return {
    'sellUnitCode': sellUnit.sellUnitCode,
    'batchCode': sellUnit.batchCode,
    'unitName': sellUnit.unitName,
    'quantityMultiplier': sellUnit.quantityMultiplier,
    'sellingPrice': sellUnit.sellingPrice,
    'active': sellUnit.active,
    'packagingLevel': sellUnit.packagingLevel != null
        ? packagingLevelToString(sellUnit.packagingLevel!)
        : null,
    'baseUnitsPerSellUnit': sellUnit.baseUnitsPerSellUnit,
    'baseUnit': sellUnit.baseUnit,
    'baseUnitType': sellUnit.baseUnitType != null
        ? stockUnitTypeToString(sellUnit.baseUnitType!)
        : null,
    'operationType': sellUnit.operationType,
    'modifiedFields': sellUnit.modifiedFields,
  };
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
