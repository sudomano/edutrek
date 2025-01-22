import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart'; // Import globalTermId

class DeletePaymentPurposeScreen extends StatelessWidget {
  final int index; // Index of the payment purpose to delete

  const DeletePaymentPurposeScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Payment Purpose')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Are you sure you want to delete this payment purpose?'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final Box<PaymentPurpose> box = Hive.box('payment_purposes');
                final List<PaymentPurpose> filteredPaymentPurposes = box.values
                    .where((paymentPurpose) =>
                        paymentPurpose.termId == globalTermId)
                    .toList();

                // Get the payment purpose to delete
                final paymentPurpose = filteredPaymentPurposes.isNotEmpty
                    ? filteredPaymentPurposes[index]
                    : null;

                if (paymentPurpose != null &&
                    paymentPurpose.termId == globalTermId) {
                  // Delete the payment purpose from the Hive box
                  await box.deleteAt(index);

                  // Delete related student payments where termId == globalTermId and paymentPurpose matches
                  await _deleteStudentPayments(
                      context, paymentPurpose.paymentPurpose);

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Payment Purpose Deleted Successfully')),
                  );

                  // Return to the previous screen
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Payment Purpose not found or invalid')),
                  );
                }
              },
              child: const Text('Confirm Deletion'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cancel deletion and go back
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStudentPayments(
      BuildContext context, String paymentPurpose) async {
    final Box<StudentPayment> studentPaymentBox = Hive.box('student_payments');

    // Filter the StudentPayment records where termId matches globalTermId and paymentPurpose matches
    final List<int> keysToDelete = studentPaymentBox.keys.cast<int>().where(
      (key) {
        final payment = studentPaymentBox.get(key);
        return payment?.termId == globalTermId &&
            payment?.paymentPurpose == paymentPurpose;
      },
    ).toList();

    // Delete all matching records
    for (var key in keysToDelete) {
      await studentPaymentBox.delete(key);
    }

    // Notify the user about the deletions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Related Student Payments Deleted')),
    );
    Navigator.pop(context);
    Navigator.pop(context);
  }
}
