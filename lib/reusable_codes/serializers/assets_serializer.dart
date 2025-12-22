import 'dart:convert';

import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> assetToJson(Asset asset) {
  return {
    'id': asset.id,
    'assetName': asset.assetName,
    'assetType': asset.assetType,
    'assetSubType': asset.assetSubType,
    'assetCode': asset.assetCode,
    'assetSerialNo': asset.assetSerialNo,
    'acquisitionDate': asset.acquisitionDate?.toIso8601String(),
    'acquisitionCost': asset.acquisitionCost,
    'acquisitionMethod': asset.acquisitionMethod,
    'department': asset.department,
    'location': asset.location,
    'depreciationRate': asset.depreciationRate,
    'depreciationMethod': asset.depreciationMethod,
    'lastDepreciationDate': asset.lastDepreciationDate?.toIso8601String(),
    'accumulatedDepreciation': asset.accumulatedDepreciation,
    'bookValue': asset.bookValue,
    'isImpaired': asset.isImpaired,
    'impairmentLoss': asset.impairmentLoss,
    'revaluationDate': asset.revaluationDate?.toIso8601String(),
    'revaluationAmount': asset.revaluationAmount,
    'lastMaintenanceDate': asset.lastMaintenanceDate?.toIso8601String(),
    'maintenanceCost': asset.maintenanceCost,
    'maintenanceDescription': asset.maintenanceDescription,
    'capitalImprovementCost': asset.capitalImprovementCost,
    'capitalImprovementDescription': asset.capitalImprovementDescription,
    'disposalDate': asset.disposalDate?.toIso8601String(),
    'disposalProceeds': asset.disposalProceeds,
    'disposalReason': asset.disposalReason,
    'gainOrLossOnDisposal': asset.gainOrLossOnDisposal,
    'isLeased': asset.isLeased,
    'leaseType': asset.leaseType,
    'leaseStartDate': asset.leaseStartDate?.toIso8601String(),
    'leaseEndDate': asset.leaseEndDate?.toIso8601String(),
    'leasePaymentAmount': asset.leasePaymentAmount,
    'lastAuditDate': asset.lastAuditDate?.toIso8601String(),
    'syncStatus': asset.syncStatus,
    'notes': asset.notes,
    'createdAt': asset.createdAt?.toIso8601String(),
    'lastModified': asset.lastModified?.toIso8601String(),
    'operationType': asset.operationType,
    'usefulLife': asset.usefulLife,
    'hasDebitBalance': asset.hasDebitBalance,
    'hasCreditBalance': asset.hasCreditBalance,
    'option': asset.option,
    'modifiedFields': asset.modifiedFields != null
        ? jsonEncode(asset.modifiedFields) // JSON encode the list
        : null,
  };
}

Asset assetFromJson(Map<String, dynamic> json) {
  return Asset(
    id: json['id'],
    assetName: json['assetName'],
    assetType: json['assetType'],
    assetSubType: json['assetSubType'],
    assetCode: json['assetCode'],
    assetSerialNo: json['assetSerialNo'],
    acquisitionDate: json['acquisitionDate'] != null
        ? DateTime.parse(json['acquisitionDate'])
        : null,
    acquisitionCost: (json['acquisitionCost'] as num?)?.toDouble(),
    acquisitionMethod: json['acquisitionMethod'],
    department: json['department'],
    location: json['location'],
    depreciationRate: (json['depreciationRate'] as num?)?.toDouble(),
    depreciationMethod: json['depreciationMethod'],
    lastDepreciationDate: json['lastDepreciationDate'] != null
        ? DateTime.parse(json['lastDepreciationDate'])
        : null,
    accumulatedDepreciation:
        (json['accumulatedDepreciation'] as num?)?.toDouble(),
    bookValue: (json['bookValue'] as num?)?.toDouble(),
    isImpaired: json['isImpaired'],
    impairmentLoss: (json['impairmentLoss'] as num?)?.toDouble(),
    revaluationDate: json['revaluationDate'] != null
        ? DateTime.parse(json['revaluationDate'])
        : null,
    revaluationAmount: (json['revaluationAmount'] as num?)?.toDouble(),
    lastMaintenanceDate: json['lastMaintenanceDate'] != null
        ? DateTime.parse(json['lastMaintenanceDate'])
        : null,
    maintenanceCost: (json['maintenanceCost'] as num?)?.toDouble(),
    maintenanceDescription: json['maintenanceDescription'],
    capitalImprovementCost:
        (json['capitalImprovementCost'] as num?)?.toDouble(),
    capitalImprovementDescription: json['capitalImprovementDescription'],
    disposalDate: json['disposalDate'] != null
        ? DateTime.parse(json['disposalDate'])
        : null,
    disposalProceeds: (json['disposalProceeds'] as num?)?.toDouble(),
    disposalReason: json['disposalReason'],
    gainOrLossOnDisposal: (json['gainOrLossOnDisposal'] as num?)?.toDouble(),
    isLeased: json['isLeased'],
    leaseType: json['leaseType'],
    leaseStartDate: json['leaseStartDate'] != null
        ? DateTime.parse(json['leaseStartDate'])
        : null,
    leaseEndDate: json['leaseEndDate'] != null
        ? DateTime.parse(json['leaseEndDate'])
        : null,
    leasePaymentAmount: (json['leasePaymentAmount'] as num?)?.toDouble(),
    lastAuditDate: json['lastAuditDate'] != null
        ? DateTime.parse(json['lastAuditDate'])
        : null,
    syncStatus: json['syncStatus'],
    notes: json['notes'],
    createdAt:
        json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    usefulLife: json['usefulLife'],
    hasDebitBalance: json['hasDebitBalance'],
    hasCreditBalance: json['hasCreditBalance'],
    option: json['option'],
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}
