import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateSecretaryScreen extends StatefulWidget {
  final int index;
  final bool canEditRole; // 👈 added flag

  const UpdateSecretaryScreen({
    required this.index,
    required this.canEditRole,
    super.key,
  });

  @override
  _UpdateSecretaryScreenState createState() => _UpdateSecretaryScreenState();
}

class _UpdateSecretaryScreenState extends State<UpdateSecretaryScreen> {
  late User _secretary;
  late Box<User> userBox;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedRole;

  bool _isPasswordVisible = true;

  final List<String> _roles = [
    'sub-admin',
    'secretary',
    'accountant',
    'teacher',
    'administration'
  ];

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  Future<void> _initBox() async {
    userBox = await Hive.openBox<User>('users');
    _loadSecretaryData();
  }

  void _loadSecretaryData() {
    _secretary = userBox.getAt(widget.index)!;
    _usernameController.text = _secretary.username;
    _passwordController.text = _secretary.password;
    _phoneController.text = _secretary.phone;
    _emailController.text = _secretary.email ?? '';
    _selectedRole = _secretary.role ?? 'secretary';
  }

  Future<void> _updateSecretary() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      _secretary = userBox.getAt(widget.index)!;

      List<String> modifiedFields = _secretary.modifiedFields ?? [];

      void checkFieldChange(String field, String oldValue, String newValue) {
        if (oldValue.toLowerCase() != newValue.toLowerCase() &&
            !modifiedFields.contains(field)) {
          modifiedFields.add(field);
        }
      }

      checkFieldChange(
          'username', _secretary.username, _usernameController.text);
      checkFieldChange(
          'password', _secretary.password, _passwordController.text);
      checkFieldChange('phone', _secretary.phone, _phoneController.text);
      checkFieldChange('email', _secretary.email ?? '', _emailController.text);

      // 👇 Only track role if allowed to edit
      if (widget.canEditRole) {
        checkFieldChange('role', _secretary.role ?? '', _selectedRole ?? '');
      }

      final code = _secretary.userCode;

      _secretary
        ..username = _usernameController.text
        ..password = _passwordController.text
        ..phone = _phoneController.text
        ..email = _emailController.text
        ..operationType = 'update'
        ..lastModified = DateTime.now()
        ..termId = globalTermId
        ..syncStatus = false
        ..userCode = code
        ..modifiedFields = modifiedFields;

      // 👇 Only update role if editing is allowed
      if (widget.canEditRole) {
        _secretary.role = _selectedRole!;
      }

      await userBox.putAt(widget.index, _secretary);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secretary updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error updating secretary: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to update secretary. Please try again.')),
      );
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
                if (value == null || value.isEmpty)
                  return 'Please enter a username';
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
                if (value == null || value.isEmpty)
                  return 'Please enter a password';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter a phone number';
                if (!RegExp(r'^\d{10,}$').hasMatch(value)) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email Address'),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter an email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 👇 Role Dropdown (disabled if user cannot edit role)
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: 'Assigned Role',
                enabled: widget.canEditRole,
              ),
              items: _roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: widget.canEditRole
                  ? (value) => setState(() => _selectedRole = value)
                  : null,
            ),
            const SizedBox(height: 24),

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
    _emailController.dispose();
    super.dispose();
  }
}
