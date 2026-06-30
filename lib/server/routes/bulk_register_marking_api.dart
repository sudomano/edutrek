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

  static Future<Map<String, dynamic>> markBulkRegister({
    required String className,
    required String termId,
    required DateTime date,
    required List<Student> students,
  }) async {
    final baseUrl = await _getBaseUrl();

    final body = {
      'className': className,
      'termId': termId,
      'date': date.toIso8601String().split('T')[0],
      'records': students
          .map((student) => {
                'studentId': student.studentIdNumber,
                'isPresent': student.isPresent,
              })
          .toList(),
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register/mark/bulk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 409) {
        final errorResponse = jsonDecode(response.body);
        final allowUpdate = errorResponse['allowUpdate'] ?? false;
        final message = errorResponse['message'] ?? 'Attendance already marked';

        // ✅ Include the allowUpdate flag in the exception
        throw AttendanceConflictException(
          message: message,
          allowUpdate: allowUpdate,
          response: errorResponse,
        );
      } else {
        throw Exception(
            'Failed to mark attendance: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is AttendanceConflictException) rethrow;
      throw Exception('Error marking attendance: $e');
    }
  }
}

// ✅ Custom exception for attendance conflicts
class AttendanceConflictException implements Exception {
  final String message;
  final bool allowUpdate;
  final Map<String, dynamic>? response;

  AttendanceConflictException({
    required this.message,
    required this.allowUpdate,
    this.response,
  });

  @override
  String toString() => message;
}
