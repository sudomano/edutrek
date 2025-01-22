import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class deleteSecurityScreen extends StatefulWidget {
  @override
  _UpdateSecurityScreenState2 createState() => _UpdateSecurityScreenState2();
}

class _UpdateSecurityScreenState2 extends State<deleteSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  late List<String> _securityQuestions;
  late List<String> _securityAnswers;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    try {
      var userBox = await Hive.openBox<User>('users');
      if (userBox.isNotEmpty) {
        User user = userBox.values.first; // Assuming admin user is first

        setState(() {
          _usernameController.text = user.username;
          _passwordController.text = user.password;
          _phoneController.text = user.phone;
          _securityQuestions = List<String>.from(user.securityQuestions);
          _securityAnswers = List<String>.from(user.securityAnswers);
        });
      }
    } catch (e) {
      print("Error loading security data: $e");
    }
  }

  Future<void> _updateSecurityData() async {
    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');
        if (userBox.isNotEmpty) {
          User user = userBox.values.first; // Assuming admin user is first

          user.username = _usernameController.text;
          user.password = _passwordController.text;
          user.phone = _phoneController.text;
          user.securityQuestions = _securityQuestions;
          user.securityAnswers = _securityAnswers;
          user.syncStatus = false;
          user.lastModified = DateTime.now();
          user.operationType = 'update';

          user.termId = globalTermId;

          await userBox.putAt(0, user); // Save changes to the database

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isUpdatedSecurity', true);

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Security questions and answers updated')));
        }
      } catch (e) {
        print("Error updating security data: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update data. Please try again.')));
      }
    }
  }

  Future<void> _deleteUser() async {
    try {
      var userBox = await Hive.openBox<User>('users');
      if (userBox.isNotEmpty) {
        await userBox.clear(); // Clear all users from the box

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isUpdatedSecurity');

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User data deleted successfully')));
      }
    } catch (e) {
      print("Error deleting user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete user data. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Security Questions & Answers'),
        actions: [
          IconButton(
            onPressed: _deleteUser,
            icon: Icon(Icons.delete),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                for (int i = 0; i < 5; i++)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: _securityQuestions.length > i
                            ? _securityQuestions[i]
                            : '',
                        decoration: InputDecoration(
                            labelText: 'Security Question ${i + 1}'),
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
                      SizedBox(height: 8),
                      TextFormField(
                        initialValue: _securityAnswers.length > i
                            ? _securityAnswers[i]
                            : '',
                        decoration:
                            InputDecoration(labelText: 'Answer ${i + 1}'),
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
                      SizedBox(height: 16),
                    ],
                  ),
                ElevatedButton(
                  onPressed: _updateSecurityData,
                  child: Text('Save Changes'),
                ),
              ],
            ),
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
