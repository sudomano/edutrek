import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class DeleteClassScreen extends StatefulWidget {
  final Classes? classToDelete; // <- Accept class to delete (optional)

  const DeleteClassScreen({Key? key, this.classToDelete}) : super(key: key);

  @override
  _DeleteClassScreenState createState() => _DeleteClassScreenState();
}

class _DeleteClassScreenState extends State<DeleteClassScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.classToDelete != null) {
      // If a class is passed, confirm deletion immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confirmDeleteSpecificClass(widget.classToDelete!);
      });
    }
  }

  void _confirmDeleteSpecificClass(Classes classToDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content:
            Text('Are you sure you want to delete ${classToDelete.className}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Cancel
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _deleteClass(classToDelete);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _indexController =
      TextEditingController(); // To specify which class to delete
  List<Classes> _foundClasses = [];

  void _searchClass() async {
    final box = await Hive.openBox<Classes>('classes');
    final classes =
        box.values.where((class_) => class_.termId != null).toList();
    final searchTerm = _indexController.text.toLowerCase();

    final classesWithName = classes
        .where((class_) =>
            class_.className.toLowerCase().startsWith(searchTerm) &&
            class_.termId != null)
        .toList();

    // Sort classes alphabetically by class name
    classesWithName.sort((a, b) => a.className.compareTo(b.className));

    setState(() {
      _foundClasses = classesWithName;
    });
  }

  void _deleteClass(Classes classToDelete) async {
    final classesBox = await Hive.openBox<Classes>('classes');
    final studentsBox = await Hive.openBox<Student>('students');
    final studentPaymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    final teachersBox = await Hive.openBox<Teachers>('teachers');

    if (classToDelete.termId != null) {
      final classNameToDelete = classToDelete.className;

      // Delete related records in the Students model where class_ == className
      final studentsToDelete = studentsBox.values
          .where((student) =>
              student.termId != null && student.class_ == classNameToDelete)
          .toList();
      for (var student in studentsToDelete) {
        await studentsBox.delete(student.key);
      }

      // Delete related records in the StudentPayments model where studentClass == className
      final studentPaymentsToDelete = studentPaymentsBox.values
          .where((payment) =>
              payment.termId != null &&
              payment.studentClass == classNameToDelete)
          .toList();
      for (var payment in studentPaymentsToDelete) {
        await studentPaymentsBox.delete(payment.key);
      }

      // Delete related records in the Teachers model where assignedClass == className
      final teachersToDelete = teachersBox.values
          .where((teacher) =>
              teacher.termId != null &&
              teacher.assignedClass == classNameToDelete)
          .toList();
      for (var teacher in teachersToDelete) {
        await teachersBox.delete(teacher.key);
      }

      // Delete the class itself
      await classesBox.delete(classToDelete.key);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Class and related records deleted successfully')),
      );

      setState(() {
        _foundClasses.remove(classToDelete);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class cannot be deleted')),
      );
    }
  }

  void _confirmDeleteAllClasses() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Classes'),
          content: const Text(
              'Are you sure you want to delete all classes for the current term? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllClasses,
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

  void _deleteAllClasses() async {
    final classesBox = await Hive.openBox<Classes>('classes');
    final studentsBox = await Hive.openBox<Student>('students');
    final studentPaymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    final teachersBox = await Hive.openBox<Teachers>('teachers');

    // Filter classes by termId before deleting
    final classesToDelete = classesBox.values
        .cast<Classes>()
        .where((c) => c.termId != null)
        .toList();

    for (var classRecord in classesToDelete) {
      final classNameToDelete = classRecord.className;

      // Delete related records in the Students model
      final studentsToDelete = studentsBox.values
          .where((student) => student.class_ == classNameToDelete)
          .toList();
      for (var student in studentsToDelete) {
        await studentsBox.delete(student.key);
      }

      // Delete related records in the StudentPayments model
      final studentPaymentsToDelete = studentPaymentsBox.values
          .where((payment) => payment.studentClass == classNameToDelete)
          .toList();
      for (var payment in studentPaymentsToDelete) {
        await studentPaymentsBox.delete(payment.key);
      }

      // Delete related records in the Teachers model
      final teachersToDelete = teachersBox.values
          .where((teacher) => teacher.assignedClass == classNameToDelete)
          .toList();
      for (var teacher in teachersToDelete) {
        await teachersBox.delete(teacher.key);
      }

      // Delete the class itself
      await classesBox.delete(classRecord.key);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${classesToDelete.length} Classes and related records deleted successfully')),
    );

    setState(() {
      _foundClasses.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'Delete Class',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),

        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllClasses,
            tooltip: 'Delete All Classes',
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0, // Subtle shadow
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
                      labelText: 'Enter Class Name to Search',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Class Name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _searchClass,
                        child: const Text('Search'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_foundClasses.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _foundClasses.length,
                        itemBuilder: (context, index) {
                          final foundClass = _foundClasses[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text('Name: ${foundClass.className}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text('Date created: ${foundClass.date}',
                                  style: const TextStyle(fontSize: 16)),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteClass(foundClass),
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
