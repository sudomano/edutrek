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

  final List<String> _roles = [
    'sub-admin',
    'secretary',
    'accountant',
    'teacher',
    'administration'
  ];
  String _selectedRole = 'secretary';

  // ✅ Class selection for teachers
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
    // ✅ Only count active users (not deleted)
    final activeUsers =
        box.values.where((u) => !(u.isDeleted ?? false)).toList();
    if (activeUsers.isEmpty) return 1;

    int currentMaxId = activeUsers
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
    if (_selectedRole.toLowerCase() == 'teacher' && _selectedClasses.isEmpty) {
      _showDialog('Please assign at least one class to the teacher.');
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');

        // ✅ Check if user exists (including deleted - we don't want duplicate emails even if deleted)
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
          // ✅ Deletion fields - new users are not deleted
          isDeleted: false,
          deletedSyncStatus: true,
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
    final bool isHost = _role == DeviceRole.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add User'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
        actions: [
          // ✅ View deleted users button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'View Deleted Users',
            onPressed: () => _showDeletedUsersDialog(),
          ),
        ],
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
                      // ✅ Host indicator with deletion status
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
                            const Spacer(),
                            // ✅ Deleted users count
                            FutureBuilder<int>(
                              future: _getDeletedUsersCount(),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                if (count == 0) return const SizedBox();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count deleted',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ... (rest of the form fields remain the same)

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
                      ],

                      const SizedBox(height: 16),

                      // ✅ Create Account Button
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

  // ✅ Helper to get deleted users count
  Future<int> _getDeletedUsersCount() async {
    try {
      final userBox = await Hive.openBox<User>('users');
      return userBox.values.where((u) => u.isDeleted ?? false).length;
    } catch (e) {
      return 0;
    }
  }

  // ✅ Show deleted users dialog
  void _showDeletedUsersDialog() async {
    final userBox = await Hive.openBox<User>('users');
    final deletedUsers =
        userBox.values.where((u) => u.isDeleted ?? false).toList();

    if (deletedUsers.isEmpty) {
      _showDialog('No deleted users found.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Deleted Users (${deletedUsers.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: deletedUsers.length,
                itemBuilder: (context, index) {
                  final user = deletedUsers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Text(
                          user.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${user.role} • ${user.phone}'),
                          if (user.deletedAt != null)
                            Text(
                              'Deleted: ${user.deletedAt!.toString().substring(0, 16)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ Restore button
                          IconButton(
                            icon: const Icon(
                              Icons.restore,
                              color: Colors.green,
                            ),
                            onPressed: () => _restoreUser(user),
                            tooltip: 'Restore User',
                          ),
                          // ✅ Permanent delete button
                          IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                            onPressed: () => _permanentlyDeleteUser(user),
                            tooltip: 'Permanently Delete',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Restore deleted user
  Future<void> _restoreUser(User user) async {
    try {
      user.restoreDeleted();
      await user.save();

      // Send restore to server if client
      final role = await getDeviceRole();
      if (role == DeviceRole.client) {
        // ... send restore request to server
      }

      setState(() {});
      Navigator.pop(context); // Close bottom sheet
      _showDialog('User ${user.username} restored successfully');
    } catch (e) {
      _showDialog('Error restoring user: $e');
    }
  }

  // ✅ Permanently delete user
  Future<void> _permanentlyDeleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${user.username}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await user.delete();
        setState(() {});
        Navigator.pop(context); // Close bottom sheet
        _showDialog('User ${user.username} permanently deleted');
      } catch (e) {
        _showDialog('Error permanently deleting user: $e');
      }
    }
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("User Management"),
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
