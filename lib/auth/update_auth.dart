import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/auth/crud_auth/view_admin_auth.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class ViewSecurityScreen extends StatefulWidget {
  @override
  _ViewSecurityScreenState createState() => _ViewSecurityScreenState();
}

class _ViewSecurityScreenState extends State<ViewSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  late List<String> _securityQuestions;
  late List<String> _securityAnswers;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    try {
      var userBox = await Hive.openBox<User>('users');
      var adminUserList =
          userBox.values.where((user) => user.role == 'admin').toList();

      if (adminUserList.isEmpty) {
        List<String> modifiedFields = [];
        modifiedFields.add('username');
        modifiedFields.add('userCode');
        modifiedFields.add('password');
        modifiedFields.add('role');
        modifiedFields.add('securityQuestions');
        modifiedFields.add('securityAnswers');
        modifiedFields.add('phone');
        modifiedFields.add('termId');
        // No admin account found, initialize dummy account and save it
        var dummyUser = User(
          username: 'admin',
          password: 'admin1234',
          phone: '1234567890',
          role: 'admin',
          id: 1,
          securityQuestions: [
            'Dummy question 1',
            'Dummy question 2',
            'Dummy question 3'
          ],
          securityAnswers: [
            'Dummy answer 1',
            'Dummy answer 2',
            'Dummy answer 3'
          ],
          modifiedFields: modifiedFields,
        );
        await userBox.add(dummyUser);
        adminUserList.add(dummyUser);
      }

      var adminUser = adminUserList.first; // Assuming first admin user

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

  Future<int> getNextId() async {
    final box = await Hive.openBox<User>('users');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _updateSecurityData() async {
    int newId = await getNextId();

    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');
        var adminUserList =
            userBox.values.where((user) => user.role == 'admin').toList();
        if (adminUserList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No admin user found in the database'),
          ));
        } else {
          var adminUser = adminUserList.first; // Assuming first admin user
          adminUser.id = newId;
          adminUser.username = _usernameController.text;
          adminUser.password = _passwordController.text;
          adminUser.phone = _phoneController.text;
          adminUser.securityQuestions = _securityQuestions;
          adminUser.securityAnswers = _securityAnswers;
          adminUser.termId = globalTermId;
          adminUser.syncStatus = false;
          adminUser.lastModified = DateTime.now();
          adminUser.userCode = 'admin';
          adminUser.operationType = 'update';

          await userBox.putAt(userBox.values.toList().indexOf(adminUser),
              adminUser); // Save changes to the database

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isUpdatedSecurity', true);

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Security questions and answers updated')));
        }
      } catch (e) {
        print("Error updating security data: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to update data. Please try again.')));
      }
    }
  }

  Future<void> _deleteSecurityData() async {
    try {
      var userBox = await Hive.openBox<User>('users');
      var adminUserList =
          userBox.values.where((user) => user.role == 'admin').toList();

      if (adminUserList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No admin user found in the database')));
      } else {
        var adminUser = adminUserList.first; // Assuming first admin user
        await userBox.deleteAt(
            userBox.values.toList().indexOf(adminUser)); // Delete admin user

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isDeletedSecurity', true);

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Admin deleted')));
      }
    } catch (e) {
      print("Error deleting security data: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to delete data. Please try again.')));
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

  void _refreshData() async {
    await _loadSecurityData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Data refreshed'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('View Adminnns')),
        actions: [
          IconButton(
            icon: const Icon(Icons.home,
                size: 30, color: Colors.blue), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          IconButton(
            onPressed: _viewSecurityData,
            icon: const Icon(Icons.visibility),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 30, color: Colors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditSecurityScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _refreshData,
          )
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
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
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
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
                      decoration:
                          const InputDecoration(labelText: 'Phone Number'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: 'admin', // Show role value here
                      decoration: const InputDecoration(labelText: 'Role'),
                      enabled: false, // Disable editing role
                    ),
                  ],
                ),
              ),
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
