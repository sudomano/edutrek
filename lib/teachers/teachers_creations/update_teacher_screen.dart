import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/teachers/teachers_creations/update_teacher.dart';

class SelectstaffPaymentPurposeToUpdate extends StatelessWidget {
  const SelectstaffPaymentPurposeToUpdate({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<Teachers> box = Hive.box('teachers'); // Access the Hive box

    // Assuming globalTermId is available

    // Filter payment purposes by globalTermId
    final List<Teachers> filteredPaymentPurposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Select Staff to Update '),
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
                  title: Text(
                      paymentPurpose.IdNumber), // Display the payment purpose
                  subtitle: Text(
                      ' ${paymentPurpose.surname} ${paymentPurpose.name}'), // Display the amount
                  trailing: const Icon(Icons.edit), // Icon for edit action
                  onTap: () {
                    final paymentPurpose = filteredPaymentPurposes[
                        index]; // Retrieve the selected PaymentPurpose

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpdateTeacherScreen(
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
