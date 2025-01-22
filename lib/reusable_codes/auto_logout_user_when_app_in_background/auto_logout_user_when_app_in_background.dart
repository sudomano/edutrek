import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/admin/login_screen.dart';
import 'package:collection/collection.dart';

class AutoLogoutManager with WidgetsBindingObserver {
  static const inactivityTimeout =
      Duration(minutes: 60); // Adjust timeout as needed
  Timer? _inactivityTimer;

  /// Call this to start observing app lifecycle and user inactivity.
  void initialize(BuildContext context) {
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer(context);
  }

  /// Call this to stop observing (e.g., on logout or app exit).
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is in the background
      _logoutUser(context: _currentContext);
    }
  }

  late BuildContext _currentContext;

  /// Starts or resets the inactivity timer
  void resetInactivityTimer(BuildContext context) {
    _currentContext = context;
    _inactivityTimer?.cancel();
    _startInactivityTimer(context);
  }

  void _startInactivityTimer(BuildContext context) {
    _inactivityTimer = Timer(inactivityTimeout, () {
      _logoutUser(context: context);
    });
  }

  /// Logs out the user and redirects to the login screen
  Future<void> _logoutUser({required BuildContext context}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Clear login state

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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }
}





/*
  final autoLogoutManager = AutoLogoutManager();

autoLogoutManager.initialize(context);

*/