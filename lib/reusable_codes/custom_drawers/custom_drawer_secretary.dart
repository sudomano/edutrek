import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/admin/purpose_home_screen1.dart';

import 'package:zitf_system/secretary/classes/classes_home.dart';
import 'package:zitf_system/secretary/registers/registershome.dart';
import 'package:zitf_system/secretary/student_management/create_students/students_options.dart';
import 'package:zitf_system/terms/term_switcher1.dart';

// Import your screens here

class CustomDrawerSecretary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 300,
        ),
        child: IntrinsicWidth(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 100,
                child: DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(1, 120, 131, 1),
                  ),
                  child: Center(
                    child: Text(
                      'Secretary Menu',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.date_range, // School terms
                text: 'School Terms',
                target: TermSwitcher1(),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.class_, // School classes
                text: 'School Classes',
                target: const ClassesHomeScreen1(),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.school, // School students
                text: 'School Students',
                target: CreateStudentsoption1(),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.payment, // Student payment purposes
                text: 'Student Payment Purposes',
                target: const PurposeHome1(),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.fact_check, // Registers
                text: 'Registers',
                target: RegistersHomeScreen1(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //****** */
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Widget target,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        text,
        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => target),
        );
      },
    );
  }
//********* */
}
