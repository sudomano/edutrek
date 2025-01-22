import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateSecretaryScreen extends StatefulWidget {
  final int index;

  UpdateSecretaryScreen({required this.index});

  @override
  _UpdateSecretaryScreenState createState() => _UpdateSecretaryScreenState();
}

class _UpdateSecretaryScreenState extends State<UpdateSecretaryScreen> {
  late User _secretary;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPasswordVisible = true;

  @override
  void initState() {
    super.initState();
    _loadSecretaryData();
  }

  Future<void> _loadSecretaryData() async {
    var userBox = await Hive.openBox<User>('users');
    _secretary = userBox.getAt(widget.index)!;
    _usernameController.text = _secretary.username;
    _passwordController.text = _secretary.password;
    _phoneController.text = _secretary.phone;
  }

  Future<void> _updateSecretary() async {
    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');
        _secretary = userBox.getAt(widget.index)!;

        int? newId = _secretary.id;

        List<String> modifiedFields = _secretary.modifiedFields ??
            []; // Initialize with existing modified fields

// Append new modifications without overwriting
        if (_secretary.id != newId) {
          if (!modifiedFields.contains('id')) {
            modifiedFields.add('id');
          }
        }
        print(_secretary.id);
        print(newId);

        if (_secretary.username.toLowerCase() !=
            _usernameController.text.toLowerCase()) {
          if (!modifiedFields.contains('username')) {
            modifiedFields.add('username');
          }
        }
        print(_secretary.username.toLowerCase());
        print(_usernameController.text.toLowerCase());

        if (_secretary.password.toLowerCase() !=
            _passwordController.text.toLowerCase()) {
          if (!modifiedFields.contains('password')) {
            modifiedFields.add('password');
          }
        }
        print(_secretary.password.toLowerCase());
        print(_passwordController.text.toLowerCase());

        if (_secretary.phone.toLowerCase() !=
            _phoneController.text.toLowerCase()) {
          if (!modifiedFields.contains('phone')) {
            modifiedFields.add('phone');
          }
        }
        print(_secretary.phone.toLowerCase());
        print(_phoneController.text.toLowerCase());

        final code = _secretary.userCode;
        _secretary.id = newId;
        _secretary.username = _usernameController.text;
        _secretary.password = _passwordController.text;
        _secretary.phone = _phoneController.text;
        _secretary.operationType = 'update';
        _secretary.lastModified = DateTime.now();
        _secretary.termId = globalTermId;
        _secretary.syncStatus = false;
        _secretary.userCode = code;
        modifiedFields = modifiedFields;

        await userBox.putAt(widget.index, _secretary);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Secretary updated successfully'),
        ));

        Navigator.pop(context);
        Navigator.pop(context);
      } catch (e) {
        print("Error updating secretary: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update secretary. Please try again.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Secretary',
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
                  return 'Please enter a username';
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
                  return 'Please enter a password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateSecretary,
              child: const Text('Update Secretary'),
            ),
          ],
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
