import 'dart:convert';

import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/reusable_codes/serializers/exceptions_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> studentsToJson(Student cls) {
  return {
    'id': cls.id,
    'name': cls.name,
    'surname': cls.surname,
    'class': cls.class_,
    'gender': cls.gender,
    'age': cls.age.toIso8601String(),
    'nationality': cls.nationality,
    'district': cls.district,
    'nationalIdNumber': cls.nationalIdNumber,
    'studentIdNumber': cls.studentIdNumber,
    'regNumber': cls.regNumber,
    'physicalAddress': cls.physicalAddress,
    'paymentStatus': cls.paymentStatus,
    'phoneNumber': cls.phoneNumber,
    'religion': cls.religion,
    'denomination': cls.denomination,
    'formerSchool': cls.formerSchool,
    'previousSchoolPerformanceResults': cls.previousSchoolPerformanceResults,
    'emergencyContactName': cls.emergencyContactName,
    'emergencyContactNumber': cls.emergencyContactNumber,
    'enrollmentStatus': cls.enrollmentStatus,
    'isPresent': cls.isPresent,
    'presentDates': cls.presentDates
        .map((date) => date.toIso8601String())
        .toList(), // Convert each DateTime to ISO 8601 string
    'absentDates': cls.absentDates
        .map((date) => date.toIso8601String())
        .toList(), // Convert each DateTime to ISO 8601 string
    'termId': cls.termId,
    'syncStatus': cls.syncStatus,
    'lastModified': cls.lastModified?.toIso8601String(),
    'operationType': cls.operationType,
    'terms': cls.terms != null
        ? jsonEncode(cls.terms) // JSON encode the list
        : null,
    'exceptions': cls.exceptions != null
        ? jsonEncode(
            cls.exceptions!.map((e) => exceptionalStudentsToJson(e)).toList())
        : null,
    'isNewComer': cls.isNewComer,
    'isNewComerFrom': cls.isNewComerFrom?.toIso8601String(),
    'isNewComerUntil': cls.isNewComerUntil?.toIso8601String(),
    'modifiedFields': cls.modifiedFields != null
        ? jsonEncode(cls.modifiedFields) // JSON encode the list
        : null,
  };
}

Student studentsFromJson(Map<String, dynamic> json) {
  return Student(
    id: json['id'],
    name: json['name'],
    surname: json['surname'],
    class_: json['class'],
    gender: json['gender'],
    age: DateTime.parse(json['age']),
    nationality: json['nationality'],
    district: json['district'],
    nationalIdNumber: json['nationalIdNumber'],
    studentIdNumber: json['studentIdNumber'],
    regNumber: json['regNumber'],
    physicalAddress: json['physicalAddress'], // Parsing age to DateTime
    paymentStatus: json['paymentStatus'],
    phoneNumber: json['phoneNumber'],
    religion: json['religion'],
    denomination: json['denomination'],
    formerSchool: json['formerSchool'],
    previousSchoolPerformanceResults: json['previousSchoolPerformanceResults'],
    emergencyContactName: json['emergencyContactName'],
    emergencyContactNumber: json['emergencyContactNumber'],

    isPresent: json['isPresent'],
    enrollmentStatus: json['enrollmentStatus'],

    // Correctly parsing presentDates and absentDates as lists of DateTime
    presentDates: (json['presentDates'] as List<dynamic>)
        .map((date) => DateTime.parse(date as String))
        .toList(),
    absentDates: (json['absentDates'] as List<dynamic>)
        .map((date) => DateTime.parse(date as String))
        .toList(),

    termId: json['termId'],
    syncStatus: json['syncStatus'],
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'],
    terms: json['terms'] != null
        ? List<String>.from(jsonDecode(json['terms']))
        : null,
    exceptions: json['exceptions'] != null
        ? (jsonDecode(json['exceptions']) as List<dynamic>)
            .map((e) =>
                exceptionalStudentsFromJson(Map<String, dynamic>.from(e)))
            .toList()
        : null,
    isNewComer: json['isNewComer'],
    isNewComerFrom: json['isNewComerFrom'] != null
        ? DateTime.parse(json['isNewComerFrom'])
        : null,
    isNewComerUntil: json['isNewComerUntil'] != null
        ? DateTime.parse(json['isNewComerUntil'])
        : null,
    modifiedFields: parseStringList(json['modifiedFields']),
  );
}
