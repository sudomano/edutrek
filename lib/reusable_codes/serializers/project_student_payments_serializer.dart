/*

import 'dart:convert';

import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> projectStudentPaymentsToJson(ProjectStudentPayment p) => {
      'projectStudentPaymentCode': p.projectStudentPaymentCode,
      'studentId': p.studentId,
      'projectCode': p.projectCode,
      'itemId': p.itemId,
      'amountPaid': p.amountPaid,
      'balance': p.balance,
      'syncStatus': p.syncStatus,
      'lastModified': p.lastModified?.toIso8601String(),
      'operationType': p.operationType,
      'modifiedFields': p.modifiedFields != null
          ? jsonEncode(p.modifiedFields) // JSON encode the list
          : null,
    };

ProjectStudentPayment projectStudentPaymentsFromJson(
        Map<String, dynamic> json) =>
    ProjectStudentPayment(
      projectStudentPaymentCode: json['projectStudentPaymentCode'],
      studentId: json['studentId'],
      projectCode: json['projectCode'],
      itemId: json['itemId'],
      amountPaid: json['amountPaid'],
      balance: json['balance'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      modifiedFields: parseStringList(json['modifiedFields']),
    );

 */