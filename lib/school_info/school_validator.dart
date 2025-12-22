import 'package:hive/hive.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';

Future<Map<String, dynamic>> validateAndInsertSchool(
  Map<String, dynamic> schoolData,
  Box<School> schoolBox,
) async {
  final incomingCode = schoolData['schoolCode']?.toString().trim();
  final incomingName =
      schoolData['schoolName']?.toString().toLowerCase().trim();

  // ✅ Check required fields
  final requiredFields = [
    'schoolCode',
    'schoolName',
    'schoolAddress',
    'schoolPhoneNumber',
    'schoolEmail',
    'termId',
  ];

  final missingFields = requiredFields
      .where((f) =>
          !schoolData.containsKey(f) || schoolData[f].toString().trim().isEmpty)
      .toList();

  if (missingFields.isNotEmpty) {
    return {
      "schoolCode": incomingCode,
      "schoolName": incomingName,
      "status": "failed",
      "reason": "Missing required fields: ${missingFields.join(', ')}"
    };
  }

  // ✅ Enforce single-school rule
  if (schoolBox.isNotEmpty) {
    return {
      "schoolCode": incomingCode,
      "schoolName": incomingName,
      "status": "failed",
      "reason": "Only one school is allowed in this system"
    };
  }

  // ✅ Check for duplicates
  final duplicate = schoolBox.values.any((s) {
    final storedCode = s.schoolCode?.toString().trim();
    final storedName = s.schoolName?.toString().toLowerCase().trim();
    return storedCode == incomingCode || storedName == incomingName;
  });

  if (duplicate) {
    return {
      "schoolCode": incomingCode,
      "schoolName": incomingName,
      "status": "skipped",
      "reason": "Duplicate schoolCode or schoolName already exists"
    };
  }

  try {
    final school = schoolFromJson(schoolData);
    await schoolBox.add(school);
    return {
      "schoolCode": incomingCode,
      "schoolName": incomingName,
      "status": "success",
      "message": "School inserted successfully"
    };
  } catch (e) {
    return {
      "schoolCode": incomingCode,
      "schoolName": incomingName,
      "status": "failed",
      "reason": "Deserialization or processing error",
      "details": e.toString()
    };
  }
}
