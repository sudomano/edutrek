import 'dart:convert';

import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/reusable_codes/serializers/exceptions_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/decode_to_list.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> paymentPurposesToJson(PaymentPurpose cls) {
  return {
    'id': cls.id,
    'paymentPurpose': cls.paymentPurpose,
    'purposeAmount': cls.purposeAmount,
    'termId': cls.termId,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'associatedClasses':
        jsonEncode(cls.associatedClasses), // Convert list to JSON
    'purposeCode': cls.purposeCode,
    'exceptions': cls.exceptions != null
        ? jsonEncode(
            cls.exceptions!.map((e) => exceptionalStudentsToJson(e)).toList())
        : null,
    'forNewcomersOnly': cls.forNewcomersOnly,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

PaymentPurpose paymentPurposesFromJson(Map<String, dynamic> json) {
  return PaymentPurpose(
    id: json['id'],
    paymentPurpose: json['paymentPurpose'],
    purposeAmount: json['purposeAmount'],
    termId: json['termId'],
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    purposeCode: json['purposeCode'],
    associatedClasses: decodeToList(json['associatedClasses']),
    exceptions: json['exceptions'] != null
        ? (jsonDecode(json['exceptions']) as List<dynamic>)
            .map((e) =>
                exceptionalStudentsFromJson(Map<String, dynamic>.from(e)))
            .toList()
        : null,
    forNewcomersOnly: json['forNewcomersOnly'],
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}
