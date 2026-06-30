import 'dart:convert';
import 'package:zitf_system/database/projects/packaging_level.dart';

// Convert enum to string
String packagingLevelToString(PackagingLevel level) {
  return level.toString().split('.').last;
}

// Convert string to enum
PackagingLevel stringToPackagingLevel(String value) {
  return PackagingLevel.values.firstWhere(
    (e) => e.toString().split('.').last == value,
    orElse: () => PackagingLevel.single,
  );
}

// JSON serialization
Map<String, dynamic> packagingLevelToJson(PackagingLevel level) => {
      'value': packagingLevelToString(level),
    };

PackagingLevel packagingLevelFromJson(Map<String, dynamic> json) {
  return stringToPackagingLevel(json['value']);
}
