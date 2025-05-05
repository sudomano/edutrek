// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class MakeTeacherPaymentScreen extends StatefulWidget {
  const MakeTeacherPaymentScreen({Key? key}) : super(key: key);

  @override
  _MakeTeacherPaymentScreenState createState() =>
      _MakeTeacherPaymentScreenState();
}

class _MakeTeacherPaymentScreenState extends State<MakeTeacherPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentSearchController = TextEditingController();
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final List<Map<String, dynamic>> _paymentPurposes = [];
  TeacherPaymentsPurposes? _selectedPaymentPurpose;
  double? _paymentAmount;
  Teachers? _selectedStudent;
  DateTime _paymentDate = DateTime.now();
  String? _paymentInfo;
  String? _phoneNumber;

  Future<Box<TeacherPaymentsPurposes>> _openPaymentPurposeBox() async {
    return await Hive.openBox<TeacherPaymentsPurposes>(
        'teacher_payments_purposes');
  }

  Future<List<TeacherPaymentsPurposes>> _fetchPaymentPurposesByTermId(
      String globalTermId) async {
    final paymentPurposeBox =
        await _openPaymentPurposeBox(); // Assuming this opens the box
    return paymentPurposeBox.values
        .where((purpose) => purpose.termId == globalTermId)
        .toList();
  }

  Future<List<TeacherPaymentsPurposes>>
      _getPaymentPurposesForGlobalTerm() async {
    final Box<TeacherPaymentsPurposes> box =
        await Hive.openBox<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');

    // Filter payment purposes based on termId == globalTermId
    final List<TeacherPaymentsPurposes> filteredPaymentPurposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();

    return filteredPaymentPurposes;
  }

  void _searchStudent() {
    final query = _studentSearchController.text.trim();

    if (query.isEmpty) {
      _showSnackBar('Please enter a surname to search');
      return;
    }

    final studentBox = Hive.box<Teachers>('teachers');
    final matchingStudents = studentBox.values
        .where((student) =>
            student.surname.toLowerCase().contains(query.toLowerCase()) &&
            student.terms!.contains(globalTermId))
        .toList();

    if (matchingStudents.isEmpty) {
      _showSnackBar('No matching Staff found');
    } else {
      _displayStudentSelectionDialog(matchingStudents);
    }
  }

  void _displayStudentSelectionDialog(List<Teachers> teachers) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a Staff'),
          content: SizedBox(
            height: 200,
            width: 200,
            child: ListView.builder(
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final student = teachers[index];
                return ListTile(
                  title: Text('${student.name} ${student.surname}'),
                  onTap: () {
                    setState(() {
                      _selectedStudent = student;
                    });
                    Navigator.pop(context); // Close the dialog
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _addPaymentPurpose() {
    if (_selectedPaymentPurpose == null ||
        _paymentAmount == null ||
        _paymentAmount! <= 0) {
      _showSnackBar('Please select a payment purpose and enter a valid amount');
      return;
    }

    setState(() {
      _paymentPurposes.add({
        'purpose': _selectedPaymentPurpose!,
        'amount': _paymentAmount!,
      });
      _selectedPaymentPurpose = null;
      _paymentAmount = null;
      _paymentAmountController.clear(); // Clear the text field
    });
  }

  void _confirmPayment() {
    if (_selectedStudent == null) {
      _showSnackBar('Please select a staff first');
      return;
    }

    if (_paymentPurposes.isEmpty) {
      _showSnackBar('Please add at least one payment purpose');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Staff: ${_selectedStudent!.name} ${_selectedStudent!.surname}'),
              DataTable(
                columns: const [
                  DataColumn(label: Text('Purpose')),
                  DataColumn(label: Text('Amount')),
                ],
                rows: _paymentPurposes.map((payment) {
                  return DataRow(
                    cells: [
                      DataCell(Text(payment['purpose'].paymentPurpose)),
                      DataCell(Text(payment['amount'].toString())),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _makePayment();
                Navigator.pop(context);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<TeacherPayment>('teacher_payments');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _makePayment() async {
    final paymentBox = Hive.box<TeacherPayment>('teacher_payments');
    final studentName = _selectedStudent!.name.toUpperCase();
    final studentSurname = _selectedStudent!.surname.toUpperCase();
    final phone = _selectedStudent!.phoneNumber;
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(_paymentDate);
    final allPaymentsInfo = _generatePaymentSummary(
        studentName, studentSurname, formattedDate, phone);

    for (var payment in _paymentPurposes) {
      final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
      final paymentAmount = payment['amount'];
      final newPkValue = uuid.v4();

      int newId = await getNextId();

      List<String> modifiedFields = [];
      modifiedFields.add('id');
      modifiedFields.add('receiptNumber');
      modifiedFields.add('studentName');
      modifiedFields.add('studentSurname');
      modifiedFields.add('studentClass');
      modifiedFields.add('phoneNumber');

      modifiedFields.add('paymentPurpose');
      modifiedFields.add('amountToPay');
      modifiedFields.add('paymentDate');
      modifiedFields.add('termId');

      final newPayment = TeacherPayment(
        id: newId,
        receiptNumber: newPkValue,
        studentName: studentName,
        studentSurname: studentSurname,
        studentClass:
            '${_selectedStudent!.IdNumber} (${_selectedStudent!.surname} ${_selectedStudent!.name}) ',
        phoneNumber: phone,
        paymentPurpose: paymentPurpose,
        amountToPay: paymentAmount,
        paymentDate: _paymentDate,
        termId: globalTermId,
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType: 'create', // Set operationType to 'create'
        modifiedFields: modifiedFields,
      );

      paymentBox.add(newPayment);
    }

    _showSnackBar('Staff payment Made SUCCESSFULLY.');
    _resetForm();
    _sendSmsNotification(allPaymentsInfo, phone);
  }

  String _generatePaymentSummary(String studentName, String studentSurname,
      String formattedDate, String? phone) {
    String summary = '';

    for (var payment in _paymentPurposes) {
      final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
      final paymentAmount = payment['amount'];

      summary +=
          'Dear  $studentName $studentSurname , a payment has been made to you of an AMOUNT \$ $paymentAmount for the PURPOSE OF $paymentPurpose on the DATE: $formattedDate.\n Kindly visit Admin for more info';
    }

    _paymentInfo = summary;
    _phoneNumber = phone.toString();
    return summary;
  }

  void _sendSmsNotification(String allPaymentsInfo, String? phone) {
    if (allPaymentsInfo.isEmpty) {
      _showSnackBar('No payment made yet');
      return;
    }
    launcher.launchUrl(Uri.parse(
        'sms:$phone${Platform.isAndroid ? '?' : '&'}body=$allPaymentsInfo'));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetForm() {
    _studentSearchController.clear();
    setState(() {
      _selectedStudent = null;
      _paymentPurposes.clear();
      _paymentDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (globalTermId != null) {
      return CenteredFormContainer(
        title: 'New Staff Payment',
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _studentSearchController,
                  decoration: InputDecoration(
                    labelText: 'Search Staff by Surname',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchStudent,
                    ),
                  ),
                ),
                if (_selectedStudent != null)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}'),
                          const SizedBox(height: 10),
                          const SizedBox(height: 10),
                          Text('Phone: ${_selectedStudent!.phoneNumber}'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (_selectedStudent != null) //
                  FutureBuilder<List<TeacherPaymentsPurposes>>(
                    future: _fetchPaymentPurposesByClass(globalTermId!,
                        '${_selectedStudent!.IdNumber} (${_selectedStudent!.surname} ${_selectedStudent!.name})'), // Fetch filtered data
                    builder: (context,
                        AsyncSnapshot<List<TeacherPaymentsPurposes>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text(
                            'No payment purposes found for the selected term.');
                      } else {
                        final paymentPurposes = snapshot.data!;
                        return Container(
                          color: const Color.fromARGB(255, 229, 230, 230),
                          child:
                              DropdownButtonFormField<TeacherPaymentsPurposes>(
                            decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none, // No border
                                ),
                                labelText: 'Select Payment Purpose'),
                            items: paymentPurposes.map((purpose) {
                              return DropdownMenuItem(
                                value: purpose,
                                child: Text(purpose.paymentPurpose),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPaymentPurpose = value;
                              });
                            },
                          ),
                        );
                      }
                    },
                  ),
                if (_selectedPaymentPurpose != null && _selectedStudent != null)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Purpose: ${_selectedPaymentPurpose?.paymentPurpose ?? ''}'),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  color: const Color.fromARGB(255, 229, 230, 230),
                  child: TextFormField(
                    controller: _paymentAmountController,
                    decoration:
                        const InputDecoration(labelText: 'Payment Amount'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _paymentAmount = double.tryParse(
                          value); // Update _paymentAmount for logic
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addPaymentPurpose,
                  child: const Text('Add Payment Purpose'),
                ),
                const SizedBox(height: 20),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Purpose')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: _paymentPurposes.map((payment) {
                    return DataRow(
                      cells: [
                        DataCell(Text(payment['purpose'].paymentPurpose)),
                        DataCell(Text(payment['amount'].toString())),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _confirmPayment,
                  child: const Text('Confirm Payment'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // If globalTermId is null, show an alternative UI or a message
      return Scaffold(
          appBar: AppBar(
            title: const Text('No Selected Term Found'),
          ),
          body: const Center(
            child: Text(
              'No term is currently active. Either switch to an existing term or create a new term to proceed.',
              style: TextStyle(
                fontSize: 16.0, // Set font size
                fontWeight: FontWeight.bold, // Set font weight
                color: Colors.redAccent, // Set text color
                letterSpacing: 1.2, // Set spacing between letters
                height: 1.5, // Set line height (space between lines)
              ),
              textAlign: TextAlign.center, // Align text to the center
            ),
          ));
    }
  }

  Future<List<TeacherPaymentsPurposes>> _fetchPaymentPurposesByClass(
      String termId, String class_) async {
    if (globalTermId == null) {
      return []; // Return an empty list if required fields are null
    }
    final paymentPurposeBox =
        await _openPaymentPurposeBox(); // Assuming this opens the box
    final allPaymentPurposes = paymentPurposeBox.values
        .where((purpose) => purpose.termId == globalTermId)
        .where((purpose) => purpose.associatedStaff?.contains(class_) ?? false)
        .toList();

    return allPaymentPurposes;
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
