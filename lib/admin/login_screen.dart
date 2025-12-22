import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:collection/collection.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/main.dart';
import 'dart:async';

import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  static const _usersSyncedKey = 'users_synced_v1';

  @override
  void initState() {
    super.initState();
    // Trigger background sync once on init for client devices
    _syncUsersFromHostIfClient();
  }

  /// Returns true if sync succeeded (or not needed), false on failure.
  Future<bool> _syncUsersFromHostIfClient({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceRole = await getDeviceRole();

    if (deviceRole != DeviceRole.client) {
      print('SYNC: Device is HOST — no client sync required.');
      return true;
    }

    final alreadySynced = prefs.getBool(_usersSyncedKey) ?? false;
    if (alreadySynced && !force) {
      print('SYNC: Already synced previously — skipping sync.');
      return true;
    }

    print('SYNC: Client device detected. Starting user sync from host...');

    final userBox = await Hive.openBox<User>('users');

    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    final hostUrl = prefs.getString('hostUrl') ??
        'http://$hostIp:8080/api/users/all'; // the new endpoint

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);

      print('SYNC: Requesting $hostUrl');
      final request = await client.getUrl(Uri.parse(hostUrl));

      // optionally send an identifying header (helpful for server logs)
      request.headers.add('X-Client', 'edutrek-client');

      final response = await request.close().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('Host request timed out (12s)');
        },
      );

      print('SYNC: Host response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        print('SYNC: Unexpected status ${response.statusCode}, body: $body');
        return false;
      }

      final body = await response.transform(utf8.decoder).join();
      final List<dynamic> usersJson = jsonDecode(body) as List<dynamic>;

      print('SYNC: Received ${usersJson.length} users from host (raw).');

      // Build user list
      final users = usersJson.map((u) {
        return User(
          username: u['username'] ?? '',
          password: u['password'] ?? '',
          role: u['role'] ?? '',
          securityQuestions:
              List<String>.from(u['securityQuestions'] ?? <String>[]),
          securityAnswers:
              List<String>.from(u['securityAnswers'] ?? <String>[]),
          phone: u['phone'] ?? '',
          email: u['email'] ?? '',
          isLogged: false,
        );
      }).toList();

      // Clear local users only after successful fetch
      print('SYNC: Clearing local users and writing ${users.length} users...');
      await userBox.clear();
      if (users.isNotEmpty) {
        // addAll returns list of keys; handle it as fire-and-forget
        await userBox.addAll(users);
      }
      print(
          'SYNC: Completed local save. Example users: ${users.take(5).map((u) => u.username).toList()}');

      // mark as synced
      await prefs.setBool(_usersSyncedKey, true);
      print('SYNC: users_synced flag set to true.');

      return true;
    } catch (e, st) {
      print('SYNC: Error while syncing users from host -> $e');
      print(st);
      // keep local users untouched if fetch failed (we did not clear until after success)
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<List<School>> fetchSchools() async {
    var box = await Hive.openBox<School>('school');
    return box.values.where((schoolItem) => schoolItem.termId != null).toList();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final userBox = await Hive.openBox<User>('users');
      final prefs = await SharedPreferences.getInstance();

      // Make sure client devices have attempted sync once (fallback)
      final deviceRole = await getDeviceRole();
      if (deviceRole == DeviceRole.client) {
        final synced = prefs.getBool(_usersSyncedKey) ?? false;
        if (!synced) {
          print(
              'LOGIN: No prior sync detected — attempting on-demand sync before login.');
          final ok = await _syncUsersFromHostIfClient(force: true);
          if (!ok) {
            // warn user but still try to login with whatever is available
            print(
                'LOGIN: On-demand sync failed — continuing with local users (if any).');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Could not sync users from host. Using cached users (if any).')),
            );
          }
        }
      }

      final user = userBox.values.firstWhereOrNull(
        (u) => u.username == username && u.password == password,
      );

      if (user != null) {
        // Reset previous logged-in users
        for (var u in userBox.values) {
          if (u.isLogged == true) {
            u.isLogged = false;
            await u.save();
          } else {
            // keep minimal writes
            u.isLogged = false;
            await u.save();
          }
        }

        user.isLogged = true;
        await user.save();

        await prefs.setBool('isLoggedIn', true);
        print('LOGIN: Successful. Navigating to welcome for ${user.username}');
        Navigator.pushReplacementNamed(context, '/welcome', arguments: user);
      } else {
        print('LOGIN: Invalid credentials for username: $username');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid credentials or insufficient role')),
        );
      }
    } catch (e, st) {
      print('LOGIN: Exception during login -> $e');
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------- UI below unchanged (copied from your version) ----------------
  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'User Login',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FutureBuilder<List<School>>(
                future: fetchSchools(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return const Text(
                      "No  Schools Yet",
                      style: TextStyle(color: Colors.red),
                    );
                  } else if (snapshot.hasData) {
                    return Column(
                      children: snapshot.data!.map((schoolItem) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: schoolItem.schoolLogoPath != null
                              ? Image.file(
                                  File(schoolItem.schoolLogoPath!),
                                  width: 300,
                                  height: 250,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                        );
                      }).toList(),
                    );
                  } else {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 80,
                          color: Colors.blueAccent,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'EduTrek \n SCHOOL MANAGEMENT SYSTEM \n',
                          style: TextStyle(
                            fontSize: 26,
                            fontStyle: FontStyle.normal,
                            color: Color.fromARGB(255, 36, 32, 32),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              _buildTextField('Username', _usernameController, Icons.person),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 32),
              _isLoading
                  ? Column(
                      children: [
                        LinearProgressIndicator(
                          minHeight: 6,
                          color: Colors.blue,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading, please wait...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/forgot');
                },
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.black.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color.fromARGB(179, 12, 12, 12)),
        labelText: label,
        filled: true,
        fillColor: const Color.fromARGB(255, 249, 248, 248).withOpacity(0.1),
        labelStyle: const TextStyle(color: Color.fromARGB(179, 12, 12, 12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color.fromARGB(255, 10, 10, 10)),
        ),
      ),
      style: const TextStyle(color: Color.fromARGB(255, 12, 12, 12)),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.lock, color: Color.fromARGB(179, 11, 11, 11)),
        labelText: 'Password',
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        labelStyle: const TextStyle(color: Color.fromARGB(179, 17, 16, 16)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color.fromARGB(255, 12, 12, 12)),
        ),
        suffixIcon: IconButton(
          icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Color.fromARGB(255, 10, 10, 10)),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }
}
