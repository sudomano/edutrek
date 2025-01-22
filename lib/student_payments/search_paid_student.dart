import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class SearchPaidStudent extends StatefulWidget {
  const SearchPaidStudent({Key? key});

  @override
  SearchPaidStudentState createState() => SearchPaidStudentState();
}

class SearchPaidStudentState extends State<SearchPaidStudent> {
  final _searchController = TextEditingController();
  Student? _selectedStudent;
  List<StudentPayment> _studentPayments = [];
  List<PaymentPurpose> _allPaymentPurposes = [];

  @override
  void initState() {
    super.initState();

    var students = Hive.box<PaymentPurpose>('payment_purposes').values.toList();
    _allPaymentPurposes = students
        .where((classItem) => classItem.termId == globalTermId)
        .toList();
  }

  void _searchStudent() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a surname to search')),
      );
      return;
    }

    final studentBox = Hive.box<Student>('students');
    final matchingStudents = studentBox.values
        .where((student) =>
            student.surname.toLowerCase().contains(query.toLowerCase()) &&
            student.termId == globalTermId)
        .toList();

    if (matchingStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching students found')),
      );
    } else {
      _showStudentSelectionDialog(context, matchingStudents);
    }
  }

  void _showStudentSelectionDialog(
      BuildContext context, List<Student> matchingStudents) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a Student'),
          content: SizedBox(
            height: 200,
            width: 200,
            child: ListView.builder(
              itemCount: matchingStudents.length,
              itemBuilder: (context, index) {
                final student = matchingStudents[index];
                return ListTile(
                  title: Text('${student.name} ${student.surname}'),
                  subtitle: Text('Class: ${student.class_}'),
                  onTap: () {
                    setState(() {
                      _selectedStudent = student;
                      _getStudentPayments(student);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Selected student: ${student.name} ${student.surname}')),
                    );
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _getStudentPayments(Student student) {
    final paymentBox = Hive.box<StudentPayment>('student_payments');

    _studentPayments = paymentBox.values
        .where((payment) =>
            payment.studentName == student.name &&
            payment.studentSurname == student.surname &&
            student.termId == globalTermId)
        .toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Student Payments and Purposes'),
        backgroundColor: const Color.fromARGB(255, 240, 234, 251),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Student by Surname',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchStudent,
                ),
              ),
            ),
            if (_selectedStudent != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Selected Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Class: ${_selectedStudent!.class_}'),
                  Text('Phone Number: ${_selectedStudent!.phoneNumber}'),
                ],
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _allPaymentPurposes.length,
                itemBuilder: (context, index) {
                  final purpose = _allPaymentPurposes[index];
                  final payment = _studentPayments.firstWhere(
                    (p) =>
                        p.paymentPurpose == purpose.paymentPurpose &&
                        p.termId == globalTermId,
                    orElse: () => StudentPayment(
                        paymentPurpose: purpose.paymentPurpose,
                        amountToPay: 0,
                        studentName: '?',
                        studentSurname: '?',
                        studentClass: '?',
                        phoneNumber: '?',
                        paymentDate: DateTime.now()), // Added default date
                  );

                  return ListTile(
                    title: Text('Purpose: ${purpose.paymentPurpose}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount Paid: ${payment.amountToPay}'),
                        Text(
                            'Payment Date: ${DateFormat('yyyy-MM-dd').format(payment.paymentDate)}'), // Display payment date
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
