import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class DeleteTermScreen extends StatefulWidget {
  const DeleteTermScreen({Key? key}) : super(key: key);

  @override
  _DeleteTermScreenState createState() => _DeleteTermScreenState();
}

class _DeleteTermScreenState extends State<DeleteTermScreen> {
  final _formKey = GlobalKey<FormState>();
  final _termController =
      TextEditingController(); // To specify which term to delete
  List<Terms> _foundTerms = [];

  void _searchTerm() async {
    final box = await Hive.openBox<Terms>('terms');
    final terms = box.values.toList();
    final searchTerm = _termController.text.toLowerCase();

    final termsWithName = terms
        .where((term) =>
            term.termId.toLowerCase().startsWith(searchTerm.toLowerCase()) &&
            term.status.toLowerCase() != 'opened')
        .toList();
    if (termsWithName.isEmpty) {
      // Show a notification that the term cannot be deleted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please Note: Opened terms cannot be deleted. If the term you want to delete is opened, try closing it by creating a new term.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return; // Don't proceed with showing delete options
    }
    // Sort terms alphabetically by term name
    termsWithName.sort((a, b) => a.termId.compareTo(b.termId));

    setState(() {
      _foundTerms = termsWithName;
    });
  }

  void _deleteTerm(Terms termToDelete) async {
    // Open all relevant Hive boxes
    final termsBox = await Hive.openBox<Terms>('terms');
    final teachersBox = await Hive.openBox<Teachers>('teachers');
    final studentsBox = await Hive.openBox<Student>('students');
    final classesBox = await Hive.openBox<Classes>('classes');
    final studentPaymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    final teacherPaymentsBox =
        await Hive.openBox<TeacherPayment>('teacher_payments');
    final teacherPaymentsPurposesBox =
        await Hive.openBox<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    final paymentPurposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    final withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');

    // Delete the term
    await termsBox.delete(termToDelete.key);

    // Function to delete records with matching termId from a box
    Future<void> deleteRecordsFromBox<T>(Box<T> box) async {
      final records = box.values.where((record) {
        final termIdField = (record as dynamic)
            .termId; // Adjust this if termId is named differently
        return termIdField == termToDelete.termId;
      }).toList();

      for (var record in records) {
        //   await box.delete((record as dynamic).key); // Adjust key if needed
      }
    }

    Future<void> removeTermIdFromModel(Box box) async {
      for (var key in box.keys) {
        var item = box.get(key);

        if (item != null && item is dynamic) {
          // Check if the termId is in the terms list and remove it
          if (item.terms.contains(termToDelete.termId)) {
            item.terms
                .remove(termToDelete.termId); // Remove the termId from the list
            await box.put(key, item); // Save the updated record
          }
        }
      }
    }

    // Delete records related to the term from all boxes
    await Future.wait([
      deleteRecordsFromBox(teachersBox),
      deleteRecordsFromBox(studentsBox),
      deleteRecordsFromBox(classesBox),
      deleteRecordsFromBox(studentPaymentsBox),
      deleteRecordsFromBox(teacherPaymentsBox),
      deleteRecordsFromBox(teacherPaymentsPurposesBox),
      deleteRecordsFromBox(paymentPurposesBox),
      deleteRecordsFromBox(withdrawalsBox),
    ]);

    // Remove the termId from the terms list in all related models
    await Future.wait([
      removeTermIdFromModel(teachersBox),
      removeTermIdFromModel(studentsBox),
      removeTermIdFromModel(classesBox),
    ]);
    globalTermId == null;
    // Show a confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Term and related records deleted successfully')),
    );

    // Delay the pop to allow the SnackBar to be seen before navigating back
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context); // Go back to the previous page
    });

    setState(() {
      _foundTerms.remove(termToDelete);
    });
  }

  void _confirmDeleteAllTerms() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Terms'),
          content: const Text(
              'Are you sure you want to delete all terms? All the records associated to all the terms will be lost! This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllTerms,
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

  void _deleteAllTerms() async {
    // Open all relevant Hive boxes
    final termsBox = await Hive.openBox<Terms>('terms');
    final teachersBox = await Hive.openBox<Teachers>('teachers');
    final studentsBox = await Hive.openBox<Student>('students');
    final classesBox = await Hive.openBox<Classes>('classes');
    final studentPaymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    final teacherPaymentsBox =
        await Hive.openBox<TeacherPayment>('teacher_payments');
    final teacherPaymentsPurposesBox =
        await Hive.openBox<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    final paymentPurposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    final withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');

    // Fetch all terms
    final allTerms = termsBox.values.toList().cast<Terms>();

    // Function to delete records with matching termId from a box
    Future<void> deleteRecordsFromBox<T>(
        Box<T> box, List<String> termIds) async {
      final records = box.values.where((record) {
        final termIdField = (record as dynamic).termId;
        return termIds.contains(termIdField);
      }).toList();

      for (var record in records) {
        //  await box.delete((record as dynamic).key);
      }
    }

    // Extract term IDs
    final termIds = allTerms.map((term) => term.termId).toList();

    // Delete records related to the terms from all boxes
    await Future.wait([
      deleteRecordsFromBox(teachersBox, termIds),
      deleteRecordsFromBox(studentsBox, termIds),
      deleteRecordsFromBox(classesBox, termIds),
      deleteRecordsFromBox(studentPaymentsBox, termIds),
      deleteRecordsFromBox(teacherPaymentsBox, termIds),
      deleteRecordsFromBox(teacherPaymentsPurposesBox, termIds),
      deleteRecordsFromBox(paymentPurposesBox, termIds),
      deleteRecordsFromBox(withdrawalsBox, termIds),
    ]);
    globalTermId == null;
    // Clear the terms box
    await termsBox.clear();

    // Show a confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('All Terms and related records deleted successfully!')),
    );

    // Delay the pop to allow the SnackBar to be seen before navigating back
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context); // Go back to the previous page
    });

    setState(() {
      _foundTerms.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Term',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.red, // Set app bar background color
            ),
            onPressed: _confirmDeleteAllTerms,
            tooltip: 'Delete All Terms.',
          ),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0, // Optional: Add a subtle shadow
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _termController,
                    decoration: InputDecoration(
                      labelText: 'Enter Term Name to Search',
                      filled: true,
                      fillColor: const Color.fromARGB(255, 168, 162, 162)
                          .withOpacity(0.3), // Transparent background
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none, // No border
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Term Name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _searchTerm,
                        child: const Text('Search'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_foundTerms.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _foundTerms.length,
                        itemBuilder: (context, index) {
                          final foundTerm = _foundTerms[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text('Name: ${foundTerm.termId}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Date created: ${foundTerm.startDate}',
                                  style: const TextStyle(fontSize: 16)),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTerm(foundTerm),
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
    _termController.dispose();
    super.dispose();
  }
}
