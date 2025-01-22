import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:zitf_system/admin/home_screen1.dart';
import 'package:zitf_system/auth/crud_auth/secretary/secretary_home1.dart';
// ignore: unused_import
import 'package:zitf_system/auth/update_auth.dart'; // Import CRUD operations screen

class AdminPanelScreen1 extends StatelessWidget {
  const AdminPanelScreen1({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Secretary Panel',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        actions: [
          
          IconButton(
            icon: Icon(Icons.home, size: 30, color: Colors.blue), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen1()),
              );
            },
          ),
         
        ],
        backgroundColor: Color.fromARGB(255, 235, 247, 248),
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
                  'Welcome!',
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
                  icon: Icons.view_list,
                  text: 'Go To Secretary Account',
                  target:  SecretaryScreen1(),
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
        title: Text(text, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
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
