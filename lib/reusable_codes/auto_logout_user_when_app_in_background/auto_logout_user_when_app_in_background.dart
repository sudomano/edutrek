import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/admin/login_screen.dart';
import 'package:collection/collection.dart';
import 'package:zitf_system/database/auto_logout_timer/auto_logou_timer.dart';
import 'package:zitf_system/main.dart';

class AutoLogoutManager with WidgetsBindingObserver {
  // Foreground inactivity timeout (if needed) remains unchanged.
  static const inactivityTimeout = Duration(minutes: 720);

  Timer? _inactivityTimer;
  Timer? _backgroundTimer;

  late BuildContext _currentContext;

  /// Initialize the AutoLogoutManager.
  void initialize(BuildContext context) {
    _currentContext = context;
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer();
  }

  /// Dispose and clean up resources.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _backgroundTimer?.cancel();
  }

  /// Listen for app lifecycle changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // When app goes to background, start a background timer using the user setting.
      print("App paused. Starting background timer for logout...");
      _backgroundTimer?.cancel();
      int timeoutMinutes = await _getUserLogoutTimeout();
      _backgroundTimer = Timer(Duration(minutes: timeoutMinutes), () {
        print(
            "Background timer elapsed (${timeoutMinutes} minute(s)). Logging out...");
        _logoutUser();
      });
    } else if (state == AppLifecycleState.resumed) {
      // Cancel background timer if app resumes.
      print("App resumed. Cancelling background timer...");
      _backgroundTimer?.cancel();
      _startInactivityTimer();
    }
  }

  /// Resets the inactivity timer whenever user interaction occurs.
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  /// Starts the inactivity timer for foreground activity.
  void _startInactivityTimer() {
    _inactivityTimer = Timer(inactivityTimeout, _logoutUser);
  }

  /// Reads the user-defined logout timeout from Hive.
  Future<int> _getUserLogoutTimeout() async {
    final settingsBox = Hive.box<AutoLogoutSettings>('auto_logout_settings');
    final settings = settingsBox.get('settings') ?? AutoLogoutSettings();
    return settings.logoutTimeoutMinutes;
  }

  /// Logs out the user and navigates to the login screen.
  Future<void> _logoutUser() async {
    _inactivityTimer?.cancel();
    _backgroundTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    var userBox = Hive.box<User>('users');
    var loggedInUser =
        userBox.values.firstWhereOrNull((user) => user.isLogged == true);

    if (loggedInUser != null) {
      print("Logging out user: ${loggedInUser.username}");
      int userKey =
          userBox.keyAt(userBox.values.toList().indexOf(loggedInUser));
      var updatedUser = loggedInUser.copyWith(isLogged: false);
      await userBox.put(userKey, updatedUser);
      print("User ${loggedInUser.username} has been logged out successfully.");
    } else {
      print("No logged-in user found.");
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
    });
  }
}
