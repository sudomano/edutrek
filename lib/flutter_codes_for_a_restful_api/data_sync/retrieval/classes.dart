import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class ClassesSync extends StatefulWidget {
  const ClassesSync({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<ClassesSync> {
  Box<Classes>? _classesBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _classesBox = await Hive.openBox<Classes>('classes');
    print('Hive box opened successfully.');
  }

  Future<void> _fetchAndSyncSchools() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> classes = jsonDecode(response.body);

        for (var classData in classes) {
          DateTime parsedDate =
              DateTime.tryParse(classData['date']) ?? DateTime.now();

          Classes fetchedClass = Classes(
            id: int.tryParse(classData['fid'] ?? '0') ?? 0,
            classCode: classData['classCode'],
            className: classData['className'],
            date: parsedDate, // Assign the parsed DateTime
            termId: classData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingClassList = _classesBox!.values
              .where(
                (classes) => classes.classCode == fetchedClass.classCode,
              )
              .toList();

          Classes? existingClasses =
              existingClassList.isNotEmpty ? existingClassList.first : null;

          if (existingClasses?.classCode != null) {
            if (existingClasses != null) {
              // Update existing record
              existingClasses
                ..id = fetchedClass.id
                ..classCode = fetchedClass.classCode
                ..className = fetchedClass.className
                ..date = fetchedClass.date
                ..termId = fetchedClass.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingClasses.save();
              print(
                  'Classes ${fetchedClass.classCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _classesBox!.add(fetchedClass);
              print(
                  'Classes ${fetchedClass.classCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another Class record was Found with no Class Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Classes from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing Classes: $e');
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
        title: const Center(child: Text('Fetch and Save Classes')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _fetchAndSyncSchools();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Classes data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save Classes'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
