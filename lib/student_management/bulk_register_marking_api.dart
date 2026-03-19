import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/student.dart';

class StudentRegisterBulkApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  static Future<void> markBulkRegister({
    required String className,
    required String termId,
    required DateTime date,
    required List<Student> students,
  }) async {
    final baseUrl = await _getBaseUrl();

    final payload = {
      "className": className,
      "termId": termId,
      "date": date.toIso8601String().split('T').first,
      "records": students.map((s) {
        return {
          "studentId": s.studentIdNumber,
          "isPresent": s.isPresent,
        };
      }).toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/register/mark/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Bulk attendance failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
