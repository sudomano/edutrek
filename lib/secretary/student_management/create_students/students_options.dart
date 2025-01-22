import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:zitf_system/admin/home_screen1.dart';
import 'package:zitf_system/admin/purpose_home_screen1.dart';
import 'package:zitf_system/secretary/classes/classes_home.dart';
import 'package:zitf_system/secretary/registers/registershome.dart';
import 'package:zitf_system/secretary/student_management/create_students/create_student.dart';
import 'package:zitf_system/student_management/student_filter.dart';
import 'package:zitf_system/terms/term_switcher1.dart';

class CreateStudentsoption1 extends StatelessWidget {
  const CreateStudentsoption1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Students',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center, // Custom font
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home,
                size: 30, color: Colors.blue), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen1()),
              );
            },
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 244, 252, 253),
      ),
      //************* */
      // Add the drawer (sidebar)
      drawer: Drawer(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 300, // Maximum width for the drawer
          ),
          child: IntrinsicWidth(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 100, // Adjust the height to your preference
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

                /*_buildDrawerItem(
                  context,
                  icon: Icons.update,
                  text: 'Notifications',
                  target: const UpdateStudentScreen(),
                ),*/
              ],
            ),
          ),
        ),
      ),
//****** */
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
                  ' Students Options',
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
                  text: 'Go To Students',
                  target: const CreateStudents11(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.people,
                  text: 'Filter Search Students',
                  target: ViewStudentsScreenfilter(),
                ),

                _buildElevatedCard(
                  context,
                  icon: Icons.payment,
                  text: 'Go to Home Page',
                  target: const HomeScreen1(),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => target),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
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
}
//********* */