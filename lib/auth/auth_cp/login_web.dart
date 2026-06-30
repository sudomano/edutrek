// login_web.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/auth_cp/platform_auth_services.dart';
import 'package:zitf_system/auth/auth_cp/school_interface.dart';
import 'package:zitf_system/auth/userdb.dart';

class PlatformAuthServiceWeb implements PlatformAuthService {
  // ✅ Cache for logged-in user
  User? _cachedLoggedInUser;

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

      // ✅ Store user info
      await prefs.setString('logged_in_username', data['username'] ?? '');
      await prefs.setString('logged_in_role', data['role'] ?? '');
      await prefs.setString('logged_in_email', data['email'] ?? '');
      await prefs.setString('logged_in_phone', data['phone'] ?? '');
      await prefs.setStringList('logged_in_assigned_classes', []);
      await prefs.setBool('logged_in_is_active', true);

      // ✅ Create a user object for caching
      _cachedLoggedInUser = User(
        username: data['username'] ?? '',
        password: '',
        role: data['role'] ?? '',
        securityQuestions: [],
        securityAnswers: [],
        phone: data['phone'] ?? '',
        email: data['email'] ?? '',
        userCode: data['userCode'] ?? '',
        isLogged: true,
        isActive: true,
        assignedClasses: [],
        createdAt: DateTime.now(),
      );

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
    _cachedLoggedInUser = null;
  }

  @override
  Future<List<ISchool>> fetchSchools() async {
    // Return dummy schools for web
    return [
      DummySchool(name: 'Bilaal College'),
      DummySchool(name: 'Sunrise Academy'),
    ];
  }

  // ==============================
  // 👤 GET LOGGED IN USER
  // ==============================
  @override
  Future<User?> getLoggedInUser() async {
    try {
      // ✅ First check cache
      if (_cachedLoggedInUser != null) {
        return _cachedLoggedInUser;
      }

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('logged_in_username');

      if (username == null || username.isEmpty) {
        return null;
      }

      // For web, reconstruct from preferences
      final role = prefs.getString('logged_in_role') ?? '';
      final email = prefs.getString('logged_in_email') ?? '';
      final phone = prefs.getString('logged_in_phone') ?? '';
      final assignedClasses =
          prefs.getStringList('logged_in_assigned_classes') ?? [];
      final isActive = prefs.getBool('logged_in_is_active') ?? true;

      final user = User(
        username: username,
        password: '',
        role: role,
        securityQuestions: [],
        securityAnswers: [],
        phone: phone,
        email: email,
        userCode: prefs.getString('userCode') ?? '',
        isLogged: true,
        isActive: isActive,
        assignedClasses: assignedClasses,
        createdAt: DateTime.now(),
      );

      _cachedLoggedInUser = user;
      return user;
    } catch (e) {
      debugPrint('❌ Error getting web logged-in user: $e');
      return null;
    }
  }

  // ==============================
  // 👤 GET LOGGED IN USER (SYNC)
  // ==============================
  @override
  User? getLoggedInUserSync() {
    return _cachedLoggedInUser;
  }
}
