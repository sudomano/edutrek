// reusable_codes/serializers/project_sale_transaction_serializer.dart

import 'dart:convert';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

Map<String, dynamic> projectSaleTransactionToJson(ProjectSaleTransaction tx) {
  return {
    'transactionCode': tx.transactionCode,
    'studentId': tx.studentId,
    'projectCode': tx.projectCode,
    'projectItemCode': tx.projectItemCode,
    'batchCode': tx.batchCode,
    'sellUnitCode': tx.sellUnitCode,
    'sellUnitNameSnapshot': tx.sellUnitNameSnapshot,
    'quantitySold': tx.quantitySold,
    'unitSellingPrice': tx.unitSellingPrice,
    'totalAmount': tx.totalAmount,
    'baseUnitsPerSellUnit': tx.baseUnitsPerSellUnit,
    'totalBaseUnitsSold': tx.totalBaseUnitsSold,
    'baseUnit': tx.baseUnit,
    'baseUnitType': tx.baseUnitType.name, // Convert enum to string
    'transactionDate': tx.transactionDate.toIso8601String(),
    'paymentMethod': tx.paymentMethod,
    'reference': tx.reference,
    'syncStatus': tx.syncStatus,
    'lastModified': tx.lastModified?.toIso8601String(),
    'operationType': tx.operationType,
    'modifiedFields':
        tx.modifiedFields != null ? jsonEncode(tx.modifiedFields) : null,
    'isDeleted': tx.isDeleted,
    'deletedAt': tx.deletedAt?.map((d) => d.toIso8601String()).toList(),
    'restoredAt': tx.restoredAt?.map((d) => d.toIso8601String()).toList(),
    'deletedByUsers': tx.deletedByUsers,
    'restoredByUsers': tx.restoredByUsers,
    'amountPaid': tx.amountPaid,
    'arrears': tx.arrears,
    'paymentMethodCode': tx.paymentMethodCode,
    'methodType': tx.methodType,
    'amountPaidInPaymentMethod': tx.amountPaidInPaymentMethod,
    'currency': tx.currency,
    'provider': tx.provider,
    'referenceNumber': tx.referenceNumber,
    'phoneNumber': tx.phoneNumber,
    'accountNumber': tx.accountNumber,
    'accountName': tx.accountName,
    'paymentDatetransacted': tx.paymentDatetransacted?.toIso8601String(),
    'isReversed': tx.isReversed,
    'lineTransactionCodes': tx.lineTransactionCodes != null
        ? jsonEncode(tx.lineTransactionCodes)
        : null,
    'financialType': tx.financialType,
    'parentTransactionCode': tx.parentTransactionCode,
    'affectsStock': tx.affectsStock,
    'createsObligation': tx.createsObligation,
    'settlesObligation': tx.settlesObligation,
  };
}

ProjectSaleTransaction projectSaleTransactionFromJson(
    Map<String, dynamic> json) {
  // Helper to parse StockUnitType from string
// ...existing code...
  StockUnitType _parseStockUnitType(dynamic value) {
    // Default to 'piece' which matches your enum values
    if (value == null) return StockUnitType.piece;

    // Accept numeric indices (0 -> first enum)
    if (value is int) {
      if (value >= 0 && value < StockUnitType.values.length) {
        return StockUnitType.values[value];
      }
      return StockUnitType.piece;
    }

    final s = value.toString().toLowerCase().trim();

    // Common textual mappings / legacy variants
    if (s == 'piece' ||
        s == 'pieces' ||
        s == 'unit' ||
        s == 'units' ||
        s == 'pc') {
      return StockUnitType.piece;
    }
    if (s == 'weight' ||
        s == 'kg' ||
        s == 'kgs' ||
        s == 'g' ||
        s == 'gram' ||
        s == 'grams') {
      return StockUnitType.weight;
    }
    if (s == 'volume' ||
        s == 'litre' ||
        s == 'litres' ||
        s == 'l' ||
        s == 'liter' ||
        s == 'liters') {
      return StockUnitType.volume;
    }

    // Fallback: try exact enum name match (case-insensitive)
    try {
      return StockUnitType.values.firstWhere(
        (e) => e.name.toLowerCase() == s,
        orElse: () => StockUnitType.piece,
      );
    } catch (_) {
      return StockUnitType.piece;
    }
  }
// ...existing code...

  // Helper to parse DateTime list
  List<DateTime>? _parseDateTimeList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => DateTime.parse(e.toString()))
          .toList();
    }
    return null;
  }

  // Helper to parse string list
  List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return List<String>.from(value);
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return List<String>.from(decoded);
        }
      } catch (_) {
        // Not JSON array, treat as single value
        return [value];
      }
    }
    return null;
  }

  return ProjectSaleTransaction(
    transactionCode: json['transactionCode'] ?? '',
    studentId: json['studentId'] ?? '',
    projectCode: json['projectCode'] ?? '',
    projectItemCode: json['projectItemCode'] ?? '',
    batchCode: json['batchCode'] ?? '',
    sellUnitCode: json['sellUnitCode'] ?? '',
    sellUnitNameSnapshot: json['sellUnitNameSnapshot'] ?? '',
    quantitySold: json['quantitySold'] ?? 0,
    unitSellingPrice: (json['unitSellingPrice'] ?? 0.0).toDouble(),
    totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
    baseUnitsPerSellUnit: (json['baseUnitsPerSellUnit'] ?? 0.0).toDouble(),
    totalBaseUnitsSold: (json['totalBaseUnitsSold'] ?? 0.0).toDouble(),
    baseUnit: json['baseUnit'] ?? '',
    baseUnitType: _parseStockUnitType(json['baseUnitType']),
    transactionDate: json['transactionDate'] != null
        ? DateTime.parse(json['transactionDate'])
        : DateTime.now(),
    paymentMethod: json['paymentMethod'] ?? '',
    reference: json['reference'] ?? '',
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    modifiedFields: _parseStringList(json['modifiedFields']),
    isDeleted: json['isDeleted'] ?? false,
    deletedAt: _parseDateTimeList(json['deletedAt']),
    restoredAt: _parseDateTimeList(json['restoredAt']),
    deletedByUsers: _parseStringList(json['deletedByUsers']),
    restoredByUsers: _parseStringList(json['restoredByUsers']),
    amountPaid: (json['amountPaid'] ?? 0.0).toDouble(),
    arrears: (json['arrears'] ?? 0.0).toDouble(),
    paymentMethodCode: json['paymentMethodCode'],
    methodType: json['methodType'],
    amountPaidInPaymentMethod:
        (json['amountPaidInPaymentMethod'] as num?)?.toDouble(),
    currency: json['currency'],
    provider: json['provider'],
    referenceNumber: json['referenceNumber'],
    phoneNumber: json['phoneNumber'],
    accountNumber: json['accountNumber'],
    accountName: json['accountName'],
    paymentDatetransacted: json['paymentDatetransacted'] != null
        ? DateTime.parse(json['paymentDatetransacted'])
        : null,
    isReversed: json['isReversed'] ?? false,
    lineTransactionCodes: _parseStringList(json['lineTransactionCodes']),
    financialType: json['financialType'] ?? 'sale',
    parentTransactionCode: json['parentTransactionCode'],
    affectsStock: json['affectsStock'] ?? true,
    createsObligation: json['createsObligation'] ?? false,
    settlesObligation: json['settlesObligation'] ?? false,
  );
}
