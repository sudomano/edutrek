import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';

class TermApiService {
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    return 'http://$hostIp:8080';
  }

  static Future<List<Terms>> fetchTerms() async {
    final baseUrl = await _getBaseUrl();

    final response = await http.get(
      Uri.parse('$baseUrl/api/terms'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch terms');
    }

    final List decoded = jsonDecode(response.body);

    return decoded
        .map((t) => termsFromJson(Map<String, dynamic>.from(t)))
        .toList();
  }
}
