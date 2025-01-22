import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/purpose_home_screen1.dart';
import 'package:zitf_system/auth/crud_auth/crud_auth_home1.dart';
import 'package:zitf_system/flutter_codes_for_a_restful_api/data_sync/class_post.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_secretary.dart';
import 'package:zitf_system/secretary/classes/classes_home.dart';
import 'package:zitf_system/secretary/student_management/create_students/students_options.dart';
import 'package:zitf_system/welcome/welcome_secretary.dart';

class HomeScreen1 extends StatelessWidget {
  const HomeScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Secretary Home',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminPanelScreen1()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.home,
                size: 30, color: Colors.blue), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WelcomePage1()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app), // Logout button
            onPressed: () {
              _showLogoutConfirmationDialog(context);
            },
          ),
        ],
        backgroundColor: Color.fromARGB(255, 235, 247, 248),
      ),
      //************* */
      // Add the drawer (sidebar)
      drawer: CustomDrawerSecretary(),

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16), // Set border radius
                  child: Image.asset(
                    'assets/assets/images/logo.png', // Example image
                    height: 200,
                    width: 400,
                    fit: BoxFit.cover,
                  ),
                ),
                // Logo or branding

                Text(
                  'Welcome, Secretary!',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text on gradient
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Elevated cards with icons
                _buildElevatedCard(
                  context,
                  icon: Icons.people,
                  text: 'Classes',
                  target: const ClassesHomeScreen1(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.person_add,
                  text: 'Students',
                  target: CreateStudentsoption1(),
                ),
                _buildElevatedCard(
                  context,
                  icon: Icons.attach_money,
                  text: 'Payments',
                  target: const PurposeHome1(),
                ),

                _buildElevatedCard(
                  context,
                  icon: Icons.delete,
                  text: 'Data Synchronization  ',
                  target: SyncClassesPages(),
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
//********* */

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout Confirmation'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false); // Clear login state

              Navigator.pushReplacementNamed(
                  context, '/login'); // Redirect to login
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
