import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _securityQuestions = List<String>.generate(3, (index) => "");
  final _securityAnswers = List<String>.generate(3, (index) => "");
  bool _isPasswordVisible = false;

  // ✅ Remove unused userBox from here - we'll open it when needed

  final List<String> _roles = [
    'sub-admin',
    'secretary',
    'accountant',
    'teacher',
    'administration'
  ];
  String _selectedRole = 'secretary';

  // ✅ New: Class selection for teachers
  List<String> _availableClasses = [];
  List<String> _selectedClasses = [];
  bool _isLoadingClasses = false;

  DeviceRole? _role;
  bool _roleReady = false;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    final role = await getDeviceRole();
    setState(() {
      _role = role;
      _roleReady = true;
    });

    // Load classes if the user is on a host device
    if (_role == DeviceRole.host) {
      await _loadClasses();
    }
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final classBox = await Hive.openBox<Classes>('classes');
      final classes = classBox.values
          .where((c) => c.terms != null && c.terms!.contains(globalTermId))
          .map((c) => c.className)
          .toList()
        ..sort();

      setState(() {
        _availableClasses = classes;
        _isLoadingClasses = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading classes: $e');
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<User>('users');
    if (box.isEmpty) return 1;
    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  void _toggleClassSelection(String className) {
    setState(() {
      if (_selectedClasses.contains(className)) {
        _selectedClasses.remove(className);
      } else {
        _selectedClasses.add(className);
      }
    });
  }

  void _selectAllClasses() {
    setState(() {
      _selectedClasses = List.from(_availableClasses);
    });
  }

  void _deselectAllClasses() {
    setState(() {
      _selectedClasses = [];
    });
  }

  Future<void> _createSecretaryAccount() async {
    // ✅ Validate that teachers have at least one class assigned
    if (_selectedRole.toLowerCase() == 'teacher' && _selectedClasses.isEmpty) {
      _showDialog('Please assign at least one class to the teacher.');
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');

        // Check if a user with the same email already exists
        bool userExists = userBox.values.any((user) =>
            user.email?.trim().toLowerCase() ==
            _emailController.text.trim().toLowerCase());

        if (userExists) {
          _showDialog('An account with the same email address already exists');
          return;
        }

        int newId = await getNextId();
        var syncs = false;
        var last = DateTime.now();
        var op = 'create';
        var term = globalTermId;
        final newPkValue = uuid.v4();

        List<String> modifiedFields = [
          'username',
          'email',
          'userCode',
          'password',
          'role',
          'securityQuestions',
          'securityAnswers',
          'phone',
          'termId',
          'assignedClasses',
          'isActive',
          'createdAt'
        ];

        User newUser = User(
          id: newId,
          username: _usernameController.text,
          email: _emailController.text,
          userCode: newPkValue,
          password: _passwordController.text,
          role: _selectedRole.toLowerCase(),
          securityQuestions: _securityQuestions,
          securityAnswers: _securityAnswers,
          phone: _phoneController.text,
          termId: term,
          operationType: op,
          syncStatus: syncs,
          lastModified: last,
          modifiedFields: modifiedFields,
          assignedClasses: _selectedRole.toLowerCase() == 'teacher'
              ? List.from(_selectedClasses)
              : null,
          isActive: true,
          createdAt: DateTime.now(),
        );

        await userBox.add(newUser);

        _showDialog('User Account created successfully');

        // Clear fields after successful creation
        _usernameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _phoneController.clear();
        setState(() {
          _securityQuestions.fillRange(0, 3, "");
          _securityAnswers.fillRange(0, 3, "");
          _selectedRole = 'secretary';
          _selectedClasses = [];
        });
      } catch (e) {
        debugPrint("Error creating account: $e");
        _showDialog('Failed to create account. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Check if user is on host device
    final bool isHost = _role == DeviceRole.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add User'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ Host indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isHost
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isHost
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isHost ? Icons.check_circle : Icons.block,
                              color: isHost ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isHost
                                  ? '🔑 Host Mode - User creation allowed'
                                  : '❌ Client Mode - User creation is only available on the host device',
                              style: TextStyle(
                                color: isHost
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email address';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
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
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.admin_panel_settings),
                        ),
                        items: _roles
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            // Clear class selection if role is not teacher
                            if (_selectedRole.toLowerCase() != 'teacher') {
                              _selectedClasses = [];
                            }
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

                      // ✅ Class Selection (only for Teacher role and on Host)
                      if (_selectedRole.toLowerCase() == 'teacher' &&
                          isHost) ...[
                        const Divider(),
                        const Text(
                          'Assign Classes to Teacher',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selected: ${_selectedClasses.length} of ${_availableClasses.length} classes',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Select/Deselect All buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _availableClasses.isEmpty
                                    ? null
                                    : _selectAllClasses,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Select All'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedClasses.isEmpty
                                    ? null
                                    : _deselectAllClasses,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Deselect All'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Class list
                        if (_isLoadingClasses)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_availableClasses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No classes available. Please create classes first.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _availableClasses.length,
                              itemBuilder: (context, index) {
                                final className = _availableClasses[index];
                                final isSelected =
                                    _selectedClasses.contains(className);
                                return CheckboxListTile(
                                  title: Text(className),
                                  value: isSelected,
                                  onChanged: (value) {
                                    _toggleClassSelection(className);
                                  },
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: Colors.blue,
                                  checkColor: Colors.white,
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 8),

                        // Validation message
                        if (_selectedClasses.isEmpty)
                          const Text(
                            '⚠️ Please assign at least one class to the teacher',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // Create Account Button
                      ElevatedButton(
                        onPressed: isHost ? _createSecretaryAccount : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isHost
                              ? const Color.fromARGB(255, 38, 140, 191)
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isHost ? 'Create Account' : 'Host Only',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 User Creation Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
