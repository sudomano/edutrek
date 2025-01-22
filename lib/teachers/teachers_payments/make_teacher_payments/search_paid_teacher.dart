import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';

class SearchPaidTeacher extends StatefulWidget {
  const SearchPaidTeacher({Key? key});

  @override
  SearchPaidTeacherState createState() => SearchPaidTeacherState();
}

class SearchPaidTeacherState extends State<SearchPaidTeacher> {
  final _searchController = TextEditingController();
  Teachers? _selectedStudent;
  List<TeacherPayment> _studentPayments = [];
  List<TeacherPaymentsPurposes> _allPaymentPurposes = [];

  @override
  void initState() {
    super.initState();
    _allPaymentPurposes =
        Hive.box<TeacherPaymentsPurposes>('teacher_payments_purposes')
            .values
            .toList();
  }

  void _searchStudent() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter Teacher ID Number to search')),
      );
      return;
    }

    final studentBox = Hive.box<Teachers>('teachers');
    final matchingStudents = studentBox.values
        .where((teacher) =>
            teacher.IdNumber.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (matchingStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching Teachers found')),
      );
    } else {
      _showStudentSelectionDialog(context, matchingStudents);
    }
  }

  void _showStudentSelectionDialog(
      BuildContext context, List<Teachers> matchingStudents) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select  Teacher'),
          content: SizedBox(
            height: 200,
            width: 200,
            child: ListView.builder(
              itemCount: matchingStudents.length,
              itemBuilder: (context, index) {
                final teacher = matchingStudents[index];
                return ListTile(
                  title: Text('${teacher.name} ${teacher.surname}'),
                  onTap: () {
                    setState(() {
                      _selectedStudent = teacher;
                      _getStudentPayments(teacher);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Selected teacher: ${teacher.name} ${teacher.surname}')),
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

  void _getStudentPayments(Teachers teacher) {
    final paymentBox = Hive.box<TeacherPayment>('teacher_payments');

    _studentPayments = paymentBox.values
        .where((payment) =>
            payment.studentName == teacher.name &&
            payment.studentSurname == teacher.surname)
        .toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Teacher Payments and Purposes'),
        backgroundColor: const Color.fromARGB(255, 240, 234, 251),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Teacher by Id Number',
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
                    'Selected Teacher: ${_selectedStudent!.name} ${_selectedStudent!.surname}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Phone Number: ${_selectedStudent!.phoneNumber}'),
                ],
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _allPaymentPurposes.length,
                itemBuilder: (context, index) {
                  final purpose = _allPaymentPurposes[index];
                  final payment = _studentPayments.firstWhere(
                    (p) => p.paymentPurpose == purpose.paymentPurpose,
                    orElse: () => TeacherPayment(
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
