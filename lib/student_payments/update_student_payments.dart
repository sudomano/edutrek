import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class UpdatePaymentScreen extends StatefulWidget {
  const UpdatePaymentScreen({Key? key}) : super(key: key);

  @override
  _UpdatePaymentScreenState createState() => _UpdatePaymentScreenState();
}

class _UpdatePaymentScreenState extends State<UpdatePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentSearchController = TextEditingController();
  Student? _selectedStudent;
  StudentPayment? _selectedPayment;
  PaymentPurpose? _selectedPaymentPurpose;
  double? _paymentAmount;
  String? _receiptNumber;
  DateTime _paymentDate = DateTime.now();
  List<StudentPayment> _studentPayments = [];

  void _searchStudent() {
    final query = _studentSearchController.text.trim();

    if (query.isEmpty) {
      _showDialog('Please enter a surname to search');
      return;
    }

    final studentBox = Hive.box<Student>('students');
    final matchingStudents = studentBox.values
        .where((student) =>
            student.surname.toLowerCase().contains(query.toLowerCase()) &&
            student.terms!.contains(globalTermId!))
        .toList();

    if (matchingStudents.isEmpty) {
      _showDialog('No matching payments found for that student');
    } else {
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
                        _getStudentPayments();
                      });
                      _showDialog(
                        'Selected student: ${student.name} ${student.surname}',
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
  }

  // Fetch payments for the selected student
  void _getStudentPayments() {
    if (_selectedStudent == null) return;

    final paymentBox = Hive.box<StudentPayment>('student_payments');
    setState(() {
      _studentPayments = paymentBox.values
          .where((payment) =>
              payment.studentName.toLowerCase() ==
                  _selectedStudent!.name.toLowerCase() &&
              payment.studentSurname.toLowerCase() ==
                  _selectedStudent!.surname.toLowerCase() &&
              payment.termId == globalTermId)
          .toList();
    });
  }

  Future<void> _updatePayment(StudentPayment payment) async {
    if (_selectedPayment == null) {
      _showDialog('Please select a payment to update');
      return;
    }

    if (_selectedPaymentPurpose == null) {
      _showDialog('Please select a payment purpose');
      return;
    }

    if (_paymentAmount == null || _paymentAmount! <= 0) {
      _showDialog('Please enter a valid payment amount');
      return;
    }

    final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

    List<String> modifiedFields = payment.modifiedFields ??
        []; // Initialize with existing modified fields

// Append new modifications without overwriting
    if (payment.receiptNumber != _receiptNumber) {
      if (!modifiedFields.contains('receiptNumber')) {
        modifiedFields.add('receiptNumber');
      }
    }

    if (payment.paymentPurpose.toLowerCase() !=
        _selectedPaymentPurpose!.paymentPurpose.toLowerCase()) {
      if (!modifiedFields.contains('paymentPurpose')) {
        modifiedFields.add('paymentPurpose');
      }
    }

    if (payment.amountToPay != _paymentAmount) {
      if (!modifiedFields.contains('amountToPay')) {
        modifiedFields.add('amountToPay');
      }
    }

    if (payment.paymentDate != _paymentDate) {
      if (!modifiedFields.contains('paymentDate')) {
        modifiedFields.add('paymentDate');
      }
    }

    if (payment.termId != globalTermId) {
      if (!modifiedFields.contains('termId')) {
        modifiedFields.add('termId');
      }
    }

    final updatedPayment = payment.copyWith(
      paymentPurpose: _selectedPaymentPurpose!.paymentPurpose,
      receiptNumber: _receiptNumber,
      amountToPay: _paymentAmount!,
      paymentDate: _paymentDate,
      termId: globalTermId,
      syncStatus: false,
      lastModified: DateTime.now(),
      operationType: 'update',
      modifiedFields: modifiedFields,
    );

    if (payment.key != null) {
      paymentBox.put(
          payment.key, updatedPayment); // Use 'put' instead of 'putAt'
    } else {
      paymentBox.add(updatedPayment);
    }

    _showDialog('Payment updated successfully');

    Navigator.pop(context);
    Navigator.pop(context);
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Update  Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(StudentPayment payment) {
    _selectedPayment = payment;

    _selectedPaymentPurpose = Hive.box<PaymentPurpose>('payment_purposes')
        .values
        .firstWhere(
            (purpose) =>
                purpose.paymentPurpose.toLowerCase() ==
                    payment.paymentPurpose.toLowerCase() &&
                purpose.termId == globalTermId,
            orElse: () => PaymentPurpose(
                paymentPurpose: '',
                termId: globalTermId,
                id: -1,
                purposeAmount: -1));
    _paymentAmount = payment.amountToPay;
    _paymentDate = payment.paymentDate;
    _receiptNumber = payment.receiptNumber;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Payment'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(
                    'Purpose: ${_selectedPaymentPurpose?.paymentPurpose.toUpperCase() ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextFormField(
                  initialValue: _paymentAmount?.toString(),
                  decoration:
                      const InputDecoration(labelText: 'Payment Amount'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _paymentAmount = double.tryParse(value);
                  },
                ),
                ListTile(
                  title: const Text('Payment Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_paymentDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _paymentDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          _paymentDate = selectedDate;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  _updatePayment(payment);
                }
              },
              child: const Text('Update Payment'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Update Student Payment'),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(255, 255, 255, 1),
                Color.fromARGB(255, 231, 240, 239)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _studentSearchController,
                decoration: InputDecoration(
                  labelText: 'Search Student by Surname',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchStudent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _studentPayments.length,
                  itemBuilder: (context, index) {
                    final payment = _studentPayments[index];
                    return ListTile(
                      title: Text(
                          'Payment for ${payment.paymentPurpose} - ${payment.amountToPay}'),
                      subtitle: Text(
                          'Date: ${DateFormat('yyyy-MM-dd').format(payment.paymentDate)}'),
                      onTap: () {
                        _showUpdateDialog(payment);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }
}
