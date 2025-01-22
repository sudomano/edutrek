import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'delete_payment_purpose_screen.dart'; // Interface for deleting a payment purpose

class SelectTeacherPaymentPurposeToDelete extends StatelessWidget {
  const SelectTeacherPaymentPurposeToDelete({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<TeacherPaymentsPurposes> box =
        Hive.box('teacher_payments_purposes');
    final List<TeacherPaymentsPurposes> filteredPaymentPurposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();
    // Access the Hive box

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Staff Payment Purpose to Delete'),
        backgroundColor:
            Color.fromARGB(255, 255, 255, 255), // Set app bar background color
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 255, 255, 255),
              const Color.fromARGB(255, 255, 255, 255)
            ],
          ),
        ),
        child: ListView.builder(
          itemCount:
              filteredPaymentPurposes.length, // Number of payment purposes
          itemBuilder: (context, index) {
            final paymentPurpose =
                filteredPaymentPurposes[index]; // Retrieve the item

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  paymentPurpose.paymentPurpose,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ), // Display the payment purpose
                subtitle: Text('Amount: \$${paymentPurpose.purposeAmount}'),
                trailing: const Icon(Icons.delete,
                    color: Colors.red), // Icon for delete action
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeleteTeacherPaymentPurposeScreen(
                          index: index), // Pass the index
                    ),
                  ); // Navigate to delete screen with the selected index
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
