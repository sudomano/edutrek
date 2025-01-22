import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class TeachersSync extends StatefulWidget {
  const TeachersSync({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<TeachersSync> {
  Box<Teachers>? _teachersBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _teachersBox = await Hive.openBox<Teachers>('teachers');

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

  Future<void> _fetchAndSyncTeachers() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> teachers = jsonDecode(response.body);

        for (var teachersData in teachers) {
          /* teachersData.forEach((key, value) {
            print('Key: $key, Value: $value, Type: ${value?.runtimeType}');
          });*/
          Teachers fetchedTeachers = Teachers(
            id: int.tryParse(teachersData['fid'] ?? '0') ?? 0,
            name: teachersData['name'] ?? '',
            surname: teachersData['surname'] ?? '',
            IdNumber: teachersData['IdNumber'],
            assignedClass: teachersData['assignedClass'] ?? '',
            assignedClasses: _decodeToList(teachersData['assignedClasses']),
            gender: teachersData['gender'] ?? '',
            dateOfBirth: DateTime.tryParse(teachersData['dateOfBirth']) ??
                DateTime.now(),
            phoneNumber: teachersData['phoneNumber'] ?? '',
            paymentPurpose: teachersData['paymentPurpose'] ?? '',
            isPaid: teachersData['isPaid'],
            paymentAmount: teachersData['paymentAmount'] != null
                ? double.tryParse(teachersData['paymentAmount'].toString()) ??
                    0.0
                : 0.0,
            paymentDate: teachersData['paymentDate'] != null
                ? DateTime.tryParse(teachersData['paymentDate'])
                : null,
            email: teachersData['email'] ?? '',
            address: teachersData['address'] ?? '',
            hireDate:
                DateTime.tryParse(teachersData['hireDate']) ?? DateTime(1900),
            qualifications: teachersData['qualifications'] ?? '',
            employmentStatus: teachersData['employmentStatus'] ?? '',
            termId: teachersData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingTeachersList = _teachersBox!.values
              .where(
                (teachers) => teachers.IdNumber == fetchedTeachers.IdNumber,
              )
              .toList();

          Teachers? existingTeachers = existingTeachersList.isNotEmpty
              ? existingTeachersList.first
              : null;
          if (fetchedTeachers.IdNumber != null) {
            if (existingTeachers != null) {
              // Update existing record
              existingTeachers
                ..id = fetchedTeachers.id
                ..name = fetchedTeachers.name
                ..surname = fetchedTeachers.surname
                ..IdNumber = fetchedTeachers.IdNumber
                ..assignedClass = fetchedTeachers.assignedClass
                ..assignedClass = fetchedTeachers.assignedClass
                ..gender = fetchedTeachers.gender
                ..dateOfBirth = fetchedTeachers.dateOfBirth
                ..phoneNumber = fetchedTeachers.phoneNumber
                ..paymentPurpose = fetchedTeachers.paymentPurpose
                ..isPaid = fetchedTeachers.isPaid
                ..paymentAmount = fetchedTeachers.paymentAmount
                ..paymentDate = fetchedTeachers.paymentDate
                ..email = fetchedTeachers.email
                ..address = fetchedTeachers.address
                ..hireDate = fetchedTeachers.hireDate
                ..employmentStatus = fetchedTeachers.employmentStatus
                ..termId = fetchedTeachers.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingTeachers.save();
              print(
                  'Teachers ${fetchedTeachers.IdNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _teachersBox!.add(fetchedTeachers);
              print(
                  'Teachers ${fetchedTeachers.IdNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Record Was Found with no Staff ID Number and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Teachers from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing Teachers: $e');
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
        title: const Center(child: Text('Fetch and Save Teachers')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || secretary || accountant || subadmin)
              await _fetchAndSyncTeachers();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Teachers data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save Teachers'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
