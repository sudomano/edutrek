import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/auth_cp/platform_auth_services.dart';
import 'package:zitf_system/auth/auth_cp/school_interface.dart';

class PlatformAuthServiceWeb implements PlatformAuthService {
  @override
  Future<bool> syncUsersFromHostIfClient({bool force = false}) async {
    // 🌐 Web does not sync local users
    return true;
  }

  static const String baseUrl =
      'https://edutrekholdings.co.zw/api_school_management_system/php_codes_for_a_restful_api';

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('HTTP error ${response.statusCode}: ${response.body}');
        return false;
      }
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['success'] != true) {
        return false;
      }

      // ✅ Store login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', data['username']);
      await prefs.setString('role', data['role'] ?? '');
      await prefs.setString('userCode', data['userCode'] ?? '');

      return true;
    } catch (e) {
      print('Web login error: $e');
      return false;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Future<List<ISchool>> fetchSchools() async {
    // Return dummy schools for web
    return [
      DummySchool(name: 'Bilaal College'),
      DummySchool(name: 'Sunrise Academy'),
    ];
  }
}
