import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateTeacherPaymentPurposeScreen extends StatefulWidget {
  final TeacherPaymentsPurposes existingPurpose;

  const UpdateTeacherPaymentPurposeScreen(
      {super.key, required this.existingPurpose}); // Ensure the index is passed

  @override
  _UpdateTeacherPaymentPurposeScreenState createState() =>
      _UpdateTeacherPaymentPurposeScreenState();
}

class _UpdateTeacherPaymentPurposeScreenState
    extends State<UpdateTeacherPaymentPurposeScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _purposeController;
  late TextEditingController _amountController;
  List<String> _classes = [];
  late List<String> _selectedClasses;

  @override
  void initState() {
    super.initState();
    _purposeController =
        TextEditingController(text: widget.existingPurpose.paymentPurpose);
    _amountController = TextEditingController(
        text: widget.existingPurpose.purposeAmount.toString());
    // Ensure _selectedClasses is never null.
    _selectedClasses = widget.existingPurpose.associatedStaff != null
        ? List.from(widget.existingPurpose.associatedStaff as Iterable)
        : <String>[];

    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.box<Teachers>('teachers');
    final classes = box.values
        .where((classItem) =>
            classItem.termId != null && classItem.termId == globalTermId)
        .map((e) => '${e.IdNumber} (${e.surname} ${e.name})')
        .toList();

    setState(() {
      _classes = classes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Payment Purposes',
      child: Form(
        key: _formKey, // Key for form validation
        child: ListView(
          children: [
            _buildTextField('Purpose', _purposeController), // Input for purpose
            _buildAmountField(), // Input for amount
            const SizedBox(height: 20), // Add spacing
            _buildClassesList(),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _update,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                backgroundColor:
                    Color.fromARGB(255, 201, 197, 197), // Set text color
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
        fillColor: Colors.white, // Set background color
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label'; // Ensure input is not empty
        }
        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: 'Amount',
        filled: true, // Add background color
        fillColor: Colors.white, // Set background color
      ),
      keyboardType: TextInputType.number, // Allow only numeric input
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the amount'; // Ensure input is not empty
        }
        try {
          double.parse(value); // Ensure it's a valid number
        } catch (e) {
          return 'Amount must be a valid number'; // Handle invalid input
        }
        return null;
      },
    );
  }

  Widget _buildClassesList() {
    bool _selectAll = _selectedClasses.length == _classes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: (isChecked) {
                  setState(() {
                    if (isChecked == true) {
                      _selectedClasses = List.from(_classes);
                    } else {
                      _selectedClasses.clear();
                    }
                  });
                },
              ),
              const Text('Select All'),
            ],
          ),
          ..._classes.map((className) {
            return CheckboxListTile(
              title: Text(className),
              value: _selectedClasses.contains(className),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) {
                    _selectedClasses.add(className);
                  } else {
                    _selectedClasses.remove(className);
                  }
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _update() async {
    if (_formKey.currentState!.validate()) {
      final code = widget.existingPurpose.purposeCode;

      List<String> modifiedFields = widget.existingPurpose.modifiedFields ?? [];
// Append new modifications without overwriting

      if (widget.existingPurpose.paymentPurpose.toLowerCase() !=
          _purposeController.text.toLowerCase()) {
        if (!modifiedFields.contains('paymentPurpose')) {
          modifiedFields.add('paymentPurpose');
        }
      }

      if (widget.existingPurpose.purposeAmount !=
          double.parse(_amountController.text)) {
        if (!modifiedFields.contains('purposeAmount')) {
          modifiedFields.add('purposeAmount');
        }
      }

      if (!const DeepCollectionEquality()
          .equals(widget.existingPurpose.associatedStaff, _selectedClasses)) {
        if (!modifiedFields.contains('associatedStaff')) {
          modifiedFields.add('associatedStaff');
        }
      }
      final updatedPurpose = widget.existingPurpose.copyWith(
        paymentPurpose: _purposeController.text,
        purposeCode: code,
        purposeAmount: double.parse(_amountController.text),
        associatedStaff: _selectedClasses,
        syncStatus: false, // Mark for syncing
        lastModified: DateTime.now(), // Update last modified time
        operationType: 'update', // Mark operation as update
      );

      final box = await Hive.openBox<TeacherPaymentsPurposes>(
          'teacher_payments_purposes');
      final index = box.values
          .toList()
          .indexWhere((purpose) => purpose.id == widget.existingPurpose.id);

      if (index != -1) {
        box.putAt(index, updatedPurpose); // Update the record in Hive
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Purpose Updated Successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Purpose Not Found')),
        );
      }
    }
  }

  Future<void> _updateStudentPayments(
      String oldPurpose, String newPurpose) async {
    final Box<TeacherPayment> studentPaymentBox =
        Hive.box<TeacherPayment>('teacher_payments');

    final List<TeacherPayment> studentPayments = studentPaymentBox.values
        .where((payment) =>
            payment.termId == globalTermId &&
            payment.paymentPurpose.toLowerCase() == oldPurpose.toLowerCase())
        .toList();

    for (var payment in studentPayments) {
      final updatedPayment = payment.copyWith(
        paymentPurpose: newPurpose,
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'update',
        termId: globalTermId,
      );

      studentPaymentBox.put(payment.key, updatedPayment); // Update in Hive
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Staff Payments Updated Successfully')),
    );
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
