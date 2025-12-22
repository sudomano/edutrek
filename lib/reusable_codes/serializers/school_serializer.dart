import 'dart:convert';

import 'package:zitf_system/database/school_info.dart';

///////////////////==== school ====///////////////////
School schoolFromJson(Map<String, dynamic> json) {
  return School(
    id: json['id'],
    schoolName: json['schoolName'],
    schoolCode: json['schoolCode'],
    schoolAddress: json['schoolAddress'],
    schoolPhoneNumber: json['schoolPhoneNumber'],
    schoolEmail: json['schoolEmail'],
    termId: json['termId'],
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    modifiedFields: _parseStringList(json['modifiedFields']),
  );
}

Map<String, dynamic> schoolToJson(School cls) {
  return {
    'id': cls.id,
    'schoolName': cls.schoolName,
    'schoolCode': cls.schoolCode,
    'schoolAddress': cls.schoolAddress,
    'schoolPhoneNumber': cls.schoolPhoneNumber,
    'schoolEmail': cls.schoolEmail,
    'termId': cls.termId,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'modifiedFields':
        cls.modifiedFields != null ? jsonEncode(cls.modifiedFields) : null,
  };
}

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  } else if (value is String) {
    return [value];
  } else {
    return [];
  }
}

School copyWithFromJson(School existing, Map<String, dynamic> json) {
  return School(
    schoolName: json['schoolName'] ?? existing.schoolName,
    schoolAddress: json['schoolAddress'] ?? existing.schoolAddress,
    schoolPhoneNumber: json['schoolPhoneNumber'] ?? existing.schoolPhoneNumber,
    schoolEmail: json['schoolEmail'] ?? existing.schoolEmail,
    termId: json['termId'] ?? existing.termId,
    syncStatus: json['syncStatus'] ?? existing.syncStatus,
    lastModified: json['lastModified'] != null
        ? DateTime.tryParse(json['lastModified'])
        : existing.lastModified,
    operationType: json['operationType'] ?? existing.operationType,
    id: json['id'] ?? existing.id,
    schoolLogoPath: json['schoolLogoPath'] ?? existing.schoolLogoPath,
    schoolCode: json['schoolCode'] ?? existing.schoolCode,
    modifiedFields: json['modifiedFields'] != null
        ? List<String>.from(json['modifiedFields'])
        : existing.modifiedFields,
  );
}
