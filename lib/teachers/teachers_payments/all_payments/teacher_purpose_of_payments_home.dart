import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts

import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/all_payments/payment_purpose/add_payment_purpose.dart';
import 'package:zitf_system/all_payments/payment_purpose/delete_payment_purpose.dart';
import 'package:zitf_system/all_payments/payment_purpose/update_payment_purpose.dart';
import 'package:zitf_system/all_payments/payment_purpose/view_payment_purpose.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class Createpayments extends StatelessWidget {
  const Createpayments({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Staff payments'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(0, 233, 254, 1),
              Color.fromARGB(255, 1, 80, 71)
            ], // Gradient colors
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Teacher Payment Purposes',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text on gradient
                  ),
                ),
                const SizedBox(height: 16),
                // Elevated cards with icons
                _buildElevatedCard(
                  context,
                  icon: Icons.person_add,
                  text: 'Create New Payment Purpose',
                  target: const AddPaymentPurposeScreen(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.people,
                  text: 'View All Payment Purposes',
                  target: const ViewPaymentPurposesScreen(),
                ),

                _buildElevatedCard(
                  context,
                  icon: Icons.update,
                  text: 'Update Payment Purpose',
                  target: const SelectPaymentPurposeToUpdate(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.delete,
                  text: 'Delete Payment Purpose',
                  target: const SelectPaymentPurposeToDelete(),
                ),

                _buildElevatedCard(
                  context,
                  icon: Icons.payment,
                  text: 'Go to Home Page',
                  target: const HomeScreen(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElevatedCard(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Widget target,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(text,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => target),
          );
        },
      ),
    );
  }
}
