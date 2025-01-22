import 'package:flutter/material.dart';

class EditAdminScreen extends StatefulWidget {
  const EditAdminScreen({super.key});

  @override
  _EditAdminScreenState createState() => _EditAdminScreenState();
}

class _EditAdminScreenState extends State<EditAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField('Admin Name', _nameController),
              _buildTextField('Admin Username', _usernameController),
              _buildPasswordField(),
              ElevatedButton(
                onPressed: _saveAdmin,
                child: const Text('Save Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(labelText: 'Admin Password'),
      obscureText: true, // Hide password
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the admin password';
        }
        return null;
      },
    );
  }

  void _saveAdmin() {
    if (_formKey.currentState!.validate()) {
      // Save or update the admin information
      // Implement the logic to save admin data (e.g., with Hive or other storage)

      Navigator.pop(context); // Return to the previous screen
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
