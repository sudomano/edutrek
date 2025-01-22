import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class DeleteTeacherPaymentPurposeScreen extends StatelessWidget {
  final int index; // Index of the payment purpose to delete

  const DeleteTeacherPaymentPurposeScreen(
      {super.key, required this.index}); // Ensure the index is passed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Staff Payment Purpose')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Are you sure you want to delete this payment purpose?'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final Box<TeacherPaymentsPurposes> box =
                    Hive.box('teacher_payments_purposes');
                final List<TeacherPaymentsPurposes> filteredPaymentPurposes =
                    box.values
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
                  box.deleteAt(index);

                  // Delete related student payments where termId == globalTermId and paymentPurpose matches
                  _deleteStudentPayments(
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
    final Box<TeacherPayment> studentPaymentBox = Hive.box('teacher_payments');

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
      const SnackBar(content: Text('Related Staff Payments Deleted')),
    );
  }
}
