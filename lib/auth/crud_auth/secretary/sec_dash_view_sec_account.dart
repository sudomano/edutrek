import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/auth/crud_auth/secretary/update_secretary.dart';

class ViewSecretaryScreen1 extends StatefulWidget {
  @override
  _ViewSecretaryScreenState createState() => _ViewSecretaryScreenState();
}

class _ViewSecretaryScreenState extends State<ViewSecretaryScreen1> {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Secretary account deleted successfully'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Secretaries'),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 0,
      ),
      // ignore: unnecessary_null_comparison
      body: userBox == null
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: userBox.length,
              itemBuilder: (context, index) {
                final user = userBox.getAt(index);
                if (user == null || user.role != 'secretary')
                  return Container(); // Show only secretaries

                return ListTile(
                  title: Text(user.username),
                  subtitle:
                      Text('${user.phone} - ${user.role}'), // Display role here
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
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
                    ],
                  ),
                );
              },
            ),
    );
  }
}
