import 'dart:io';
import 'dart:convert';

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

  @override
  Future<bool> syncUsersFromHostIfClient({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceRole = await getDeviceRole();

    if (deviceRole != DeviceRole.client) {
      return true;
    }

    final alreadySynced = prefs.getBool(_usersSyncedKey) ?? false;
    if (alreadySynced && !force) return true;

    final userBox = await Hive.openBox<User>('users');

    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    final hostUrl =
        prefs.getString('hostUrl') ?? 'http://$hostIp:8080/api/users/all';

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

      final request = await client.getUrl(Uri.parse(hostUrl));
      request.headers.add('X-Client', 'edutrek-client');

      final response = await request.close();
      if (response.statusCode != 200) return false;

      final body = await response.transform(utf8.decoder).join();
      final List usersJson = jsonDecode(body);

      final users = usersJson
          .map((u) => User(
                username: u['username'] ?? '',
                password: u['password'] ?? '',
                role: u['role'] ?? '',
                securityQuestions:
                    List<String>.from(u['securityQuestions'] ?? []),
                securityAnswers: List<String>.from(u['securityAnswers'] ?? []),
                phone: u['phone'] ?? '',
                email: u['email'] ?? '',
                isLogged: false,
              ))
          .toList();

      await userBox.clear();
      await userBox.addAll(users);

      await prefs.setBool(_usersSyncedKey, true);
      return true;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    await syncUsersFromHostIfClient();

    final userBox = await Hive.openBox<User>('users');

    final user = userBox.values.firstWhereOrNull(
      (u) => u.username == username && u.password == password,
    );

    if (user == null) return false;

    for (final u in userBox.values) {
      u.isLogged = false;
      await u.save();
    }

    user.isLogged = true;
    await user.save();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    return true;
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

    final userBox = await Hive.openBox<User>('users');
    for (final u in userBox.values) {
      u.isLogged = false;
      await u.save();
    }
  }

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
}
