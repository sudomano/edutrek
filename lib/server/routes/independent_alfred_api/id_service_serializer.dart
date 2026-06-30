// api/id_counter_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_counter.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/id_counter_serializer.dart';

// Get current ID counter status
Future<Map<String, dynamic>> getCounterStatus() async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    // Host: Read from Hive directly
    final counter = await _getLocalCounter();
    return {
      'success': true,
      'data': idCounterToJson(counter),
      'source': 'local',
    };
  } else {
    // Client: Fetch from host
    try {
      final response = await http.get(
        Uri.parse('http://$hostIp:8080/api/ids/counter'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch counter status');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// Update counter manually (admin only)
Future<Map<String, dynamic>> updateCounter(int newLastId) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdCounter>('id_counter');
      final counter = box.getAt(0);
      if (counter != null) {
        counter.lastAssignedId = newLastId;
        counter.lastUpdated = DateTime.now();
        await counter.save();
        return {
          'success': true,
          'message': 'Counter updated successfully',
          'newValue': newLastId,
        };
      }
      return {
        'success': false,
        'error': 'Counter not found',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  } else {
    // Client: Send to host
    try {
      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/ids/counter/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lastId': newLastId}),
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

// Helper: Get local counter
Future<IdCounter> _getLocalCounter() async {
  final box = await Hive.openBox<IdCounter>('id_counter');
  final counter = box.getAt(0);
  if (counter != null) {
    return counter;
  }
  // Create default if not exists
  final newCounter = IdCounter();
  await box.add(newCounter);
  return newCounter;
}
