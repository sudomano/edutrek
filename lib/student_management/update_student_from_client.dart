import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:http/http.dart' as http;

class StudentApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip');
    if (hostIp == null) throw Exception('Host IP not configured');
    return 'http://$hostIp:8080';
  }

  static Future<List<Student>> searchStudents(String query) async {
    final baseUrl = await _getBaseUrl();

    final response = await http.get(
      Uri.parse('$baseUrl/api/students?search=${Uri.encodeComponent(query)}'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch students');
    }

    final List decoded = jsonDecode(response.body);

    return decoded.map<Student>((json) => studentsFromJson(json)).toList();
  }
}
