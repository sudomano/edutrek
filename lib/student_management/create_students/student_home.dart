import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/student_management/add_student.dart';
import 'package:zitf_system/student_management/delete_student.dart';
import 'package:zitf_system/student_management/student_filter.dart';
import 'package:zitf_system/student_management/update_student.dart';

class CreateStudents extends StatefulWidget {
  const CreateStudents({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<CreateStudents> {
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

    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'School Students'),
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
                    buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      'Student Information',
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
                              if (admin || secretary || subadmin)

                                // Elevated cards with icons
                                const ElevatedCard(
                                  icon: Icons.people,
                                  text: 'View  Students',
                                  target: ViewStudentsScreenfilter(),
                                  isLargeScreen: true,
                                ),
                              if (admin || secretary || subadmin)
                                const ElevatedCard(
                                  icon: Icons.person_add,
                                  text: 'Add Student',
                                  target: AddStudentScreen(),
                                  isLargeScreen: true,
                                ),
                              if (admin || secretary || subadmin)
                                const ElevatedCard(
                                  icon: Icons.update,
                                  text: 'Update Student',
                                  target: UpdateStudentScreen(),
                                  isLargeScreen: true,
                                ),
                              if (admin || subadmin)
                                const ElevatedCard(
                                  icon: Icons.delete,
                                  text: 'Delete Student',
                                  target: DeleteStudentScreen(),
                                  isLargeScreen: true,
                                ),
                            ],
                          )
                        : Column(
                            children: [
                              if (admin || secretary || subadmin)

                                // Elevated cards with icons
                                const ElevatedCard(
                                  icon: Icons.people,
                                  text: 'Filter Search Students',
                                  target: ViewStudentsScreenfilter(),
                                  isLargeScreen: false,
                                ),
                              const SizedBox(height: 16),
                              if (admin || secretary || subadmin)

                                // Elevated cards with icons
                                const ElevatedCard(
                                  icon: Icons.person_add,
                                  text: 'Add Student',
                                  target: AddStudentScreen(),
                                  isLargeScreen: false,
                                ),
                              if (admin || secretary || subadmin)
                                const ElevatedCard(
                                  icon: Icons.update,
                                  text: 'Update Student',
                                  target: UpdateStudentScreen(),
                                  isLargeScreen: false,
                                ),
                              if (admin || subadmin)
                                const ElevatedCard(
                                  icon: Icons.delete,
                                  text: 'Delete Student',
                                  target: DeleteStudentScreen(),
                                  isLargeScreen: false,
                                ),
                              if (admin || secretary || subadmin)
                                const ElevatedCard(
                                  icon: Icons.payment,
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
        },
      ),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }
}
