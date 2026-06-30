import 'package:zitf_system/database/id_sync_status.dart';

Map<String, dynamic> idSyncStatusToJson(IdSyncStatus status) {
  return {
    'deviceId': status.deviceId,
    'lastSyncedId': status.lastSyncedId,
    'lastSyncTime': status.lastSyncTime.toIso8601String(),
    'pendingIdsCount': status.pendingIdsCount,
  };
}

IdSyncStatus idSyncStatusFromJson(Map<String, dynamic> json) {
  return IdSyncStatus(
    deviceId: json['deviceId'] ?? '',
    lastSyncedId: json['lastSyncedId'] ?? 0,
    lastSyncTime: json['lastSyncTime'] != null
        ? DateTime.parse(json['lastSyncTime'])
        : DateTime.now(),
    pendingIdsCount: json['pendingIdsCount'] ?? 0,
  );
}

List<IdSyncStatus> idSyncStatusesFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) => idSyncStatusFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

List<Map<String, dynamic>> idSyncStatusesToJson(List<IdSyncStatus> statuses) {
  return statuses.map((status) => idSyncStatusToJson(status)).toList();
}

// Specialized methods
Map<String, dynamic> idSyncStatusReportToJson(IdSyncStatus status) {
  return {
    'deviceId': status.deviceId,
    'lastSyncedId': status.lastSyncedId,
    'lastSyncTime': status.lastSyncTime.toIso8601String(),
    'pendingIdsCount': status.pendingIdsCount,
    'syncStatus': status.pendingIdsCount == 0 ? 'in_sync' : 'pending_sync',
  };
}
