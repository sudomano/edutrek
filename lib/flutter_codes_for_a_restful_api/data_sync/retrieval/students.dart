import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class SyncStudentsPages extends StatefulWidget {
  const SyncStudentsPages({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<SyncStudentsPages> {
  Box<Student>? _studentsBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _studentsBox = await Hive.openBox<Student>('students');
    print('Hive box opened successfully.');
  }

  Future<void> _fetchAndSyncSchools() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> students = jsonDecode(response.body);

        for (var studentsData in students) {
          print(studentsData['isPresent'].runtimeType);

          Student fetchedStudents = Student(
            id: int.tryParse(studentsData['fid'] ?? '0'),
            name: studentsData['name'],
            surname: studentsData['surname'],
            regNumber: studentsData['regNumber'],
            class_: studentsData['class'],
            gender: studentsData['gender'] ?? '',
            age: DateTime.tryParse(studentsData['age']) ?? DateTime(1900),
            phoneNumber: studentsData['phoneNumber'] ?? '',
            paymentStatus: studentsData['paymentStatus'] ?? '',
            isPresent: studentsData['isPresent'],
            presentDates: _parseDateList(studentsData['presentDates']),
            absentDates: _parseDateList(studentsData['absentDates']),
            termId: studentsData['termId'] ?? '',
            physicalAddress: studentsData['physicalAddress'] ?? '',
            formerSchool: studentsData['formerSchool'] ?? '',
            religion: studentsData['religion'] ?? '',
            denomination: studentsData['denomination'] ?? '',
            studentIdNumber: studentsData['studentIdNumber'],
            nationalIdNumber: studentsData['nationalIdNumber'] ?? '',
            nationality: studentsData['nationality'] ?? '',
            district: studentsData['district'] ?? '',
            previousSchoolPerformanceResults:
                studentsData['previousSchoolPerformanceResults'] ?? '',
            enrollmentStatus: studentsData['enrollmentStatus'] ?? '',
            emergencyContactName: studentsData['emergencyContactName'] ?? '',
            emergencyContactNumber:
                studentsData['emergencyContactNumber'] ?? '',
          );

          // Check if the record exists in Hive using termId
          var existingStudentsList = _studentsBox!.values
              .where(
                (students) =>
                    students.studentIdNumber == fetchedStudents.studentIdNumber,
              )
              .toList();

          Student? existingStudents = existingStudentsList.isNotEmpty
              ? existingStudentsList.first
              : null;
          if (fetchedStudents.studentIdNumber != null) {
            if (existingStudents != null) {
              // Update existing record
              existingStudents
                ..name = fetchedStudents.name
                ..surname = fetchedStudents.surname
                ..regNumber = fetchedStudents.regNumber
                ..class_ = fetchedStudents.class_
                ..gender = fetchedStudents.gender
                ..termId = fetchedStudents.termId
                ..age = fetchedStudents.age
                ..phoneNumber = fetchedStudents.phoneNumber
                ..paymentStatus = fetchedStudents.paymentStatus
                ..isPresent = fetchedStudents.isPresent
                ..presentDates = fetchedStudents.presentDates
                ..termId = fetchedStudents.termId
                ..absentDates = fetchedStudents.absentDates
                ..termId = fetchedStudents.termId
                ..id = fetchedStudents.id
                ..physicalAddress = fetchedStudents.physicalAddress
                ..formerSchool = fetchedStudents.formerSchool
                ..termId = fetchedStudents.termId
                ..religion = fetchedStudents.religion
                ..denomination = fetchedStudents.denomination
                ..studentIdNumber = fetchedStudents.studentIdNumber
                ..nationalIdNumber = fetchedStudents.nationalIdNumber
                ..nationality = fetchedStudents.nationality
                ..district = fetchedStudents.district
                ..previousSchoolPerformanceResults =
                    fetchedStudents.previousSchoolPerformanceResults
                ..enrollmentStatus = fetchedStudents.enrollmentStatus
                ..emergencyContactName = fetchedStudents.emergencyContactName
                ..emergencyContactNumber =
                    fetchedStudents.emergencyContactNumber
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingStudents.save();
              print(
                  'Student ${fetchedStudents.studentIdNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _studentsBox!.add(fetchedStudents);
              print(
                  'Student ${fetchedStudents.studentIdNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other Student Record Was Found with no Student Reg Number and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch students from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing students: $e');
    }
  }

  List<DateTime> _parseDateList(dynamic jsonList) {
    if (jsonList == null || jsonList is! List) return [];
    return jsonList
        .map<DateTime>(
            (dateStr) => DateTime.tryParse(dateStr) ?? DateTime(1900))
        .toList();
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
        title: const Center(child: Text('Fetch and Save Student')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || secretary || teacher || accountant || subadmin)
              await _fetchAndSyncSchools();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Student data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save Student'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
