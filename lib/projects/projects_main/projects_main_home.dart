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
    final administration = loggedInUser.role.toLowerCase() == 'administration';
    return Scaffold(
      appBar: const CustomAppBar(title: 'Projects'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (constraints.maxWidth >= 500)
                SizedBox(
                  width: 250,
                  child: CustomDrawerAdmin(loggedInUser: loggedInUser),
                ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        bool isLargeScreen = constraints.maxWidth >= 500;
                        // Adjust crossAxisCount based on screen width
                        int crossAxisCount = 2; // Default 2 items per row
                        double crossAxisSpacing = 16.0;

                        if (constraints.maxWidth >= 1200) {
                          crossAxisCount = 4;
                        } else if (constraints.maxWidth >= 1000) {
                          crossAxisCount = 4;
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
                                mainAxisAlignment: MainAxisAlignment.start,
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
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                accountant)
                                              ElevatedCard(
                                                icon: Icons
                                                    .create_new_folder_outlined,
                                                text: 'Create Projects',
                                                target: CreateProjectForm(),
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                accountant)
                                              const ElevatedCard(
                                                icon: Icons
                                                    .view_comfortable_outlined,
                                                text: 'View Projects',
                                                target: ViewProjects(),
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin)
                                              _buildElevatedCardWithDialog(
                                                context,
                                                icon: Icons.update,
                                                text: 'Update Projects',
                                                isLargeScreen:
                                                    true, // Flag to check screen size
                                              ),
                                            if (admin || administration)
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
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                accountant)
                                              ElevatedCard(
                                                icon: Icons
                                                    .create_new_folder_outlined,
                                                text: 'Create Projects',
                                                target: CreateProjectForm(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin ||
                                                accountant)
                                              const ElevatedCard(
                                                icon: Icons
                                                    .view_comfortable_outlined,
                                                text: 'View Projects',
                                                target: ViewProjects(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin)
                                              _buildElevatedCardWithDialog(
                                                context,
                                                icon: Icons.update,
                                                text: 'Update Projects',
                                                isLargeScreen:
                                                    false, // Flag to check screen size
                                              ),
                                            if (admin || administration)
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
                      }),
                    ),
                  ],
                ),
              ),
            ],
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
            final projects = box.values
                .where((p) =>
                    p.status.toLowerCase() != 'deleted') // only non-deleted
                .toList();
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
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return ListTile(
                          title: Text(
                            project.name,
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
                                builder: (context) => UpdateProjects(
                                    hiveKey: project.key), // pass Hive key
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
