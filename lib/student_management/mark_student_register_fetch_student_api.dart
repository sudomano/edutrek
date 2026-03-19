import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentRegisterApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  /// Mark attendance for a single student
  static Future<void> markRegister({
    required String studentId,
    required DateTime date,
    required bool isPresent,
  }) async {
    final baseUrl = await _getBaseUrl();

    final response = await http.put(
      Uri.parse('$baseUrl/api/students/$studentId/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': date.toIso8601String(),
        'status': isPresent ? 'present' : 'absent',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark register (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Optional: clear attendance for a date
  static Future<void> clearRegister({
    required String studentId,
    required DateTime date,
  }) async {
    final baseUrl = await _getBaseUrl();

    final response = await http.put(
      Uri.parse('$baseUrl/api/students/$studentId/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': date.toIso8601String(),
        'status': 'clear',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to clear register (${response.statusCode}): ${response.body}',
      );
    }
  }
}
