// Combined status report
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/database/id_client_reservation.dart';
import 'package:zitf_system/database/id_counter.dart';
import 'package:zitf_system/database/id_lock.dart';
import 'package:zitf_system/database/id_range.dart';
import 'package:zitf_system/database/id_sync_status.dart';
import 'package:zitf_system/reusable_codes/serializers/client_id_reservation_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/id_assignment_log_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/id_counter_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/id_lock_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/id_range_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/id_sync_status_serializer.dart';

Map<String, dynamic> idServiceStatusToJson({
  required IdCounter counter,
  required IdLock lock,
  required List<IdAssignmentLog> recentLogs,
  required List<ClientIdReservation> activeReservations,
  required List<IdSyncStatus> syncStatuses,
}) {
  return {
    'counter': idCounterToJson(counter),
    'lock': idLockToJson(lock),
    'recentLogs':
        recentLogs.map((log) => idAssignmentLogSummaryToJson(log)).toList(),
    'activeReservations': activeReservations
        .map((res) => clientIdReservationStatusToJson(res))
        .toList(),
    'syncStatuses':
        syncStatuses.map((status) => idSyncStatusReportToJson(status)).toList(),
    'timestamp': DateTime.now().toIso8601String(),
  };
}

// Bulk import/export
Map<String, dynamic> idServiceExportData({
  required List<IdCounter> counters,
  required List<IdLock> locks,
  required List<IdAssignmentLog> logs,
  required List<ClientIdReservation> reservations,
  required List<IdRange> ranges,
  required List<IdSyncStatus> syncStatuses,
}) {
  return {
    'counters': counters.map((c) => idCounterToJson(c)).toList(),
    'locks': locks.map((l) => idLockToJson(l)).toList(),
    'logs': logs.map((l) => idAssignmentLogToJson(l)).toList(),
    'reservations':
        reservations.map((r) => clientIdReservationToJson(r)).toList(),
    'ranges': ranges.map((r) => idRangeToJson(r)).toList(),
    'syncStatuses': syncStatuses.map((s) => idSyncStatusToJson(s)).toList(),
    'exportedAt': DateTime.now().toIso8601String(),
  };
}

// Bulk import
void idServiceImportData(
  Map<String, dynamic> data, {
  required Function(IdCounter) onCounter,
  required Function(IdLock) onLock,
  required Function(IdAssignmentLog) onLog,
  required Function(ClientIdReservation) onReservation,
  required Function(IdRange) onRange,
  required Function(IdSyncStatus) onSyncStatus,
}) {
  if (data['counters'] != null) {
    for (var json in data['counters']) {
      onCounter(idCounterFromJson(json));
    }
  }
  if (data['locks'] != null) {
    for (var json in data['locks']) {
      onLock(idLockFromJson(json));
    }
  }
  if (data['logs'] != null) {
    for (var json in data['logs']) {
      onLog(idAssignmentLogFromJson(json));
    }
  }
  if (data['reservations'] != null) {
    for (var json in data['reservations']) {
      onReservation(clientIdReservationFromJson(json));
    }
  }
  if (data['ranges'] != null) {
    for (var json in data['ranges']) {
      onRange(idRangeFromJson(json));
    }
  }
  if (data['syncStatuses'] != null) {
    for (var json in data['syncStatuses']) {
      onSyncStatus(idSyncStatusFromJson(json));
    }
  }
}

// ID conflict check result
Map<String, dynamic> idConflictCheckToJson({
  required int id,
  required bool exists,
  required String status,
  required Map<String, dynamic>? details,
}) {
  return {
    'id': id,
    'exists': exists,
    'status': status, // 'available', 'used', 'pending', 'reserved'
    'details': details,
    'checkedAt': DateTime.now().toIso8601String(),
  };
}
