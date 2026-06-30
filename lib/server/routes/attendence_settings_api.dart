import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceSettingsApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  // ✅ Check if updates are allowed
  static Future<bool> isUpdateAllowed() async {
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/register/allow-update'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['allowUpdate'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // ✅ Update the setting (Host only)
  static Future<bool> setAllowUpdate(bool allowUpdate) async {
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/settings/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'allowUpdate': allowUpdate}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // ✅ Debug: Get all settings
  static Future<Map<String, dynamic>> debugGetAllSettings() async {
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/settings/debug'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Failed to get debug settings'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

// ✅ Debug: Reset settings
  static Future<bool> debugResetSettings() async {
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/settings/reset'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
