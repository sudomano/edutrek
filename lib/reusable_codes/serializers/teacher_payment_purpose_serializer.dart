import 'dart:convert';

import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/decode_to_list.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> teacherPaymentPurposesToJsonList(
    TeacherPaymentsPurposes cls) {
  return {
    'id': cls.id,
    'paymentPurpose': cls.paymentPurpose,
    'purposeAmount': cls.purposeAmount,
    'purposeCode': cls.purposeCode,
    'termId': cls.termId,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'associatedStaff': cls.associatedStaff != null
        ? jsonEncode(
            cls.associatedStaff) // Explicit JSON encode for associatedStaff
        : null,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

TeacherPaymentsPurposes teacherPaymentPurposesFromJsonList(
    Map<String, dynamic> json) {
  return TeacherPaymentsPurposes(
    id: json['id'] ?? '', // Provide a default empty string if null
    paymentPurpose: json['purpose'] ?? '',
    purposeCode: json['purposeCode'] ?? '', // Default empty string
    purposeAmount:
        json['purposeAmount'] ?? 0.0, // Default value for numeric fields
    termId: json['termId'], // Allow nullable if the field itself is nullable
    syncStatus:
        json['syncStatus'], // Allow nullable if the field itself is nullable
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null, // Handle nullable dates
    operationType: json['operationType'] ?? '',
    associatedStaff: decodeToList(json['associatedStaff']),
    modifiedFields: parseStringList(json['modifiedFields']),

// Default empty string
  );
}
