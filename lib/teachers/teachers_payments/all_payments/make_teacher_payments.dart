import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/student_payments/delete_paid_student.dart';
import 'package:zitf_system/student_payments/make_student_payment.dart';
import 'package:zitf_system/student_payments/search_paid_student.dart';
import 'package:zitf_system/student_payments/update_student_payments.dart';
import 'package:zitf_system/student_payments/view_all_paid_students.dart';

class MakePayment extends StatelessWidget {
  const MakePayment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Teachers Payments Home Page',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center, // Custom font
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home,
                size: 30, color: Colors.blue), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app), // Logout button
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false); // Clear login state

              Navigator.pushReplacementNamed(
                  context, '/login'); // Redirect to login
            },
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 234, 247, 249),
      ),
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
                  'Manage Teachers Payments',
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
                  text: 'New Student Payment',
                  target: const MakePaymentScreen(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.people,
                  text: 'View All Paid Student',
                  target: const ViewAllStudentPayments(),
                ),

                _buildElevatedCard(
                  context,
                  icon: Icons.update,
                  text: 'Update Student Payments',
                  target: const UpdatePaymentScreen(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.delete,
                  text: 'Delete Student Payment',
                  target: const DeletePaidStudentBySurname(),
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
