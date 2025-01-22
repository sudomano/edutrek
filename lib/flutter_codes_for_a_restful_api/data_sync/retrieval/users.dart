import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class UsersSync extends StatefulWidget {
  const UsersSync({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<UsersSync> {
  Box<User>? _usersBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _usersBox = await Hive.openBox<User>('users');
    print('Hive box opened successfully.');
  }

  // Helper function to decode string to List<String>
  List<String> _decodeToList(dynamic value) {
    if (value is String) {
      // If it's a string, try to decode it as JSON
      try {
        return List<String>.from(jsonDecode(value));
      } catch (e) {
        print('Error decoding string to List: $e');
        return [];
      }
    } else if (value is List) {
      // If it's already a list, return it directly
      return List<String>.from(value);
    }
    return [];
  }

  Future<void> _fetchAndSyncSchools() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> users = jsonDecode(response.body);

        for (var userData in users) {
          User fetchedUser = User(
            id: int.tryParse(userData['fid'] ?? '0'),
            username: userData['username'] ?? '',
            password: userData['password'] ?? '',
            role: userData['role'] ?? '',
            securityQuestions: _decodeToList(userData['securityQuestions']),
            securityAnswers: _decodeToList(userData['securityAnswers']),
            phone: userData['phone'] ?? '',
            userCode: userData['userCode'],
            termId: userData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingUserList = _usersBox!.values
              .where(
                (users) => users.userCode == fetchedUser.userCode,
              )
              .toList();

          User? existingUsers =
              existingUserList.isNotEmpty ? existingUserList.first : null;
          if (fetchedUser.userCode != null) {
            if (existingUsers != null) {
              // Update existing record
              existingUsers
                ..id = fetchedUser.id
                ..userCode = fetchedUser.userCode
                ..username = fetchedUser.username
                ..password = fetchedUser.password
                ..role = fetchedUser.role
                ..securityQuestions = fetchedUser.securityQuestions
                ..securityAnswers = fetchedUser.securityAnswers
                ..phone = fetchedUser.phone
                ..termId = fetchedUser.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingUsers.save();
              print(
                  'User ${fetchedUser.userCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _usersBox!.add(fetchedUser);
              print('User ${fetchedUser.userCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other User  Record Was Found with no User Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch User from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing User: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final admin = loggedInUser?.role.toLowerCase() == 'admin';
    final secretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser?.role.toLowerCase() == 'teacher';

    final accountant = loggedInUser?.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser?.role.toLowerCase() == 'sub-admin';
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Fetch and Save User')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || subadmin) await _fetchAndSyncSchools();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('User data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save User'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
