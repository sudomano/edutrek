import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/database/student_payments.dart'; // Import for StudentPayments model
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart'; // Import for Teachers model

class UpdateClassScreen extends StatefulWidget {
  final String classCode; // Using classCode as primary key

  const UpdateClassScreen({super.key, required this.classCode});

  @override
  _UpdateClassScreenState createState() => _UpdateClassScreenState();
}

class _UpdateClassScreenState extends State<UpdateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();

  late Classes _currentClass;
  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadTerms();
  }

  Future<void> _initializeData() async {
    final box = await Hive.openBox<Classes>('classes');

    final currentClass = box.values.firstWhere(
      (c) => c.classCode == widget.classCode,
      orElse: () => Classes(
        id: -1,
        className: '',
        classCode: '',
        date: DateTime(1970),
        termId: globalTermId,
      ),
    );

    if (currentClass.id == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Selected class not found')),
      );
      return;
    }

    setState(() {
      _currentClass = currentClass;
      _classNameController.text = currentClass.className;
      _selectedTerms = List<String>.from(currentClass.terms ?? []);
    });
  }

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    setState(() {
      _availableTerms = termsBox.values.map((term) => term.termId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Class',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('Class Name ', _classNameController),
            const SizedBox(height: 20),
            _buildTermSelection(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateClass,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSelection() {
    return _availableTerms.isEmpty
        ? const Text('No terms available')
        : Column(
            children: _availableTerms.map((term) {
              return CheckboxListTile(
                title: Text(term),
                value: _selectedTerms.contains(term),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTerms.add(term);
                    } else {
                      _selectedTerms.remove(term);
                    }
                  });
                },
              );
            }).toList(),
          );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  void _updateClass() async {
    if (_formKey.currentState!.validate()) {
      final box = await Hive.openBox<Classes>('classes');

      final currentClass = box.values.firstWhere(
        (c) => c.classCode == widget.classCode,
        orElse: () => Classes(
          id: -1,
          className: '',
          classCode: '',
          date: DateTime(1970),
          termId: globalTermId,
        ),
      );

      if (currentClass.id == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Class not found')),
        );
        return;
      }

      final oldClassName = currentClass.className;
      final className = _classNameController.text.trim().toLowerCase();

      final existingClass = box.values.firstWhere(
        (c) =>
            c.className.toLowerCase() == className.toLowerCase() &&
            c.classCode != widget.classCode,
        orElse: () => Classes(
            id: -1,
            className: '',
            classCode: '',
            date: DateTime(1970),
            termId: globalTermId),
      );

      if (existingClass.id != -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class with this name already exists')),
        );
        return;
      }

      List<String> modifiedFields = currentClass.modifiedFields ?? [];
      if (currentClass.className != className &&
          !modifiedFields.contains('className')) {
        modifiedFields.add('className');
      }
      if (currentClass.terms?.join(',') != _selectedTerms.join(',') &&
          !modifiedFields.contains('terms')) {
        modifiedFields.add('terms');
      }

      final updatedClass = currentClass.copyWith(
        id: currentClass.id,
        className: className,
        date: DateTime.now(),
        termId: globalTermId,
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'update',
        modifiedFields: modifiedFields,
        terms: List<String>.from(_selectedTerms),
      );

      // Delete the original record (to avoid duplicates)
      await box.delete(widget.classCode);
      // Insert the updated class using classCode as the key
      await box.put(widget.classCode, updatedClass);
      // Update students' terms based on the changes to the class's terms
      await _updateStudentsTerms(oldClassName, className, updatedClass.terms);

      await _updateRelatedRecords(oldClassName, className);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class Updated Successfully')),
      );

      Navigator.pop(context);
    }
  }

// This method updates the terms for all students in the class being updated
  Future<void> _updateStudentsTerms(
      String oldClassName, String newClassName, List<String>? newTerms) async {
    final studentBox = await Hive.openBox<Student>('students');

    for (var student
        in studentBox.values.where((s) => s.class_ == oldClassName)) {
      // Get the current terms of the student
      List<String> studentTerms = List<String>.from(student.terms ?? []);

      // Add new terms that are in the updated class terms list but not in the student's current terms list
      if (newTerms != null) {
        for (var term in newTerms) {
          if (!studentTerms.contains(term)) {
            studentTerms.add(term); // Append new terms
          }
        }

        // Remove terms from the student's list that are no longer part of the updated class terms
        studentTerms.removeWhere((term) => !newTerms.contains(term));
      }

      // Save the updated student record
      await studentBox.put(
        student.key,
        student.copyWith(
          terms: studentTerms, // Update terms list
          syncStatus: false, // Mark for sync
          lastModified: DateTime.now(), // Update lastModified field
        ),
      );
    }
  }

  Future<void> _updateRelatedRecords(
      String oldClassName, String newClassName) async {
    final studentBox = await Hive.openBox<Student>('students');
    for (var student
        in studentBox.values.where((s) => s.class_ == oldClassName)) {
      await studentBox.put(
          student.key,
          student.copyWith(
              class_: newClassName,
              syncStatus: false,
              lastModified: DateTime.now()));
    }

    final paymentsBox = await Hive.openBox<StudentPayment>('student_payments');
    for (var payment
        in paymentsBox.values.where((p) => p.studentClass == oldClassName)) {
      await paymentsBox.put(
          payment.key,
          payment.copyWith(
              studentClass: newClassName,
              syncStatus: false,
              lastModified: DateTime.now()));
    }

    final teachersBox = await Hive.openBox<Teachers>('teachers');
    for (var teacher
        in teachersBox.values.where((t) => t.assignedClass == oldClassName)) {
      await teachersBox.put(teacher.key,
          teacher.copyWith(syncStatus: false, lastModified: DateTime.now()));
    }
  }
}
