import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  /// Used by CLIENT during submit (even for single record)
  static Future<Map<String, dynamic>> sendStudents(
      List<Map<String, dynamic>> students) async {
    final baseUrl = await _getBaseUrl();

    final response = await http.post(
      Uri.parse('$baseUrl/api/students/bulk/single'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'students': students}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Student sync failed (${response.statusCode}): ${response.body}',
    );
  }
}
