import 'dart:convert';

import 'package:zitf_system/database/classes.dart';

dynamic _deepDecodeJsonString(dynamic value) {
  if (value == null) return null;

  // If it's already a List or Map, return as-is
  if (value is List || value is Map) return value;

  // If it's a String, try to decode it recursively
  if (value is String) {
    try {
      // Attempt to decode the JSON string
      dynamic decoded = jsonDecode(value);
      // Recursively decode again in case it's still a JSON string
      return _deepDecodeJsonString(decoded);
    } catch (e) {
      // Not a valid JSON string, return original
      return value;
    }
  }

  return value;
}

// Clean a single Classes object
Classes cleanClasses(Classes cls) {
  return Classes(
    id: cls.id,
    className: cls.className,
    classCode: cls.classCode,
    date: cls.date,
    termId: cls.termId,
    syncStatus: cls.syncStatus,
    lastModified: cls.lastModified,
    operationType: cls.operationType,
    // Clean the terms field
    terms: cls.terms != null ? _deepDecodeJsonString(cls.terms) : null,
    // Clean the modifiedFields field
    modifiedFields: cls.modifiedFields != null
        ? _deepDecodeJsonString(cls.modifiedFields)
        : null,
  );
}

// Clean a list of classes
List<Classes> cleanAllClasses(List<Classes> classes) {
  return classes.map((cls) => cleanClasses(cls)).toList();
}
