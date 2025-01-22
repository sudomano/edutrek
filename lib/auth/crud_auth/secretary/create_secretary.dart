import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class CreateSecretaryAccountScreen extends StatefulWidget {
  @override
  _CreateSecretaryAccountScreenState createState() =>
      _CreateSecretaryAccountScreenState();
}

class _CreateSecretaryAccountScreenState
    extends State<CreateSecretaryAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _securityQuestions = List<String>.generate(3, (index) => "");
  final _securityAnswers = List<String>.generate(3, (index) => "");
  bool _isPasswordVisible = false;

  final List<String> _roles = [
    'sub-admin',
    'secretary',
    'accountant',
    'teacher'
  ];
  String _selectedRole = 'secretary'; // Default selected role

  Future<int> getNextId() async {
    final box = await Hive.openBox<User>('users');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _createSecretaryAccount() async {
    int newId = await getNextId();

    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');
        // Check if a user with the same username or phone number already exists
        bool userExists = userBox.values
            .any((user) => user.username == _usernameController.text);

        if (userExists) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'An account with the same username or code  already exists'),
          ));
          return; // Stop the account creation process
        }

        var syncs = false;
        var last = DateTime.now();
        var op = 'create';
        var term = globalTermId;

        List<String> modifiedFields = [];
        modifiedFields.add('username');
        modifiedFields.add('userCode');
        modifiedFields.add('password');
        modifiedFields.add('role');
        modifiedFields.add('securityQuestions');
        modifiedFields.add('securityAnswers');
        modifiedFields.add('phone');
        modifiedFields.add('termId');
        final newPkValue = uuid.v4();

        User newUser = User(
          id: newId,
          username: _usernameController.text,
          userCode: newPkValue,
          password: _passwordController.text,
          role: _selectedRole.toLowerCase(), // Use selected role
          securityQuestions: _securityQuestions,
          securityAnswers: _securityAnswers,
          phone: _phoneController.text,
          termId: term,
          operationType: op,
          syncStatus: syncs,
          lastModified: last,
          modifiedFields: modifiedFields,
        );

        await userBox.add(newUser); // Add new secretary user to the database

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created successfully'),
        ));

        // Clear fields after successful creation
        _usernameController.clear();
        _passwordController.clear();
        _phoneController.clear();
        setState(() {
          _securityQuestions.fillRange(0, 3, "");
          _securityAnswers.fillRange(0, 3, "");
          _selectedRole = 'secretary'; // Reset role to default
        });
      } catch (e) {
        print("Error creating  account: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: const Text('Failed to create  account. Please try again.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add User',
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
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(labelText: 'Role'),
              items: _roles
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a role';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createSecretaryAccount,
              child: const Text('Create Account'),
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
