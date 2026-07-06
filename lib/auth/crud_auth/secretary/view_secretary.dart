import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/auth/crud_auth/secretary/update_secretary.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ViewSecretaryScreen extends StatefulWidget {
  @override
  _ViewSecretaryScreenState createState() => _ViewSecretaryScreenState();
}

class _ViewSecretaryScreenState extends State<ViewSecretaryScreen> {
  late Box<User> userBox;
  bool _isLoading = false;
  bool _showDeletedUsers = false;
  List<User> _activeUsers = [];
  List<User> _deletedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUserBox();
  }

  Future<void> _loadUserBox() async {
    setState(() => _isLoading = true);
    try {
      userBox = await Hive.openBox<User>('users');
      _refreshUserLists();
    } catch (e) {
      debugPrint('❌ Error loading user box: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _refreshUserLists() {
    final allUsers = userBox.values.toList();
    _activeUsers = allUsers.where((u) => !(u.isDeleted ?? false)).toList();
    _deletedUsers = allUsers.where((u) => u.isDeleted ?? false).toList();
  }

  // ✅ SOFT DELETE user
  Future<void> _softDeleteUser(User user, {String? reason}) async {
    try {
      // Get current user
      final currentUser = getLoggedInUser();

      // Mark as deleted locally
      user.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await user.save();

      // Send delete request to server (if client)
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

      _refreshUserLists();
      setState(() {});
      _showDialog('User ${user.username} deleted successfully');
    } catch (e) {
      _showDialog('Error deleting user: $e');
    }
  }

  // ✅ RESTORE user
  Future<void> _restoreUser(User user) async {
    try {
      // Restore locally
      user.restoreDeleted();
      await user.save();

      // Send restore request to server (if client)
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

      _refreshUserLists();
      setState(() {});
      _showDialog('User ${user.username} restored successfully');
    } catch (e) {
      _showDialog('Error restoring user: $e');
    }
  }

  // ✅ PERMANENTLY DELETE user
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
        _refreshUserLists();
        setState(() {});
        _showDialog('User ${user.username} permanently deleted');
      } catch (e) {
        _showDialog('Error permanently deleting user: $e');
      }
    }
  }

  // ✅ Helper to format class list for display
  String _formatClassList(List<String>? classes) {
    if (classes == null || classes.isEmpty) {
      return 'No classes assigned';
    }
    if (classes.length <= 3) {
      return classes.join(', ');
    }
    return '${classes.take(3).join(', ')} +${classes.length - 3} more';
  }

  // ✅ Get role-based color
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'administration':
        return Colors.deepPurple;
      case 'teacher':
        return Colors.blue;
      case 'secretary':
        return Colors.green;
      case 'accountant':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ✅ Get role icon
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'administration':
        return Icons.assignment;
      case 'teacher':
        return Icons.school;
      case 'secretary':
        return Icons.description;
      case 'accountant':
        return Icons.calculate;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final loggedInRole = loggedInUser.role.toLowerCase();
    final loggedInUsername = loggedInUser.username;

    final isAdmin = loggedInRole == 'admin';
    final isAdministration = loggedInRole == 'administration';

    // Determine which users to show
    final displayUsers = _showDeletedUsers ? _deletedUsers : _activeUsers;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'View Accounts',
        actions: [
          // ✅ Toggle show deleted users
          IconButton(
            icon: Icon(
              _showDeletedUsers ? Icons.visibility : Icons.visibility_off,
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
          // ✅ Deleted count badge
          if (_deletedUsers.isNotEmpty && !_showDeletedUsers)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_deletedUsers.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // ✅ Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshUserLists();
              setState(() {});
              _showDialog('Users refreshed');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(16.0),
                child: userBox == null || userBox.isEmpty
                    ? const Center(
                        child: Text(
                          'No user accounts found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          // ✅ Header with counts
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _showDeletedUsers
                                  ? Colors.red.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _showDeletedUsers
                                    ? Colors.red.shade200
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _showDeletedUsers
                                          ? Icons.delete_outline
                                          : Icons.people,
                                      color: _showDeletedUsers
                                          ? Colors.red
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _showDeletedUsers
                                          ? 'Deleted Users (${_deletedUsers.length})'
                                          : 'Active Users (${_activeUsers.length})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _showDeletedUsers
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!_showDeletedUsers &&
                                    _deletedUsers.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showDeletedUsers = true;
                                      });
                                    },
                                    child: Text(
                                      'View ${_deletedUsers.length} deleted',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                if (_showDeletedUsers)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showDeletedUsers = false;
                                      });
                                    },
                                    child: const Text(
                                      'Back to Active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ✅ User List
                          Expanded(
                            child: ListView.builder(
                              itemCount: displayUsers.length,
                              itemBuilder: (context, index) {
                                final user = displayUsers[index];
                                if (user == null) return Container();

                                final role = user.role.toLowerCase();
                                final isDeleted = user.isDeleted ?? false;

                                // 🔒 Skip showing admin or administration accounts in this list
                                if (role == 'admin' ||
                                    role == 'administration') {
                                  return Container();
                                }

                                // 🧭 Access control logic
                                if ((!isAdmin && !isAdministration) &&
                                    user.username != loggedInUsername) {
                                  return Container();
                                }

                                final bool isTeacher = role == 'teacher';
                                final bool hasClasses = isTeacher &&
                                    user.assignedClasses != null &&
                                    user.assignedClasses!.isNotEmpty;

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  elevation: isDeleted ? 1 : 2,
                                  color:
                                      isDeleted ? Colors.grey.shade100 : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: isDeleted
                                          ? Colors.grey.shade300
                                          : _getRoleColor(role)
                                              .withOpacity(0.2),
                                      child: Icon(
                                        isDeleted
                                            ? Icons.delete
                                            : _getRoleIcon(role),
                                        color: isDeleted
                                            ? Colors.grey
                                            : _getRoleColor(role),
                                      ),
                                    ),
                                    title: Text(
                                      user.username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isDeleted ? Colors.grey : null,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          '${user.phone} - ${user.role.toUpperCase()}',
                                          style: TextStyle(
                                            color: isDeleted
                                                ? Colors.grey.shade600
                                                : Colors.grey.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        // ✅ Show assigned classes for teachers
                                        if (isTeacher && !isDeleted) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: hasClasses
                                                  ? Colors.blue.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: hasClasses
                                                    ? Colors.blue.shade200
                                                    : Colors.orange.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hasClasses
                                                      ? Icons.class_
                                                      : Icons.warning_amber,
                                                  size: 14,
                                                  color: hasClasses
                                                      ? Colors.blue.shade700
                                                      : Colors.orange.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    hasClasses
                                                        ? 'Classes: ${_formatClassList(user.assignedClasses)}'
                                                        : 'No classes assigned',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: hasClasses
                                                          ? Colors.blue.shade700
                                                          : Colors
                                                              .orange.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                if (hasClasses)
                                                  Text(
                                                    '${user.assignedClasses!.length}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.blue.shade700,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        // ✅ Deletion info
                                        if (isDeleted) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.red.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.info_outline,
                                                  size: 14,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Deleted: ${user.deletedAt?.toString().substring(0, 16) ?? 'Unknown'}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isDeleted) ...[
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
                                            onPressed: () =>
                                                _permanentlyDeleteUser(user),
                                            tooltip: 'Permanently Delete',
                                          ),
                                        ] else ...[
                                          // ✅ Edit button
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      UpdateSecretaryScreen(
                                                    index: userBox.values
                                                        .toList()
                                                        .indexOf(user),
                                                    canEditRole: isAdmin ||
                                                        isAdministration,
                                                  ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Edit User',
                                          ),
                                          // ✅ Soft Delete button (Admin only)
                                          if (isAdmin || isAdministration)
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteConfirmation(user),
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
                        ],
                      ),
              ),
            ),
    );
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(User user) {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("User Account Feedback"),
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
}
