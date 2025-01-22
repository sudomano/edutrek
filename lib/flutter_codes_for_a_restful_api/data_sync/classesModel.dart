import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

import 'package:zitf_system/database/student.dart';

class Classesmodel extends StatefulWidget {
  const Classesmodel({super.key});

  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

class _SyncClassesPageState extends State<Classesmodel> {
  Box<Student>? _studentsBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _studentsBox = await Hive.openBox<Student>(
        'students'); // Open the box for student data
    print('All Hive boxes opened successfully.');
  }

  Future<List<Student>> _fetch_studentsForCreate() async {
    print('Fetching students for creation...');
    List<Student> createStudent =
        _studentsBox!.values.where((cls) => cls.syncStatus == false).toList();
    print('${createStudent.length} Student found for creation.');

    for (var paymentPurpose in createStudent) {
      print('PaymentPurpose ID: ${paymentPurpose.id}, '
          'Operation Type: ${paymentPurpose.operationType}, '
          'Sync Status: ${paymentPurpose.syncStatus}');
    }

    return createStudent;
  }

  // Sync models to MySQL
  Future<void> _syncModels() async {
    try {
      // Sync PaymentPurpose records

      // Sync Student records
      List<Student> students =
          _studentsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Student cls in students) {
        if (cls.operationType == 'create') {
          await _createClassInMySQLStudent(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentInMySQL(cls);
        }
      }

      print('All models have been synced.');
    } catch (e) {
      print('Error syncing models: $e');
    }
  }

  Map<String, dynamic> _studentInfoToJson(Student cls) {
    return {
      'name': cls.name,
      'surname': cls.surname,
      'regNumber': cls.regNumber,
      'class': cls.class_,
      'gender': cls.gender,
      'age': cls.age.toIso8601String(),
      'phoneNumber': cls.phoneNumber,
      'paymentStatus': cls.paymentStatus,
      'isPresent': cls.isPresent,
      'presentDates':
          cls.presentDates.map((date) => date.toIso8601String()).toList(),
      'absentDates':
          cls.absentDates.map((date) => date.toIso8601String()).toList(),
      'termId': cls.termId,
      'id': cls.id,
      'physicalAddress': cls.physicalAddress,
      'formerSchool': cls.formerSchool,
      'religion': cls.religion,
      'denomination': cls.denomination,
      'studentIdNumber': cls.studentIdNumber,
      'nationalIdNumber': cls.nationalIdNumber,
      'nationality': cls.nationality,
      'district': cls.district,
      'previousSchoolPerformanceResults': cls.previousSchoolPerformanceResults,
      'enrollmentStatus': cls.enrollmentStatus,
      'emergencyContactName': cls.emergencyContactName,
      'emergencyContactNumber': cls.emergencyContactNumber,
    };
  }

  Future<void> _createClassInMySQLStudent(Student newClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(newClass);

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('student_information ${newClass.name} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        await newClass.save();
      } else {
        throw Exception('Failed to create student_information.');
      }
    } catch (e) {
      print('Error creating student_information: $e');
    }
  }

  Future<void> _updateStudentInMySQL(Student updatedClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(updatedClass);
    print('Updating Student in MySQL: ${updatedClass.name}');

    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?pid=${updatedClass.id}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print('Student ${updatedClass.name} updated successfully.');
        // Update syncStatus and operationType in Hive
        updatedClass.syncStatus = true;
        updatedClass.operationType = 'none';
        await updatedClass.save();
      } else {
        throw Exception('Failed to update Student.');
      }
    } catch (e) {
      print('Error updating Student: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Synchronization')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _syncModels();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('all records have been synchronized Successfully.'),
            ));
          },
          child: Text('Sync All New Records'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _studentsBox?.close();

    super.dispose();
  }
}
