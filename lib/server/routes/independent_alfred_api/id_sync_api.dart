// api/id_sync_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_sync_status.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/id_sync_status_serializer.dart';

// Sync client with server
Future<Map<String, dynamic>> syncClient({
  required String clientId,
  required int lastSyncedId,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdSyncStatus>('id_sync_status');
      final existing = box.values.where((s) => s.deviceId == clientId).toList();

      IdSyncStatus status;
      if (existing.isNotEmpty) {
        status = existing.first;
        status.lastSyncedId = lastSyncedId;
        status.lastSyncTime = DateTime.now();
      } else {
        status = IdSyncStatus(
          deviceId: clientId,
          lastSyncedId: lastSyncedId,
          lastSyncTime: DateTime.now(),
        );
        await box.add(status);
      }

      // Get pending IDs for this client
      final assignmentBox =
          await Hive.openBox<IdAssignmentLog>('id_assignment_log');
      final pendingIds = assignmentBox.values
          .where((log) => !log.isUsed && log.id > lastSyncedId)
          .toList();

      status.pendingIdsCount = pendingIds.length;
      await status.save();

      return {
        'success': true,
        'message': 'Client synced successfully',
        'lastSyncedId': status.lastSyncedId,
        'pendingIdsCount': status.pendingIdsCount,
        'pendingIds': pendingIds.map((log) => log.id).toList(),
        'syncTime': status.lastSyncTime.toIso8601String(),
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
        Uri.parse('http://$hostIp:8080/api/sync/client'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientId': clientId,
          'lastSyncedId': lastSyncedId,
        }),
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

// Get all sync statuses (admin)
Future<Map<String, dynamic>> getAllSyncStatuses() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdSyncStatus>('id_sync_status');
      final statuses = box.values.toList();

      return {
        'success': true,
        'statuses': idSyncStatusesToJson(statuses),
        'count': statuses.length,
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
        Uri.parse('http://$hostIp:8080/api/sync/statuses'),
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
