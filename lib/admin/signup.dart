/*import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts
import 'package:flutter_spinkit/flutter_spinkit.dart'; // For animations
import 'package:hive/hive.dart';
import 'package:home_page_hive/auth/userdb.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _securityQuestionControllers =
      List.generate(5, (_) => TextEditingController());
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.cyan], // Gradient colors
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SHERRYBERRY',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Font style and color
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(16), // Set border radius
                    child: Image.asset(
                      'assets/images/logo.png', // Example image
                      height: 200,
                      width: 400,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Logo or branding
                  const SizedBox(height: 16),
                  Text(
                    'Create an Account',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Font style and color
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField('Username', _usernameController),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildTextField('Phone', _phoneController),
                  const SizedBox(height: 16),
                  for (int i = 0; i < _securityQuestionControllers.length; i++)
                    _buildTextField('Security Question ${i + 1}',
                        _securityQuestionControllers[i]),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 40)),
                      backgroundColor: MaterialStateProperty.all(
                          const Color.fromARGB(255, 252, 1, 1)), // Button color
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8.0), // Rounded corners
                        ),
                      ),
                    ), // Disable while loading
                    child: _isLoading
                        ? const SpinKitFadingCircle(
                            // Loading animation
                            color: Color.fromRGBO(5, 1, 1, 1),
                            size: 24,
                          )
                        : const Text('Sign Up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.person), // Icon for the text field
        filled: true,
        fillColor: Colors.white.withOpacity(0.2), // Transparent background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none, // No border
        ),
      ),
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
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock), // Icon for password field
        filled: true,
        fillColor: Colors.white.withOpacity(0.2), // Transparent background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none, // No border
        ),
      ),
      obscureText: true, // Hide the password
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Show loading animation
      });

      final username = _usernameController.text;
      final password = _passwordController.text;
      final phone = _phoneController.text;
      final securityQuestions = _securityQuestionControllers
          .map((controller) => controller.text)
          .toList();

      final box = Hive.box<User>('users');
      final user = User(
        username: username,
        password: password,
        role: 'admin', // Default to secretary for this example
        securityQuestions: securityQuestions,
        phone: phone, securityAnswers: '',
      );

      box.add(user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created successfully')),
      );

      Navigator.pushReplacementNamed(context, '/login');

      setState(() {
        _isLoading = false; // Hide loading animation
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    for (var controller in _securityQuestionControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}*/
