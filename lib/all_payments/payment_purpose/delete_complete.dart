import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class DeletePaymentPurposeScreens extends StatefulWidget {
  const DeletePaymentPurposeScreens({super.key});

  @override
  _DeletePaymentPurposeScreenState createState() =>
      _DeletePaymentPurposeScreenState();
}

class _DeletePaymentPurposeScreenState
    extends State<DeletePaymentPurposeScreens> {
  List<PaymentPurpose> _paymentPurposes = []; // List to hold payment purposes
  List<PaymentPurpose> _selectedPurposes =
      []; // List of selected purposes for deletion

  @override
  void initState() {
    super.initState();
    _fetchPaymentPurposes(); // Fetch payment purposes when screen loads
  }

  Future<void> _fetchPaymentPurposes() async {
    final box = await Hive.box<PaymentPurpose>('payment_purposes');
    final purposes = box.values
        .where((purpose) =>
            purpose.termId == globalTermId) // Filter by globalTermId
        .toList();

    setState(() {
      _paymentPurposes = purposes;
    });
  }

  Future<void> _deleteStudentPayments(String paymentPurpose) async {
    final Box<StudentPayment> studentPaymentBox = Hive.box('student_payments');

    // Filter the StudentPayment records where termId matches globalTermId and paymentPurpose matches
    final List<int> keysToDelete = studentPaymentBox.keys.cast<int>().where(
      (key) {
        final payment = studentPaymentBox.get(key);
        return payment?.termId == globalTermId &&
            payment?.paymentPurpose.toLowerCase() ==
                paymentPurpose.toLowerCase();
      },
    ).toList();

    // Delete all matching records
    for (var key in keysToDelete) {
      await studentPaymentBox.delete(key);
    }
  }

  Future<void> _deleteSelectedPurposes() async {
    if (_selectedPurposes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Payment Purpose Selected')),
      );
      return;
    }

    final paymentPurposeBox =
        await Hive.box<PaymentPurpose>('payment_purposes');

    // Delete related student payments for each selected payment purpose
    for (var paymentPurpose in _selectedPurposes) {
      await _deleteStudentPayments(
          paymentPurpose.paymentPurpose); // Delete related student payments
    }

    // Delete the selected payment purposes from the Hive box
    for (var purpose in _selectedPurposes) {
      await paymentPurposeBox.delete(purpose.key);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Selected Payment Purposes and Related Records Deleted')),
    );

    // Refresh the list of payment purposes after deletion
    _fetchPaymentPurposes();
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Delete Payment Purpose',
      child: ListView(
        children: [
          ..._paymentPurposes.map((paymentPurpose) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  title: Text(
                    paymentPurpose.paymentPurpose,
                    style: const TextStyle(
                      fontSize: 14.0,
                      color: Colors.black87,
                    ),
                  ),
                  value: _selectedPurposes.contains(paymentPurpose),
                  onChanged: (isChecked) {
                    setState(() {
                      if (isChecked == true) {
                        _selectedPurposes.add(paymentPurpose);
                      } else {
                        _selectedPurposes.remove(paymentPurpose);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _deleteSelectedPurposes,
            child: const Text('Delete Selected Payment Purposes'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
