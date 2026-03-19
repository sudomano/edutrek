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
}
