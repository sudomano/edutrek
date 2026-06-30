// api/id_lock_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_lock.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/id_lock_serializer.dart';

// Get lock status
Future<Map<String, dynamic>> getLockStatus() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    final lock = await _getLocalLock();
    return {
      'success': true,
      'data': idLockToJson(lock),
      'source': 'local',
    };
  } else {
    try {
      final response = await http.get(
        Uri.parse('http://$hostIp:8080/api/ids/lock'),
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

// Force unlock (admin only - use with caution)
Future<Map<String, dynamic>> forceUnlock() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdLock>('id_lock');
      final lock = box.getAt(0);
      if (lock != null) {
        lock.isLocked = false;
        lock.lockedAt = null;
        lock.lockedByClientId = null;
        lock.lockedForCount = null;
        await lock.save();
        return {
          'success': true,
          'message': 'Lock forcefully released',
        };
      }
      return {
        'success': false,
        'error': 'Lock not found',
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
        Uri.parse('http://$hostIp:8080/api/ids/lock/force-unlock'),
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

// Helper: Get local lock
Future<IdLock> _getLocalLock() async {
  final box = await Hive.openBox<IdLock>('id_lock');
  final lock = box.getAt(0);
  if (lock != null) {
    return lock;
  }
  final newLock = IdLock(isLocked: false);
  await box.add(newLock);
  return newLock;
}
