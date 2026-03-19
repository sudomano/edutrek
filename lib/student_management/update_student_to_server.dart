import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';

class StudentApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  /// Update a student on the host
  static Future<Map<String, dynamic>> updateStudent(Student student) async {
    final baseUrl = await _getBaseUrl();
    final studentId = student.studentIdNumber ?? student.regNumber;

    final response = await http.put(
      Uri.parse('$baseUrl/api/students/$studentId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(studentsToJson(student)), // Send all fields
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
        'Failed to update student (${response.statusCode}): ${response.body}');
  }
}
