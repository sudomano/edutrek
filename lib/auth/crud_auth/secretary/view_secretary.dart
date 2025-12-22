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

  @override
  void initState() {
    super.initState();
    _loadUserBox();
  }

  Future<void> _loadUserBox() async {
    userBox = await Hive.openBox<User>('users');
    setState(() {}); // Refresh after loading
  }

  Future<void> _deleteSecretary(int index) async {
    await userBox.deleteAt(index);
    setState(() {});
    _showDialog('User account was deleted successfully');
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
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: userBox == null
              ? const Center(child: CircularProgressIndicator())
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
                    // Admin/Administration can see all other users
                    // Others see only their own account
                    if ((!isAdmin && !isAdministration) &&
                        user.username != loggedInUsername) {
                      return Container();
                    }

                    return ListTile(
                      title: Text(user.username),
                      subtitle: Text('${user.phone} - ${user.role}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UpdateSecretaryScreen(
                                    index: index,
                                    canEditRole: (isAdmin ||
                                        isAdministration), // ✅ Correct
                                  ),
                                ),
                              );
                            },
                          ),
                          if (isAdmin || isAdministration)
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete User'),
                                    content: const Text(
                                        'Are you sure you want to delete this user account?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteSecretary(index);
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
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
        title: const Text("🧾 User Account Submission Feedback"),
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
