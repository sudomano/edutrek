// api/id_admin_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/database/id_client_reservation.dart';
import 'package:zitf_system/database/id_counter.dart';
import 'package:zitf_system/database/id_lock.dart';
import 'package:zitf_system/database/id_range.dart';
import 'package:zitf_system/database/id_sync_status.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/id_service_serializer.dart';

// Get full ID service status
Future<Map<String, dynamic>> getIdServiceStatus() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      // Get all data
      final counterBox = await Hive.openBox<IdCounter>('id_counter');
      final lockBox = await Hive.openBox<IdLock>('id_lock');
      final logBox = await Hive.openBox<IdAssignmentLog>('id_assignment_log');
      var reservationBox =
          await Hive.openBox<ClientIdReservation>('id_reservations');
      final rangeBox = await Hive.openBox<IdRange>('id_ranges');
      var syncBox = await Hive.openBox<IdSyncStatus>('id_sync_status');

      final counter = counterBox.getAt(0);
      final lock = lockBox.getAt(0);
      final logs = logBox.values.toList();
      final reservations = reservationBox.values.toList();
      final ranges = rangeBox.values.toList();
      final syncStatuses = syncBox.values.toList();

      // Sort logs by date (most recent first)
      logs.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      final recentLogs = logs.take(50).toList();

      return {
        'success': true,
        'status': idServiceStatusToJson(
          counter: counter ?? IdCounter(),
          lock: lock ?? IdLock(isLocked: false),
          recentLogs: recentLogs,
          activeReservations: reservations.where((r) => r.isActive).toList(),
          syncStatuses: syncStatuses,
        ),
        'stats': {
          'totalLogs': logs.length,
          'usedLogs': logs.where((l) => l.isUsed).length,
          'pendingLogs': logs.where((l) => !l.isUsed).length,
          'activeReservations': reservations.where((r) => r.isActive).length,
          'totalRanges': ranges.length,
          'usedRanges': ranges.where((r) => r.isFullyUsed).length,
          'totalClients': syncStatuses.length,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  } else {
    try {
      final response = await http.get(
        Uri.parse('http://$hostIp:8080/api/admin/status'),
        headers: {'Content-Type': 'application/json'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// Cleanup old data
Future<Map<String, dynamic>> cleanupOldData({int daysOld = 30}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      // Clean up old assignment logs
      final logBox = await Hive.openBox<IdAssignmentLog>('id_assignment_log');
      final oldLogs = logBox.values
          .where((log) => log.assignedAt.isBefore(cutoffDate))
          .toList();

      for (var log in oldLogs) {
        await log.delete();
      }

      // Clean up old reservations
      final reservationBox =
          await Hive.openBox<ClientIdReservation>('id_reservations');
      final oldReservations = reservationBox.values
          .where((r) => r.reservedAt.isBefore(cutoffDate) && !r.isActive)
          .toList();

      for (var reservation in oldReservations) {
        await reservation.delete();
      }

      return {
        'success': true,
        'message': 'Cleanup completed',
        'deletedLogs': oldLogs.length,
        'deletedReservations': oldReservations.length,
        'cutoffDate': cutoffDate.toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  } else {
    try {
      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/admin/cleanup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'daysOld': daysOld}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
