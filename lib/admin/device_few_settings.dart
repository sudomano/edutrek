import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart'; // Import your user data model
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class DeviceFewSettingsScreen extends StatefulWidget {
  const DeviceFewSettingsScreen({super.key});

  @override
  _DeviceFewSettingsScreenState createState() =>
      _DeviceFewSettingsScreenState();
}

class _DeviceFewSettingsScreenState extends State<DeviceFewSettingsScreen> {
  late User _user;
  late List<String> _securityQuestions;
  late List<TextEditingController> _answerControllers;
  final _formKey = GlobalKey<FormState>();
  int _tapCount = 0;
  bool _isDeveloperMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var userBox = await Hive.openBox<User>('users');
    if (userBox.isNotEmpty) {
      _user = userBox.values.first;
      _securityQuestions = _user.securityQuestions;
      _answerControllers = List.generate(
        _securityQuestions.length,
        (index) => TextEditingController(),
      );
    } else {
      // 🔧 Prevent LateInitializationError by initializing with empty values
      _user = User(
          username: '',
          password: '',
          role: '',
          securityQuestions: [],
          securityAnswers: [],
          phone:
              ''); // You may need to define a default constructor or dummy user
      _securityQuestions = [];
      _answerControllers = [];
    }

    setState(() {
      _isLoading = false;
    });
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

  void _navigateToDeveloperLoginFew() {
    Navigator.pushNamed(context, '/developer_device_few_settings');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return CenteredFormContainer(
      title: 'Device Settings',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _handleTap,
              child: _isDeveloperMode
                  ? ElevatedButton(
                      onPressed: _navigateToDeveloperLoginFew,
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
