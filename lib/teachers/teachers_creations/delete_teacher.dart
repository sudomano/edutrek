import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class DeleteTeacherScreen extends StatefulWidget {
  const DeleteTeacherScreen({super.key});

  @override
  _DeleteTeacherScreenState createState() => _DeleteTeacherScreenState();
}

class _DeleteTeacherScreenState extends State<DeleteTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indexController =
      TextEditingController(); // To specify which teacher to delete
  List<Teachers> _foundTeachers = [];

  void _searchTeacher() async {
    final box = await Hive.openBox<Teachers>('teachers');
    final classes = box.values
        .where((class_) => class_.terms!.contains(globalTermId))
        .toList();
    final searchTerm = _indexController.text.toLowerCase();

    final teacherWithIdNumber = classes
        .where((teachers) =>
            teachers.IdNumber.toLowerCase()
                .startsWith(searchTerm.toLowerCase()) &&
            teachers.terms!.contains(globalTermId))
        .toList();
    teacherWithIdNumber.sort((a, b) => a.surname.compareTo(b.surname));

    setState(() {
      _foundTeachers = teacherWithIdNumber;
    });
  }

  void _deleteTeacher(Teachers teacherToDelete) async {
    final box = await Hive.openBox<Teachers>('teachers');
    final paymentBox = await Hive.openBox<TeacherPayment>('teacher_payments');
    if (teacherToDelete.terms!.contains(globalTermId)) {
      final classNameToDelete = teacherToDelete.name.toLowerCase();
      final classSurnameToDelete = teacherToDelete.surname.toLowerCase();
      final classClassToDelete = teacherToDelete.assignedClass;

      // Delete related records in the Students-Payments model
      final studentsToDelete = paymentBox.values
          .where((student) =>
              student.termId == globalTermId &&
              student.studentName.toLowerCase() ==
                  classNameToDelete.toLowerCase() &&
              student.studentSurname.toLowerCase() ==
                  classSurnameToDelete.toLowerCase() &&
              student.studentClass.toLowerCase() == classClassToDelete)
          .toList();
      for (var student in studentsToDelete) {
        await paymentBox.delete(student.key);
      }

      // Delete the class itself
      await box.delete(teacherToDelete.key);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff Deleted Successfully')),
      );

      setState(() {
        _foundTeachers.remove(teacherToDelete);
      });
    }
  }

  void _confirmDeleteAllTeachers() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Staff'),
          content: const Text(
              'Are you sure you want to delete all Staff? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllTeachers,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAllTeachers() async {
    final box = await Hive.openBox<Teachers>('teachers');
    final paymentBox = await Hive.openBox<TeacherPayment>('teacher_payments');

    // Filter classes by termId before deleting
    final classesToDelete = box.values
        .cast<Teachers>()
        .where((c) => c.terms!.contains(globalTermId))
        .toList();

    for (var classRecord in classesToDelete) {
      final classNameToDelete = classRecord.name.toLowerCase();

      final classSurnameToDelete = classRecord.surname.toLowerCase();
      final classClassToDelete = classRecord.assignedClass;

      // Delete related records in the Students model
      final studentsToDelete = paymentBox.values
          .where((student) =>
              student.termId == globalTermId &&
              student.studentName.toLowerCase() ==
                  classNameToDelete.toLowerCase() &&
              student.studentSurname.toLowerCase() ==
                  classSurnameToDelete.toLowerCase() &&
              student.studentClass.toLowerCase() == classClassToDelete)
          .toList();
      for (var student in studentsToDelete) {
        await paymentBox.delete(student.key);
      }

      // Delete the class itself
      await box.delete(classRecord.key);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${classesToDelete.length} Staff and related records deleted successfully')),
    );

    setState(() {
      _foundTeachers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Delete Staff',
            style: TextStyle(
              fontSize: 14.0, // Adjust font size
              fontWeight: FontWeight.normal, // Font weight
              color: Colors.white, // Title color
              letterSpacing: 1.2, // Slight letter spacing for elegance
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllTeachers,
            tooltip: 'Delete All Staff',
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _indexController,
                    decoration: InputDecoration(
                      labelText: "Enter Staff Id Number to DELETE",
                      filled: true,
                      fillColor: Colors.white
                          .withOpacity(0.3), // Transparent background
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none, // No border
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Id Number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: _searchTeacher,
                      child: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_foundTeachers.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _foundTeachers.length,
                        itemBuilder: (context, index) {
                          final foundTeacher = _foundTeachers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                'Name: ${foundTeacher.name}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Id Number: ${foundTeacher.IdNumber}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTeacher(foundTeacher),
                              ),
                            ),
                          );
                        },
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

  @override
  void dispose() {
    _indexController.dispose();
    super.dispose();
  }
}
