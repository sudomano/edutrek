import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'delete_payment_purpose_screen.dart'; // Interface for deleting a payment purpose

class SelectPaymentPurposeToDelete extends StatelessWidget {
  const SelectPaymentPurposeToDelete({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<PaymentPurpose> box = Hive.box('payment_purposes');
    final List<PaymentPurpose> filteredPaymentPurposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();

    // Access the Hive box

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Payment Purpose to Delete'),
        backgroundColor:
            Color.fromARGB(255, 255, 255, 255), // Set app bar background color
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255)
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
                  paymentPurpose!.paymentPurpose,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ), // Display the payment purpose
                subtitle: Text('Amount: \$${paymentPurpose.purposeAmount}'),
                trailing: const Icon(Icons.delete,
                    color: Colors.red), // Icon for delete action
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeletePaymentPurposeScreen(
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
