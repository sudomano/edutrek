import 'dart:convert';

import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/decode_to_list.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> teachersToJson(Teachers cls) {
  return {
    'id': cls.id,
    'name': cls.name,
    'surname': cls.surname,
    'IdNumber': cls.IdNumber,
    'assignedClass': cls.assignedClass,
    'gender': cls.gender,
    'dateOfBirth': cls.dateOfBirth.toIso8601String(),
    'phoneNumber': cls.phoneNumber,
    'paymentPurpose': cls.paymentPurpose,
    'isPaid': cls.isPaid,
    'paymentAmount': cls.paymentAmount,
    'paymentDate': cls.paymentDate?.toIso8601String(),
    'email': cls.email,
    'address': cls.address,
    'hireDate': cls.hireDate.toIso8601String(),
    'qualifications': cls.qualifications,
    'employmentStatus': cls.employmentStatus,
    'termId': cls.termId,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'assignedClasses': cls.assignedClasses != null
        ? jsonEncode(cls.assignedClasses) // JSON encode the list
        : null,
    'terms': cls.terms != null
        ? jsonEncode(cls.terms) // JSON encode the list
        : null,
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

Teachers teachersFromJson(Map<String, dynamic> json) {
  return Teachers(
    id: json['id'],

    name: json['name'],
    surname: json['surname'],
    IdNumber: json['IdNumber'],
    assignedClass: json['assignedClass'],
    gender: json['gender'],

    // Parsing dateOfBirth as DateTime
    dateOfBirth: DateTime.parse(json['dateOfBirth']),

    phoneNumber: json['phoneNumber'],
    paymentPurpose: json['paymentPurpose'],
    isPaid: json['isPaid'],
    paymentAmount: json['paymentAmount'],

    // paymentDate could be nullable, so we handle it safely
    paymentDate: json['paymentDate'] != null
        ? DateTime.parse(json['paymentDate'])
        : null,

    email: json['email'],
    address: json['address'],

    // Parsing hireDate as DateTime
    hireDate: DateTime.parse(json['hireDate']),

    qualifications: json['qualifications'],
    employmentStatus: json['employmentStatus'],
    termId: json['termId'],
    syncStatus: json['syncStatus'],

    // Handling nullable lastModified
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,

    operationType: json['operationType'],
    assignedClasses: decodeToList(json['assignedClasses']),
    terms: json['terms'] != null
        ? List<String>.from(jsonDecode(json['terms']))
        : null,
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}
