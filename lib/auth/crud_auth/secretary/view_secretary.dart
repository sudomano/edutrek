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
    setState(() {}); // Refresh the UI after loading the box
  }

  Future<void> _deleteSecretary(int index) async {
    await userBox.deleteAt(index);
    setState(() {}); // Refresh the UI after deletion
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(' account deleted successfully'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final loggedInRole = loggedInUser.role.toLowerCase();
    final loggedInUsername = loggedInUser.username;
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    bool secretary = false;
    bool admin = false;
    bool teacher = false;
    bool accountant = false;
    bool guest = false;
    bool subadmin = false;

    if (role.toLowerCase() == "secretary") {
      secretary = true;
    } else if (role.toLowerCase() == "teacher") {
      teacher = true;
    } else if (role.toLowerCase() == "accountant") {
      accountant = true;
    } else if (role.toLowerCase() == "admin") {
      admin = true;
    } else if (role.toLowerCase() == "subadmin") {
      subadmin = true;
    } else {
      guest = true;
    }
    return Scaffold(
      appBar: const CustomAppBar(title: 'View Accounts'),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          child: userBox == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: userBox.length,
                  itemBuilder: (context, index) {
                    final user = userBox.getAt(index);
                    // Skip null or invalid users
                    if (user == null) return Container();

                    // Admin: See all users; Non-admin: See only their own account
                    if (loggedInRole != 'admin' &&
                        user.username != loggedInUsername) {
                      return Container();
                    }

                    return ListTile(
                      title: Text(user.username),
                      subtitle: Text(
                          '${user.phone} - ${user.role} '), // Display role here
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      UpdateSecretaryScreen(index: index),
                                ),
                              );
                            },
                          ),
                          if (admin)
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Secretary'),
                                    content: const Text(
                                        'Are you sure you want to delete this secretary?'),
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
}
