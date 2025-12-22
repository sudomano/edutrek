import 'dart:convert';

import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> studentPaymentsToJson(StudentPayment cls) {
  return {
    'id': cls.id,
    'studentName': cls.studentName,
    'studentSurname': cls.studentSurname,
    'studentClass': cls.studentClass,
    'phoneNumber': cls.phoneNumber,
    'paymentPurpose': cls.paymentPurpose,
    'amountToPay': cls.amountToPay,
    'paymentDate': cls.paymentDate.toIso8601String(),
    'termId': cls.termId,
    'receiptNumber': cls.receiptNumber,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'username': cls.username,
    'role': cls.role,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

StudentPayment studentPaymentsFromJson(Map<String, dynamic> json) {
  return StudentPayment(
    id: json['id'],
    studentName: json['studentName'],
    studentSurname: json['studentSurname'],
    studentClass: json['studentClass'],
    phoneNumber: json['phoneNumber'],
    paymentPurpose: json['paymentPurpose'],
    amountToPay: json['amountToPay'],
    paymentDate: DateTime.parse(json['paymentDate']),
    termId: json['termId'],
    receiptNumber: json['receiptNumber'],
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    username: json['username'],
    role: json['role'],
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}
