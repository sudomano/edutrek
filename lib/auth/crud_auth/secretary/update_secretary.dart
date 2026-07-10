import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateSecretaryScreen extends StatefulWidget {
  final int index;
  final bool canEditRole;

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

  // Class selection for teachers
  List<String> _availableClasses = [];
  List<String> _selectedClasses = [];
  bool _isLoadingClasses = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  Future<void> _initBox() async {
    userBox = await Hive.openBox<User>('users');
    _loadSecretaryData(); // ✅ REMOVED await - it's a void function
    await _loadClasses();
    setState(() {});
  }

  // ✅ Changed to void (no return needed)
  void _loadSecretaryData() {
    _secretary = userBox.getAt(widget.index)!;
    _usernameController.text = _secretary.username;
    _passwordController.text = _secretary.password;
    _phoneController.text = _secretary.phone;
    _emailController.text = _secretary.email ?? '';
    _selectedRole = _secretary.role ?? 'secretary';

    // Load assigned classes if teacher
    _selectedClasses = List.from(_secretary.assignedClasses ?? []);
  }

  Future<void> _loadClasses() async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
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
    } else {
      // Client mode - try to fetch from server
      try {
        setState(() => _isLoadingClasses = true);
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await http.get(
          Uri.parse('http://$hostIp:8080/api/classes'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          final classes = data
              .where((c) => c['terms']?.contains(globalTermId) ?? false)
              .map((c) => c['className'] as String)
              .toList()
            ..sort();

          setState(() {
            _availableClasses = classes;
            _isLoadingClasses = false;
          });
        } else {
          setState(() => _isLoadingClasses = false);
        }
      } catch (e) {
        debugPrint('❌ Error loading classes from server: $e');
        setState(() => _isLoadingClasses = false);
      }
    }
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

  // ✅ Helper to compare lists - handles null properly
  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _updateSecretary() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate teacher class assignment
    if (_selectedRole?.toLowerCase() == 'teacher' && _selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign at least one class to the teacher.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

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

      if (widget.canEditRole) {
        checkFieldChange('role', _secretary.role ?? '', _selectedRole ?? '');
      }

      // ✅ FIXED: Type-safe class comparison
      final List<String> oldClasses = _secretary.assignedClasses ?? [];
      final List<String> newClasses = _selectedRole?.toLowerCase() == 'teacher'
          ? List<String>.from(_selectedClasses)
          : [];

      if (!_listEquals(oldClasses, newClasses)) {
        modifiedFields.add('assignedClasses');
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

      if (widget.canEditRole) {
        _secretary.role = _selectedRole!;
      }

      // Update assigned classes
      if (_selectedRole?.toLowerCase() == 'teacher') {
        _secretary.assignedClasses = List<String>.from(_selectedClasses);
      } else {
        _secretary.assignedClasses = null;
      }

      await userBox.putAt(widget.index, _secretary);

      // Sync with server if client
      final role = await getDeviceRole();
      if (role == DeviceRole.client) {
        await _syncWithServer(_secretary);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("❌ Error updating user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update user. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _syncWithServer(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      final payload = {
        'userCode': user.userCode,
        'username': user.username,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'assignedClasses': user.assignedClasses,
        'modifiedFields': user.modifiedFields,
        'operationType': 'update',
        'lastModified': user.lastModified?.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        user.syncStatus = true;
        user.operationType = 'none';
        await user.save();
        debugPrint('✅ User synced with server');
      } else {
        debugPrint('⚠️ Failed to sync user: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error syncing user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = _selectedRole?.toLowerCase() == 'teacher';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update User'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: SingleChildScrollView(
        // ✅ Wrap with SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
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
                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter a username';
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
                          if (value == null || value.isEmpty)
                            return 'Please enter a password';
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

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter an email';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Assigned Role',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                          enabled: widget.canEditRole,
                        ),
                        items: _roles.map((role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: widget.canEditRole
                            ? (value) => setState(() {
                                  _selectedRole = value;
                                  // Clear classes if not teacher
                                  if (_selectedRole?.toLowerCase() !=
                                      'teacher') {
                                    _selectedClasses = [];
                                  }
                                })
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Class Selection (only for Teacher role)
                      if (isTeacher) ...[
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
                            constraints: const BoxConstraints(
                                maxHeight: 150), // ✅ Reduced height
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
                      ],

                      const SizedBox(height: 24),

                      // Update Button
                      ElevatedButton(
                        onPressed: _isSyncing ? null : _updateSecretary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 38, 140, 191),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Update User',
                                style: TextStyle(fontSize: 16),
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
