import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import '../database/student.dart';
import '../database/student_payments.dart'; // Import for the StudentPayments model

class DeleteStudentScreen extends StatefulWidget {
  const DeleteStudentScreen({super.key});

  @override
  _DeleteStudentScreenState createState() => _DeleteStudentScreenState();
}

class _DeleteStudentScreenState extends State<DeleteStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indexController =
      TextEditingController(); // To specify which student to delete
  List<Student> _foundStudents = [];

  void _searchStudent() async {
    final box = await Hive.openBox<Student>('students');
    final classes =
        box.values.where((class_) => class_.termId == globalTermId).toList();
    final searchTerm = _indexController.text.toLowerCase();

    final classesWithName = classes
        .where((class_) =>
            class_.surname.toLowerCase().startsWith(searchTerm.toLowerCase()) &&
            class_.termId == globalTermId)
        .toList();

    // Sort classes alphabetically by class name
    classesWithName.sort((a, b) => a.surname.compareTo(b.surname));

    setState(() {
      _foundStudents = classesWithName;
    });
  }

  void _deleteStudent(Student classToDelete) async {
    final classesBox = await Hive.openBox<Student>('students');
    final studentsBox = await Hive.openBox<StudentPayment>('student_payments');

    if (classToDelete.termId == globalTermId) {
      final classNameToDelete = classToDelete.name.toLowerCase();
      final classSurnameToDelete = classToDelete.surname.toLowerCase();
      final classClassToDelete = classToDelete.class_.toLowerCase();

      // Delete related records in the Students-Payments model
      final studentsToDelete = studentsBox.values
          .where((student) =>
              student.termId == globalTermId &&
              student.studentName.toLowerCase() ==
                  classNameToDelete.toLowerCase() &&
              student.studentSurname.toLowerCase() ==
                  classSurnameToDelete.toLowerCase() &&
              student.studentClass.toLowerCase() ==
                  classClassToDelete.toLowerCase())
          .toList();
      for (var student in studentsToDelete) {
        await studentsBox.delete(student.key);
      }

      // Delete the class itself
      await classesBox.delete(classToDelete.key);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Student and related records deleted successfully')),
      );

      setState(() {
        _foundStudents.remove(classToDelete);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student cannot be deleted')),
      );
    }
  }

  void _confirmDeleteAllStudents() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Students'),
          content: const Text(
              'Are you sure you want to delete all Students for the current term? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllStudents,
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

  void _deleteAllStudents() async {
    final studentsBox = await Hive.openBox<Student>('students');
    final studentPaymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');

    // Filter classes by termId before deleting
    final classesToDelete = studentsBox.values
        .cast<Student>()
        .where((c) => c.termId == globalTermId)
        .toList();

    for (var classRecord in classesToDelete) {
      final classNameToDelete = classRecord.name.toLowerCase();

      final classSurnameToDelete = classRecord.surname.toLowerCase();
      final classClassToDelete = classRecord.class_.toLowerCase();

      // Delete related records in the Students model
      final studentsToDelete = studentPaymentsBox.values
          .where((student) =>
              student.termId == globalTermId &&
              student.studentName.toLowerCase() ==
                  classNameToDelete.toLowerCase() &&
              student.studentSurname.toLowerCase() ==
                  classSurnameToDelete.toLowerCase() &&
              student.studentClass.toLowerCase() ==
                  classClassToDelete.toLowerCase())
          .toList();
      for (var student in studentsToDelete) {
        await studentPaymentsBox.delete(student.key);
      }

      // Delete the class itself
      await studentsBox.delete(classRecord.key);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${classesToDelete.length} Classes and related records deleted successfully')),
    );

    setState(() {
      _foundStudents.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'Delete Student',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllStudents,
            tooltip: 'Delete All Students',
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
                      labelText: 'Enter Surname to Search',
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
                        return 'Please enter a surname';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _searchStudent,
                        child: const Text('Search'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_foundStudents.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _foundStudents.length,
                        itemBuilder: (context, index) {
                          final foundStudent = _foundStudents[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                'Name: ${foundStudent.name}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Registration Number: ${foundStudent.regNumber}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteStudent(foundStudent),
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
