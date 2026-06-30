import 'package:zitf_system/database/id_assignment_log.dart';

Map<String, dynamic> idAssignmentLogToJson(IdAssignmentLog log) {
  return {
    'id': log.id,
    'assignedAt': log.assignedAt.toIso8601String(),
    'assignedByClientId': log.assignedByClientId,
    'paymentReceiptNumber': log.paymentReceiptNumber,
    'isUsed': log.isUsed,
    'usedAt': log.usedAt?.toIso8601String(),
  };
}

IdAssignmentLog idAssignmentLogFromJson(Map<String, dynamic> json) {
  return IdAssignmentLog(
    id: json['id'] ?? 0,
    assignedAt: json['assignedAt'] != null
        ? DateTime.parse(json['assignedAt'])
        : DateTime.now(),
    assignedByClientId: json['assignedByClientId'] ?? 'unknown',
    paymentReceiptNumber: json['paymentReceiptNumber'],
    isUsed: json['isUsed'] ?? false,
    usedAt: json['usedAt'] != null ? DateTime.parse(json['usedAt']) : null,
  );
}

List<IdAssignmentLog> idAssignmentLogsFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) => idAssignmentLogFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

List<Map<String, dynamic>> idAssignmentLogsToJson(List<IdAssignmentLog> logs) {
  return logs.map((log) => idAssignmentLogToJson(log)).toList();
}

// Specialized methods
Map<String, dynamic> idAssignmentLogSummaryToJson(IdAssignmentLog log) {
  return {
    'id': log.id,
    'isUsed': log.isUsed,
    'assignedAt': log.assignedAt.toIso8601String(),
    'assignedBy': log.assignedByClientId,
    'receiptNumber': log.paymentReceiptNumber ?? 'N/A',
  };
}
