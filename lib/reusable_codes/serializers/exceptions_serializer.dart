// JSON Serialization method for ExceptionalStudents
import 'dart:convert';

import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> exceptionalStudentsToJson(ExceptionalStudents exc) {
  return {
    'id': exc.id,
    'exceptionId': exc.exceptionId,
    'exceptionName': exc.exceptionName,
    'exceptionStatus': exc.exceptionStatus,
    'exceptionType': exc.exceptionType,
    'exceptionFigure': exc.exceptionFigure,
    'syncStatus': exc.syncStatus,
    'lastModified': exc.lastModified?.toIso8601String(),
    'operationType': exc.operationType,
    'modifiedFields': exc.modifiedFields != null
        ? jsonEncode(exc.modifiedFields) // JSON encode the list
        : null,
    'terms': exc.terms != null
        ? jsonEncode(exc.terms) // JSON encode the list
        : null,
  };
}

// JSON Deserialization method for ExceptionalStudents
ExceptionalStudents exceptionalStudentsFromJson(Map<String, dynamic> json) {
  return ExceptionalStudents(
    id: json['id'],
    exceptionId: json['exceptionId'],
    exceptionName: json['exceptionName'],
    exceptionStatus: json['exceptionStatus'],
    exceptionType: json['exceptionType'],
    exceptionFigure: json['exceptionFigure'],
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    modifiedFields: parseStringList(json['modifiedFields']),
    terms: json['terms'] != null
        ? List<String>.from(jsonDecode(json['terms']))
        : null,
  );
}
