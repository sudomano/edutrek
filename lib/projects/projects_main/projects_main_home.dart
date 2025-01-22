import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:hive/hive.dart';

import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/all_payments/payment_purpose/add_payment_purpose.dart';
import 'package:zitf_system/all_payments/payment_purpose/delete_complete.dart';
import 'package:zitf_system/all_payments/payment_purpose/delete_payment_purpose.dart';
import 'package:zitf_system/all_payments/payment_purpose/update_payment_purpose.dart';
import 'package:zitf_system/all_payments/payment_purpose/view_payment_purpose.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/projects/projects_main/create_project.dart';
import 'package:zitf_system/projects/projects_main/delete_projects.dart';
import 'package:zitf_system/projects/projects_main/update_projects.dart';
import 'package:zitf_system/projects/projects_main/view_projects.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';

class ProjectsMainHome extends StatefulWidget {
  const ProjectsMainHome({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<ProjectsMainHome> {
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
    final admin = loggedInUser?.role.toLowerCase() == 'admin';
    final secretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser?.role.toLowerCase() == 'teacher';

    final accountant = loggedInUser?.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser?.role.toLowerCase() == 'sub-admin';
    return Scaffold(
      appBar: const CustomAppBar(title: 'Projects'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth >= 600;
          // Adjust crossAxisCount based on screen width
          int crossAxisCount = 2; // Default 2 items per row
          double crossAxisSpacing = 16.0;

          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 4;
            crossAxisSpacing = 10.0;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 4;
            crossAxisSpacing = 1.0;
          } else if (constraints.maxWidth >= 600) {
            crossAxisCount = 3;
            crossAxisSpacing = 4.0;
          } else {
            crossAxisCount = 1;
            crossAxisSpacing = 2.0;
          }
          return Container(
            decoration: BoxDecoration(
              color: isLargeScreen
                  ? const Color.fromRGBO(0, 233, 254, 1)
                  : null, // Set white background for large screens
              gradient: isLargeScreen
                  ? null
                  : const LinearGradient(
                      colors: [
                        Color.fromRGBO(0, 233, 254, 1),
                        Color.fromARGB(255, 1, 80, 71)
                      ], // Gradient colors for small screens
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 5,
                    ),
                    buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      'Main Projets',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.normal,
                        color: const Color.fromARGB(
                            255, 0, 0, 0), // White text on gradient
                      ),
                      textAlign: TextAlign.center,
                    ),
                    isLargeScreen
                        ? GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: crossAxisSpacing,
                            padding: const EdgeInsets.all(8),
                            children: [
                              //if (admin || secretary || subadmin)

                              // Elevated cards with icons
                              const ElevatedCard(
                                icon: Icons.view_comfortable_outlined,
                                text: 'View Projects',
                                target: ViewProjects(),
                                isLargeScreen: true,
                              ),
                              //if (admin || secretary || subadmin)
                              ElevatedCard(
                                icon: Icons.create_new_folder_outlined,
                                text: 'Create Projects',
                                target: CreateProjectForm(),
                                isLargeScreen: true,
                              ),
                              // if (admin || subadmin)
                              _buildElevatedCardWithDialog(
                                context,
                                icon: Icons.update,
                                text: 'Update Projects',
                                isLargeScreen:
                                    true, // Flag to check screen size
                              ),

                              // if (admin || subadmin)
                              const ElevatedCard(
                                icon: Icons.delete,
                                text: 'Delete Projects',
                                target: DeleteProjects(),
                                isLargeScreen: true,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              // Elevated cards with icons
                              const ElevatedCard(
                                icon: Icons.view_comfortable_outlined,
                                text: 'View Projects',
                                target: ViewProjects(),
                                isLargeScreen: false,
                              ),
                              //if (admin || secretary || subadmin)
                              ElevatedCard(
                                icon: Icons.create_new_folder_outlined,
                                text: 'Create Projects',
                                target: CreateProjectForm(),
                                isLargeScreen: false,
                              ),
                              _buildElevatedCardWithDialog(
                                context,
                                icon: Icons.update,
                                text: 'Update Projects',
                                isLargeScreen:
                                    false, // Flag to check screen size
                              ),
                              if (admin || subadmin)
                                const ElevatedCard(
                                  icon: Icons.delete,
                                  text: 'Delete Projects',
                                  target: DeleteProjects(),
                                  isLargeScreen: false,
                                ),
                            ],
                          )
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }
}

Widget _buildElevatedCardWithDialog(
  BuildContext context, {
  required IconData icon,
  required String text,
  bool isLargeScreen = false, // Flag to check screen size
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
      child: Card(
        elevation: 4.0,
        color: isLargeScreen
            ? Colors.white
            : Colors.blueGrey[50], // Background color for large screens
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () async {
            final Box<Project> box = Hive.box<Project>('projects');
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(
                    'Select Project to Update',
                    style: GoogleFonts.montserrat(
                        fontSize: isLargeScreen ? 18 : 20,
                        fontWeight: FontWeight.bold),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: box.length,
                      itemBuilder: (context, index) {
                        final currentClass = box.getAt(index);
                        return ListTile(
                          title: Text(
                            currentClass!.name.toString(),
                            style: GoogleFonts.montserrat(
                              fontSize: isLargeScreen ? 14 : 16,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UpdateProjects(index: index),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            constraints: isLargeScreen
                ? const BoxConstraints(minWidth: 400, maxWidth: 400)
                : null,
            padding: const EdgeInsets.all(16.0),
            child: isLargeScreen
                // For large screens, icon above the text
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 30, // Larger icon size for large screens
                        color: Colors.blue.shade800,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                // For smaller screens, icon next to the text
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 30,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
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
