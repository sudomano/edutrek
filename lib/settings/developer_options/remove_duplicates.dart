import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/teachers.dart';

class SettingsScreens extends StatefulWidget {
  const SettingsScreens({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreens> {
  bool _isUpdating = false; // Track update process
  String _updateMessage = '';

  // Function to remove duplicate records
  Future<void> _removeDuplicateRecords() async {
    setState(() {
      _isUpdating = true;
      _updateMessage = 'Removing duplicates... Please wait.';
    });

    try {
      // Open all relevant Hive boxes
      final studentsBox = await Hive.openBox<Student>('students');
      final classesBox = await Hive.openBox<Classes>('classes');
      final teachersBox = await Hive.openBox<Teachers>('teachers');

      // Remove duplicates in students
      await _removeStudentDuplicates(studentsBox);

      // Remove duplicates in classes
      await _removeClassDuplicates(classesBox);

      // Remove duplicates in teachers
      await _removeTeacherDuplicates(teachersBox);

      // Update progress message
      setState(() {
        _isUpdating = false;
        _updateMessage = 'Duplicates removed successfully!';
      });
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _updateMessage = 'Error removing duplicates: $e';
      });
    }
  }

  // Remove duplicates in the students model
  Future<void> _removeStudentDuplicates(Box<Student> studentsBox) async {
    final studentMap = <String, List<Student>>{};

    // Group students by their identifying fields
    for (var key in studentsBox.keys) {
      var student = studentsBox.get(key);

      if (student != null) {
        // Create a unique key based on (name, surname, class, gender) or (studentIdNumber)
        String groupKey = student.studentIdNumber ??
            '${student.name}-${student.surname}-${student.class_}-${student.gender}';

        if (!studentMap.containsKey(groupKey)) {
          studentMap[groupKey] = [];
        }

        studentMap[groupKey]?.add(student);
      }
    }

    // Iterate through each group and remove duplicates
    for (var groupKey in studentMap.keys) {
      var studentsInGroup = studentMap[groupKey]!;
      if (studentsInGroup.length > 1) {
        // Sort the students by lastModified date (latest first)
        studentsInGroup
            .sort((a, b) => b.lastModified!.compareTo(a.lastModified!));

        // Keep the latest one and delete the older ones
        for (var i = 1; i < studentsInGroup.length; i++) {
          await studentsBox.delete(studentsInGroup[i].key);
        }
      }
    }
  }

  // Remove duplicates in the classes model
  Future<void> _removeClassDuplicates(Box<Classes> classesBox) async {
    final classMap = <String, List<Classes>>{};

    // Group classes by className or classCode
    for (var key in classesBox.keys) {
      var classItem = classesBox.get(key);

      if (classItem != null) {
        // Create a unique key based on className or classCode
        String groupKey = classItem.classCode ?? classItem.className;

        if (!classMap.containsKey(groupKey)) {
          classMap[groupKey] = [];
        }

        classMap[groupKey]?.add(classItem);
      }
    }

    // Iterate through each group and remove duplicates
    for (var groupKey in classMap.keys) {
      var classesInGroup = classMap[groupKey]!;
      if (classesInGroup.length > 1) {
        // Sort the classes by lastModified date (latest first)
        classesInGroup
            .sort((a, b) => b.lastModified!.compareTo(a.lastModified!));

        // Keep the latest one and delete the older ones
        for (var i = 1; i < classesInGroup.length; i++) {
          await classesBox.delete(classesInGroup[i].key);
        }
      }
    }
  }

  // Remove duplicates in the teachers model
  Future<void> _removeTeacherDuplicates(Box<Teachers> teachersBox) async {
    final teacherMap = <String, List<Teachers>>{};

    // Group teachers by idNumber
    for (var key in teachersBox.keys) {
      var teacher = teachersBox.get(key);

      if (teacher != null) {
        // Create a unique key based on idNumber
        String groupKey = teacher.IdNumber;

        if (!teacherMap.containsKey(groupKey)) {
          teacherMap[groupKey] = [];
        }

        teacherMap[groupKey]?.add(teacher);
      }
    }

    // Iterate through each group and remove duplicates
    for (var groupKey in teacherMap.keys) {
      var teachersInGroup = teacherMap[groupKey]!;
      if (teachersInGroup.length > 1) {
        // Sort the teachers by lastModified date (latest first)
        teachersInGroup
            .sort((a, b) => b.lastModified!.compareTo(a.lastModified!));

        // Keep the latest one and delete the older ones
        for (var i = 1; i < teachersInGroup.length; i++) {
          await teachersBox.delete(teachersInGroup[i].key);
        }
      }
    }
  }

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
                    'Manage Duplicate Records',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : _removeDuplicateRecords,
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
                            'Remove Duplicates',
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
