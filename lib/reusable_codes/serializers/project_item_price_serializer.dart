import 'dart:convert';
import 'package:zitf_system/database/projects/project_item_price_model.dart';

// ==================== PROJECT ITEM PRICE SERIALIZER ====================

Map<String, dynamic> projectItemPriceToJson(ProjectItemPrice price) => {
      'priceCode': price.priceCode,
      'projectItemCode': price.projectItemCode,
      'amount': price.amount,
      'pricingType': price.pricingType,
      'appliesTo': price.appliesTo,
      'effectiveFrom': price.effectiveFrom.toIso8601String(),
      'effectiveTo': price.effectiveTo?.toIso8601String(),
      'syncStatus': price.syncStatus,
      'lastModified': price.lastModified?.toIso8601String(),
      'operationType': price.operationType,
      'modifiedFields': price.modifiedFields != null
          ? jsonEncode(price.modifiedFields)
          : null,
    };

ProjectItemPrice projectItemPriceFromJson(Map<String, dynamic> json) =>
    ProjectItemPrice(
      priceCode: json['priceCode'],
      projectItemCode: json['projectItemCode'],
      amount: _toDouble(json['amount']),
      pricingType: json['pricingType'] ?? 'per_unit',
      appliesTo: json['appliesTo'],
      effectiveFrom: DateTime.parse(json['effectiveFrom']),
      effectiveTo: json['effectiveTo'] != null
          ? DateTime.parse(json['effectiveTo'])
          : null,
      syncStatus: json['syncStatus'] ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'] ?? 'sync',
      modifiedFields: json['modifiedFields'] != null
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : null,
    );

// List serializers
String projectItemPriceListToJson(List<ProjectItemPrice> prices) {
  return jsonEncode(
      prices.map((price) => projectItemPriceToJson(price)).toList());
}

List<ProjectItemPrice> projectItemPriceListFromJson(String jsonStr) {
  final List<dynamic> jsonList = jsonDecode(jsonStr);
  return jsonList
      .map((json) => projectItemPriceFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

// Sync payload
Map<String, dynamic> projectItemPriceToSyncPayload(ProjectItemPrice price) {
  return {
    'priceCode': price.priceCode,
    'projectItemCode': price.projectItemCode,
    'amount': price.amount,
    'pricingType': price.pricingType,
    'appliesTo': price.appliesTo,
    'effectiveFrom': price.effectiveFrom.toIso8601String(),
    'effectiveTo': price.effectiveTo?.toIso8601String(),
    'operationType': price.operationType,
    'modifiedFields': price.modifiedFields,
  };
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
