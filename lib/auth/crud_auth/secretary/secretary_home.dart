// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/auth/crud_auth/secretary/create_secretary.dart';
import 'package:zitf_system/auth/crud_auth/secretary/view_secretary.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class SecretaryScreen extends StatelessWidget {
  const SecretaryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final admin = loggedInUser.role.toLowerCase() == 'admin';
    final secretary = loggedInUser.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser.role.toLowerCase() == 'teacher';

    final accountant = loggedInUser.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser.role.toLowerCase() == 'sub-admin';
    return Scaffold(
      appBar: const CustomAppBar(title: 'Staff Panel'),
      body: Center(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(0, 233, 254, 1),
                Color.fromRGBO(0, 233, 254, 1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (admin || subadmin)
                      _buildElevatedCard(
                        context,
                        icon: Icons.add,
                        text: 'Create New Staff Account',
                        target: CreateSecretaryAccountScreen(),
                      ),
                    _buildElevatedCard(
                      context,
                      icon: Icons.view_list,
                      text: 'View Staff Accounts',
                      target: ViewSecretaryScreen(),
                    ),
                  ],
                ),
              ),
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
