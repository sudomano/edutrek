import 'dart:convert';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/reusable_codes/serializers/batch_unit_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/stock_unit_type_serializer.dart';

// ==================== PRODUCT BATCH SERIALIZER ====================

Map<String, dynamic> productBatchesToJson(ProductBatch productBatch) => {
      'batchCode': productBatch.batchCode,
      'productCode': productBatch.productCode,
      'reference': productBatch.reference,
      'baseUnitType': productBatch.baseUnitType != null
          ? stockUnitTypeToString(productBatch.baseUnitType!)
          : null,
      'baseUnit': productBatch.baseUnit,
      'units': productBatch.units != null
          ? productBatch.units!.map((unit) => batchUnitToJson(unit)).toList()
          : null,
      'totalBaseUnits': productBatch.totalBaseUnits,
      'remainingBaseUnits': productBatch.remainingBaseUnits,
      'totalBuyingCost': productBatch.totalBuyingCost,
      'purchaseDate': productBatch.purchaseDate?.toIso8601String(),
      'createdAt': productBatch.createdAt?.toIso8601String(),
      'syncStatus': productBatch.syncStatus,
      'lastModified': productBatch.lastModified?.toIso8601String(),
      'operationType': productBatch.operationType,
      'modifiedFields': productBatch.modifiedFields != null
          ? jsonEncode(productBatch.modifiedFields)
          : null,
      'baseUnitSize': productBatch.baseUnitSize,
    };

ProductBatch productBatchesFromJson(Map<String, dynamic> json) => ProductBatch(
      batchCode: json['batchCode'],
      productCode: json['productCode'],
      reference: json['reference'],
      baseUnitType: json['baseUnitType'] != null
          ? stringToStockUnitType(json['baseUnitType'])
          : null,
      baseUnit: json['baseUnit'],
      units: json['units'] != null
          ? (json['units'] as List)
              .map((unitJson) => batchUnitFromJson(unitJson))
              .toList()
          : null,
      totalBaseUnits: _toDouble(json['totalBaseUnits']),
      remainingBaseUnits: _toDouble(json['remainingBaseUnits']),
      totalBuyingCost: _toDouble(json['totalBuyingCost']),
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'])
          : null,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      syncStatus: json['syncStatus'] ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'] ?? 'sync',
      modifiedFields: json['modifiedFields'] != null
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : null,
      baseUnitSize: _toDouble(json['baseUnitSize']),
    );

// List serializers
String productBatchListToJson(List<ProductBatch> batches) {
  return jsonEncode(
      batches.map((batch) => productBatchesToJson(batch)).toList());
}

List<ProductBatch> productBatchListFromJson(String jsonStr) {
  final List<dynamic> jsonList = jsonDecode(jsonStr);
  return jsonList
      .map((json) => productBatchesFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

// Sync payload (lighter version for network)
Map<String, dynamic> productBatchToSyncPayload(ProductBatch batch) {
  return {
    'batchCode': batch.batchCode,
    'productCode': batch.productCode,
    'reference': batch.reference,
    'baseUnitType': batch.baseUnitType != null
        ? stockUnitTypeToString(batch.baseUnitType!)
        : null,
    'baseUnit': batch.baseUnit,
    'totalBaseUnits': batch.totalBaseUnits,
    'remainingBaseUnits': batch.remainingBaseUnits,
    'totalBuyingCost': batch.totalBuyingCost,
    'purchaseDate': batch.purchaseDate?.toIso8601String(),
    'operationType': batch.operationType,
    'modifiedFields': batch.modifiedFields,
    'baseUnitSize': batch.baseUnitSize,
  };
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
