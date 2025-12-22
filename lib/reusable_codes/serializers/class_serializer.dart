// JSON Deserialization methods
import 'dart:convert';

import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Classes classesFromJson(Map<String, dynamic> json) {
  List<String>? termsList;

  if (json['terms'] != null) {
    if (json['terms'] is String) {
      // Case 1: terms stored as JSON string
      termsList = List<String>.from(jsonDecode(json['terms']));
    } else if (json['terms'] is List) {
      // Case 2: terms already a JSON array
      termsList = (json['terms'] as List).map((e) => e.toString()).toList();
    }
  }

  return Classes(
    id: json['id'],
    className: json['className'],
    classCode: json['classCode'],
    date: DateTime.parse(json['date']),
    termId: json['termId'],
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    terms: termsList,
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}

// JSON Serialization methods
Map<String, dynamic> classesToJson(Classes cls) {
  return {
    'id': cls.id,
    'className': cls.className,
    'classCode': cls.classCode,
    'date': cls.date.toIso8601String(),
    'termId': cls.termId,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'terms': cls.terms != null
        ? jsonEncode(cls.terms) // JSON encode the list
        : null,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}
