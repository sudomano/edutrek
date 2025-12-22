import 'dart:convert';

import 'package:zitf_system/database/payment_receipts_log.dart';

Map<String, dynamic> paymentLogToJson(PaymentLog log) {
  return {
    'receiptNumber': log.receiptNumber,
    'studentName': log.studentName,
    'className': log.className,
    'dateTime': log.dateTime,
    'receiptLines': jsonEncode(log.receiptLines),
    'parentName': log.parentName,
    'parentPhone': log.parentPhone,
// list of maps as JSON string
  };
}

PaymentLog paymentLogFromJson(Map<String, dynamic> json) {
  return PaymentLog(
    receiptNumber: json['receiptNumber'],
    studentName: json['studentName'],
    className: json['className'],
    dateTime: json['dateTime'],
    receiptLines: (json['receiptLines'] != null)
        ? List<Map<String, dynamic>>.from(jsonDecode(json['receiptLines']))
        : [],
    parentName: json['parentName'] ?? '',
    parentPhone: json['parentPhone'] ?? '',
  );
}
