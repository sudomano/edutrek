import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/database/student_payments.dart'; // Import for StudentPayments model
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart'; // Import for Teachers model

class UpdateClassScreen extends StatefulWidget {
  final int index; // Index of the class to update

  const UpdateClassScreen(
      {super.key, required this.index}); // Ensure the index is passed

  @override
  _UpdateClassScreenState createState() => _UpdateClassScreenState();
}

class _UpdateClassScreenState extends State<UpdateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController(); // For class name

  late List<Classes> _classes; // List to hold the classes

  @override
  void initState() {
    super.initState();
    _initializeData(); // Call the async method here
  }

  Future<void> _initializeData() async {
    final box = await Hive.openBox<Classes>('classes');

    final matchingClasses = box.values
        .where(
          (classItem) => classItem.termId != null,
        )
        .toList();

    final currentClass =
        matchingClasses[widget.index]; // Get the item to update

    setState(() {
      _classNameController.text =
          currentClass.className; // Initialize with current data

      _classes = box.values
          .where((c) => c.termId != null) // Filter by globalTermId
          .toList();
      _classes.sort(
          (a, b) => a.className.compareTo(b.className)); // Sort alphabetically
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Class',
      child: Form(
        key: _formKey, // Key for form validation
        child: ListView(
          children: [
            _buildTextField(
                'Class Name ', _classNameController), // Input for class name
            const SizedBox(height: 20), // Add spacing
            ElevatedButton(
              onPressed: _updateClass,
              style: ElevatedButton.styleFrom(
                foregroundColor: Color.fromARGB(255, 6, 6, 6),
                backgroundColor:
                    Color.fromARGB(255, 247, 248, 249), // Set text color
                elevation: 3, // Add elevation
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10), // Add rounded corners
                ),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true, // Add background color
        fillColor: Colors.white, // Set background crolor
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label'; // Ensure input is not empty
        }
        return null;
      },
    );
  }

  void _updateClass() async {
    if (_formKey.currentState!.validate()) {
      final box = await Hive.openBox<Classes>('classes');

      // Retrieve the current class using the globalTermId and index
      final matchingClasses =
          box.values.where((classItem) => classItem.termId != null).toList();

      final currentClass = matchingClasses[widget.index];
      final classKey = currentClass.key; // Use this key for updating

      final oldClassName = currentClass.className; // Save the old class name
      final className = _classNameController.text.toLowerCase();
      final classCode = currentClass.classCode!;

      // Check if a class with the new name already exists
      final existingClass = box.values.firstWhere(
        (c) =>
            c.className.toLowerCase().trim() ==
                className.toLowerCase().trim() &&
            c.termId != null,
        orElse: () => Classes(
          id: -1,
          className: '',
          date: DateTime(1970),
          termId: globalTermId,
        ),
      );

      // Ensure we're not creating a duplicate class
      if (existingClass.id != -1 && existingClass.id != currentClass.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class with this name already exists')),
        );
        return;
      }

      // Track modified fields
      List<String> modifiedFields = currentClass.modifiedFields ?? [];

      if (currentClass.className != className) {
        modifiedFields.add('className');
      }
      if (currentClass.className.toLowerCase() != className) {
        if (!modifiedFields.contains('className')) {
          modifiedFields.add('className');
        }
      }

      // Update the class with the new information
      final updatedClass = Classes(
        id: currentClass.id, // Retain original ID
        className: className, // Update class name
        classCode: classCode,
        date: DateTime.now(), // Update to the current date
        termId: globalTermId, // Keep the same term ID
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set the last modified time
        operationType: 'update', // Mark operation as update
        modifiedFields: modifiedFields,
      );

      // Use the Hive key to update the class, not the index
      await box.put(classKey, updatedClass);

      // Update related records (students, payments, teachers)
      await _updateRelatedRecords(oldClassName, className);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class Updated Successfully')),
      );

      Navigator.pop(context);
    }
  }

  Future<void> _updateRelatedRecords(
      String oldClassName, String newClassName) async {
    // Update Students
    final studentBox = await Hive.openBox<Student>('students');
    final studentsToUpdate = studentBox.values
        .where((student) =>
            student.termId != null && student.class_ == oldClassName)
        .toList();

    for (var student in studentsToUpdate) {
      // Track modified fields
      List<String> modifiedFields = [];
      modifiedFields.add('class_');

      final updatedStudent = student.copyWith(
        class_: newClassName,
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType: 'update',
        modifiedFields: modifiedFields,
      );
      // Set operationType to 'create');
      if (studentsToUpdate.isNotEmpty) {
        await studentBox.put(student.key, updatedStudent);
      }
    }

    // Update StudentPayments
    final paymentsBox = await Hive.openBox<StudentPayment>('student_payments');
    final paymentsToUpdate = paymentsBox.values
        .where((payment) =>
            payment.termId != null && payment.studentClass == oldClassName)
        .toList();

    for (var payment in paymentsToUpdate) {
      List<String> modifiedFields = [];
      modifiedFields.add('studentClass');

      final updatedPayment = payment.copyWith(
        studentClass: newClassName,
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType: 'update',
        modifiedFields: modifiedFields,
      );
      if (paymentsToUpdate.isNotEmpty) {
        await paymentsBox.put(payment.key, updatedPayment);
      }
    }

    // Update Teachers
    final teachersBox = await Hive.openBox<Teachers>('teachers');
    final teachersToUpdate = teachersBox.values
        .where((teacher) =>
            teacher.termId != null && teacher.assignedClass == oldClassName)
        .toList();

    for (var teacher in teachersToUpdate) {
      List<String> modifiedFields = [];
      modifiedFields.add('studentClass');

      final updatedTeacher = teacher.copyWith(
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType: 'update',
        modifiedFields: modifiedFields,
      );
      if (teachersToUpdate.isNotEmpty) {
        await teachersBox.put(teacher.key, updatedTeacher);
      }
    }
  }
}
