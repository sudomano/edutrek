import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/auth/crud_auth/view_admin_auth.dart';
import 'package:zitf_system/auth/super_user_do/super_user_login_screen.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart'; // For getDeviceRole
import 'package:http/http.dart' as http;
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class ViewSecurityScreen extends StatefulWidget {
  @override
  _ViewSecurityScreenState createState() => _ViewSecurityScreenState();
}

class _ViewSecurityScreenState extends State<ViewSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  late List<String> _securityQuestions;
  late List<String> _securityAnswers;
  bool _isPasswordVisible = false;

  // ✅ State for deleted users management
  List<User> _allUsers = [];
  List<User> _activeUsers = [];
  List<User> _deletedUsers = [];
  bool _showDeletedUsers = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
    _loadSecurityData();
  }

  // ✅ Load all users (including deleted)
  Future<void> _loadAllUsers() async {
    try {
      final userBox = await Hive.openBox<User>('users');
      final allUsers = userBox.values.toList();

      setState(() {
        _allUsers = allUsers;
        _activeUsers = allUsers.where((u) => !(u.isDeleted ?? false)).toList();
        _deletedUsers = allUsers.where((u) => u.isDeleted ?? false).toList();
      });

      print(
          '📊 Users loaded: ${_activeUsers.length} active, ${_deletedUsers.length} deleted');
    } catch (e) {
      print('❌ Error loading users: $e');
    }
  }

  Future<void> _loadSecurityData() async {
    try {
      var userBox = await Hive.openBox<User>('users');
      var adminUserList = userBox.values
          .where((user) => user.role == 'admin' && !(user.isDeleted ?? false))
          .toList();

      if (adminUserList.isEmpty) {
        List<String> modifiedFields = [];
        modifiedFields.add('username');
        modifiedFields.add('userCode');
        modifiedFields.add('password');
        modifiedFields.add('role');
        modifiedFields.add('securityQuestions');
        modifiedFields.add('securityAnswers');
        modifiedFields.add('phone');
        modifiedFields.add('termId');

        var dummyUser = User(
          username: 'admin',
          password: 'admin1234',
          phone: '1234567890',
          role: 'admin',
          id: 1,
          securityQuestions: [
            'Dummy question 1',
            'Dummy question 2',
            'Dummy question 3'
          ],
          securityAnswers: [
            'Dummy answer 1',
            'Dummy answer 2',
            'Dummy answer 3'
          ],
          modifiedFields: modifiedFields,
          isDeleted: false,
          deletedSyncStatus: true,
        );
        await userBox.add(dummyUser);
        adminUserList.add(dummyUser);
        await _loadAllUsers();
      }

      if (adminUserList.isNotEmpty) {
        var adminUser = adminUserList.first;
        setState(() {
          _usernameController.text = adminUser.username;
          _passwordController.text = adminUser.password;
          _phoneController.text = adminUser.phone;
          _securityQuestions = List<String>.from(adminUser.securityQuestions);
          _securityAnswers = List<String>.from(adminUser.securityAnswers);
        });
      }
    } catch (e) {
      print("Error loading security data: $e");
    }
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<User>('users');
    final activeUsers =
        box.values.where((u) => !(u.isDeleted ?? false)).toList();
    if (activeUsers.isEmpty) return 1;

    int currentMaxId = activeUsers
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _updateSecurityData() async {
    int newId = await getNextId();

    if (_formKey.currentState!.validate()) {
      try {
        var userBox = await Hive.openBox<User>('users');
        var adminUserList = userBox.values
            .where((user) => user.role == 'admin' && !(user.isDeleted ?? false))
            .toList();

        if (adminUserList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No admin user found in the database'),
          ));
        } else {
          var adminUser = adminUserList.first;
          adminUser.id = newId;
          adminUser.username = _usernameController.text;
          adminUser.password = _passwordController.text;
          adminUser.phone = _phoneController.text;
          adminUser.securityQuestions = _securityQuestions;
          adminUser.securityAnswers = _securityAnswers;
          adminUser.termId = globalTermId;
          adminUser.syncStatus = false;
          adminUser.lastModified = DateTime.now();
          adminUser.userCode = 'admin';
          adminUser.operationType = 'update';
          adminUser.isDeleted = false;
          adminUser.deletedSyncStatus = true;

          await adminUser.save();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isUpdatedSecurity', true);

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Security questions and answers updated')));

          await _loadAllUsers();
        }
      } catch (e) {
        print("Error updating security data: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to update data. Please try again.')));
      }
    }
  }

  // ✅ SOFT DELETE user
  Future<void> _softDeleteUser(User user, {String? reason}) async {
    try {
      // Get current user
      final currentUser = await getLoggedInUser();

      // Mark as deleted locally
      user.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await user.save();

      // Send delete request to server
      final role = await getDeviceRole();
      if (role == DeviceRole.client) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await http.delete(
          Uri.parse(
              'http://$hostIp/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php'
              '?userCode=${user.userCode}'
              '&deletedBy=${currentUser?.username ?? "system"}'
              '&reason=${Uri.encodeComponent(reason ?? "")}'),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          user.deletedSyncStatus = true;
          user.syncStatus = true;
          user.operationType = 'none';
          await user.save();
        }
      }

      await _loadAllUsers();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('User ${user.username} deleted successfully')));
    } catch (e) {
      print('❌ Error deleting user: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
    }
  }

  // ✅ RESTORE user
  Future<void> _restoreUser(User user) async {
    try {
      // Restore locally
      user.restoreDeleted();
      await user.save();

      // Send restore request to server
      final role = await getDeviceRole();
      if (role == DeviceRole.client) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await http.post(
          Uri.parse(
              'http://$hostIp/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'restore',
            'userCode': user.userCode,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          user.syncStatus = true;
          user.deletedSyncStatus = true;
          user.operationType = 'none';
          await user.save();
        }
      }

      await _loadAllUsers();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('User ${user.username} restored successfully')));
    } catch (e) {
      print('❌ Error restoring user: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error restoring user: $e')));
    }
  }

  // ✅ PERMANENTLY DELETE (archive)
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
        // Delete from local
        await user.delete();

        // Optionally delete from server
        final role = await getDeviceRole();
        if (role == DeviceRole.client) {
          final prefs = await SharedPreferences.getInstance();
          final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

          // You might want to implement a permanent delete endpoint
          // or just leave it with is_deleted=1
        }

        await _loadAllUsers();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('User ${user.username} permanently deleted')));
      } catch (e) {
        print('❌ Error permanently deleting user: $e');
      }
    }
  }

  // ✅ SHOW user details
  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(user.isDeleted ?? false
                  ? '🗑️ Deleted User'
                  : '👤 User Details'),
            ),
            if (user.isDeleted ?? false)
              TextButton.icon(
                icon: const Icon(Icons.restore, color: Colors.green, size: 16),
                label: const Text('Restore', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Navigator.pop(context);
                  _restoreUser(user);
                },
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailTile('Username', user.username),
              _detailTile('Role', user.role),
              _detailTile('Phone', user.phone),
              _detailTile('Email', user.email ?? 'N/A'),
              _detailTile('User Code', user.userCode ?? 'N/A'),
              _detailTile('Term ID', user.termId ?? 'N/A'),
              _detailTile(
                  'Status', user.isActive == true ? 'Active' : 'Inactive'),
              if (user.isDeleted ?? false) ...[
                const Divider(color: Colors.red),
                _detailTile(
                    'Deleted At', user.deletedAt?.toString() ?? 'Unknown'),
                _detailTile('Deleted By', user.deletedBy ?? 'Unknown'),
                _detailTile('Reason', user.deleteReason ?? 'Not specified'),
              ],
              const Divider(),
              _detailTile('Sync Status',
                  user.syncStatus == true ? 'Synced' : 'Pending'),
              _detailTile(
                  'Last Modified', user.lastModified?.toString() ?? 'Never'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Admin Account Management')),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, size: 30, color: Colors.blue),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _showDeletedUsers ? Icons.visibility : Icons.visibility_off,
              size: 30,
              color: _deletedUsers.isNotEmpty ? Colors.orange : Colors.grey,
            ),
            tooltip:
                _showDeletedUsers ? 'Hide Deleted Users' : 'Show Deleted Users',
            onPressed: () {
              setState(() {
                _showDeletedUsers = !_showDeletedUsers;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: () async {
              await _loadAllUsers();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data refreshed')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings,
                size: 30, color: Colors.orange),
            tooltip: 'Super User Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SuperUserLoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ Admin Info Card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.admin_panel_settings,
                                color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Admin Account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditSecurityScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildAdminInfo(),
                      ],
                    ),
                  ),
                ),

                // ✅ User List
                Expanded(
                  child: ListView.builder(
                    itemCount: _showDeletedUsers
                        ? _allUsers.length
                        : _activeUsers.length,
                    itemBuilder: (context, index) {
                      final user = _showDeletedUsers
                          ? _allUsers[index]
                          : _activeUsers[index];

                      final isDeleted = user.isDeleted ?? false;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        color: isDeleted ? Colors.grey.shade100 : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isDeleted ? Colors.grey : Colors.blue,
                            child: Text(
                              user.username[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            user.username,
                            style: TextStyle(
                              decoration:
                                  isDeleted ? TextDecoration.lineThrough : null,
                              color: isDeleted ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            '${user.role} • ${user.phone}',
                            style: TextStyle(
                              color: isDeleted ? Colors.grey : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ✅ View details button
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 20),
                                onPressed: () => _showUserDetails(user),
                              ),

                              if (isDeleted) ...[
                                // ✅ Restore button for deleted users
                                IconButton(
                                  icon: const Icon(Icons.restore,
                                      color: Colors.green, size: 20),
                                  onPressed: () => _restoreUser(user),
                                  tooltip: 'Restore User',
                                ),
                                // ✅ Permanent delete for deleted users
                                IconButton(
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _permanentlyDeleteUser(user),
                                  tooltip: 'Permanently Delete',
                                ),
                              ] else if (user.role != 'admin') ...[
                                // ✅ Soft delete for active non-admin users
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _confirmDelete(user),
                                  tooltip: 'Delete User',
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ✅ Deleted users count
                if (_deletedUsers.isNotEmpty && !_showDeletedUsers)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      label: Text(
                        '${_deletedUsers.length} deleted user(s). Tap to view.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _showDeletedUsers = true;
                        });
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAdminInfo() {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
                width: 100,
                child: Text('Username:',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(_usernameController.text)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(
                width: 100,
                child: Text('Phone:',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(_phoneController.text)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(
                width: 100,
                child: Text('Role:',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const Expanded(child: Text('admin')),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(User user) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${user.username}"?'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Reason for deletion (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => reason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _softDeleteUser(user, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
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
