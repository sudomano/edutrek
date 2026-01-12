import 'package:flutter/foundation.dart';
import 'package:zitf_system/auth/auth_cp/login_web.dart';
import 'package:zitf_system/auth/auth_cp/login_win_android.dart';
import 'package:zitf_system/auth/auth_cp/school_interface.dart';

abstract class PlatformAuthService {
  /// Factory constructor resolves correct implementation
  factory PlatformAuthService() {
    if (kIsWeb) {
      return PlatformAuthServiceWeb();
    } else {
      return PlatformAuthServiceIO();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  });

  Future<bool> isLoggedIn();

  Future<void> logout();
  Future<bool> syncUsersFromHostIfClient({bool force = false});

  Future<List<ISchool>> fetchSchools();
}
