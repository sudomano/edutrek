import 'dart:convert';

import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> termsToJson(Terms cls) {
  return {
    'id': cls.id,
    'termId': cls.termId,
    'termName': cls.termName,
    'startDate': cls.startDate.toIso8601String(),
    'endDate': cls.endDate?.toIso8601String(),
    'isActive': cls.isActive,
    'status': cls.status,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

Terms termsFromJson(Map<String, dynamic> json) {
  return Terms(
    id: json['id'],
    termId: json['termId'], // Adjusted to match termId
    termName: json['termName'],

    // Parsing startDate as DateTime
    startDate: DateTime.parse(json['startDate']),

    // endDate could be nullable, so we handle it safely
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,

    // Adjusted to match isActive field
    isActive: json['isActive'],

    // Adjusted to match status field
    status: json['status'],

    syncStatus: json['syncStatus'],

    // Handling nullable lastModified
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,

    operationType: json['operationType'],
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}
