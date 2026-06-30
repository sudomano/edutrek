// api/id_range_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_range.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/id_range_serializer.dart';

// Assign ID range to client
Future<Map<String, dynamic>> assignIdRange({
  required int startId,
  required int endId,
  required String assignedTo,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final range = IdRange(
        startId: startId,
        endId: endId,
        assignedTo: assignedTo,
        assignedAt: DateTime.now(),
        isFullyUsed: false,
      );

      final box = await Hive.openBox<IdRange>('id_ranges');
      await box.add(range);

      return {
        'success': true,
        'message': 'ID range assigned',
        'range': idRangeToJson(range),
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
        Uri.parse('http://$hostIp:8080/api/ranges/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'startId': startId,
          'endId': endId,
          'assignedTo': assignedTo,
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

// Get assigned ranges for client
Future<Map<String, dynamic>> getClientRanges(String clientId) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdRange>('id_ranges');
      final ranges = box.values
          .where((r) => r.assignedTo == clientId && !r.isFullyUsed)
          .toList();

      return {
        'success': true,
        'ranges': idRangesToJson(ranges),
        'count': ranges.length,
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
        Uri.parse('http://$hostIp:8080/api/ranges/client/$clientId'),
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

// Mark range as fully used
Future<Map<String, dynamic>> markRangeFullyUsed(int rangeId) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<IdRange>('id_ranges');
      final range = box.getAt(rangeId);
      if (range != null) {
        range.isFullyUsed = true;
        await range.save();
        return {
          'success': true,
          'message': 'Range marked as fully used',
        };
      }
      return {
        'success': false,
        'error': 'Range not found',
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
        Uri.parse('http://$hostIp:8080/api/ranges/fully-used'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rangeId': rangeId}),
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
