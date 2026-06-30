// api/id_routes.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Complete API service class
class IdApiService {
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await http.get(
        Uri.parse('http://$hostIp:8080/api/ids/$endpoint'),
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

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/ids/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Convenience methods
  static Future<Map<String, dynamic>> reserveIds(int count,
      {String? clientId}) {
    return post('reserve', {
      'count': count,
      'clientId': clientId ?? 'unknown',
    });
  }

  static Future<Map<String, dynamic>> markIdUsed(int id, String receiptNumber) {
    return post('mark-used', {
      'id': id,
      'receiptNumber': receiptNumber,
    });
  }

  static Future<Map<String, dynamic>> getStatus() {
    return get('status');
  }

  static Future<Map<String, dynamic>> getHistory(
      {int limit = 50, int offset = 0}) {
    return get('history?limit=$limit&offset=$offset');
  }

  static Future<Map<String, dynamic>> getPending() {
    return get('pending');
  }

  static Future<Map<String, dynamic>> checkId(int id) {
    return get('check/$id');
  }

  static Future<Map<String, dynamic>> syncClient(
      String clientId, int lastSyncedId) {
    return post('sync', {
      'clientId': clientId,
      'lastSyncedId': lastSyncedId,
    });
  }
}

// Example usage in your code
void exampleApiUsage() async {
  // Reserve 5 IDs
  final result = await IdApiService.reserveIds(5, clientId: 'host');
  if (result['success']) {
    final ids = result['ids'] as List<int>;
    print('Reserved IDs: $ids');
  }

  // Mark ID as used
  await IdApiService.markIdUsed(100, 'RCP-2024-001');

  // Get status
  final status = await IdApiService.getStatus();
  print('Status: $status');

  // Get history
  final history = await IdApiService.getHistory(limit: 20);
  print('Recent assignments: ${history['logs']}');
}
