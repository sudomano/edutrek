// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/admin/purpose_home_screen.dart';
import 'package:zitf_system/auth/crud_auth/crud_auth_home.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/classes/classes_home.dart';
import 'package:zitf_system/export_import_backup_data/export_import_home.dart';
import 'package:zitf_system/flutter_codes_for_a_restful_api/data_sync/classes_final.dart';
import 'package:zitf_system/registers/registershome.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/logout_confirmations/logout_confirmation.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/revenues/accounts_vs_incomes_home.dart';
import 'package:zitf_system/school_info/school_home.dart';
import 'package:zitf_system/student_management/create_students/student_home.dart';
import 'package:zitf_system/teachers/teachers_creations/create_teachers_Home/teachers_options.dart';
import 'package:zitf_system/terms/manage_terms.dart';
import 'package:zitf_system/welcome/welcome_admin.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }

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
    final administration = loggedInUser.role.toLowerCase() == 'administration';

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            '${loggedInUser.username.toUpperCase()} : HOME',
            style: const TextStyle(
              fontSize: 14.0, // Adjust font size
              fontWeight: FontWeight.normal, // Font weight
              color: Colors.white, // Title color
              letterSpacing: 1.2, // Slight letter spacing for elegance
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit,
                color: const Color.fromARGB(255, 255, 255, 255)), // Home button
            // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdminPanelScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.home,
                size: 30,
                color: Color.fromARGB(255, 255, 255, 255)), // Home button
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WelcomePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app,
                color: const Color.fromARGB(255, 255, 255, 255)), // Home button
            // Logout button
            onPressed: () {
              showLogoutConfirmationDialog(context);
            },
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0, // Subtle shadow
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return Row(
          children: [
            if (constraints.maxWidth >= 500)
              SizedBox(
                width: 190,
                child: CustomDrawerAdmin(loggedInUser: loggedInUser),
              ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isLargeScreen = constraints.maxWidth >= 500;
                        // Adjust crossAxisCount based on screen width
                        int crossAxisCount = 2; // Default 2 items per row
                        double crossAxisSpacing = 16.0;

                        if (constraints.maxWidth >= 1200) {
                          crossAxisCount = 6;
                        } else if (constraints.maxWidth >= 1000) {
                          crossAxisCount = 5;
                        } else if (constraints.maxWidth >= 800) {
                          crossAxisCount = 4;
                        } else if (constraints.maxWidth >= 600) {
                          crossAxisCount = 4;
                        } else if (constraints.maxWidth >= 400) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 300) {
                          crossAxisCount = 2;
                        } else {
                          crossAxisCount = 1;
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: isLargeScreen
                                ? const Color.fromRGBO(255, 255, 255, 1)
                                : null, // Set white background for large screens
                            gradient: isLargeScreen
                                ? const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(255, 255, 255, 1),
                                      Color.fromARGB(255, 255, 255, 255)
                                    ], // Gradient colors for small screens
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(255, 255, 255, 1),
                                      Color.fromARGB(255, 255, 255, 255)
                                    ], // Gradient colors for small screens
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  buildFutureSchoolsWidget(
                                      isLargeScreen: isLargeScreen),
                                  isLargeScreen
                                      ? GridView.count(
                                          crossAxisCount: crossAxisCount,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          crossAxisSpacing: crossAxisSpacing,
                                          padding: const EdgeInsets.all(8),
                                          children: [
                                            if (admin || administration)
                                              const ElevatedCard(
                                                icon: Icons.info,
                                                text: 'School Information',
                                                target: SchoolHomeScreen(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.date_range,
                                                text: 'Manage Terms',
                                                target: ManageTermsScreen(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.class_,
                                                text: 'School Classes',
                                                target: ClassesHomeScreen(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.school,
                                                text: 'School Students',
                                                target: CreateStudents(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                teacher)
                                              const ElevatedCard(
                                                icon: Icons.payment,
                                                text: 'Student Payments',
                                                target: PurposeHome(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin ||
                                                secretary)
                                              const ElevatedCard(
                                                icon: Icons.work_outline,
                                                text: 'School Staff',
                                                target: CreateTeachersoption(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                accountant)
                                              const ElevatedCard(
                                                icon: Icons
                                                    .account_balance_wallet,
                                                text: 'Incomes',
                                                // target: AccountsVsIncomesHome(),
                                                target: AccountsVsIncomesHome(),

                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                teacher ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.fact_check,
                                                text: 'Registers',
                                                target: RegistersHomeScreen(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.sync,
                                                text: 'Data Sync',
                                                target: ClassesFinal(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin ||
                                                secretary)
                                              const ElevatedCard(
                                                icon: Icons.sync,
                                                text: 'Data Backup',
                                                target: ExportImportHome(),
                                                isLargeScreen:
                                                    true, // Passing the large screen flag
                                              ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            if (admin || administration)
                                              const ElevatedCard(
                                                icon: Icons.info,
                                                text: 'School Information',
                                                target: SchoolHomeScreen(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.date_range,
                                                text: 'Manage Terms',
                                                target: ManageTermsScreen(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.class_,
                                                text: 'School Classes',
                                                target: ClassesHomeScreen(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.school,
                                                text: 'School Students',
                                                target: CreateStudents(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                teacher)
                                              const ElevatedCard(
                                                icon: Icons.payment,
                                                text: 'Student Payments',
                                                target: PurposeHome(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.work_outline,
                                                text: 'School Staff',
                                                target: CreateTeachersoption(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                accountant)
                                              const ElevatedCard(
                                                icon: Icons
                                                    .account_balance_wallet,
                                                text: 'Incomes',
                                                target: AccountsVsIncomesHome(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                teacher)
                                              const ElevatedCard(
                                                icon: Icons.fact_check,
                                                text: 'Registers',
                                                target: RegistersHomeScreen(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.backup,
                                                text: 'Data Synchronization',
                                                target: ClassesFinal(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin ||
                                                secretary)
                                              const ElevatedCard(
                                                icon: Icons.sync_lock_outlined,
                                                text: 'Data Backup',
                                                target: ExportImportHome(),
                                                isLargeScreen:
                                                    false, // Passing the large screen flag
                                              ),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }
}
