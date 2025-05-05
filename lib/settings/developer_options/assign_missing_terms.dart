import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isUpdating = false; // Track update process
  String _updateMessage = '';
  Future<void> _updateRecords() async {
    setState(() {
      _isUpdating = true;
      _updateMessage = 'Updating records... Please wait.';
    });

    try {
      final classBox = await Hive.openBox<Classes>('classes');
      final teacherBox = await Hive.openBox<Teachers>('teachers');
      final studentBox = await Hive.openBox<Student>('students');
      final termsBox = await Hive.openBox<Terms>('terms');

      // Get all terms
      List<String> allTerms =
          termsBox.values.map((term) => term.termId).toList();

      if (allTerms.isEmpty) {
        setState(() {
          _isUpdating = false;
          _updateMessage = 'No terms found. Please create terms first.';
        });
        return;
      }

      // Get students, classes, and teachers with null or empty terms
      List<Student> studentsToUpdate = studentBox.values
          .where((student) => student.terms == null || student.terms!.isEmpty)
          .toList();

      List<Classes> classesToUpdate = classBox.values
          .where((classItem) =>
              classItem.terms == null || classItem.terms!.isEmpty)
          .toList();

      List<Teachers> teachersToUpdate = teacherBox.values
          .where((teacher) => teacher.terms == null || teacher.terms!.isEmpty)
          .toList();

      // If no records need updating, return early
      if (studentsToUpdate.isEmpty &&
          classesToUpdate.isEmpty &&
          teachersToUpdate.isEmpty) {
        setState(() {
          _isUpdating = false;
          _updateMessage = 'All records already have assigned terms.';
        });
        return;
      }

      int updatedCount = 0;

      // Update students
      for (var student in studentsToUpdate) {
        Student updatedStudent = student.copyWith(
          terms: List<String>.from(allTerms), // Assign all available terms
          modifiedFields: [...(student.modifiedFields ?? []), 'terms'],
          syncStatus: false, // Mark as needing sync
          lastModified: DateTime.now(), // Update last modified date
          operationType: 'update', // Mark as update
        );

        final key =
            studentBox.keys.firstWhere((k) => studentBox.get(k) == student);
        await studentBox.put(key, updatedStudent);
        updatedCount++;
      }

      // Update classes
      for (var classItem in classesToUpdate) {
        Classes updatedClass = classItem.copyWith(
          terms: List<String>.from(allTerms), // Assign all available terms
          modifiedFields: [...(classItem.modifiedFields ?? []), 'terms'],
          syncStatus: false, // Mark as needing sync
          lastModified: DateTime.now(), // Update last modified date
          operationType: 'update', // Mark as update
        );

        final key =
            classBox.keys.firstWhere((k) => classBox.get(k) == classItem);
        await classBox.put(key, updatedClass);
        updatedCount++;
      }

      // Update teachers
      for (var teacher in teachersToUpdate) {
        Teachers updatedTeacher = teacher.copyWith(
          terms: List<String>.from(allTerms), // Assign all available terms
          modifiedFields: [...(teacher.modifiedFields ?? []), 'terms'],
          syncStatus: false, // Mark as needing sync
          lastModified: DateTime.now(), // Update last modified date
          operationType: 'update', // Mark as update
        );

        final key =
            teacherBox.keys.firstWhere((k) => teacherBox.get(k) == teacher);
        await teacherBox.put(key, updatedTeacher);
        updatedCount++;
      }

      setState(() {
        _isUpdating = false;
        _updateMessage = 'Successfully updated $updatedCount records.';
      });
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _updateMessage = 'Error updating records: $e';
      });
    }
  }

/*

  Future<void> _updateStudentTerms() async {
    setState(() {
      _isUpdating = true;
      _updateMessage = 'Updating students... Please wait.';
    });

    try {
      final ClassBox = await Hive.openBox<Classes>('classes');
      final teacherBox = await Hive.openBox<Teachers>('teachers');
      final studentBox = await Hive.openBox<Student>('students');
      final termsBox = await Hive.openBox<Terms>('terms');

      // Get all terms
      List<String> allTerms =
          termsBox.values.map((term) => term.termId).toList();

      if (allTerms.isEmpty) {
        setState(() {
          _isUpdating = false;
          _updateMessage = 'No terms found. Please create terms first.';
        });
        return;
      }

      // Get students with null or empty terms
      List<Student> studentsToUpdate = studentBox.values
          .where((student) => student.terms == null || student.terms!.isEmpty)
          .toList();

      if (studentsToUpdate.isEmpty) {
        setState(() {
          _isUpdating = false;
          _updateMessage = 'All students already have assigned terms.';
        });
        return;
      }

      int updatedCount = 0;

      for (var student in studentsToUpdate) {
        Student updatedStudent = student.copyWith(
          terms: List<String>.from(allTerms), // Assign all available terms
          modifiedFields: [...(student.modifiedFields ?? []), 'terms'],
          syncStatus: false, // Mark as needing sync
          lastModified: DateTime.now(), // Update last modified date
          operationType: 'update', // Mark as update
        );

        final key =
            studentBox.keys.firstWhere((k) => studentBox.get(k) == student);
        await studentBox.put(key, updatedStudent);
        updatedCount++;
      }

      setState(() {
        _isUpdating = false;
        _updateMessage = 'Successfully updated $updatedCount students.';
      });
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _updateMessage = 'Error updating students: $e';
      });
    }
  }

  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings, size: 60, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  const Text(
                    'Manage Student Records',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : _updateRecords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Assign Terms to Students',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 20),
                  if (_updateMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Text(
                        _updateMessage,
                        style:
                            const TextStyle(fontSize: 16, color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
