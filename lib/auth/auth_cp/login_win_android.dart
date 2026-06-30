// login_win_android.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zitf_system/auth/auth_cp/school_interface.dart' as si;
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/school_info.dart' as hi;
import 'package:zitf_system/main.dart';
import 'platform_auth_services.dart';

class PlatformAuthServiceIO implements PlatformAuthService {
  static const _usersSyncedKey = 'users_synced_v1';

  // ✅ Cache for logged-in user
  User? _cachedLoggedInUser;

  // ✅ Helper function to safely parse string lists
  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      try {
        return List<String>.from(value);
      } catch (_) {
        return [];
      }
    }
    if (value is String) {
      if (value.isEmpty) return [];
      // Check if it's a JSON array string
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return List<String>.from(decoded);
        }
      } catch (_) {
        // Not JSON, treat as single value or comma-separated
        if (value.contains(',')) {
          return value.split(',').map((e) => e.trim()).toList();
        }
        return [value];
      }
    }
    return [];
  }

  // ==============================
  // 🔄 SYNC USERS FROM HOST
  // ==============================
  @override
  Future<bool> syncUsersFromHostIfClient({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceRole = await getDeviceRole();

    print('================ SYNC USERS START ================');
    print('🖥 Role: $deviceRole');
    print('⚡ Force sync: $force');

    if (deviceRole != DeviceRole.client) {
      print('ℹ️ Not client → skipping sync');
      return true;
    }

    final alreadySynced = prefs.getBool(_usersSyncedKey) ?? false;
    print('📦 Already synced flag: $alreadySynced');

    if (alreadySynced && !force) {
      print('✅ Sync skipped (cached)');
      return true;
    }

    final hostIp = prefs.getString('host_ip');

    if (hostIp == null || hostIp.isEmpty) {
      print('❌ HOST IP MISSING → cannot sync');
      return false;
    }

    final hostUrl =
        prefs.getString('hostUrl') ?? 'http://$hostIp:8080/api/users/all';

    print('🌐 Host IP: $hostIp');
    print('📡 Host URL: $hostUrl');

    HttpClient? client;

    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

      final request = await client.getUrl(Uri.parse(hostUrl));
      request.headers.add('Accept', 'application/json');
      request.headers.add('X-Client', 'edutrek-client');

      final response = await request.close();

      print('📥 Response Status: ${response.statusCode}');

      final body = await response.transform(utf8.decoder).join();

      print('📦 Raw Response: $body');

      if (response.statusCode != 200) {
        print('❌ SYNC FAILED: HTTP ${response.statusCode}');
        return false;
      }

      final decoded = jsonDecode(body);

      if (decoded is! List) {
        print('❌ INVALID RESPONSE FORMAT (expected List)');
        print('📦 Received: $decoded');
        return false;
      }

      final List usersJson = decoded;

      final userBox = await Hive.openBox<User>('users');

      print('👥 Clearing old users...');
      await userBox.clear();

      // ✅ Parse all users with safe list parsing
      final users = usersJson.map((u) {
        final securityQuestions = _safeStringList(u['securityQuestions']);
        final securityAnswers = _safeStringList(u['securityAnswers']);
        final modifiedFields = _safeStringList(u['modifiedFields']);
        final assignedClasses = _safeStringList(u['assignedClasses']);

        print('📚 User: ${u['username']}, assignedClasses: $assignedClasses');

        return User(
          id: u['id'] as int?,
          username: u['username'] ?? '',
          password: u['password'] ?? '',
          role: u['role'] ?? '',
          securityQuestions: securityQuestions,
          securityAnswers: securityAnswers,
          phone: u['phone'] ?? '',
          email: u['email'] ?? '',
          userCode: u['userCode'] ?? '',
          termId: u['termId'],
          isLogged: false,
          syncStatus: true,
          lastModified: u['lastModified'] != null
              ? DateTime.parse(u['lastModified'])
              : DateTime.now(),
          operationType: u['operationType'] ?? 'create',
          modifiedFields: modifiedFields,
          assignedClasses: assignedClasses,
          isActive: u['isActive'] ?? true,
          createdAt: u['createdAt'] != null
              ? DateTime.parse(u['createdAt'])
              : DateTime.now(),
        );
      }).toList();

      await userBox.addAll(users);

      print('✅ USERS SYNCED: ${userBox.length}');

      // ✅ Clear cache after sync
      _cachedLoggedInUser = null;

      await prefs.setBool(_usersSyncedKey, true);

      print('================ SYNC USERS END (SUCCESS) ================');

      return true;
    } catch (e, st) {
      print('================ SYNC ERROR ================');
      print('❌ ERROR: $e');
      print('📍 STACKTRACE: $st');
      print('===========================================');

      return false;
    } finally {
      client?.close(force: true);
    }
  }

  // ==============================
  // 🔐 LOGIN
  // ==============================
  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    print('================ LOGIN START ================');
    print('👤 Username: $username');
    print('🔑 Password length: ${password.length}');

    final syncResult = await syncUsersFromHostIfClient();

    print('🔄 Sync result: $syncResult');

    final userBox = await Hive.openBox<User>('users');

    print('👥 Users in Hive: ${userBox.length}');

    final user = userBox.values.firstWhereOrNull(
      (u) => u.username == username && u.password == password,
    );

    if (user == null) {
      print('❌ LOGIN FAILED: user not found');
      return false;
    }

    // ✅ Check if user is active
    if (user.isActive == false) {
      print('❌ LOGIN FAILED: user account is deactivated');
      return false;
    }

    for (final u in userBox.values) {
      u.isLogged = false;
      await u.save();
    }

    user.isLogged = true;
    await user.save();

    // ✅ Cache the logged-in user
    _cachedLoggedInUser = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    // ✅ Store user info in preferences
    await prefs.setString('logged_in_username', user.username);
    await prefs.setString('logged_in_role', user.role);
    await prefs.setStringList(
        'logged_in_assigned_classes', user.assignedClasses ?? []);
    await prefs.setBool('logged_in_is_active', user.isActive ?? true);
    await prefs.setString('logged_in_phone', user.phone);
    await prefs.setString('logged_in_email', user.email ?? '');

    print('✅ LOGIN SUCCESS');
    if (user.role.toLowerCase() == 'teacher') {
      print('📚 Teacher assigned classes: ${user.assignedClasses}');
    }
    print('================ LOGIN END ================');

    return true;
  }

  // ==============================
  // 🔍 LOGIN STATE
  // ==============================
  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // ==============================
  // 🚪 LOGOUT
  // ==============================
  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final userBox = await Hive.openBox<User>('users');

    for (final u in userBox.values) {
      u.isLogged = false;
      await u.save();
    }

    // ✅ Clear cache
    _cachedLoggedInUser = null;

    print('🚪 LOGOUT COMPLETE');
  }

  // ==============================
  // 🏫 SCHOOLS
  // ==============================
  @override
  Future<List<si.ISchool>> fetchSchools() async {
    final box = await Hive.openBox<hi.School>('school');

    return box.values
        .where((s) => s.termId != null)
        .map<si.ISchool>((s) => si.School(
              name: s.schoolName.toString(),
              logoPath: s.schoolLogoPath,
              termId: s.termId,
            ))
        .toList();
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

      final userBox = await Hive.openBox<User>('users');
      final user = userBox.values.firstWhere(
        (u) => u.username == username,
        orElse: () => throw Exception('User not found'),
      );

      // ✅ Cache for future use
      _cachedLoggedInUser = user;
      return user;
    } catch (e) {
      debugPrint('❌ Error getting logged-in user: $e');
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

  // ==============================
  // 🐛 DEBUG USERS
  // ==============================
  Future<void> debugUsers() async {
    try {
      final userBox = await Hive.openBox<User>('users');
      print('================ USER DEBUG ================');
      print('Total users: ${userBox.length}');

      for (var user in userBox.values) {
        print('👤 User: ${user.username}');
        print('  - Role: ${user.role}');
        print('  - assignedClasses: ${user.assignedClasses}');
        print('  - isActive: ${user.isActive}');
        print('  - securityQuestions: ${user.securityQuestions}');
        print('  - securityAnswers: ${user.securityAnswers}');
        print('---');
      }
      print('================ USER DEBUG END ================');
    } catch (e) {
      print('❌ Error debugging users: $e');
    }
  }
}
