import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/configScreen.dart';

Future<void> developerLogin(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final storedUsername = prefs.getString('developerUsername') ?? '';
  final storedPassword = prefs.getString('developerPassword') ?? '';

  String username = '';
  String password = '';
  bool loginSuccess = false;

  await showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissal by tapping outside
    builder: (context) {
      return AlertDialog(
        title: const Text("Developer Login"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Username"),
              onChanged: (value) {
                username = value;
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
              onChanged: (value) {
                password = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cancel login
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (username == storedUsername && password == storedPassword) {
                loginSuccess = true;
                Navigator.of(context).pop();
              } else {
                // Optionally, show an error message if credentials are invalid.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid credentials.")),
                );
              }
            },
            child: const Text("Login"),
          ),
        ],
      );
    },
  );

  if (loginSuccess) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DomainConfigScreen()),
    );
  }
}
