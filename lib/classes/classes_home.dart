// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/classes/create_class.dart';
import 'package:zitf_system/classes/delete_class.dart';
import 'package:zitf_system/classes/search_class.dart';
import 'package:zitf_system/classes/update_class.dart';
import 'package:zitf_system/classes/view_classes.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/student_management/student_filter.dart';
import 'package:zitf_system/student_payments/view_all_paid_students.dart';

class ClassesHomeScreen extends StatefulWidget {
  const ClassesHomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<ClassesHomeScreen> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 School Submission Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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

    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: CustomAppBar(
        title: 'School Classes',
        actions: [
          Tooltip(
            message: 'View Students',
            child: IconButton(
              icon: const Icon(
                Icons.people_rounded,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewStudentsScreenfilter(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
                      child: LayoutBuilder(builder: (context, constrains) {
                        bool isLargeScreen = constraints.maxWidth >= 800;
                        // Adjust crossAxisCount based on screen width
                        int crossAxisCount = 2; // Default 2 items per row
                        double crossAxisSpacing = 16.0;

                        if (constraints.maxWidth >= 1200) {
                          crossAxisCount = 5;
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
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)

                                              // Elevated cards with icons
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'Create New Class',
                                                target: CreateClass(),
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.people,
                                                text: 'View All Classes',
                                                target: ViewClassesScreen(),
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.search,
                                                text: 'Search Class',
                                                target: SearchClassScreen(),
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              _buildElevatedCardWithDialog(
                                                context,
                                                icon: Icons.update,
                                                text: 'Update Class',
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Class',
                                                target: DeleteClassScreen(),
                                                isLargeScreen: true,
                                              ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)

                                              // Elevated cards with icons
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'Create New Class',
                                                target: CreateClass(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.people,
                                                text: 'View All Classes',
                                                target: ViewClassesScreen(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.search,
                                                text: 'Search Class',
                                                target: SearchClassScreen(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              _buildElevatedCardWithDialog(
                                                context,
                                                icon: Icons.update,
                                                text: 'Update Class',
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Class',
                                                target: DeleteClassScreen(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.home,
                                                text: 'Go to Home Page',
                                                target: HomeScreen(),
                                                isLargeScreen: false,
                                              ),
                                          ],
                                        ),
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
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    elevation: 4,
    color: isLargeScreen ? Colors.white : Colors.blueGrey[50],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: InkWell(
      onTap: () async {
        final Box<Classes> box = Hive.box<Classes>('classes');

        // Get all classes matching the globalTermId
        final matchingClasses = box.values
            //       .where((classItem) => classItem.terms!.contains(globalTermId))
            .toList();

        if (matchingClasses.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Center(
                  child: Text(
                    'Select Class to Update',
                    style: GoogleFonts.montserrat(
                      fontSize: isLargeScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    // Wrap ListView with SingleChildScrollView
                    child: ListBody(
                      children: matchingClasses.map((currentClass) {
                        return ListTile(
                          title: Text(
                            currentClass.className,
                            style: GoogleFonts.montserrat(
                              fontSize: isLargeScreen ? 14 : 16,
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UpdateClassScreen(
                                  classCode: currentClass
                                      .classCode!, // ✅ Force unwrap (only if sure it's non-null)
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No classes available for the current term.',
                style: GoogleFonts.montserrat(
                  fontSize: isLargeScreen ? 14 : 16,
                  color: Colors.white,
                ),
              ),
              backgroundColor:
                  isLargeScreen ? Colors.blue.shade700 : Colors.redAccent,
            ),
          );
        }
      },
      child: Padding(
        padding: isLargeScreen
            ? const EdgeInsets.all(8.0)
            : const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: isLargeScreen
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: const Color.fromARGB(255, 0, 42, 89),
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: const Color.fromARGB(255, 0, 0, 0),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    ),
  );
}
