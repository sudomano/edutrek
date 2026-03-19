import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/reusable_codes/serializers/exceptions_serializer.dart';

class ExceptionalStudentApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  static Future<List<ExceptionalStudents>> fetchActiveExceptions(
      String termId) async {
    final baseUrl = await _getBaseUrl();

    final response = await http.get(
      Uri.parse('$baseUrl/api/exceptionalStudents?termId=$termId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exceptional students');
    }

    final List decoded = jsonDecode(response.body);

    return decoded
        .map((e) => exceptionalStudentsFromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
