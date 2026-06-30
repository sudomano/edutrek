import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/auth/crud_auth/secretary/update_secretary.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class ViewSecretaryScreen extends StatefulWidget {
  @override
  _ViewSecretaryScreenState createState() => _ViewSecretaryScreenState();
}

class _ViewSecretaryScreenState extends State<ViewSecretaryScreen> {
  late Box<User> userBox;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserBox();
  }

  Future<void> _loadUserBox() async {
    setState(() => _isLoading = true);
    try {
      userBox = await Hive.openBox<User>('users');
    } catch (e) {
      debugPrint('❌ Error loading user box: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSecretary(int index) async {
    try {
      await userBox.deleteAt(index);
      setState(() {});
      _showDialog('User account was deleted successfully');
    } catch (e) {
      _showDialog('Error deleting user account: $e');
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

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final loggedInRole = loggedInUser.role.toLowerCase();
    final loggedInUsername = loggedInUser.username;

    final isAdmin = loggedInRole == 'admin';
    final isAdministration = loggedInRole == 'administration';

    return Scaffold(
      appBar: const CustomAppBar(title: 'View Accounts'),
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
                    : ListView.builder(
                        itemCount: userBox.length,
                        itemBuilder: (context, index) {
                          final user = userBox.getAt(index);
                          if (user == null) return Container();

                          final role = user.role.toLowerCase();

                          // 🔒 Skip showing admin or administration accounts in this list
                          if (role == 'admin' || role == 'administration') {
                            return Container();
                          }

                          // 🧭 Access control logic
                          if ((!isAdmin && !isAdministration) &&
                              user.username != loggedInUsername) {
                            return Container();
                          }

                          // ✅ Check if user is a teacher
                          final bool isTeacher = role == 'teacher';
                          final bool hasClasses = isTeacher &&
                              user.assignedClasses != null &&
                              user.assignedClasses!.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isTeacher
                                    ? Colors.blue.shade100
                                    : Colors.grey.shade200,
                                child: Icon(
                                  isTeacher ? Icons.school : Icons.person,
                                  color: isTeacher
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                user.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${user.phone} - ${user.role.toUpperCase()}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  // ✅ Show assigned classes for teachers
                                  if (isTeacher) ...[
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
                                        borderRadius: BorderRadius.circular(8),
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
                                                    : Colors.orange.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (hasClasses)
                                            Text(
                                              '${user.assignedClasses!.length}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.bold,
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
                                            index: index,
                                            canEditRole:
                                                isAdmin || isAdministration,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'Edit User',
                                  ),
                                  // ✅ Delete button (Admin only)
                                  if (isAdmin || isAdministration)
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete User'),
                                            content: Text(
                                                'Are you sure you want to delete "${user.username}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteSecretary(index);
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      tooltip: 'Delete User',
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
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
