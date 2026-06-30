import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';

class StudentRegisterFetchApi {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  static Future<List<Student>> fetchByClass({
    required String className,
    required String termId,
  }) async {
    final baseUrl = await _getBaseUrl();

    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/students?class=$className&termId=$termId',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch students');
    }

    final List decoded = jsonDecode(response.body);
    return decoded.map((e) => studentsFromJson(e)).toList();
  }

  // ✅ NEW: Fetch ALL students using /all endpoint
  static Future<List<Student>> fetchAllStudents() async {
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/all'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List decoded = jsonDecode(response.body);
        return decoded
            .map((json) => studentsFromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw Exception('Failed to fetch all students: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching all students: $e');
    }
  }

  // ✅ NEW: Check if attendance is already marked for a class on a specific date
  static Future<bool> isAttendanceMarked({
    required String className,
    required DateTime date,
  }) async {
    final baseUrl = await _getBaseUrl();

    try {
      final formattedDate = date.toIso8601String().split('T')[0]; // YYYY-MM-DD

      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/students/registers/check?class=$className&date=$formattedDate',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['isMarked'] ?? false;
      } else if (response.statusCode == 404) {
        // Endpoint not found - fallback to checking students directly
        return false;
      } else {
        return false;
      }
    } catch (e) {
      // If API call fails, return false (not marked)
      return false;
    }
  }

  // ✅ NEW: Get attendance status for a specific student on a date
  static Future<bool> isStudentMarked({
    required String studentId,
    required DateTime date,
  }) async {
    final baseUrl = await _getBaseUrl();

    try {
      final formattedDate = date.toIso8601String().split('T')[0];

      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/students/$studentId/attendance?date=$formattedDate',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['isMarked'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
