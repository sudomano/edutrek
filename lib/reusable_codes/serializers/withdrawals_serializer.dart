import 'dart:convert';

import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> withdrawalsToJson(Withdrawal cls) {
  return {
    'id': cls.id,
    'amount': cls.amount,
    'withdrawalPurpose': cls.withdrawalPurpose,
    'withdrawalCode': cls.withdrawalCode,
    'termId': cls.termId,
    'date': cls.date.toIso8601String(),
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

Withdrawal withdrawalsFromJson(Map<String, dynamic> json) {
  return Withdrawal(
    id: json['id'], // Matches 'amount' in the toJson

    amount: json['amount'], // Matches 'amount' in the toJson
    withdrawalPurpose:
        json['withdrawalPurpose'], // Added to match withdrawalPurpose
    termId: json['termId'], // Matches 'termId' in the toJson
    withdrawalCode: json['withdrawalCode'],
    // Parsing 'date' as DateTime
    date: DateTime.parse(json['date']), // Fixed 'withdrawalDate' to 'date'

    syncStatus: json['syncStatus'], // Matches 'syncStatus'

    // Handling nullable lastModified
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,

    operationType: json['operationType'],
    modifiedFields: parseStringList(json['modifiedFields']),
    // Matches 'operationType'
  );
}
