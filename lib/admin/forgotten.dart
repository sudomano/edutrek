import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart'; // Import your user data model
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class ForgottenPasswordScreen extends StatefulWidget {
  @override
  _ForgottenPasswordScreenState createState() =>
      _ForgottenPasswordScreenState();
}

class _ForgottenPasswordScreenState extends State<ForgottenPasswordScreen> {
  late User _user;
  late List<String> _securityQuestions;
  late List<TextEditingController> _answerControllers;
  final _formKey = GlobalKey<FormState>();
  int _tapCount = 0;
  bool _isDeveloperMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var userBox = await Hive.openBox<User>('users');
    if (userBox.isNotEmpty) {
      setState(() {
        _user = userBox.values.first; // Assuming admin user is first
        _securityQuestions = _user.securityQuestions;
        _answerControllers = List.generate(
          _securityQuestions.length,
          (index) => TextEditingController(),
        );
      });
    }
  }

  @override
  void dispose() {
    _answerControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _resetPassword() {
    if (_formKey.currentState!.validate()) {
      bool allAnswersMatch = true;
      for (int i = 0; i < _securityQuestions.length; i++) {
        if (_user.securityAnswers[i] != _answerControllers[i].text) {
          allAnswersMatch = false;
          break;
        }
      }

      if (allAnswersMatch) {
        // Navigate to the admin view if security answers match
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security answers do not match')),
        );
      }
    }
  }

  void _handleTap() {
    setState(() {
      _tapCount++;
      if (_tapCount >= 3) {
        _isDeveloperMode = true;
      }
    });
  }

  void _navigateToDeveloperLogin() {
    Navigator.pushNamed(context, '/developer');
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Forgotten Password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Security Questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < _securityQuestions.length; i++)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _securityQuestions[i],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  TextFormField(
                    controller: _answerControllers[i],
                    decoration: const InputDecoration(
                      labelText: 'Answer',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Color.fromARGB(255, 248, 247, 251),
                          width: 2.0,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your answer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetPassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color.fromARGB(
                    255, 249, 248, 252), // Primary color for business
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm'),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _handleTap,
              child: _isDeveloperMode
                  ? ElevatedButton(
                      onPressed: _navigateToDeveloperLogin,
                      child: const Text('Developed'),
                    )
                  : const Text(
                      'Developed',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'For Management',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
