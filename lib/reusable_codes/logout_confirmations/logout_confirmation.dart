import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/admin/login_screen.dart';
import 'package:collection/collection.dart'; // Import the collection package

void showLogoutConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout Confirmation'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Dismiss the dialog
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', false); // Clear login state
            try {
              // Open the Hive box for users if not already open
              if (!Hive.isBoxOpen('users')) {
                await Hive.openBox<User>('users');
              }
              // Access the Hive database to update the isLogged field
              var userBox = Hive.box<User>('users');
              var loggedInUser = userBox.values
                  .firstWhereOrNull((user) => user.isLogged == true);

              if (loggedInUser != null) {
                print(
                    "Logging out user: ${loggedInUser.username}"); // Log logged-in user

                int userKey = userBox
                    .keyAt(userBox.values.toList().indexOf(loggedInUser));
                var updatedUser = loggedInUser.copyWith(isLogged: false);
                await userBox.put(
                    userKey, updatedUser); // Update the user's isLogged field

                print(
                    "User ${loggedInUser.username} has been logged out successfully."); // Confirm user logout
              } else {
                print(
                    "No logged-in user found."); // Log if no user was logged in
              }
            } catch (e) {
              print("Error accessing Hive box: $e"); // Log Hive-related errors
            }

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
              (Route<dynamic> route) => false, // Remove all previous routes
            );
          },
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}
