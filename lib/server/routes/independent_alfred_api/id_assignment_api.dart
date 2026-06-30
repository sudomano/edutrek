// api/id_assignment_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/database/id_counter.dart';
import 'package:zitf_system/database/id_lock.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/id_assignment_log_serializer.dart';

// Get last assigned ID
Future<Map<String, dynamic>> getLastAssignedId() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdCounter>('id_counter');
      final counter = box.getAt(0);
      final lastId = counter?.lastAssignedId ?? 0;
      return {
        'success': true,
        'lastId': lastId,
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
        Uri.parse('http://$hostIp:8080/api/ids/last'),
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

// Reserve next ID(s)
Future<Map<String, dynamic>> reserveIds({
  required int count,
  String? clientId,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final ids = await _reserveIdsLocally(count, clientId: clientId);
      return {
        'success': true,
        'ids': ids,
        'count': ids.length,
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
      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/ids/reserve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'count': count,
          'clientId': clientId ?? 'unknown',
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

// Mark ID as used
Future<Map<String, dynamic>> markIdAsUsed({
  required int id,
  required String receiptNumber,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      await _markIdUsedLocally(id, receiptNumber);
      return {
        'success': true,
        'message': 'ID $id marked as used',
        'receiptNumber': receiptNumber,
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
        Uri.parse('http://$hostIp:8080/api/ids/mark-used'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'receiptNumber': receiptNumber,
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

// Check if ID exists
Future<Map<String, dynamic>> checkIdExists(int id) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final exists = await _checkIdExistsLocally(id);
      return {
        'success': true,
        'exists': exists,
        'id': id,
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
        Uri.parse('http://$hostIp:8080/api/ids/check/$id'),
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

// Get pending IDs
Future<Map<String, dynamic>> getPendingIds() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdAssignmentLog>('id_assignment_log');
      final pending = box.values.where((log) => !log.isUsed).toList();
      return {
        'success': true,
        'pendingIds': pending.map((log) => log.id).toList(),
        'count': pending.length,
        'pendingLogs': idAssignmentLogsToJson(pending),
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
        Uri.parse('http://$hostIp:8080/api/ids/pending'),
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

// Get assignment history
Future<Map<String, dynamic>> getAssignmentHistory({
  int limit = 100,
  int offset = 0,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdAssignmentLog>('id_assignment_log');
      final all = box.values.toList();
      all.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

      final paginated = all.skip(offset).take(limit).toList();

      return {
        'success': true,
        'logs': idAssignmentLogsToJson(paginated),
        'total': all.length,
        'limit': limit,
        'offset': offset,
        'hasMore': offset + limit < all.length,
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
        Uri.parse(
            'http://$hostIp:8080/api/ids/history?limit=$limit&offset=$offset'),
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

// ============================================================
// LOCAL IMPLEMENTATIONS
// ============================================================

Future<List<int>> _reserveIdsLocally(int count, {String? clientId}) async {
  final box = await Hive.openBox<IdCounter>('id_counter');
  final lockBox = await Hive.openBox<IdLock>('id_lock');
  final logBox = await Hive.openBox<IdAssignmentLog>('id_assignment_log');

  // Acquire lock
  final lock = lockBox.getAt(0);
  if (lock != null) {
    if (lock.isLocked) {
      throw Exception('ID generation is locked');
    }
    lock.isLocked = true;
    lock.lockedAt = DateTime.now();
    lock.lockedByClientId = clientId ?? 'unknown';
    lock.lockedForCount = count;
    await lock.save();
  }

  try {
    final counter = box.getAt(0);
    if (counter == null) {
      throw Exception('Counter not initialized');
    }

    final List<int> ids = [];
    for (int i = 1; i <= count; i++) {
      ids.add(counter.lastAssignedId + i);
    }

    counter.lastAssignedId += count;
    counter.lastUpdated = DateTime.now();
    counter.totalIdsAssigned += count;
    counter.lastClientId = clientId ?? 'unknown';
    await counter.save();

    // Log assignments
    for (int id in ids) {
      final log = IdAssignmentLog(
        id: id,
        assignedAt: DateTime.now(),
        assignedByClientId: clientId ?? 'unknown',
        isUsed: false,
      );
      await logBox.add(log);
    }

    return ids;
  } finally {
    // Release lock
    if (lock != null) {
      lock.isLocked = false;
      lock.lockedAt = null;
      lock.lockedByClientId = null;
      lock.lockedForCount = null;
      await lock.save();
    }
  }
}

Future<void> _markIdUsedLocally(int id, String receiptNumber) async {
  final box = await Hive.openBox<IdAssignmentLog>('id_assignment_log');
  final logs = box.values.where((log) => log.id == id && !log.isUsed).toList();

  if (logs.isNotEmpty) {
    final log = logs.first;
    log.isUsed = true;
    log.usedAt = DateTime.now();
    log.paymentReceiptNumber = receiptNumber;
    await log.save();
  } else {
    throw Exception('No pending assignment found for ID: $id');
  }
}

Future<bool> _checkIdExistsLocally(int id) async {
  final box = await Hive.openBox<IdAssignmentLog>('id_assignment_log');
  return box.values.any((log) => log.id == id && log.isUsed);
}
