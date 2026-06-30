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

    print('📡 Fetching from: $baseUrl/api/exceptionalStudents?termId=$termId');

    final response = await http.get(
      Uri.parse('$baseUrl/api/exceptionalStudents?termId=$termId'),
      headers: {'Content-Type': 'application/json'},
    );

    print('📡 Response status: ${response.statusCode}');
    print('📡 Response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exceptional students');
    }

    final List decoded = jsonDecode(response.body);

    print('📊 Decoded ${decoded.length} exceptions');
    for (var item in decoded) {
      print(
          '  - ${item['exceptionName']}: priorityFlag=${item['priorityFlag']}');
    }

    return decoded
        .map((e) => exceptionalStudentsFromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
