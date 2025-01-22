import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class SyncSchoolsPages extends StatefulWidget {
  const SyncSchoolsPages({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<SyncSchoolsPages> {
  Box<School>? _schoolBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _schoolBox = await Hive.openBox<School>('school');
    print('Hive box opened successfully.');
  }

  Future<void> _fetchAndSyncSchools() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> schools = jsonDecode(response.body);

        for (var schoolData in schools) {
          School fetchedSchool = School(
            id: int.tryParse(schoolData['fid'] ?? '0'),
            schoolName: schoolData['schoolName'],
            schoolCode: schoolData['schoolCode'],
            schoolAddress: schoolData['schoolAddress'],
            schoolPhoneNumber: schoolData['schoolPhoneNumber'],
            schoolEmail: schoolData['schoolEmail'],
            termId: schoolData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingSchoolList = _schoolBox!.values
              .where(
                (school) => school.schoolCode == fetchedSchool.schoolCode,
              )
              .toList();

          School? existingSchool =
              existingSchoolList.isNotEmpty ? existingSchoolList.first : null;
          if (fetchedSchool.schoolCode != null) {
            if (existingSchool != null) {
              // Update existing record
              existingSchool
                ..schoolName = fetchedSchool.schoolName
                ..schoolAddress = fetchedSchool.schoolAddress
                ..schoolPhoneNumber = fetchedSchool.schoolPhoneNumber
                ..schoolEmail = fetchedSchool.schoolEmail
                ..termId = fetchedSchool.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedSchool.id;

              await existingSchool.save();
              print(
                  'School ${fetchedSchool.schoolCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _schoolBox!.add(fetchedSchool);
              print(
                  'School ${fetchedSchool.schoolCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another School record was Found with no School Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch schools from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing schools: $e');
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
        title: const Center(child: Text('Fetch and Save Schools')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || accountant || subadmin) await _fetchAndSyncSchools();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Schools data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save Schools'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
