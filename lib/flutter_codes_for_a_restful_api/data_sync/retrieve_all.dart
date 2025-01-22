import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/school_info.dart';

class SyncSchoolsPage extends StatefulWidget {
  const SyncSchoolsPage({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<SyncSchoolsPage> {
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
      if (response.statusCode == 200) {
        List<dynamic> schools = jsonDecode(response.body);

        for (var schoolData in schools) {
          School fetchedSchool = School(
            id: schoolData['id'],
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
              ..lastModified = DateTime.now();
            await existingSchool.save();
            print(
                'School ${fetchedSchool.schoolCode} updated successfully in Hive.');
          } else {
            // Create a new record
            await _schoolBox!.add(fetchedSchool);
            print(
                'School ${fetchedSchool.schoolCode} added successfully to Hive.');
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
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Fetch and Save Schools')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _fetchAndSyncSchools();
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
