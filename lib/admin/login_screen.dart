import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:collection/collection.dart';
import 'package:zitf_system/database/school_info.dart';
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
  String? _selectedRole;
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  bool _isPasswordVisible = false;

  Future<List<School>> fetchSchools() async {
    var box = await Hive.openBox<School>('school');
    return box.values.where((schoolItem) => schoolItem.termId != null).toList();
  }

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
                        SizedBox(height: 16), // Space between the icon and text
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

              // Logo or branding
              // Welcoming Note
              FutureBuilder<List<School>>(
                future: fetchSchools(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return const Text(
                      "Error fetching school data",
                      style: TextStyle(color: Colors.red),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final schoolItem = snapshot
                        .data!.first; // Use the first school for display
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        '${schoolItem.schoolName} School Management System',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.normal,
                          color: Color.fromARGB(255, 1, 1, 1),
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(2, 2),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
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
                        SizedBox(height: 16), // Space between the icon and text
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
              _buildTextField(
                'Username',
                _usernameController,
                Icons.person,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 32),
              _isLoading
                  ? Column(
                      children: [
                        LinearProgressIndicator(
                          minHeight: 6, // Optional: Adjust the thickness
                          color: Colors.blue, // Primary progress color
                          backgroundColor:
                              Colors.grey[300], // Optional: Track color
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading, please wait...', // Replace percentage with a subtle message
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color.fromARGB(255, 12, 12, 12)),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
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

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final username = _usernameController.text;
      final password = _passwordController.text;

      try {
        // Open the Hive box
        var userBox = await Hive.openBox<User>('users');

        // Find the user matching the credentials
        final user = userBox.values.firstWhereOrNull(
          (user) => user.username == username && user.password == password,
        );

        if (user != null) {
          print("Login attempt successful for username: $username");

          // Reset isLogged for all users
          for (var u in userBox.values) {
            if (u.isLogged == true) {
              print("Dislogged user: ${u.username}");
            }
            u.isLogged = false;
            userBox.put(u.id.toString(), u); // Ensure key is a String
          }

          // Mark the current user as logged in
          user.isLogged = true;
          userBox.put(user.id.toString(), user); // Ensure key is a String

          print("Logged-in user: ${user.username}");

          // Store login status in SharedPreferences (optional)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          // Navigate based on role
          if (user.role.toLowerCase() != 'null') {
            Navigator.pushReplacementNamed(context, '/welcome',
                arguments: user);
          }
        } else {
          print("Invalid login attempt for username: $username");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid credentials or insufficient role')),
          );
        }
      } catch (e) {
        print("Error during login: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
