import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class EditSecurityScreen extends StatefulWidget {
  @override
  _EditSecurityScreenState1 createState() => _EditSecurityScreenState1();
}

class _EditSecurityScreenState1 extends State<EditSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  late List<String> _securityQuestions = [];
  late List<String> _securityAnswers = [];
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    try {
      var userBox = await Hive.openBox<User>('users');
      var adminUser = userBox.values
          .firstWhere((user) => user.role == 'admin'); // Filter admin user

      setState(() {
        _usernameController.text = adminUser.username;
        _passwordController.text = adminUser.password;
        _phoneController.text = adminUser.phone;
        _securityQuestions = List<String>.from(adminUser.securityQuestions);
        _securityAnswers = List<String>.from(adminUser.securityAnswers);
      });
    } catch (e) {
      print("Error loading security data: $e");
    }
  }

  Future<void> _updateSecurityData() async {
    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');
        var adminUser =
            userBox.values.firstWhere((user) => user.role == 'admin');

        List<String> modifiedFields = adminUser.modifiedFields ??
            []; // Initialize with existing modified fields

// Append new modifications without overwriting

        modifiedFields.add('securityQuestions');

        modifiedFields.add('securityAnswers');

        modifiedFields.add('termId');

        modifiedFields.add('username');

        modifiedFields.add('password');

        modifiedFields.add('phone');

        adminUser.username = _usernameController.text;
        adminUser.password = _passwordController.text;
        adminUser.phone = _phoneController.text;
        adminUser.securityQuestions = _securityQuestions;
        adminUser.securityAnswers = _securityAnswers;
        adminUser.termId = globalTermId;
        adminUser.syncStatus = false;
        adminUser.lastModified = DateTime.now();
        adminUser.operationType = 'create';
        adminUser.userCode = 'admin';
        modifiedFields = modifiedFields;

        await userBox.putAt(userBox.values.toList().indexOf(adminUser),
            adminUser); // Save changes to the database

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isUpdatedSecurity', true);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Admin updated successfully'),
        ));
      } catch (e) {
        print("Error updating security data: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update data. Please try again.'),
        ));
      }
    }
  }

  void _viewSecurityData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Questions & Answers'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _securityQuestions.length; i++)
                ListTile(
                  title: Text('Question ${i + 1}: ${_securityQuestions[i]}'),
                  subtitle: Text('Answer ${i + 1}: ${_securityAnswers[i]}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'View Admin',
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: !_isPasswordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_securityQuestions.isNotEmpty)
                for (int i = 0; i < 3; i++)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: _securityQuestions.length > i
                            ? _securityQuestions[i]
                            : '',
                        decoration: InputDecoration(
                          labelText: 'Security Question ${i + 1}',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          if (_securityQuestions.length > i) {
                            _securityQuestions[i] = value;
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a security question';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _securityAnswers.length > i
                            ? _securityAnswers[i]
                            : '',
                        decoration: InputDecoration(
                          labelText: 'Answer ${i + 1}',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          if (_securityAnswers.length > i) {
                            _securityAnswers[i] = value;
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an answer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
              ElevatedButton(
                onPressed: _updateSecurityData,
                child: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 7, 7, 7),
                  backgroundColor: const Color.fromARGB(255, 208, 207, 207),
                  textStyle: const TextStyle(fontSize: 16),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
