import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'update_payment_purpose_screen.dart'; // Interface to update a payment purpose

class SelectPaymentPurposeToUpdate extends StatelessWidget {
  const SelectPaymentPurposeToUpdate({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<PaymentPurpose>('payment_purposes');

    // Assuming globalTermId is available

    // Filter payment purposes by globalTermId
    final List<PaymentPurpose> filteredPaymentPurposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Select Purpose to Update '),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            itemCount:
                filteredPaymentPurposes.length, // Use filtered list length
            itemBuilder: (context, index) {
              final paymentPurpose =
                  filteredPaymentPurposes[index]; // Retrieve the filtered item

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(paymentPurpose
                      .paymentPurpose), // Display the payment purpose
                  subtitle: Text(
                      'Amount: ${paymentPurpose.purposeAmount}'), // Display the amount
                  trailing: const Icon(Icons.edit), // Icon for edit action
                  onTap: () {
                    final paymentPurpose = filteredPaymentPurposes[
                        index]; // Retrieve the selected PaymentPurpose

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpdatePaymentPurposeScreen(
                          existingPurpose:
                              paymentPurpose, // Pass the PaymentPurpose object
                        ),
                      ),
                    ); // Navigate to the update screen with the selected PaymentPurpose
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
